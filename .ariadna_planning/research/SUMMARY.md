# Project Research Summary

**Project:** Director — v1.4 Agent Execution milestone
**Domain:** AI agent orchestration platform — subprocess lifecycle, streaming output, HTTP delivery
**Researched:** 2026-03-28
**Confidence:** HIGH

## Executive Summary

Director v1.4 transforms the agent execution pipeline from a collection of stubbed no-ops into a working system that actually invokes AI agents. Three adapter types need real implementation: `claude_local` (spawns the Claude CLI as a subprocess), `http` (fires a real POST to an external agent URL), and `process` (runs an arbitrary shell command). All the Rails infrastructure for this already exists — Action Cable, Turbo Streams, Solid Queue, and the BaseAdapter scaffold are in place. The milestone is fundamentally a plumbing exercise: wire real execution into the stubs, stream output to the browser, and persist results durably.

The recommended technical approach uses zero new gems. `Open3.popen2e` handles subprocess spawning for both Claude and process adapters; `Net::HTTP` covers HTTP delivery. `Turbo::StreamsChannel.broadcast_append_to` provides live output streaming without a custom Action Cable channel class. The one architectural addition this milestone requires is an `AgentRun` model — a persistent execution record that owns lifecycle state (queued/running/completed/failed), the accumulated log, session identifiers for Claude resumption, cost data, and exit codes. All three execution services write through this model and broadcast through the same Turbo Streams pattern already used elsewhere in the codebase.

The dominant risks are all subprocess-related and well-documented. The Claude CLI has two confirmed bugs: stdout is block-buffered when piped (output arrives in batches, not lines), and the final `result` JSON event is sometimes omitted. The concurrent-write hazard in `~/.claude/claude.json` corrupts session state when multiple CLI processes run simultaneously. SQLite write contention is a real concern when execution log writes, Solid Cable broadcasts, and Solid Queue heartbeats all hit the database concurrently. These risks have known mitigations — PTY spawning for buffering, exit-code-as-ground-truth for missing result events, `--bare` with explicit `ANTHROPIC_API_KEY` for session isolation, and batched log writes to keep SQLite pressure manageable — and they must be applied from the first working prototype, not retrofitted later.

## Key Findings

### Recommended Stack

All required capabilities are already available in the Ruby stdlib and in gems already present in the Gemfile. No new gems are needed for v1.4. `Open3` (stdlib) handles subprocess management; `Net::HTTP` (stdlib) handles HTTP delivery; `turbo-rails` (already in Gemfile) provides `Turbo::StreamsChannel` for live output broadcast; Solid Queue (already running) handles background job dispatch.

The one deferred addition worth flagging: `faraday ~> 2.14` plus `faraday-retry ~> 2.2` for HTTP retry with exponential backoff on webhook delivery. `Net::HTTP` is sufficient for v1.4 fire-and-forget delivery. Add Faraday in v1.5 if retry behaviour is required.

**Ruby & Rails version:**
- Rails 8.1 + Ruby 3.x already in use — no changes needed; constraints are fully satisfied

**Subprocess:**
- `Open3.popen2e` (stdlib) — combined stdout+stderr avoids the two-thread deadlock requirement of `popen3`

**HTTP delivery:**
- `Net::HTTP` (stdlib) — sufficient for v1.4 synchronous POST to external agent URLs

**Real-time streaming:**
- `Turbo::StreamsChannel.broadcast_append_to` (turbo-rails, already in Gemfile) — no new channel class needed; matches existing dashboard broadcast pattern

**Background jobs:**
- Solid Queue (already configured) — add a dedicated `execution` queue to isolate long-running subprocess jobs from short `default` queue work

**Session management:**
- `adapter_config["session_id"]` on `Agent` model — store Claude session ID between runs; pass `--resume` on subsequent invocations

**Total new gems for v1.4: zero.**

### Expected Features

**Must have (table stakes):**
- Claude CLI subprocess spawning with `--output-format stream-json --bare --no-session-persistence` — the core deliverable; currently a no-op
- Real HTTP POST delivery in `WakeAgentService#deliver_http` — replaces existing TODO stub
- Agent status transitions (`idle → running → idle/error`) reflecting real execution state
- Streaming output rendered in task/agent-run view while agent is active
- Error capture: subprocess stderr, HTTP failures, timeouts stored durably in `AgentRun`
- Session ID persistence — capture from Claude `result` event; store in `adapter_config`
- Result callback API — `POST /api/tasks/:id/result` so agents can report completion and wake their manager

**Should have (differentiators):**
- Session resumption — pass `--resume <session_id>` on subsequent invocations for the same agent
- Tool-use indicators in stream UI — parse `content_block_start` events and show `[Using Bash...]`
- Execution cancellation — kill subprocess via stored PID, mark run cancelled
- Budget-gated execution start — block spawn if `agent.budget_exhausted?` (already on model)
- Cost tracking — write `total_cost_usd` from Claude result event to `AgentRun#cost_cents`

**Defer to v1.5+:**
- Webhook signature verification (HMAC) on outbound HTTP delivery
- Multi-agent concurrent execution (need single-agent stability first)
- Faraday-based retry with exponential backoff for HTTP adapter
- Fork-based session management (state explosion risk)

### Architecture Approach

The execution architecture is a thin service layer sitting between `WakeAgentService` and the existing Action Cable infrastructure. `WakeAgentService#deliver` stops dispatching to stubs and instead enqueues `ExecuteAgentJob`, which creates an `AgentRun` record, then delegates to one of three execution services (`ClaudeExecutionService`, `ProcessExecutionService`, `HttpExecutionService`). Each service owns the full lifecycle for its adapter type: spawning, output accumulation, broadcasting, and writing the final result back to `AgentRun`.

**Application structure:**

1. **Data model** — `AgentRun` (new) owns execution lifecycle state, session IDs, log text, cost, exit code. `HeartbeatEvent` links to `AgentRun` via nullable FK. `Agent` gains `has_many :agent_runs`.
2. **Service layer** — `ClaudeExecutionService`, `ProcessExecutionService`, `HttpExecutionService` each follow the existing `self.call(agent, run) = new(agent, run).call` pattern and the `mark_failed! then re-raise` rescue pattern from `ExecuteHookService`.
3. **Job layer** — `ExecuteAgentJob` enqueues from `WakeAgentService`, creates `AgentRun`, delegates to service. Uses same `find_by + return unless + state check` guard pattern as `ExecuteHookJob`.
4. **Controller layer** — `AgentRunsController` (nested under agents) for execution history and live view. `Api::AgentRunsController` (extending `Api::AgentEventsController`) for agent result callbacks.
5. **View/streaming layer** — `agent_runs/show.html.erb` with `turbo_stream_from "agent_run_#{@run.id}"`. No custom Action Cable channel class — `Turbo::StreamsChannel` is sufficient for unidirectional output streaming.
6. **Broadcast pattern** — `Turbo::StreamsChannel.broadcast_append_to` from inside the execution service, one call per buffered chunk (not per token). Accumulated-text replacement strategy preferred over delta+sequence for correctness.

**Key subprocess pattern:** Use `Open3.popen2e` (not `popen3`) for all adapter services. Combined stdout+stderr eliminates the two-thread deadlock requirement. For Claude specifically, consider PTY spawning to work around the stdout buffering bug.

### Critical Pitfalls

1. **Open3.popen3 stdout/stderr deadlock** — reading stdout and stderr sequentially causes the parent to block when the 64KB stderr pipe buffer fills. Prevention: use `Open3.popen2e` (combined stream) for all adapter services. Do not use `popen3` without concurrent threads draining both streams.

2. **Claude CLI stdout block-buffering when piped** — confirmed upstream bug (#25670): the CLI does not line-flush `--output-format stream-json` when stdout is a pipe (non-TTY). Output arrives in batches or all at once on process exit. Prevention: spawn under PTY (`require 'pty'`), which tricks the CLI into line-buffered mode. Rescue `Errno::EIO` as normal loop termination (not an error) when using PTY.

3. **Missing `result` event in stream-json output** — confirmed upstream bug (#8126): the final `{"type":"result",...}` event is sometimes not emitted. Prevention: use process exit code (`wait_thr.value.exitstatus`) as the authoritative completion signal. Never gate job completion on receiving a result event type.

4. **Concurrent Claude CLI session file corruption** — confirmed upstream bug (#29051): concurrent processes write to `~/.claude/claude.json` without locking, causing JSON corruption. Prevention: always use `--bare` flag (skips config reads/writes); pass `ANTHROPIC_API_KEY` explicitly in `Open3` env hash; optionally set a per-job `HOME` env override to isolate config files completely.

5. **SQLite write contention under long-running jobs** — execution log writes + Solid Cable broadcast writes + Solid Queue heartbeat writes all contend for the SQLite write lock. Prevention: batch log writes (accumulate N lines, flush every 5-10 lines); verify `IMMEDIATE` transaction mode and Ruby-level busy handler are configured; use separate SQLite DB files for queue and cable (Rails 8 default — verify configuration); set `timeout: 5000` in `database.yml`.

6. **Action Cable broadcast flooding** — broadcasting every partial token from `--include-partial-messages` generates thousands of DB writes per run via Solid Cable, causing browser slowdown and SQLite pressure. Prevention: buffer at minimum 100ms intervals or 5-10 lines before broadcasting. Start with accumulated-text replacement (full output so far) rather than deltas — simpler, correct, lower broadcast frequency.

7. **Agent status stuck as `:running` on job failure** — if the job fails mid-execution and is retried, a second execution path opens on the same agent. Prevention: `ExecuteAgentJob` rescue must call `agent.update_column(:status, :idle)` before re-raising. Add an orphan-recovery recurring job that finds `AgentRun` records with `status: :running` and `started_at < 30.minutes.ago` and marks them failed.

## Implications for Roadmap

Based on combined research, four phases are needed. Dependencies drive the order.

### Phase 22: AgentRun Data Model and Job Dispatch

**Rationale:** All three execution services need the `AgentRun` table before they can do anything. No streaming, no UI, no real execution can proceed without the persistent execution record. This phase is the foundation.

**Delivers:** `agent_runs` migration; `AgentRun` model with `mark_running!`, `mark_completed!`, `mark_failed!` state machine methods; `ExecuteAgentJob` skeleton; `WakeAgentService#deliver` modified to enqueue `ExecuteAgentJob` instead of calling stubs.

**Addresses:** Agent status transitions (idle → running → idle/error); error capture and storage in `AgentRun`.

**Avoids:** Broadcasting before `run.id` exists (stream name becomes garbage); agent status stuck as `:running` on retry (rescue pattern in job from day one).

**Stack elements:** Rails migration, integer enum, existing `mark_*!` pattern from `HookExecution`, Solid Queue with dedicated `execution` queue.

**Research flag:** Standard Rails patterns — no additional research needed.

### Phase 23: HTTP and Process Adapter Real Execution

**Rationale:** HTTP and process adapters are simpler than Claude — no streaming, no JSON parsing, no session state. Implementing them first validates the `AgentRun` model, the `ExecuteAgentJob` dispatch chain, and the `HttpExecutionService` pattern (which reuses `ExecuteHookService`'s Net::HTTP code) before tackling the complex Claude adapter.

**Delivers:** `HttpExecutionService` (real Net::HTTP POST with explicit timeouts, error classification, retry delegation); `ProcessExecutionService` (Open3.popen2e subprocess with output accumulation); both wired into `BaseAdapter.execute` interface; `HttpAdapter` and `ProcessAdapter` fully implemented.

**Addresses:** HTTP adapter delivery (replaces TODO stub); process adapter (currently no-op); idempotency key for webhook delivery to prevent double-delivery on job retry.

**Avoids:** Thread-blocking HTTP timeouts (explicit `open_timeout: 5, read_timeout: 15`); non-idempotent delivery on retry (idempotency key before HTTP call); shell injection (always use array form with `Open3.popen2e`).

**Stack elements:** `Net::HTTP` stdlib, `Open3` stdlib, `webmock` (already in Gemfile from Phase 19).

**Research flag:** Standard patterns — reuse `ExecuteHookService` approach, no additional research needed.

### Phase 24: Claude CLI Execution and Session Resumption

**Rationale:** The most complex adapter — subprocess spawning with stream-JSON parsing, PTY for buffering, session ID capture, and resumption logic. Depends on `AgentRun` for `session_id_before/session_id_after` columns. Isolated in its own phase because the Claude-specific bugs (buffering, missing result event, session corruption) need careful handling.

**Delivers:** `ClaudeExecutionService` with PTY-based spawning, stream-JSON line-by-line parsing, session ID capture on completion, `--resume` flag on subsequent runs; `ClaudeLocalAdapter` fully implemented; "Clear Session" action on agent; session ID displayed in agent show view.

**Addresses:** Claude subprocess spawning; session ID persistence and resumption; cost tracking from `total_cost_usd`; budget-gated execution start.

**Avoids:** stdout block-buffering (PTY from the first prototype); missing result event (exit code as ground truth); session file corruption (`--bare` + explicit `ANTHROPIC_API_KEY` env injection + consider per-job `HOME`); zombie processes (`ensure` block with `Process.kill("TERM")` + `Process.wait`).

**Stack elements:** Ruby PTY stdlib, `Open3.popen2e` (fallback if PTY unavailable), Claude CLI `--bare --output-format stream-json --include-partial-messages --no-session-persistence`, `ANTHROPIC_API_KEY` via `Open3` env hash.

**Research flag:** Needs validation — PTY behavior on the production Docker image must be confirmed. `stdbuf` is not available on macOS; PTY is the recommended cross-platform workaround, but confirm it works in the Kamal deployment context before coding the service.

### Phase 25: Live Streaming UI and Result Callbacks

**Rationale:** The visible payoff of all execution work. Depends on all three execution services being stable and the `AgentRun` model being fully operational. Adds the live log view, agent status broadcasting, and the API endpoints that allow Claude (and other agents) to report results back to Director asynchronously.

**Delivers:** `AgentRunsController` with `index` (execution history) and `show` (live log view with `turbo_stream_from`); `agent_runs/_log_line.html.erb` partial; agent status broadcast on `"agent_#{agent.id}"` stream (idle → running → idle); `ClaudeExecutionService#broadcast_line` wired in; `POST /api/tasks/:id/result` and `POST /api/tasks/:id/progress` callback endpoints (extending `Api::AgentEventsController`); full autonomous loop: task assignment → wake → execute → result callback → manager woken.

**Addresses:** Streaming output to task view; result posting back to task messages; task status update via API callback; live output ordering (accumulated-text replacement strategy).

**Avoids:** Action Cable broadcast flooding (100ms batching gate); Turbo Stream subscription race (explicit "started" broadcast as first job action); SSE/`ActionController::Live` (use Turbo Streams consistently with existing codebase).

**Stack elements:** `Turbo::StreamsChannel.broadcast_append_to` (broadcast_replace_to for accumulated text), no custom channel class, Stimulus controller for scroll-to-bottom and spinner state.

**Research flag:** Action Cable message ordering — confirm accumulated-text replacement strategy is sufficient before building delta+sequence fallback. If ordering issues appear during development, Evil Martians' analysis (December 2025) documents the sequence-number approach.

### Phase Ordering Rationale

- **AgentRun first** because every execution service writes to it and broadcasts using its ID. There is no streaming without a run record.
- **HTTP/Process before Claude** because simpler adapters validate the job dispatch chain without the Claude-specific bugs adding noise.
- **Claude before UI** because the live streaming view is only meaningful when Claude is actually streaming. Building the UI against a stub wastes iteration cycles.
- **UI last** because it depends on all execution services and the `AgentRun` model being stable. Adding broadcast calls to services before the view exists is fine — broadcasts to an unsubscribed stream are silently discarded.

### Research Flags

Needs deeper research during planning:
- **Phase 24:** PTY spawning behaviour in the production Docker container (Kamal deployment). Confirm `require 'pty'` works in the Docker image used for deployment. If not, `stdbuf -oL` on Linux is the fallback.
- **Phase 24:** Per-job `HOME` directory isolation for Claude session files — validate that setting `HOME` in the `Open3` env hash fully isolates `~/.claude/` config writes, and determine the correct ephemeral directory strategy (tmpdir per job or persistent per-agent).

Phases with standard patterns (skip research):
- **Phase 22:** Standard Rails migration + model + job patterns, identical to existing `HookExecution`/`HeartbeatEvent` precedents.
- **Phase 23:** `Net::HTTP` delivery reuses `ExecuteHookService` code; `Open3.popen2e` follows well-documented Ruby stdlib patterns.
- **Phase 25:** Turbo Streams broadcast pattern is already used for dashboard updates — no new patterns needed.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Zero new gems confirmed from official Ruby stdlib and turbo-rails docs. Claude CLI version 2.1.86 verified locally. |
| Features | HIGH | Table stakes derived directly from existing codebase stubs; Claude CLI event types verified from official docs and live invocation. |
| Architecture | HIGH | Existing codebase read directly. All patterns (`self.call`, `find_by + return unless`, `mark_failed! then re-raise`) confirmed in production code. |
| Pitfalls | HIGH | Five of seven critical pitfalls backed by confirmed upstream GitHub issues with reproduction steps. Two (SQLite contention, Action Cable flooding) confirmed in Solid Queue/Rails issue trackers. |

**Overall confidence: HIGH**

### Gaps to Address

- **PTY in production Docker image** — PTY is the recommended workaround for Claude CLI stdout buffering, but its availability in the Kamal Docker image has not been verified. Validate during Phase 24 planning before committing to PTY as the implementation strategy.

- **Solid Cable database configuration** — research confirms Rails 8 provisions a separate SQLite file for Solid Cable, which mitigates write contention. Verify this is correctly configured in `config/cable.yml` and `database.yml` before Phase 22 begins. If it shares the primary DB, refactor before adding execution log writes.

- **Solid Queue thread count vs. connection pool** — `config/queue.yml` currently sets `threads: 3`. Adding a dedicated `execution` queue with its own concurrency may require increasing the connection pool. Audit `database.yml` pool sizes across all three SQLite connections (primary, queue, cable) before Phase 22.

- **ANTHROPIC_API_KEY in production Docker containers** — confirm the key is available in the Kamal deployment environment. It must be passed explicitly in the `Open3` env hash regardless, but it must also exist in the Rails process environment (via `ENV` or Rails credentials) to be read. Verify the Kamal secrets/env configuration before Phase 24.

- **OrphanRunRecoveryJob** — the pitfall of agents stuck in `:running` requires a recurring recovery job. Solid Queue recurring job configuration is not in scope for the initial phases but should be designed in Phase 22 even if deferred to Phase 25.

## What NOT to Add

These temptations should be explicitly rejected during planning and implementation:

| Anti-Feature | Reason to Reject |
|---|---|
| Custom Action Cable channel class | `Turbo::StreamsChannel.broadcast_*_to` is sufficient for unidirectional output streaming |
| SSE via `ActionController::Live` | Conflicts with Puma thread pool; incompatible with existing Turbo Streams approach |
| `concurrent-ruby` gem | `Open3` + stdlib `Thread` is sufficient; concurrent-ruby is heavyweight for subprocess threading |
| `eventmachine` or async-http gems | The job queue + Solid Cable is the async layer; adding another async framework creates two competing event loops |
| Redis | Solid Cable uses SQLite; adding Redis requires Kamal changes and is unnecessary for this milestone |
| Faraday in v1.4 | `Net::HTTP` is sufficient for fire-and-forget delivery; defer until retry middleware is actually needed |
| Interactive Claude sessions (stdin) | Non-interactive headless mode (`-p` flag) is correct for automation; never use interactive sessions |
| AnyCable | Requires infra changes; overkill when sequence-number mitigation or accumulated-text replacement solves ordering |
| Fork-based session management | State explosion; one session per agent is the correct model |

## Sources

### Primary (HIGH confidence)
- Claude Code CLI headless/programmatic docs — https://code.claude.com/docs/en/headless — CLI flags, stream-JSON event structure, `--bare`, `--resume`
- Claude Code CLI environment variables — https://code.claude.com/docs/en/env-vars — `ANTHROPIC_API_KEY`, `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`
- Claude CLI version confirmed locally: `claude --version` → 2.1.86
- Stream-JSON event types — verified from live `claude -p` invocation with `--output-format stream-json`
- Ruby Open3 stdlib documentation — https://docs.ruby-lang.org/en/master/Open3.html
- Ruby PTY stdlib documentation — standard behaviour; `Errno::EIO` as normal termination
- Rails Action Cable overview — https://guides.rubyonrails.org/action_cable_overview.html
- Turbo::Streams::Broadcasts API — https://rubydoc.info/github/hotwired/turbo-rails/Turbo/Streams/Broadcasts
- Existing codebase (read directly): `WakeAgentService`, `ExecuteHookService`, `ExecuteHookJob`, `BaseAdapter`, `HeartbeatEvent`, `AgentEventsController` — ground truth

### Secondary (MEDIUM confidence)
- AnyCable, Rails, and the pitfalls of LLM streaming — Evil Martians, December 2025 — Action Cable ordering analysis, sequence-number mitigation
- Streaming LLM Responses with Rails: SSE vs Turbo Streams — aha.io — Turbo Streams preferred over SSE/`ActionController::Live`
- Advanced HTTP techniques in Ruby — mattbrictson.com — timeout recommendations (`open_timeout: 5, read_timeout: 30`)
- On dangers of Open3.popen3 — dmytro.sh — deadlock mechanism explained
- Ruby subprocesses with stdout/stderr streams — Nick Charlton — concurrent thread drain pattern
- SQLite concurrent writes and database locked errors — tenthousandmeters.com — WAL mode analysis
- SQLite on Rails — improving concurrency — fractaledmind.com — IMMEDIATE transaction mode, Ruby busy handler
- Broadcasting progress from background jobs — Drifting Ruby — Turbo broadcast from job pattern

### Confirmed upstream bugs (HIGH confidence)
- Claude CLI stdout not flushed when piped — GitHub #25670 (closed as duplicate of #25629)
- Missing result event in stream-json — GitHub #8126 (multiple reporters confirmed)
- `claude.json` corrupted by concurrent writes — GitHub #29051 (confirmed with reproduction steps)
- Solid Queue SQLite busy exception — issue #309 (confirmed with root cause analysis)
- Solid Queue SQLite database corruption — issue #324 (confirmed)
- DB connection pool size for Solid Queue — issue #271 (documented in README)

---
*Research completed: 2026-03-28*
*Ready for roadmap: yes*
