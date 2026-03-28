# Feature Landscape: Agent Execution (v1.4)

**Domain:** Agent execution platform — subprocess lifecycle, streaming output, HTTP delivery, result callbacks
**Researched:** 2026-03-28
**Milestone scope:** Claude Local adapter execution, HTTP adapter delivery, live streaming UI, autonomous execution loop

---

## Table Stakes

Features that users expect from any real agent execution system. Missing = product feels incomplete or fake.

| Feature | Why Expected | Complexity | Dependencies |
|---------|--------------|------------|--------------|
| Claude CLI subprocess spawning | Core promise of claude_local adapter — currently stubbed | High | ANTHROPIC_API_KEY, claude binary on PATH |
| Streaming output to task view | Agents visibly "working" is essential UX signal | High | Action Cable channel, task show view |
| HTTP POST delivery in WakeAgentService | http adapter currently fakes delivery — wire it up | Medium | Net::HTTP already used in ExecuteHookService |
| Agent status transitions during execution | idle → running → idle/error must reflect real execution state | Medium | Agent.status enum already exists |
| Result posting back to task messages | Agent reports completion by creating a Message on the task | Medium | Message model, API auth already exist |
| Task status update via API callback | Agent marks task in_progress/completed via callback | Medium | API auth, Task.status enum already exist |
| Error capture and storage | Subprocess stderr, HTTP failures, timeouts recorded durably | Medium | HeartbeatEvent.metadata already stores errors |
| Session ID persistence for Claude | claude -p returns session_id in JSON result — store it | Medium | adapter_config JSON column on Agent |

---

## Differentiators

Features that make this feel like a real orchestration platform, not just plumbing.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Session resumption for Claude | Multi-task continuity — agent remembers previous work | Medium | --resume flag + stored session_id; requires same cwd |
| Tool-use indicators in stream UI | Show "[Using Bash...]" during tool calls, not just text | Medium | Requires parsing content_block_start events |
| Live output ordering guarantee | Sequence numbers on broadcast chunks prevent scrambled display | High | Action Cable threading causes out-of-order delivery |
| Execution cancellation | Kill running subprocess, mark task blocked/cancelled | High | Requires PID storage + Process.kill signal |
| Budget-gated execution start | Block claude_local spawn if agent has exhausted budget | Low | budget_exhausted? already on Agent model |
| Cost tracking from Claude result | ResultMessage contains total_cost_usd — write to task.cost_cents | Low | Task.cost_cents already exists |

---

## Anti-Features

Features to explicitly NOT build in v1.4.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| AnyCable or custom cable server | Ordering is a real problem but AnyCable requires infra changes; overkill for v1.4 | Mitigate with sequence numbers on chunk payloads; accumulate text in DB |
| Persistent connection polling loop | Long-running jobs that poll a process in a tight loop will exhaust Solid Queue workers | Use IO.select with a timeout; yield between reads |
| Streaming via SSE (ActionController::Live) | Conflicts with Puma thread pool; requires separate connection; incompatible with existing Turbo Streams approach | Use Action Cable channel broadcasting from background job |
| Multi-process parallelism for one agent | Spawning multiple claude processes per agent creates budget and session chaos | One active subprocess per agent at a time; guard with agent.running? check |
| Webhook signature verification for outbound | v1.4 is delivery, not security hardening | Add HMAC signatures in a later milestone |
| Interactive Claude sessions (stdin) | Non-interactive headless mode (-p flag) is the right model for automation | Use claude -p always; never interactive sessions |
| Fork-based session management | Forking sessions adds state explosion; v1.4 needs one session per agent | Continue or resume a single session per agent |

---

## Feature Breakdown by Execution Component

### 1. Subprocess Lifecycle (claude_local adapter)

**What to build:**

- `ClaudeLocalAdapter.execute(agent, context)` — the actual implementation that:
  - Invokes `claude -p "<prompt>" --output-format stream-json --verbose --include-partial-messages --bare`
  - Passes `--resume <session_id>` if `adapter_config["session_id"]` is present
  - Uses `Open3.popen3` (not `popen2e`) to separate stdout (JSON stream) from stderr (errors/diagnostics)
  - Reads stdout line-by-line with `io.each_line` inside a background job
  - Uses `IO.select` with a timeout to avoid blocking indefinitely
  - Captures the `session_id` from the final `ResultMessage` JSON and persists it back to `adapter_config`

**Stream JSON event types to handle** (HIGH confidence — verified against official Claude docs):

| Event type | Field path | Use |
|-----------|------------|-----|
| `stream_event` | `.event.type == "content_block_delta"` + `.event.delta.type == "text_delta"` | Broadcast text chunk to UI |
| `stream_event` | `.event.type == "content_block_start"` + `.event.content_block.type == "tool_use"` | Broadcast tool indicator `[Using X...]` |
| `stream_event` | `.event.type == "content_block_stop"` | Broadcast tool completion |
| `result` | `.subtype == "success"`, `.result`, `.session_id`, `.total_cost_usd` | Store result, cost, session ID |
| `system` | `.subtype == "api_retry"` | Log retry event; surface to UI optionally |
| `assistant` | Complete message object | Store as Message on task when received |

**Session resumption** (HIGH confidence — official Claude docs):
- `session_id` is available on the final `ResultMessage` as `.session_id`
- CLI equivalent: `claude -p "..." --resume <session_id>`
- Sessions stored at `~/.claude/projects/<encoded-cwd>/*.jsonl` — resumption requires matching `cwd`
- Store `session_id` in `adapter_config["session_id"]` on agent after each run
- Use `--continue` (most recent session) vs `--resume <id>` (specific session) — prefer `--resume` for multi-agent systems

**Process cleanup requirements:**
- Store subprocess PID in the HeartbeatEvent or a new execution record during the run
- Call `Process.waitpid(pid, Process::WNOHANG)` to avoid zombie processes
- On job timeout or cancellation, send `Process.kill("TERM", pid)` then `Process.kill("KILL", pid)` after grace period
- `Process.detach(pid)` if not waiting — required to prevent zombie accumulation

**Background job pattern:**
- `ExecuteClaudeJob` — one job per task assignment
- Job enqueued by `WakeAgentService` when `adapter_type == :claude_local`
- Job transitions agent to `running`, spawns subprocess, streams output, transitions back to `idle` or `error`
- Job timeout set to `adapter_config["max_turns"] * estimated_turn_time` (conservatively long)

---

### 2. HTTP Adapter Delivery

**What to build** (implementation is already partially wired via `ExecuteHookService` pattern):

- `WakeAgentService#deliver_http` — replace the TODO stub with real `Net::HTTP.post`
- POST to `adapter_config["url"]` with `build_request_payload` as JSON body
- Include `Authorization: Bearer <adapter_config["auth_token"]>` if configured
- Respect `adapter_config["timeout"]` (default 30s)
- Classify response codes:
  - 2xx → `mark_delivered!`
  - 4xx → `mark_failed!` without retry (permanent error; endpoint rejected the request)
  - 5xx / timeout / connection refused → `mark_failed!` and re-raise (let job retry with backoff)

**Retry pattern** (MEDIUM confidence — community practice, consistent with existing `ExecuteHookJob` pattern in codebase):
- Reuse `retry_on` pattern already established in `ExecuteHookJob`
- 3 attempts with polynomial backoff (existing pattern) for transient failures
- Add jitter to avoid thundering herd (multiple agents failing simultaneously)
- After all retries exhausted: HeartbeatEvent stays `failed`; no silent discard

**Headers to send** (standard convention):
- `Content-Type: application/json`
- `X-Director-Event: <trigger_type>` (signature-less for now)
- `User-Agent: Director/1.0`
- Custom headers from `adapter_config["headers"]` (already in schema)

---

### 3. Live Streaming UI

**What to build:**

- `AgentOutputStream` channel (Action Cable) — subscribes clients to a task-scoped stream
- Frontend subscribes to `"agent_output_task_<task_id>"` stream when viewing a task
- Background job broadcasts each parsed chunk as it arrives from the subprocess
- Task show view renders a `<div id="agent-output">` that receives `turbo_stream` appends

**Broadcast payload shape per chunk:**
```json
{
  "sequence": 42,
  "type": "text",
  "content": "Analyzing the codebase...",
  "tool_name": null
}
```

**Message ordering mitigation** (HIGH confidence — Evil Martians analysis, December 2025):
- Action Cable's threaded architecture gives NO ordering guarantee
- Chunks broadcast in rapid succession arrive scrambled because multiple Ruby threads pick them up concurrently
- Mitigation: include a `sequence` counter in each broadcast payload; client-side Stimulus controller sorts by sequence before rendering
- Alternative mitigation: broadcast accumulated text (full output so far) instead of deltas — more bandwidth, guaranteed correctness

**Recommendation:** Start with accumulated-text broadcasts (simpler, correct). Add delta + sequence if bandwidth becomes a concern.

**Frontend pattern:**
- Stimulus controller on `#agent-output` subscribes via `turbo_stream_from`
- On each broadcast, replace the entire output div with updated content
- Scroll-to-bottom on each update
- Show spinner while agent is `running`, hide on `idle`/`error`

**Turbo Streams vs SSE** (MEDIUM confidence — aha.io analysis):
- Turbo Streams: integrates with existing Hotwire setup; works with background jobs; matches codebase conventions
- SSE (ActionController::Live): simpler for pure streaming but conflicts with Puma thread pool; disconnected from existing Turbo infrastructure
- **Use Turbo Streams** — consistent with existing `Turbo::StreamsChannel.broadcast_append_to` already used in the codebase

---

### 4. Result Callbacks (Agent Reports Back via API)

**What to build** (extending existing `Api::AgentEventsController`):

- `POST /api/tasks/:id/result` — agent posts its completion result
  - Auth: existing `AgentApiAuthenticatable` concern (Bearer token)
  - Body: `{ status: "completed", output: "...", cost_cents: 1234 }`
  - Creates a `Message` on the task authored by the agent
  - Updates `task.status` to `:completed` (or `:blocked` on failure)
  - Updates `task.cost_cents` if provided
  - Wakes manager agent via `WakeAgentService` with `trigger_type: :task_completed`

- `POST /api/tasks/:id/progress` — agent posts intermediate progress (optional)
  - Creates a `Message` with `body` containing progress update
  - Does not change task status

- `PATCH /api/tasks/:id/status` — agent explicitly transitions task status
  - Validates transition is legal (open → in_progress → completed/blocked)
  - Auth-scoped: agent can only update tasks assigned to it

**What already exists:**
- `Api::AgentEventsController` with `AgentApiAuthenticatable` — extend this pattern
- `Message` model with polymorphic `author` — agents can author messages
- Task status enum with all needed states
- Bearer token on each agent (`api_token`)

**Payload conventions for agent → Director API:**
```json
{
  "status": "completed",
  "output": "I've analyzed the codebase and found 3 issues...",
  "cost_cents": 1450,
  "session_id": "abc123def456"
}
```

---

### 5. Session Management

**What to build:**

- Store `session_id` in `agent.adapter_config["session_id"]` after each successful run
- Pass `--resume <session_id>` on subsequent invocations for the same agent
- Validate that the session file exists at `~/.claude/projects/<encoded-cwd>/<session-id>.jsonl` before attempting resume; fall back to fresh session if missing
- Expose `session_id` in agent show view (read-only) so operators can see the current session
- Add "Clear Session" action on agent that nullifies `adapter_config["session_id"]` — forces fresh context next invocation

**Session resumption caveats** (HIGH confidence — official docs):
- Session files are local to the machine; cross-host resumption requires copying `~/.claude/projects/` files
- `cwd` must match exactly at resume time — encode the working directory when storing the session
- Session stores conversation history, NOT filesystem state — agent re-reads files each run
- A new `session_id` is assigned even when using `--resume` if the session file is missing

---

## Feature Dependencies Map

```
HTTP adapter delivery
  └── WakeAgentService (already exists, replace TODO stub)
  └── Net::HTTP with error classification
  └── Background job retry_on pattern (already in ExecuteHookJob)

Claude subprocess spawning
  └── Open3.popen3 with stdout/stderr separation
  └── ExecuteClaudeJob (new)
  └── WakeAgentService (already exists, add claude_local branch)
  └── Session ID stored in adapter_config

Live streaming UI
  └── Claude subprocess (above) — produces the stream
  └── Action Cable channel (new) subscribed to task-scoped stream
  └── Turbo::StreamsChannel.broadcast_replace_to (already in codebase)
  └── Stimulus controller on task show view (new)

Result callbacks
  └── Api::AgentEventsController pattern (already exists) — add new endpoints
  └── AgentApiAuthenticatable (already exists)
  └── Message model (already exists, agents as author)
  └── Task status transitions (already exist)

Full autonomous loop (all of the above +)
  └── Task assignment triggers WakeAgentService (already via Task#trigger_assignment_wake)
  └── Agent receives task payload → works → posts result → manager woken
```

---

## MVP Recommendation

Prioritize in this order:

1. **HTTP adapter real delivery** — smallest scope, removes a TODO stub, validates the delivery pipeline before building the harder subprocess work
2. **Claude subprocess spawning + result storage** — core of the milestone; get non-streaming invocation working first (`--output-format json`), then add streaming
3. **Result callback API endpoints** — required for autonomous loop; builds on existing API auth infrastructure
4. **Live streaming UI** — most visible feature, but depends on subprocess streaming being stable
5. **Session resumption** — differentiator; only add after basic execution works reliably

**Defer from v1.4:**
- Execution cancellation (PID-based kill) — complex process lifecycle; add in v1.5
- Multi-agent concurrent execution — need single-agent stability first
- Webhook signature verification on outbound delivery — security hardening for later

---

## Sources

- [Run Claude Code programmatically (Headless/CLI)](https://code.claude.com/docs/en/headless) — HIGH confidence, official docs
- [Claude Agent SDK: Streaming Output](https://platform.claude.com/docs/en/agent-sdk/streaming-output) — HIGH confidence, official docs
- [Claude Agent SDK: Sessions and Resumption](https://platform.claude.com/docs/en/agent-sdk/sessions) — HIGH confidence, official docs
- [AnyCable, Rails, and the pitfalls of LLM streaming](https://evilmartians.com/chronicles/anycable-rails-and-the-pitfalls-of-llm-streaming) — HIGH confidence, Evil Martians Dec 2025, verified Action Cable ordering issue
- [Streaming LLM Responses with Rails: SSE vs Turbo Streams (aha.io)](https://www.aha.io/engineering/articles/streaming-llm-responses-rails-sse-turbo-streams) — MEDIUM confidence, production experience post
- [Rails Action Cable Overview (official guides)](https://guides.rubyonrails.org/action_cable_overview.html) — HIGH confidence
- [Sending Webhooks with Exponential Backoff (GoRails)](https://gorails.com/episodes/sending-webhooks-with-exponential-backoff) — MEDIUM confidence, community practice
- [Building Reliable Webhook Delivery (DEV Community, 2026)](https://dev.to/young_gao/building-reliable-webhook-delivery-retries-signatures-and-failure-handling-40ff) — MEDIUM confidence
- [Ruby Open3 subprocess documentation](https://github.com/ruby/open3) — HIGH confidence, stdlib
- Existing codebase: `ExecuteHookService`, `WakeAgentService`, `Api::AgentEventsController`, `Task`, `Agent`, `Message` models — HIGH confidence, ground truth
