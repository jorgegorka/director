# Technology Stack: v1.4 Agent Execution

**Project:** Director — v1.4 execution milestone
**Researched:** 2026-03-28
**Scope:** NEW capabilities only — Claude CLI streaming, HTTP adapter delivery, subprocess management, Action Cable live output

---

## Executive Decision

**No new gems required for the core execution path.** All three adapter types can be implemented
using Ruby stdlib (`Open3`, `Net::HTTP`) plus the Action Cable / Turbo Streams infrastructure
already in place. The only justified gem addition is `faraday` for the HTTP adapter, and only if
retry/connection-pooling behaviour is wanted. A minimal first pass can use `Net::HTTP` directly.

---

## What Already Exists (DO NOT RE-RESEARCH)

| Capability | Where |
|---|---|
| Action Cable, WebSocket channel | `app/channels/application_cable/connection.rb` |
| Turbo Streams broadcasting | `turbo-rails` gem already in Gemfile |
| Solid Queue background jobs | Running, configured in `config/queue.yml` |
| Solid Cable adapter | Configured for production in `config/cable.yml` |
| BaseAdapter scaffold | `app/adapters/base_adapter.rb` (NotImplementedError stubs) |
| ClaudeLocalAdapter scaffold | `app/adapters/claude_local_adapter.rb` |
| HttpAdapter scaffold | `app/adapters/http_adapter.rb` |
| ProcessAdapter scaffold | `app/adapters/process_adapter.rb` |
| WakeAgentService | `app/services/wake_agent_service.rb` (stubbed `deliver_http`) |
| HeartbeatEvent model | Tracks trigger, status, request/response payloads |

---

## New Capabilities Required

### 1. Claude CLI Streaming (ClaudeLocalAdapter)

**Runtime:** Claude Code CLI (`@anthropic-ai/claude-code`)
**Current version:** 2.1.86 (confirmed locally with `claude --version`)
**Installation:** Native installer (npm method deprecated as of early 2026 but still functional)
**Authentication:** `ANTHROPIC_API_KEY` environment variable

#### Invocation pattern

```bash
claude -p "<prompt>" \
  --output-format stream-json \
  --verbose \
  --include-partial-messages \
  --bare \
  --model <model> \
  --no-session-persistence
```

`--bare` is the **required flag for programmatic invocation**: skips hooks, CLAUDE.md discovery,
keychain reads, plugins, auto-memory. Anthropic auth must come from `ANTHROPIC_API_KEY` when
`--bare` is used — OAuth/keychain are never read. This is the recommended mode for scripted calls
and will become the `-p` default in a future release.

`--no-session-persistence` prevents session files being written to disk on every execution, which
matters when running many agents concurrently.

#### Stream-JSON event structure (HIGH confidence — verified from live CLI + official docs)

Each stdout line is a newline-delimited JSON object. Three event types matter for execution:

```json
// 1. Init event — first line always
{ "type": "system", "subtype": "init", "session_id": "...", "model": "...", ... }

// 2. Partial text delta — arrives continuously while Claude is writing
{
  "type": "stream_event",
  "event": {
    "type": "content_block_delta",
    "index": 0,
    "delta": { "type": "text_delta", "text": "fragment" }
  },
  "session_id": "..."
}

// 3. Final result — always the last line
{
  "type": "result",
  "subtype": "success",
  "is_error": false,
  "result": "<full text>",
  "session_id": "...",
  "total_cost_usd": 0.0023,
  "usage": { "input_tokens": 100, "output_tokens": 250, ... },
  "duration_ms": 4200
}
```

When `is_error: true` the `result` field contains the error message. The `total_cost_usd` and
`usage` fields in the result event are what feed budget tracking.

#### Ruby subprocess pattern

Use `Open3.popen3` with per-stream threads. **Do not use `Open3.capture3`** — it buffers all
output and blocks until process exit, destroying the streaming benefit.

```ruby
require "open3"
require "json"

cmd = ["claude", "-p", prompt, "--output-format", "stream-json",
       "--verbose", "--include-partial-messages", "--bare",
       "--no-session-persistence"]

env = { "ANTHROPIC_API_KEY" => api_key }

Open3.popen3(env, *cmd) do |stdin, stdout, stderr, thread|
  stdin.close

  stderr_thread = Thread.new { stderr.read } # drain stderr to prevent deadlock

  stdout.each_line do |line|
    event = JSON.parse(line.strip) rescue next
    yield event if block_given?
  end

  stderr_thread.join
  thread.join
end
```

**Critical deadlock rule:** stdout and stderr must be read concurrently. If stderr fills its
OS pipe buffer (typically 64KB) while stdout is being read, the subprocess blocks and the reader
deadlocks. The pattern above drains stderr in a background thread.

**Process cleanup:** `thread.join` blocks until the child exits. If a timeout is needed, use
`thread.join(timeout_seconds)` and then `Process.kill("TERM", thread.pid)` followed by
`Process.kill("KILL", thread.pid)` if TERM does not produce exit within a grace period.

#### Session resumption

The `--resume <session_id>` flag continues a prior conversation. The `session_id` from the
`system/init` event should be persisted to the execution record for resumption. The
`--fork-session` flag creates a new session ID when resuming, useful for branching.

#### Security: passing ANTHROPIC_API_KEY to subprocess

Pass the key via the env hash argument to `Open3.popen3(env, *cmd_array)`. **Never interpolate
secrets into a shell string** — use the array form. The key is inherited by the child process
only; it does not leak to logs. Store the key in Rails credentials or an env var, never in the
`adapter_config` JSON column.

---

### 2. HTTP Adapter Delivery (HttpAdapter)

**Use:** Ruby stdlib `Net::HTTP` for the first pass. Add `faraday` (~> 2.14) only if retry logic
or connection pooling is needed.

#### Net::HTTP pattern (no new gem, HIGH confidence)

```ruby
require "net/http"
require "uri"
require "json"

uri = URI.parse(url)
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = uri.scheme == "https"
http.open_timeout = 5   # seconds to establish TCP connection
http.read_timeout = 30  # seconds to receive first response byte

request = Net::HTTP::Post.new(uri.path.presence || "/")
request["Content-Type"] = "application/json"
request["Authorization"] = "Bearer #{auth_token}" if auth_token

request.body = payload.to_json
response = http.request(request)
```

**Recommended timeouts:** `open_timeout: 5`, `read_timeout: 30`. These match the constraints
from the ultimate-guide-to-ruby-timeouts and the Basecamp/mattbrictson recommendations.

#### If faraday is added later

```ruby
# Gemfile
gem "faraday", "~> 2.14"          # released 2025-09-28
gem "faraday-retry", "~> 2.2"     # exponential backoff
```

Faraday 2.14 requires Ruby 3.0+, which Rails 8.1 already mandates. The `faraday-net_http`
adapter is bundled as a runtime dependency of faraday 2.x — no separate adapter gem needed for
basic use.

**Do not add faraday in v1.4.** `Net::HTTP` is sufficient for fire-and-forget webhook delivery.
Faraday earns its keep when you need retry middleware, connection pooling across requests, or
pluggable adapters. Defer until v1.5+ if retry behaviour is required.

---

### 3. Subprocess Management (ProcessAdapter)

For the `process` adapter type (arbitrary shell commands), use the same `Open3.popen3` pattern
as ClaudeLocalAdapter. The adapter receives `command`, `working_directory`, `env`, and `timeout`
from `adapter_config`.

**Command safety:** Always use the array form:

```ruby
# CORRECT — array, no shell interpolation
Open3.popen3(env_hash, *Shellwords.split(command), chdir: working_directory) do ...

# WRONG — shell string with interpolation
Open3.popen3("#{command}") do ...
```

**Timeout handling:**

```ruby
wait_thread = thread  # the third return value from popen3

unless wait_thread.join(timeout_seconds)
  Process.kill("TERM", wait_thread.pid)
  sleep 2
  Process.kill("KILL", wait_thread.pid) rescue nil
end
```

Send SIGTERM first (graceful shutdown), wait 2 seconds, then SIGKILL. This mirrors how Solid
Queue itself handles job timeouts.

---

### 4. Action Cable Live Streaming

**Pattern:** Broadcast from the background job executing the adapter, chunk by chunk, using
`Turbo::StreamsChannel.broadcast_append_to`. The view subscribes with `<%= turbo_stream_from %>`.

#### Channel pattern

No new Action Cable channel class is needed. Use `Turbo::StreamsChannel` directly — it is
already provided by `turbo-rails` and handles the WebSocket subscription lifecycle.

```ruby
# In the view (subscribe)
<%= turbo_stream_from "execution_#{@execution.id}_output" %>

# In the job (broadcast a chunk)
Turbo::StreamsChannel.broadcast_append_to(
  "execution_#{@execution.id}_output",
  target: "execution-output",
  partial: "executions/output_chunk",
  locals: { chunk: text_delta, sequence: n }
)
```

#### Why append_to over a custom channel

`broadcast_append_to` is a one-liner that works from any Ruby context (job, service, rake task)
without needing a channel class or subscription state. It piggybacks on the existing Solid Cable
adapter. A custom `ApplicationCable::Channel` subclass would be needed only if you require
two-way communication (client → server messages during execution, e.g., abort signals).

For abort signals, broadcast an "execution aborted" Turbo Stream frame that updates the UI, and
handle the actual process kill inside a separate controller action or job — do not open a
bidirectional channel for a unidirectional streaming use case.

#### Broadcast frequency

Stream every text delta for immediate feedback. The Action Cable / Solid Cable pipeline handles
batching internally. Do **not** buffer chunks in Ruby before broadcasting — it defeats the purpose
of streaming and adds code complexity.

#### Database persistence alongside streaming

Persist output to an `execution_logs` table (or append to a `text` column on the execution
record) as chunks arrive. This gives:
1. A replay mechanism when a user visits an execution that already completed
2. A durable record for audit and cost attribution
3. No dependency on WebSocket availability for result retrieval

Pattern: accumulate chunks in a `StringIO` inside the job, persist to DB on job completion,
broadcast each chunk to the WebSocket in real time.

---

## Recommended Additions Summary

| Item | Why | Gem / Change |
|---|---|---|
| `faraday ~> 2.14` | HTTP adapter retry/pooling | Defer to v1.5 — not needed for v1.4 |
| `faraday-retry ~> 2.2` | Exponential backoff on webhook delivery | Defer to v1.5 |
| New `AgentExecutionJob` | Run adapter in background, broadcast output | New file, no gem |
| New `execution_logs` table | Persist streamed output | New migration, no gem |
| `Turbo::StreamsChannel` | Broadcast output chunks | Already available via turbo-rails |
| `Open3` (stdlib) | Subprocess management | Already in Ruby stdlib, no gem |
| `Net::HTTP` (stdlib) | HTTP adapter delivery | Already in Ruby stdlib, no gem |

**Total new gems for v1.4: zero.**

---

## Environment Variables for ClaudeLocalAdapter

These must be present in the process environment when ClaudeLocalAdapter executes:

| Variable | Purpose | Required? |
|---|---|---|
| `ANTHROPIC_API_KEY` | API key for Claude CLI in `--bare` mode | YES — CLI will not authenticate without it |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | Disables telemetry, autoupdater, error reporting | Recommended for background jobs |
| `CLAUDE_STREAM_IDLE_TIMEOUT_MS` | Milliseconds before streaming idle watchdog closes stalled connection (default 90000) | Optional — increase for long-running agents |

Store `ANTHROPIC_API_KEY` in Rails credentials (`config/credentials.yml.enc`) or a host
environment variable. Pass it explicitly in the `env` hash to `Open3.popen3` — do not rely on
the Rails process inheriting it automatically in production Docker containers.

---

## Integration with Existing Architecture

### Adapter execution flow

```
WakeAgentService#call
  → creates HeartbeatEvent (status: queued)
  → enqueues AgentExecutionJob (Solid Queue)

AgentExecutionJob#perform
  → AdapterRegistry.for(agent.adapter_type).execute(agent, context)
  → adapter streams output via Open3 or Net::HTTP
  → each chunk: Turbo::StreamsChannel.broadcast_append_to(...)
  → on completion: updates HeartbeatEvent (status: delivered, cost data)
  → on error: HeartbeatEvent#mark_failed!
```

### What changes in WakeAgentService

The `deliver_http` stub becomes a real call through the adapter. The `deliver` method routes all
three adapter types through `AdapterRegistry` instead of the current `agent.http? ? ... : ...`
branch. HTTP agents still get synchronous stub-style delivery in v1.4 until the HTTP adapter is
fully implemented.

### HeartbeatEvent status lifecycle

Existing statuses (`queued`, `delivered`, `failed`) are sufficient. Add `running` as an
intermediate status if the UI needs to show "in progress" distinct from "not yet started":

```ruby
# Migration
add_value_to_enum :heartbeat_events, :status, :running
# Or (since SQLite doesn't have real enum DDL):
# The enum is integer-backed — add 3 => :running by expanding the Rails enum definition
```

### Solid Queue concurrency

The existing `config/queue.yml` sets `threads: 3` per process. Each `AgentExecutionJob` holds
its thread for the entire subprocess duration. For parallel agent execution, increase `threads`
or `processes`. This is a deployment-time tuning decision, not a code change.

---

## What NOT to Add

| Temptation | Why to resist |
|---|---|
| `concurrent-ruby` gem for subprocess threading | Open3 + stdlib Thread is sufficient; concurrent-ruby is heavyweight for this use case |
| `whenever` or `rufus-scheduler` for agent scheduling | Solid Queue recurring jobs already handle this |
| `eventmachine` or async-http gems | Overkill; the job queue + Solid Cable is the async layer |
| Server-Sent Events (SSE) via ActionController::Live | Action Cable already running; adding SSE creates a second streaming transport to maintain |
| Redis | Solid Cable uses SQLite; adding Redis for cable would require Kamal changes and is unnecessary |
| Custom Action Cable channel class | Turbo::StreamsChannel.broadcast_*_to is sufficient for unidirectional output streaming |

---

## Sources

- Claude CLI official docs (verified live): https://code.claude.com/docs/en/headless
- Claude CLI environment variables (verified live): https://code.claude.com/docs/en/env-vars
- Claude CLI version confirmed locally: `claude --version` → 2.1.86
- Stream-JSON event structure confirmed from live `claude -p` invocation with `--output-format stream-json`
- Open3 deadlock pattern: https://nickcharlton.net/posts/ruby-subprocesses-with-stdout-stderr-streams.html
- Faraday 2.14.0: https://rubygems.org/gems/faraday/versions/2.14.0 (released 2025-09-28)
- Advanced Ruby HTTP techniques (timeout/retry): https://mattbrictson.com/blog/advanced-http-techniques-in-ruby
- Turbo::Streams::Broadcasts API: https://rubydoc.info/github/hotwired/turbo-rails/Turbo/Streams/Broadcasts
- Turbo broadcast from job: https://www.driftingruby.com/episodes/broadcasting-progress-from-background-jobs
- Rails streaming LLM pattern: https://www.aha.io/engineering/articles/streaming-llm-responses-rails-sse-turbo-streams
