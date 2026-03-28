# Domain Pitfalls: Agent Execution + Streaming + Webhooks

**Domain:** Subprocess execution, streaming output, HTTP webhook delivery, live streaming UI
**Stack:** Rails 8 + SQLite + Solid Queue + Action Cable
**Researched:** 2026-03-28
**Scope:** v1.4 Agent Execution milestone

---

## Critical Pitfalls

Mistakes that cause rewrites, data loss, or production outages.

---

### Pitfall 1: Open3.popen3 stdout/stderr Deadlock

**What goes wrong:** The job spawns the Claude CLI with `Open3.popen3`. It reads from stdout in a loop while ignoring stderr (or reads them sequentially). The stderr buffer fills to its OS-level capacity (~64KB on Linux, ~4KB on macOS). The Claude process blocks trying to write more stderr. The parent thread is stuck waiting on stdout. Neither can proceed. The job hangs forever.

**Why it happens:** `Open3.popen3` exposes both stdout and stderr as IO objects backed by OS pipes. Pipes have fixed-capacity kernel buffers. A process writing to a full pipe blocks until the reader drains it. Reading streams sequentially guarantees one is always unread while the other is being drained.

**Consequences:** Solid Queue job holds its thread indefinitely. Depending on thread count, the entire worker stalls. SQLite write lock is held (if a transaction was open). No timeout rescues this — `Timeout` module is explicitly incompatible with `Open3` per ruby-core guidance.

**Prevention:**
- Use two threads, one per stream, both running concurrently. Join both before calling `wait_thr.value`.
- Or use `IO.select` with `read_nonblock` to multiplex both streams without threads. This is ~4x faster for high-volume output but harder to write correctly.
- Never read stdout then stderr sequentially in the same thread.
- Use `Open3.popen2e` (merges stderr into stdout) as a simpler alternative if separate stderr handling is not required.

**Detection:** Job hangs without producing output or raising an exception. No log lines after spawn. Thread is alive but doing no work.

**Confidence:** HIGH — documented in Ruby stdlib, confirmed by independent analysis at dmytro.sh.

---

### Pitfall 2: Claude CLI stdout Not Flushed When Piped

**What goes wrong:** The Rails job reads from the Claude CLI subprocess using a pipe. In TTY mode (terminal) the CLI flushes after each JSON line. When stdout is a pipe (not a TTY), the Node.js process behind `claude` uses block buffering. JSON lines accumulate in the 4-8KB kernel buffer and do not appear until the buffer fills or the process exits. From Rails, output appears to arrive in bursts or not at all during execution.

**Why it happens:** This is a confirmed upstream bug in Claude Code CLI (issue #25670, closed as duplicate of #25629). The CLI does not force `--output-format stream-json` to line-flush when stdout is non-TTY. `stdbuf -oL` is not available on macOS.

**Consequences:** Real-time streaming to the browser via Action Cable is delayed or arrives in chunks. The "live" experience is broken. The job may appear stalled. Worse, if the job has a timeout and the subprocess is killed mid-buffer, the last partial JSON line never arrives.

**Prevention:**
- Use PTY (`require 'pty'`) to spawn the subprocess under a pseudo-terminal. The CLI detects a TTY and enables line-buffered output. This is the only reliable cross-platform workaround.
- Alternatively, use `unbuffer` (util from `expect` package) on Linux deployments: `unbuffer claude -p ...`
- Do not rely on `IO.select` timeouts to detect stalls — they will fire even when data is buffered but not yet delivered to the pipe.
- When using PTY: handle `Errno::EIO` (raised when the child closes the PTY master) as the normal end-of-output signal, not an error.

**Detection:** Output appears in large batches rather than line-by-line. `ActionCable.server.broadcast` is called infrequently despite Claude actively generating text.

**Confidence:** HIGH — confirmed upstream issue with linked GitHub issue and reproduction steps.

---

### Pitfall 3: Zombie Subprocess When Job Is Cancelled or Times Out

**What goes wrong:** A Solid Queue job is interrupted (cancelled via the UI, killed by a deployer, or times out). The Rails job thread is killed. The Claude CLI subprocess continues running, consuming API credits and CPU. Because no parent ever calls `Process.wait`, the OS keeps the process entry in the process table as a zombie after it eventually exits.

**Why it happens:** `Process.spawn` / `Open3.popen3` creates a child process. The parent (Rails job thread) must call `wait` or `detach` on the child PID. If the thread is killed without cleanup, neither happens. Multiple job retries (each spawning a new CLI process) compound this.

**Consequences:** Runaway Claude CLI processes accumulating over time. API credits consumed for cancelled runs. Zombie processes accumulating in the process table. If the system runs out of PIDs (rare but possible at scale), new processes cannot be spawned.

**Prevention:**
- Capture the child PID from `Open3.popen3` or `Process.spawn` immediately after spawn.
- Use `ensure` in the job `perform` method to run cleanup on any exit path:
  ```ruby
  ensure
    Process.kill("TERM", child_pid) if child_pid
    Process.wait(child_pid) rescue nil
  ```
- Use `Process.detach(child_pid)` if the job does not need to wait for exit status (lets a separate Ruby thread reap the status automatically).
- Store the child PID in the job or a DB record so a separate cleanup job can kill orphaned processes on restart.

**Detection:** `ps aux | grep claude` shows multiple claude processes. Job records are marked failed/cancelled but processes are still running.

**Confidence:** HIGH — Ruby Process documentation + confirmed patterns from production Rails subprocess usage.

---

### Pitfall 4: SQLite Write Lock Contention Under Long-Running Jobs

**What goes wrong:** A long-running Solid Queue job periodically writes execution log lines, status updates, and audit events to SQLite while the web process is also writing (enqueuing jobs, recording heartbeats, Solid Queue's own heartbeat writes). Because SQLite allows only one writer at a time, one writer blocks until the other finishes. With multiple concurrent Solid Queue workers (each writing log lines every few seconds), a "database is locked" error erupts even with `busy_timeout` set.

**Why it happens:** SQLite WAL mode allows one writer + multiple readers. It does NOT allow multiple concurrent writers. Solid Queue's internal heartbeat mechanism writes frequently. When a long-running job also writes frequently (per-line execution logs), write contention multiplies. The standard C-level `busy_timeout` holds the Ruby GVL while waiting, preventing other threads from making progress. Deferred transactions (pre-Rails 8 default) can deadlock because the lock is not acquired until first write — if two transactions each need a lock they can reach stalemate.

**Consequences:** `SQLite3::BusyException: database is locked` in jobs. Execution log lines are lost. Audit events are silently dropped if errors are rescued. Job retries increase write pressure (making it worse). Database corruption has been reported in Solid Queue SQLite issues (#324).

**Prevention:**
- Use `IMMEDIATE` transaction mode — Rails 8 defaults to this, which acquires the write lock at transaction start and enables proper retry via the custom Ruby busy handler.
- Ensure `activerecord-enhancedsqlite3-adapter` or equivalent is providing the custom Ruby-level busy handler (releases GVL while waiting). Verify this is configured in `database.yml` for all three SQLite connections (primary, queue, cable).
- Set `timeout: 5000` (milliseconds) in `database.yml` — the default is too low under Solid Queue's own write pressure.
- Batch execution log writes: accumulate lines in memory and flush every N lines or every X seconds rather than writing each line individually.
- Use a separate SQLite database file for execution logs (not the primary DB) to isolate write pressure.
- Avoid holding long-running transactions open while waiting for subprocess output — write in short, discrete transactions.

**Detection:** `SQLite3::BusyException` in logs. Jobs retried frequently. Execution logs have gaps.

**Confidence:** HIGH — Confirmed in Rails 8 release notes, Solid Queue issues #309 and #324, and fractaledmind.com analysis.

---

### Pitfall 5: Action Cable Broadcast Flooding the Client

**What goes wrong:** The job reads Claude CLI output character by character (or token by token with `--include-partial-messages`) and broadcasts every token to Action Cable. With a 5,000-word response, this means thousands of `ActionCable.server.broadcast` calls over ~30 seconds. The browser's WebSocket message queue fills. The client-side Stimulus/Turbo controller cannot apply DOM updates fast enough. The browser slows down or crashes. With Solid Cable (SQLite-backed), each broadcast is a DB write — combined with the job's own writes, this exhausts the SQLite write budget.

**Why it happens:** There is no built-in backpressure mechanism between `ActionCable.server.broadcast` in a background thread and the WebSocket client. The server writes as fast as it can; the client receives as fast as the TCP stack delivers. Excessive broadcasts are expensive at the DB level with Solid Cable.

**Consequences:** Browser memory spikes. UI lag or freeze. SQLite lock contention from broadcast writes. With Solid Cable using the same SQLite file, the double-write pressure from job logs + broadcasts causes `BusyException`.

**Prevention:**
- Batch output lines before broadcasting: buffer N lines (e.g., 5-10) or accumulate over a short interval (e.g., 100ms) and broadcast once.
- Use a separate SQLite DB file for Solid Cable (separate from the primary and queue DBs). Rails 8 already provisions this separately — verify configuration.
- Broadcast structured diff updates (append new content) rather than full state replacement — smaller payloads per broadcast.
- Never broadcast on every partial token from `--include-partial-messages`. Buffer at the line level at minimum.
- Cap maximum broadcast rate with a simple time-gating mechanism in the job.

**Detection:** Browser devtools show hundreds of WebSocket messages per second. RAM in browser tab climbs during agent runs. DB logs show high write rate correlated with broadcasts.

**Confidence:** HIGH — Action Cable issue #42336 (stale threshold with many events) + confirmed Solid Queue/Cable SQLite write pressure in issue #309.

---

## Moderate Pitfalls

---

### Pitfall 6: ActiveRecord Connection Not Returned to Pool During Subprocess Wait

**What goes wrong:** The Solid Queue job thread checks out a database connection at job start (implicitly via any AR query). The job then enters a subprocess read loop (blocking on subprocess output for potentially minutes). The connection remains checked out for the entire duration. Other threads needing connections for short writes (heartbeats, broadcasts) time out with `ActiveRecord::ConnectionTimeoutError`.

**Why it happens:** Rails 7.2+ changed connection lease granularity from per-job to per-query. However, explicit transactions or manual connection use still hold the connection for the transaction duration. Long loops without AR calls keep the connection checked out if it was checked out before the loop.

**Prevention:**
- Ensure all database writes during the execution loop use short transactions that immediately release the connection.
- Avoid calling `ActiveRecord::Base.connection` directly in long loops. Use model-level operations which benefit from Rails 7.2+ per-query lease semantics.
- Configure connection pool size to account for Solid Queue threads + Puma threads + Action Cable threads: `pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 }.to_i + 2 %>`.
- As of Rails 8 / Solid Queue, set `threads` in `queue.yml` to no more than `pool_size - 2`.

**Detection:** `ActiveRecord::ConnectionTimeoutError` during agent runs. Connection pool exhaustion errors correlated with long-running jobs.

**Confidence:** MEDIUM — Supported by Rails connection pool documentation and BigBinary blog analysis. Rails 7.2 change partially mitigates but does not eliminate.

---

### Pitfall 7: HTTP Webhook Timeout Blocking the Solid Queue Thread

**What goes wrong:** A Solid Queue job makes an HTTP POST to an external agent URL. The external server is slow or unresponsive. The `Net::HTTP` default timeout is 60 seconds of read timeout. The thread blocks for a full minute. With 5 threads in the worker, if 5 agents run simultaneously against 5 slow endpoints, the entire worker is stalled — no other jobs execute.

**Why it happens:** `Net::HTTP` requires explicit timeout configuration. The Rails default does not set a read timeout. External URLs can hang indefinitely on TCP accept, SSL handshake, or slow response.

**Prevention:**
- Set explicit timeouts on every outbound HTTP call: `open_timeout: 5, read_timeout: 15, write_timeout: 10` as sensible defaults for webhook delivery.
- Use Faraday or a wrapper that enforces timeout as part of the connection adapter rather than relying on Net::HTTP's optional timeout.
- Treat the webhook delivery as a separate job with its own retry budget, decoupled from the main execution job.
- Implement exponential backoff for retries: `retry_on StandardError, wait: :exponentially_longer, attempts: 5`.

**Detection:** Solid Queue worker threads all in `sleep`/`select` state during agent runs. No jobs processing despite the queue being non-empty.

**Confidence:** HIGH — Confirmed by ankane/the-ultimate-guide-to-ruby-timeouts and Faraday documentation.

---

### Pitfall 8: Non-Idempotent Webhook Delivery on Job Retry

**What goes wrong:** The HTTP POST to an external agent URL succeeds (200 OK), but the subsequent database write (marking delivery as complete) fails with a SQLite lock error. Solid Queue retries the job. The webhook is delivered a second time. The receiving endpoint performs the action twice (double charge, duplicate task, etc.).

**Why it happens:** Job retries are atomic from Solid Queue's perspective but not from the external system's perspective. A job that partially completes (external call succeeds, DB write fails) is retried from the beginning.

**Prevention:**
- Generate and store a delivery idempotency key before the HTTP call. Pass it as `X-Idempotency-Key` header.
- Check for existing successful delivery records before attempting the POST.
- Separate the HTTP delivery step into its own job with idempotency-aware enqueue: if a delivery record exists and is marked `delivered`, the job is a no-op.
- Prefer `perform_later` after the transaction commits, not inside it — reduces the chance of mid-transaction failures.

**Detection:** External agents report duplicate executions correlated with Solid Queue retry storms.

**Confidence:** MEDIUM — General webhook idempotency pattern confirmed by multiple sources; specific Solid Queue SQLite retry storm confirmed in issue #309.

---

### Pitfall 9: Claude CLI Session Corruption from Concurrent Processes

**What goes wrong:** Multiple agent jobs run simultaneously, each spawning a `claude` CLI subprocess. The CLI writes to `~/.claude/claude.json` for session state. Concurrent writes from multiple processes corrupt this file (partial writes, truncated JSON). On next startup, the CLI fails with "JSON Parse error: Unexpected EOF". All subsequent Claude CLI invocations fail until the file is manually repaired.

**Why it happens:** The Claude CLI does not use atomic writes or file locking for its session config file. This is a confirmed upstream bug (issue #29051). Multiple concurrent spawns in a single Rails deployment will trigger it reliably under load.

**Prevention:**
- Use `--bare` flag for all programmatic invocations (`claude -p --bare`). Bare mode skips OAuth and keychain reads, significantly reducing config file interaction.
- Use `--no-update-settings` if available, to prevent writing back to the session config.
- Run each Claude CLI invocation with a distinct `HOME` directory (via env override) to isolate config files per-execution. This is the most reliable isolation strategy.
- Pass `ANTHROPIC_API_KEY` via environment variable rather than relying on stored credentials — eliminates the need for Claude to read/write auth config.
- Monitor `~/.claude/claude.json` for corruption in health checks.

**Detection:** All Claude CLI subprocesses start failing with parse errors. Error appears after a period of concurrent job execution.

**Confidence:** HIGH — Confirmed upstream GitHub issue #29051 with reproduction steps.

---

### Pitfall 10: Missing "result" Event in stream-json Output Causes Infinite Loop

**What goes wrong:** The job reads Claude CLI stream-json output in a loop, waiting for a `{"type":"result",...}` event that signals completion. Due to a Claude CLI bug, this final event is sometimes not emitted after tool execution completes. The subprocess exits (pipe closes), but the job's line-reading loop treats pipe close differently from a result event. If the loop waits for the result event rather than checking for EOF, it hangs forever or miscategorizes the run as incomplete.

**Why it happens:** Confirmed upstream bug (issue #8126): Claude Code CLI sometimes omits the final result event in streaming JSON mode. The issue is intermittent and appears after complex tool execution.

**Prevention:**
- Treat EOF on the subprocess pipe (stdout closed, `wait_thr.value` returns) as an authoritative completion signal, regardless of whether a `result` event was seen.
- Do not gate job completion on receiving a `result` event type — use `wait_thr.value` (blocking on process exit) as the definitive end signal.
- Parse result status from the process exit code in addition to the JSON stream: exit 0 = success, non-zero = failure.
- Set a job-level timeout as a last resort (not `Timeout` module — see Pitfall 1 — but a periodic check against a wall-clock deadline).

**Detection:** Jobs that run successfully from the user's perspective never transition to "complete" status. Subprocess has exited (verified via `ps`), but job is still in running state.

**Confidence:** HIGH — Confirmed upstream issue #8126 with multiple reporter confirmations.

---

## Minor Pitfalls

---

### Pitfall 11: Solid Queue Thread Count Misconfigured vs. Connection Pool

**What goes wrong:** `config/queue.yml` sets `threads: 10`. `config/database.yml` has `pool: 5`. Solid Queue starts 10 worker threads. Each thread checks out a connection. 5 threads get connections; 5 threads wait. When the wait times out, jobs fail with `ActiveRecord::ConnectionTimeoutError`. This is easy to overlook because the errors appear in job logs rather than in web request logs.

**Prevention:** Set `threads` in `queue.yml` to at most `pool_size - 2` (reserve 2 for Solid Queue's internal polling/heartbeat connections). For three SQLite DBs (primary, queue, cable), ensure each `database.yml` entry has an appropriate pool size.

**Confidence:** HIGH — Documented in Solid Queue README and confirmed in issue #271.

---

### Pitfall 12: Enqueueing Jobs Inside a Transaction Causes Lock Escalation

**What goes wrong:** An agent status update (e.g., marking execution as started) happens inside an `ActiveRecord::Base.transaction` block. Inside the same block, `ExecuteAgentJob.perform_later` is called. With SQLite IMMEDIATE mode (Rails 8 default), the write lock is held for the entire transaction including the enqueue. Solid Queue's queue writer also needs the lock. The enqueue blocks, extending the transaction duration, which increases contention.

**Prevention:** Enqueue jobs after the transaction commits. Use `after_commit` callbacks for job enqueueing, or `perform_later` outside the transaction block. Rails 8 `after_commit_everywhere` pattern or `after_create_commit` on models are the idiomatic solutions.

**Confidence:** HIGH — Confirmed as root cause in Solid Queue issue #309.

---

### Pitfall 13: ANTHROPIC_API_KEY Not Propagated to Subprocess Environment

**What goes wrong:** The Rails app has `ANTHROPIC_API_KEY` in its environment. The job spawns the Claude CLI subprocess. On some deployment configurations (Docker, Kamal with environment filtering), the child process does not inherit the parent's environment. The CLI fails with authentication error.

**Prevention:** Explicitly pass environment variables when spawning:
```ruby
env = { "ANTHROPIC_API_KEY" => ENV.fetch("ANTHROPIC_API_KEY") }
Open3.popen3(env, "claude", "-p", "--bare", ...)
```
Never rely on implicit environment inheritance in production subprocesses.

**Confidence:** MEDIUM — Inferred from Claude CLI `--bare` documentation ("authentication must come from ANTHROPIC_API_KEY") and Docker environment isolation behavior.

---

### Pitfall 14: PTY Raises Errno::EIO Treated as Error

**What goes wrong:** The job uses PTY to force line-buffered output (workaround for Pitfall 2). When the subprocess exits, the PTY master raises `Errno::EIO` on the next read. The job's error handling rescues this as an unexpected error, marks the execution as failed, and retries — spawning a new Claude process.

**Why it happens:** `Errno::EIO` (Input/Output error) is the normal signal that a PTY master raises when the child process closes the slave end. It is not an error — it signals end-of-output.

**Prevention:** Rescue `Errno::EIO` explicitly in the PTY read loop and treat it as the normal loop-termination condition:
```ruby
rescue Errno::EIO
  # Normal: PTY master closed by child exit
  break
```

**Detection:** Executions that complete successfully are marked as failed. Multiple Claude CLI processes spawned per execution run.

**Confidence:** HIGH — Standard Ruby PTY behavior documented in Ruby stdlib and widely referenced in PTY usage guides.

---

### Pitfall 15: Turbo Stream Channel Subscription Before Job Starts

**What goes wrong:** The browser subscribes to a Turbo Stream channel for a specific execution run. The background job has not started yet (Solid Queue queue lag). There is a race: the subscription is established, the job starts and immediately broadcasts its first output lines, but the browser has not yet confirmed the subscription. Output lines are lost for the first few seconds.

**Prevention:** Design the execution start UI to show a "waiting for agent" state until the first broadcast arrives. Send an explicit "started" broadcast from the job as the very first action (before any Claude output), which confirms the channel is active. On the client side, use a loading indicator that transitions to live output only on receipt of the first message — do not assume output starts immediately.

**Confidence:** MEDIUM — Inferred from Action Cable WebSocket subscription timing and Turbo Stream channel lifecycle behavior.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Subprocess spawn (any phase) | Open3 deadlock (Pitfall 1) | Use PTY or two-thread read from day one — do not ship single-stream reads |
| Claude CLI integration | stdout buffering (Pitfall 2) | Adopt PTY in the first working prototype; validate with a long response |
| Subprocess spawn (any phase) | Zombie processes (Pitfall 3) | Add `ensure` cleanup block in the very first job implementation |
| Execution log writes | SQLite contention (Pitfall 4) | Batch writes; use separate DB file for logs; verify IMMEDIATE mode config |
| Live output streaming | Action Cable flooding (Pitfall 5) | Gate broadcasts at 100ms intervals from the first streaming prototype |
| HTTP webhook delivery | Thread blocking (Pitfall 7) | Set explicit timeouts before first external call; test with a slow endpoint |
| HTTP webhook delivery | Double-delivery (Pitfall 8) | Implement idempotency key before first external call |
| Claude CLI integration | Session file corruption (Pitfall 9) | Always use `--bare` and explicit `ANTHROPIC_API_KEY` env injection |
| Claude CLI result parsing | Missing result event (Pitfall 10) | Use process exit code as ground truth for completion status |
| Job implementation | Transaction + enqueue (Pitfall 12) | Use after_commit for job enqueueing; never enqueue inside write transactions |

---

## Sources

- [On dangers of Open3.popen3 — Dmytro on Things](https://dmytro.sh/blog/on-dangers-of-open3-popen3/) — HIGH confidence
- [Ruby Subprocesses with stdout and stderr Streams — Nick Charlton](https://nickcharlton.net/posts/ruby-subprocesses-with-stdout-stderr-streams.html) — HIGH confidence
- [claude -p with --output-format stream-json does not flush stdout when piped — GitHub #25670](https://github.com/anthropics/claude-code/issues/25670) — HIGH confidence (confirmed upstream bug)
- [Sometimes missing result in --output-format stream-json — GitHub #8126](https://github.com/anthropics/claude-code/issues/8126) — HIGH confidence (confirmed upstream bug)
- [claude.json corrupted by concurrent writes — GitHub #29051](https://github.com/anthropics/claude-code/issues/29051) — HIGH confidence (confirmed upstream bug)
- [Run Claude Code programmatically — Claude Code Docs](https://code.claude.com/docs/en/headless) — HIGH confidence (official docs)
- [SQLite database is locked in Rails 8 — Alexander Williams](https://a1w.ca/p/2024-10-29-sqlite-database-is-locked-rails-8/) — HIGH confidence
- [SQLite on Rails — Improving concurrency — fractaledmind.com](https://fractaledmind.com/2023/12/11/sqlite-on-rails-improving-concurrency/) — HIGH confidence
- [SQLite3::BusyException: database is locked — Solid Queue #309](https://github.com/rails/solid_queue/issues/309) — HIGH confidence (confirmed issue)
- [SQLite queue database corruption — Solid Queue #324](https://github.com/rails/solid_queue/issues/324) — HIGH confidence (confirmed issue)
- [ActionCable connection becomes stale with large number of consecutive events — Rails #42336](https://github.com/rails/rails/issues/42336) — MEDIUM confidence
- [DB connection pool size — Solid Queue #271](https://github.com/rails/solid_queue/issues/271) — HIGH confidence
- [The Ultimate Guide to Ruby Timeouts — ankane](https://github.com/ankane/the-ultimate-guide-to-ruby-timeouts/blob/master/README.md) — HIGH confidence
- [SQLite concurrent writes and "database is locked" errors — tenthousandmeters.com](https://tenthousandmeters.com/blog/sqlite-concurrent-writes-and-database-is-locked-errors/) — HIGH confidence
- [Write-Ahead Logging — SQLite official documentation](https://www.sqlite.org/wal.html) — HIGH confidence
- [Ruby Graceful Application Shutdown with SignalException — Kirill Shevchenko](https://kirillshevch.medium.com/ruby-graceful-application-shutdown-with-signalexeption-and-sigterm-213d45d4ef6d) — MEDIUM confidence
- [AnyCable for Ruby on Rails — AppSignal](https://blog.appsignal.com/2024/05/01/anycable-for-ruby-on-rails-how-does-it-improve-over-action-cable.html) — MEDIUM confidence
- [Webhook Retry Best Practices — hookdeck.com](https://hookdeck.com/outpost/guides/outbound-webhook-retry-best-practices) — MEDIUM confidence
- [Concurrency and Database Connections in Ruby — Heroku Dev Center](https://devcenter.heroku.com/articles/concurrency-and-database-connections) — HIGH confidence
