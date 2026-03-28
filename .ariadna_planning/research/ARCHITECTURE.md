# Architecture Patterns: v1.4 Agent Execution

**Domain:** AI agent execution — subprocess management, HTTP delivery, live streaming UI
**Researched:** 2026-03-28
**Confidence:** HIGH (existing codebase fully read; Claude CLI docs fetched from official source)

---

## Current Architecture (What Exists)

The execution chain today terminates in a stub. The full path is:

```
Task status change (after_commit)
  → Hookable#enqueue_hooks_for_transition
    → HookExecution.create! + ExecuteHookJob.perform_later
      → ExecuteHookService#dispatch_trigger_agent
        → WakeAgentService.call(agent, trigger_type:, context:)
          → HeartbeatEvent.create!(status: :queued)
          → deliver(event)
            → if agent.http?  → deliver_http [STUB — marks delivered, no real HTTP]
            → else            → event (no-op for process/claude_local)
```

**The stub is in `WakeAgentService#deliver_http`** (line 51-54). For `process` and `claude_local` adapter agents, `deliver` does nothing at all — the HeartbeatEvent sits queued forever.

v1.4 replaces the stub with real execution across three adapter types:

| Adapter Type | Current Behavior | v1.4 Behavior |
|---|---|---|
| `http` | POST stub (marks delivered only) | Real HTTP POST to `adapter_config["url"]` |
| `process` | No-op | Shell subprocess via `Open3.popen3` with streaming |
| `claude_local` | No-op | `claude -p` subprocess with `--output-format stream-json` |

---

## Recommended Architecture

### Overview

```
WakeAgentService#deliver
  ├── agent.http?         → HttpExecutionService   (HTTP POST with async response)
  ├── agent.process?      → ProcessExecutionService (Open3 subprocess)
  └── agent.claude_local? → ClaudeExecutionService  (claude CLI subprocess + stream-json)
            │
            ▼ (all three)
    AgentRun (new model — execution record with status, logs, session_id)
            │
            ▼
    StreamingBroadcastJob (line-by-line Turbo broadcast during execution)
            │
            ▼
    "agent_run_#{agent_run_id}" Action Cable stream
            │
            ▼
    AgentRunsController#show (live log view)
```

### New Components

| Component | Type | Purpose |
|---|---|---|
| `AgentRun` | Model | Persistent execution record (replaces HeartbeatEvent as execution tracking) |
| `ExecuteAgentJob` | Job | Enqueues adapter execution, owns the subprocess lifecycle |
| `ClaudeExecutionService` | Service | Spawns `claude -p` subprocess, parses stream-json, broadcasts |
| `ProcessExecutionService` | Service | Spawns shell command via `Open3.popen3`, broadcasts lines |
| `HttpExecutionService` | Service | Real HTTP POST to agent URL, handles response |
| `AgentRunChannel` (optional) | Action Cable Channel | Per-run stream subscription (if Action Cable channel JS needed) |
| `AgentRunsController` | Controller | Shows execution history and live log view |
| `Api::AgentRunsController` | API Controller | Agents POST completion/results back to Director |

### Modified Components

| Component | Change |
|---|---|
| `WakeAgentService#deliver` | Replace stubs with `ExecuteAgentJob.perform_later(event.id)` |
| `WakeAgentService#initial_status` | All types start as `:queued` (not `:delivered` for http) |
| `BaseAdapter` | Add `.execute(agent, context, run:)` signature; add `.stream_execute` for streaming adapters |
| `ClaudeLocalAdapter` | Implement `.execute` using `ClaudeExecutionService` |
| `ProcessAdapter` | Implement `.execute` using `ProcessExecutionService` |
| `HttpAdapter` | Implement `.execute` using `HttpExecutionService` |
| `HeartbeatEvent` | Add `agent_run_id` FK (optional: link heartbeat event to execution record) |

---

## Component Boundaries

### AgentRun Model

New table. Owns the complete execution lifecycle.

```
agent_runs
  id
  agent_id           FK agents
  company_id         FK companies
  heartbeat_event_id FK heartbeat_events (nullable — links wake event to run)
  adapter_type       integer enum (mirrors Agent.adapter_type)
  status             integer enum: queued/running/completed/failed/cancelled
  prompt_payload     json      (what was sent to the agent)
  result_payload     json      (what came back)
  session_id_before  string    (claude_local: session before run)
  session_id_after   string    (claude_local: session after run — for resumption)
  exit_code          integer
  error_message      text
  log_text           text      (accumulated stdout, line by line — final log)
  cost_cents         integer   (populated after run completes)
  started_at         datetime
  completed_at       datetime
  created_at
  updated_at
```

**Concerns to include:** `Tenantable`, `Chronological`

**State machine methods:** `mark_running!`, `mark_completed!(result:)`, `mark_failed!(error:)` — same pattern as `HookExecution` and `HeartbeatEvent`.

### ExecuteAgentJob

Replaces the stub. Called from `WakeAgentService#deliver`.

```ruby
class ExecuteAgentJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveJob::DeserializationError

  def perform(heartbeat_event_id)
    event = HeartbeatEvent.find_by(id: heartbeat_event_id)
    return unless event
    return if event.delivered?

    agent = event.agent
    run = AgentRun.create!(
      agent: agent,
      company_id: agent.company_id,
      heartbeat_event: event,
      adapter_type: agent.adapter_type,
      status: :queued,
      prompt_payload: event.request_payload
    )

    agent.adapter_class.execute(agent, run)
  end
end
```

This preserves the same `find_by + return unless` guard pattern used in `ExecuteHookJob`.

### ClaudeExecutionService

The most complex service. Spawns `claude -p` with `--output-format stream-json` and reads NDJSON lines.

**Claude CLI invocation pattern** (HIGH confidence — from official docs):

```bash
claude -p "{prompt}" \
  --output-format stream-json \
  --include-partial-messages \
  --dangerously-skip-permissions \
  --model "{model}" \
  --max-turns {max_turns} \
  [--resume "{session_id}"]  # only if session_id_before present
```

**Stream-JSON event types** the CLI emits (verified from official Claude Code docs):

| JSON line `type` | When emitted | Key fields |
|---|---|---|
| `system` | Session init | `subtype: "init"`, `session_id` |
| `assistant` | Complete turn | `message.content[].text` |
| `stream_event` | Per-token delta (with `--include-partial-messages`) | `event.type`, `event.delta.type`, `event.delta.text` |
| `result` | Final completion | `result` (text), `session_id`, `usage`, `duration_ms` |
| `system` | API retry notification | `subtype: "api_retry"`, `attempt`, `error` |

**Service skeleton:**

```ruby
class ClaudeExecutionService
  def self.call(agent, run)
    new(agent, run).call
  end

  def call
    run.mark_running!
    agent.update_column(:status, :running)

    cmd = build_command
    accumulated_log = []
    session_id_after = nil

    Open3.popen2e(*cmd) do |_stdin, stdout_err, wait_thread|
      stdout_err.each_line do |raw_line|
        line = raw_line.chomp
        next if line.blank?

        accumulated_log << line
        event = JSON.parse(line) rescue nil
        next unless event

        # Extract session_id from result event
        session_id_after = event["session_id"] if event["type"] == "result"

        # Broadcast to live UI
        broadcast_line(line)
      end
      @exit_code = wait_thread.value.exitstatus
    end

    if @exit_code == 0
      run.update!(
        status: :completed,
        session_id_after: session_id_after,
        log_text: accumulated_log.join("\n"),
        completed_at: Time.current
      )
      agent.update_column(:status, :idle)
    else
      run.mark_failed!(error_message: "Exit code #{@exit_code}")
      agent.update_column(:status, :error)
    end
  rescue => e
    run.mark_failed!(error_message: e.message)
    agent.update_column(:status, :error)
    raise
  end

  private

  def build_command
    config = agent.adapter_config
    cmd = ["claude", "-p", prompt_text,
           "--output-format", "stream-json",
           "--include-partial-messages",
           "--dangerously-skip-permissions"]
    cmd += ["--model", config["model"]] if config["model"]
    cmd += ["--max-turns", config["max_turns"].to_s] if config["max_turns"]
    cmd += ["--resume", run.session_id_before] if run.session_id_before.present?
    cmd
  end

  def broadcast_line(json_line)
    Turbo::StreamsChannel.broadcast_append_to(
      "agent_run_#{run.id}",
      target: "agent-run-log",
      partial: "agent_runs/log_line",
      locals: { line: json_line }
    )
  end
end
```

**Important:** `Open3.popen2e` (not `popen3`) combines stdout and stderr into one stream. This matches the `claude` CLI behavior where all output — including error messages — goes to stdout when using `--output-format stream-json`. Using `popen3` would require threading to avoid deadlock when stderr fills its pipe buffer.

**Known issue:** `claude -p --output-format stream-json` stdout is block-buffered when piped (not TTY). This means lines may not arrive individually. Mitigation: use `stdbuf -oL claude -p ...` or `unbuffer` on the subprocess command to force line buffering. This is a confirmed bug in the Claude CLI (GitHub issue #25670). Alternatively, set a read timeout and drain periodically.

### ProcessExecutionService

Simpler than Claude — just runs a shell command and streams lines.

```ruby
class ProcessExecutionService
  def call
    run.mark_running!
    agent.update_column(:status, :running)

    config = agent.adapter_config
    cmd = config["command"]
    accumulated = []

    Open3.popen2e(config.fetch("env", {}), cmd,
                  chdir: config["working_directory"] || Dir.pwd) do |_stdin, out_err, wt|
      out_err.each_line do |line|
        accumulated << line.chomp
        broadcast_line(line.chomp)
      end
      @exit_code = wt.value.exitstatus
    end

    # ... same complete/fail logic
  end
end
```

### HttpExecutionService

Real POST to the agent URL. Non-streaming response (synchronous request-response cycle).

```ruby
class HttpExecutionService
  def call
    run.mark_running!

    config = agent.adapter_config
    uri = URI.parse(config["url"])
    # ... same Net::HTTP pattern as ExecuteHookService#dispatch_webhook
    # POST run.prompt_payload, parse response, mark_completed! or mark_failed!
  end
end
```

This is the same Net::HTTP pattern already used in `ExecuteHookService#dispatch_webhook`. Reuse that implementation strategy.

---

## Data Flow: Wake Event to Live UI to Result

```
1. Task transitions to :in_progress or :completed
   → Hookable#enqueue_hooks_for_transition
   → ExecuteHookJob → ExecuteHookService#dispatch_trigger_agent
   → WakeAgentService.call(agent, trigger_type: :hook_triggered)

2. WakeAgentService#deliver (MODIFIED)
   → HeartbeatEvent.create!(status: :queued)
   → ExecuteAgentJob.perform_later(event.id)        [replaces stubs]

3. ExecuteAgentJob#perform
   → AgentRun.create!(status: :queued, heartbeat_event: event)
   → agent.adapter_class.execute(agent, run)

4. ClaudeExecutionService#call (or Process/Http variants)
   → agent.status = :running
   → run.mark_running!
   → Open3.popen2e(*claude_cmd) do |out_err|
       out_err.each_line do |json_line|
         → Turbo::StreamsChannel.broadcast_append_to(
              "agent_run_#{run.id}",
              target: "agent-run-log",
              partial: "agent_runs/log_line",
              locals: { line: json_line }
            )
       end
   → session_id extracted from "result" type JSON line
   → run.mark_completed!(session_id_after: session_id)
   → agent.status = :idle
   → HeartbeatEvent marks delivered

5. Browser (AgentRunsController#show)
   → turbo_stream_from "agent_run_#{@run.id}"
   → Turbo::StreamsChannel broadcasts append log lines in real time
   → "Complete" indicator when run transitions to :completed
      (broadcast_replace_to "agent-run-status" partial)
```

---

## Action Cable Integration

**No new Action Cable channel class needed.** The existing `Turbo::StreamsChannel` (via turbo-rails) handles everything. The pattern is identical to how `dashboard_company_#{company_id}` works today.

Stream names follow the existing convention:
- `"agent_run_#{run.id}"` — per-run stream for live log output
- `"agent_#{agent.id}"` — per-agent stream for status updates (agent status: idle → running → idle)

The `turbo_stream_from` tag in the view auto-subscribes the browser via `turbo-cable-stream-source`. No JS controller needed beyond the existing Action Cable setup.

The `ApplicationCable::Connection` already identifies users via `cookies.signed[:session_id]` — no changes needed there.

---

## Build Order

Dependencies drive the order:

### Phase 22: AgentRun Data Model
**Why first:** All subsequent services need the AgentRun table. No feature can execute without it.
- Migration: `agent_runs` table
- `AgentRun` model with status enum, `mark_running!`, `mark_completed!`, `mark_failed!`
- `ExecuteAgentJob` (skeleton — calls adapter, logs, no streaming yet)
- Modify `WakeAgentService#deliver` to enqueue `ExecuteAgentJob`
- Tests: model + job + wake service integration

### Phase 23: HTTP and Process Execution
**Why second:** Simpler adapters before the complex streaming one. No new UI needed.
- `HttpExecutionService` — real Net::HTTP POST (reuse ExecuteHookService pattern)
- `ProcessExecutionService` — Open3 subprocess with output accumulation
- Wire into `BaseAdapter` `.execute` interface
- Implement in `HttpAdapter` and `ProcessAdapter`
- Tests: service + adapter (webmock for HTTP, subprocess stubbing for process)

### Phase 24: Claude CLI Execution and Session Resumption
**Why third:** Depends on `AgentRun` model for `session_id_before/session_id_after`. Most complex.
- `ClaudeExecutionService` — stream-json parsing, session ID capture
- Implement in `ClaudeLocalAdapter`
- Session resumption: `run.session_id_before = agent_runtime_state.last_session_id`
- Tests: subprocess mock (capture commands issued, feed fake JSON lines)

### Phase 25: Live Streaming UI
**Why fourth:** Depends on all execution services + AgentRun model.
- `AgentRunsController` (nested under agents)
- `AgentRunsController#show` with `turbo_stream_from "agent_run_#{@run.id}"`
- `ClaudeExecutionService#broadcast_line` — wires broadcast into execution
- `agent_runs/log_line` partial — render one JSON line as formatted output
- Agent status broadcast (idle → running → idle on `"agent_#{agent.id}"` stream)
- Tests: controller + broadcast assertions

---

## Existing Files That Change

| File | Change | Why |
|---|---|---|
| `app/services/wake_agent_service.rb` | `deliver_http` replaced, `deliver` dispatches `ExecuteAgentJob` for all adapter types | Remove stub, add real dispatch |
| `app/adapters/base_adapter.rb` | Add `.execute(agent, run)` signature (raise NotImplementedError) | Interface contract |
| `app/adapters/claude_local_adapter.rb` | Implement `.execute` via `ClaudeExecutionService.call` | Real execution |
| `app/adapters/http_adapter.rb` | Implement `.execute` via `HttpExecutionService.call` | Real execution |
| `app/adapters/process_adapter.rb` | Implement `.execute` via `ProcessExecutionService.call` | Real execution |
| `app/models/heartbeat_event.rb` | Add `belongs_to :agent_run, optional: true` | Link wake event to run |
| `app/models/agent.rb` | Add `has_many :agent_runs` | Association |
| `config/routes.rb` | Add `resources :agent_runs` nested under agents | UI routes |

---

## New Files

| File | Type | Purpose |
|---|---|---|
| `db/migrate/..._create_agent_runs.rb` | Migration | `agent_runs` table |
| `app/models/agent_run.rb` | Model | Execution record with status machine |
| `app/jobs/execute_agent_job.rb` | Job | Dequeues execution from Solid Queue |
| `app/services/claude_execution_service.rb` | Service | `claude -p` subprocess + stream-json parsing |
| `app/services/process_execution_service.rb` | Service | `Open3.popen2e` subprocess |
| `app/services/http_execution_service.rb` | Service | Net::HTTP POST (real delivery) |
| `app/controllers/agent_runs_controller.rb` | Controller | Execution history + live view |
| `app/views/agent_runs/index.html.erb` | View | Run history list |
| `app/views/agent_runs/show.html.erb` | View | Live log view with turbo_stream_from |
| `app/views/agent_runs/_log_line.html.erb` | Partial | Single log line render |
| `app/views/agent_runs/_run.html.erb` | Partial | Run summary card |
| `test/models/agent_run_test.rb` | Test | Model state machine |
| `test/jobs/execute_agent_job_test.rb` | Test | Job dispatch |
| `test/services/claude_execution_service_test.rb` | Test | Mock subprocess |
| `test/services/process_execution_service_test.rb` | Test | Mock subprocess |
| `test/services/http_execution_service_test.rb` | Test | Webmock |
| `test/controllers/agent_runs_controller_test.rb` | Test | Controller tests |

---

## Patterns to Follow

### Pattern 1: Service Object with Class-Method Entry Point
All existing services use `self.call(**args)` as the entry point. Match this:
```ruby
class ClaudeExecutionService
  def self.call(agent, run) = new(agent, run).call
end
```

### Pattern 2: Job Guard Clauses
`ExecuteHookJob` and `ProcessValidationResultJob` both use `find_by + return unless + state check`. Match exactly:
```ruby
def perform(heartbeat_event_id)
  event = HeartbeatEvent.find_by(id: heartbeat_event_id)
  return unless event
  return if event.delivered?
  # ...
end
```

### Pattern 3: Mark-State Methods on Models
`HookExecution` and `HeartbeatEvent` have `mark_running!`, `mark_completed!`, `mark_failed!`. `AgentRun` follows the same interface.

### Pattern 4: Turbo Broadcast from Service Layer
`Agent#broadcast_overview_stats` and `Task#broadcast_kanban_update` call `Turbo::StreamsChannel.broadcast_*_to` directly from the model. Services can do the same — no special channel class needed.

### Pattern 5: Re-raise After mark_failed!
`ExecuteHookService` calls `mark_failed!` then re-raises so `retry_on` in the job can catch it:
```ruby
rescue StandardError => e
  run.mark_failed!(error_message: e.message)
  raise
end
```
Apply identically in all three execution services.

### Pattern 6: Webmock for HTTP Services
`webmock` is already in the Gemfile (added in Phase 19). Use it for `HttpExecutionService` tests.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Blocking the Job Queue with Long-Running Subprocesses
**What goes wrong:** `claude -p` can run for minutes. If Solid Queue has limited workers and a job blocks for 10 minutes, other hooks starve.
**Prevention:** Use a dedicated `execution` queue for `ExecuteAgentJob` with separate concurrency from the `default` queue. Add `queue_as :execution` and configure Solid Queue workers accordingly.

### Anti-Pattern 2: popen3 Without Concurrent Thread Reading
**What goes wrong:** `Open3.popen3` with separate stdout/stderr pipes deadlocks when stderr fills its fixed-size buffer before stdout is drained.
**Prevention:** Use `Open3.popen2e` (combined stdout+stderr) for all adapter services. This avoids the threading requirement.

### Anti-Pattern 3: Accumulating All Output in Memory for Large Runs
**What goes wrong:** A long claude run can produce megabytes of stream-json. Accumulating `accumulated_log.join` in one string causes memory pressure.
**Prevention:** Write log lines to `AgentRun#log_text` incrementally (or use `update_column` for a running append). For Phase 25, truncate displayed log to last N lines if run is still active.

### Anti-Pattern 4: Agent Status Left as :running on Job Failure
**What goes wrong:** If the job fails mid-execution and is retried, the agent is stuck as `:running`. The retry creates a second execution path on the same agent.
**Prevention:** `ExecuteAgentJob` rescue must call `agent.update_column(:status, :idle_or_error)` before re-raising. Add an `OrphanRunRecoveryJob` (recurring, every 5 min) that finds `AgentRun` records with `status: :running` and `started_at < 30.minutes.ago` and marks them failed.

### Anti-Pattern 5: Hardcoded claude Binary Path
**What goes wrong:** `claude` is not at a predictable PATH in production Docker containers.
**Prevention:** Add `claude_binary_path` to adapter config schema (optional). Default to `"claude"` (PATH lookup). Document in agent creation UI.

### Anti-Pattern 6: Broadcasting Before run.id Exists
**What goes wrong:** `broadcast_append_to "agent_run_#{run.id}"` called before the AgentRun record is persisted gives a stream name of `"agent_run_"` — a shared garbage stream.
**Prevention:** `AgentRun.create!` in the job before calling the service. Service receives the persisted record.

---

## Scalability Considerations

| Concern | Now (v1.4) | Future |
|---|---|---|
| Concurrent agent runs | Single Solid Queue process, limited concurrency | Multiple Solid Queue workers with dedicated `execution` queue |
| Log storage | `agent_runs.log_text` text column | Extract to separate `agent_run_logs` table with pagination |
| Session state | `session_id_before/after` on `AgentRun` | Dedicated `AgentRuntimeState` model (one row per agent) for current session tracking |
| Long-running runs | Job occupies worker thread | Consider async subprocess management with polling |

---

## Sources

- Claude CLI reference (official): https://code.claude.ai/docs/en/cli-reference — HIGH confidence
- Claude CLI headless/programmatic usage: https://code.claude.com/docs/en/headless — HIGH confidence
- Claude Agent SDK streaming output: https://platform.claude.com/docs/en/agent-sdk/streaming-output — HIGH confidence
- Stream-json flush bug (pipelining): https://github.com/anthropics/claude-code/issues/25670 — HIGH confidence
- Ruby Open3 documentation: https://docs.ruby-lang.org/en/master/Open3.html — HIGH confidence
- Turbo Streams broadcast pattern: existing codebase (`app/models/agent.rb`, `app/models/task.rb`) — HIGH confidence (read directly)
- ExecuteHookService pattern: existing codebase — HIGH confidence (read directly)
