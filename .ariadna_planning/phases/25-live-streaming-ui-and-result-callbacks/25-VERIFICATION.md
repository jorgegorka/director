---
phase: 25-live-streaming-ui-and-result-callbacks
verified: 2026-03-28T21:33:00Z
status: passed
score: "9/9 truths verified | security: 0 critical, 0 high | performance: 0 high"
must_haves:
  truths:
    - id: T1
      text: "User can navigate to /agents/:agent_id/agent_runs to see a list of all runs for that agent"
      status: passed
    - id: T2
      text: "User can click into /agents/:agent_id/agent_runs/:id to see the full run detail with live-streaming output"
      status: passed
    - id: T3
      text: "On the AgentRun show page, a turbo_stream_from subscription receives new log lines in real time without page refresh"
      status: passed
    - id: T4
      text: "Agent status badge on the dashboard and agent show page updates in real time when agent transitions between statuses (STREAM-02)"
      status: passed
    - id: T5
      text: "Cancel button on a running AgentRun kills the tmux session and marks the run as cancelled (STREAM-04)"
      status: passed
    - id: T6
      text: "An agent can POST to /api/agent_runs/:id/result with exit_code, cost_cents, and session_id to mark the run completed (CALLBACK-01)"
      status: passed
    - id: T7
      text: "An agent can POST to /api/agent_runs/:id/progress with a message to log intermediate progress (CALLBACK-02)"
      status: passed
    - id: T8
      text: "When result callback reports task completion, the associated task status updates to completed and a message is posted to the task conversation (CALLBACK-03)"
      status: passed
    - id: T9
      text: "When result callback includes cost_cents, the agent budget tracking is updated via BudgetEnforcementService (CALLBACK-04)"
      status: passed
security_findings: []
performance_findings: []
duplication_findings: []
---

# Phase 25 Verification: Live Streaming UI and Result Callbacks

## Phase Goal

> Users watch agent output stream live in the browser, agent status updates appear on the dashboard in real time, and agents can report task completion back to Director via API.

## Observable Truths

| ID | Truth | Status | Evidence |
|----|-------|--------|----------|
| T1 | User can navigate to /agents/:agent_id/agent_runs to see a list of runs | PASSED | `GET /agents/:agent_id/agent_runs` route exists; `AgentRunsController#index` returns 200; controller test `index lists agent runs` passes; view renders table with status, trigger, duration, cost, started columns |
| T2 | User can click into run detail with live-streaming output | PASSED | `GET /agents/:agent_id/agent_runs/:id` route exists; `AgentRunsController#show` returns 200; show view renders existing `log_output` on page load via line-by-line `_log_line` partials; output container uses monospace pre-wrap styling |
| T3 | Show page has turbo_stream_from for live log line streaming | PASSED | `show.html.erb` line 3: `turbo_stream_from "agent_run_#{@agent_run.id}"` establishes Action Cable subscription; `broadcast_line!` appends to `target: "agent-run-output"` matching the DOM element `id="agent-run-output"`; live indicator shown for running/queued runs with pulse animation |
| T4 | Agent status badge updates in real time on dashboard and show page | PASSED | `Agent#broadcast_dashboard_update` calls both `broadcast_overview_stats` (dashboard) and `broadcast_agent_status` (agent show); `agents/show.html.erb` line 1: `turbo_stream_from "agent_#{@agent.id}"`; `_status_badge.html.erb` has `id="agent-status-badge-{id}"` matching the replacement target |
| T5 | Cancel kills tmux and marks cancelled | PASSED | `POST /agents/:agent_id/agent_runs/:id/cancel` route exists; `AgentRun#cancel!` calls `ClaudeLocalAdapter.kill_session` for claude_local agents; marks run cancelled via `mark_cancelled!`; returns agent to idle; button rendered with `btn--danger` class, no confirmation dialog per CONTEXT decision 3; 5 controller cancel tests and 3 model cancel tests pass |
| T6 | Agent can POST result to mark run completed | PASSED | `POST /api/agent_runs/:id/result` route exists; `Api::AgentRunsController#result` calls `mark_completed!` with exit_code, cost_cents, claude_session_id; returns agent to idle; Bearer token auth via AgentApiAuthenticatable; ownership check ensures agent can only complete its own runs; 8 tests cover success, error, auth |
| T7 | Agent can POST progress messages | PASSED | `POST /api/agent_runs/:id/progress` route exists; `Api::AgentRunsController#progress` calls `broadcast_line!("[progress] #{message}\n")`; validates running state; validates message presence; 4 tests cover success and error paths |
| T8 | Result callback updates task and posts conversation message | PASSED | `update_task_on_completion` sets task status to completed; creates `Message` with summary text (or default) authored by agent; tested with `result updates associated task to completed`, `result posts completion message to task conversation`, and `result posts default message when summary not provided` |
| T9 | Result callback feeds budget tracking | PASSED | `record_cost_on_task` accumulates `cost_cents` on task; `BudgetEnforcementService.check!(@agent_run.agent)` called after cost recording; tested with `result with cost_cents accumulates cost on task` and `result with cost_cents triggers budget enforcement` |

## Artifact Verification

| Artifact | Status | Assessment |
|----------|--------|------------|
| `app/models/agent_run.rb` | EXISTS, SUBSTANTIVE | 111 lines. `broadcast_line!` with batching (100ms min interval via `BROADCAST_MIN_INTERVAL`), `broadcast_flush!` with after_commit callback, `cancel!` with tmux kill, `append_log!` SQL COALESCE, all state transitions. No stubs or TODOs. |
| `app/controllers/agent_runs_controller.rb` | EXISTS, SUBSTANTIVE | 33 lines. index, show, cancel actions. `require_company!`, company-scoped agent and run lookups. Thin controller pattern. |
| `app/controllers/api/agent_runs_controller.rb` | EXISTS, SUBSTANTIVE | 114 lines. result and progress endpoints. `AgentApiAuthenticatable` concern for Bearer token auth. Ownership check, state validation, task update, budget enforcement. No stubs or TODOs. |
| `app/views/agent_runs/show.html.erb` | EXISTS, SUBSTANTIVE | 72 lines. `turbo_stream_from` subscription, existing log rendering, live indicator with replaceable target ID, cancel button, metadata grid. |
| `app/views/agent_runs/index.html.erb` | EXISTS, SUBSTANTIVE | 40 lines. Table with run list, status badges, empty state. |
| `app/views/agent_runs/_log_line.html.erb` | EXISTS, SUBSTANTIVE | 23 lines. Tool-use JSON detection (content_block_start + tool_use), conditional rendering with tool indicator badge, plain text fallback, JSON::ParserError rescue. |
| `app/views/agents/_status_badge.html.erb` | EXISTS, SUBSTANTIVE | 1 line. Badge with `id="agent-status-badge-{id}"` for Turbo replacement. |
| `app/helpers/agent_runs_helper.rb` | EXISTS, SUBSTANTIVE | 18 lines. `agent_run_status_badge` and `agent_run_duration` helpers. |
| `test/controllers/agent_runs_controller_test.rb` | EXISTS, SUBSTANTIVE | 157 lines, 14 tests. Index (4), show (4), cancel (5) + setup. |
| `test/controllers/api/agent_runs_controller_test.rb` | EXISTS, SUBSTANTIVE | 259 lines, 18 tests. Result (12), progress (5) + setup. |
| `test/models/agent_run_test.rb` | EXISTS, SUBSTANTIVE | 474 lines, 63 tests (includes pre-existing + new phase 25 tests). |

## Key Links / Wiring

| From | To | Via | Status |
|------|----|-----|--------|
| `show.html.erb` turbo_stream_from | `AgentRun#broadcast_line!` | Stream name `"agent_run_#{id}"` matches broadcast target | CONNECTED |
| `AgentRun#broadcast_line!` | `_log_line.html.erb` | `broadcast_append_to` with `target: "agent-run-output"` matches DOM `id="agent-run-output"` | CONNECTED |
| `agents/show.html.erb` turbo_stream_from | `Agent#broadcast_agent_status` | Stream `"agent_#{id}"` + target `"agent-status-badge-#{id}"` match the partial's DOM id | CONNECTED |
| `ClaudeLocalAdapter#poll_session` | `AgentRun#broadcast_line!` | Both call sites (lines 128, 148) use `broadcast_line!` instead of `append_log!` | CONNECTED |
| `agents/show.html.erb` Recent Runs | `AgentRunsController#index` | `link_to "View all runs", agent_agent_runs_path(@agent)` | CONNECTED |
| `AgentsController#show` | `@recent_runs` | Line 11: `@agent.agent_runs.order(created_at: :desc).limit(5)` | CONNECTED |
| `AgentRunsController#cancel` | `AgentRun#cancel!` | Delegates to model method which calls `ClaudeLocalAdapter.kill_session` + `mark_cancelled!` | CONNECTED |
| `Api::AgentRunsController#result` | `AgentRun#mark_completed!` | Passes exit_code, cost_cents, claude_session_id | CONNECTED |
| `Api::AgentRunsController#result` | `BudgetEnforcementService.check!` | Called after cost recording when cost_cents > 0 | CONNECTED |
| `Api::AgentRunsController#progress` | `AgentRun#broadcast_line!` | Broadcasts `"[progress] #{message}\n"` | CONNECTED |
| `WakeAgentService#dispatch_execution` | `AgentRun` creation | Creates queued run, dispatches `ExecuteAgentJob` which triggers adapter -> `broadcast_line!` | CONNECTED |

## Cross-Phase Integration

| Integration Point | Status | Evidence |
|-------------------|--------|----------|
| Phase 24 (ClaudeLocalAdapter) -> Phase 25 (broadcast_line!) | CONNECTED | `poll_session` calls `broadcast_line!` at both call sites (main loop + final capture). `kill_session` used by `cancel!`. |
| Phase 22 (AgentRun model) -> Phase 25 (streaming + callbacks) | CONNECTED | `mark_completed!`, `mark_cancelled!`, `append_log!` all used. `after_commit :broadcast_flush!` hooks into existing state machine. |
| Phase 8 (Budget) -> Phase 25 (result callback) | CONNECTED | `BudgetEnforcementService.check!` called from result endpoint after cost recording. Task cost accumulation matches existing pattern. |
| Phase 5 (Tasks & Messages) -> Phase 25 (task completion) | CONNECTED | `update_task_on_completion` sets task.status and creates Message with agent as polymorphic author. |
| Phase 10 (Dashboard) -> Phase 25 (agent status) | CONNECTED | `broadcast_overview_stats` still fires on status change (existing), `broadcast_agent_status` added for agent show page. |
| Phase 7 (Triggers) -> Phase 25 (execution flow) | CONNECTED | `WakeAgentService.dispatch_execution` creates `AgentRun`, queues `ExecuteAgentJob`. Complete E2E: trigger -> run -> stream -> result callback -> task update. |

## Security Analysis

No new security findings. Analysis of changed files:

- **Api::AgentRunsController**: Bearer token auth via `AgentApiAuthenticatable` concern (existing, battle-tested). Agent ownership check in `set_agent_run` prevents accessing other agents' runs. State validation prevents double-completion. No raw SQL, no `html_safe`, no `raw` in templates.
- **AgentRunsController**: `require_company!` before_action. Company-scoped agent lookup via `Current.company.agents.find`. Agent-scoped run lookup. Standard Rails patterns.
- **_log_line.html.erb**: Uses `<%= text %>` which auto-escapes HTML. JSON parsing wrapped in rescue. No XSS vector.
- **Brakeman**: 0 new warnings. Single pre-existing `Mass Assignment` warning in `agent_hooks_controller.rb` (unrelated to this phase).

## Performance Analysis

No high-severity performance findings.

- **Broadcast batching**: `BROADCAST_MIN_INTERVAL = 0.1` (100ms) prevents Action Cable flooding. Every line still persisted via SQL. Class-level `@@last_broadcast_at` hash is lightweight (keyed by integer run ID, cleaned up on terminal state).
- **N+1 risk**: Index query is a flat `@agent.agent_runs.order(...).limit(50)` -- no includes needed since no eager-loaded associations are accessed in the view. Show query loads a single run.
- **API controller**: `find_by` + ownership check is two queries (acceptable for API endpoints).

## Anti-Pattern Check

- No TODO/FIXME/HACK/STUB/XXX markers in any phase 25 files.
- No `html_safe` or `raw` in templates.
- No debug statements (`puts`, `pp`, `debugger`, `binding.pry`).
- No duplicated logic across files -- `broadcast_line!` is the single entry point for both adapter polling and API progress, `mark_completed!` is the single entry point for both adapter results and API results.

## Test Results

- `bin/rails test test/models/agent_run_test.rb test/controllers/agent_runs_controller_test.rb test/controllers/api/agent_runs_controller_test.rb` -- **99 tests, 189 assertions, 0 failures, 0 errors**
- `bin/rails test` -- **1124 tests, 2682 assertions, 0 failures, 0 errors, 0 skips**
- `bin/rubocop` on phase 25 files -- **0 offenses**
- `bin/brakeman` -- **0 new warnings**

## Commits Verified

| Hash | Message | Status |
|------|---------|--------|
| `728c6c7` | feat(25-01): add AgentRun#broadcast_line! and ClaudeLocalAdapter integration | FOUND |
| `ed8ebe6` | feat(25-01): add AgentRunsController, views, routes, and agent show page integration | FOUND |
| `c67911d` | feat(25-02): agent status broadcasting, tool-use indicators, broadcast batching | FOUND |
| `347c000` | feat(25-02): cancel action for running AgentRuns (STREAM-04) | FOUND |
| `f31978e` | feat(25-03): add Api::AgentRunsController with result and progress endpoints | FOUND |
| `39e2bdc` | test(25-03): add integration tests for Api::AgentRunsController result and progress endpoints | FOUND |

## Conclusion

Phase 25 goal is fully achieved. All three parts of the goal are delivered:

1. **Live streaming UI**: Users can view agent run history and watch live output in the browser via Turbo Streams. The `turbo_stream_from` subscription on the show page connects to `broadcast_line!` which both persists and broadcasts. The ClaudeLocalAdapter's poll loop uses `broadcast_line!` so output flows to browsers during execution. Tool-use events render with visual indicators.

2. **Real-time status updates**: Agent status badge updates on both the dashboard (via existing `broadcast_overview_stats`) and the agent show page (via new `broadcast_agent_status` + `turbo_stream_from`). Live indicator on run show page disappears when run reaches terminal state via `broadcast_flush!`.

3. **Result callbacks via API**: Agents can report completion via `POST /api/agent_runs/:id/result` (triggering task status update, conversation message, and budget enforcement) and intermediate progress via `POST /api/agent_runs/:id/progress` (broadcasting as log lines). Both endpoints enforce Bearer token auth and agent ownership.

The autonomous execution loop is now complete: WakeAgentService triggers a run -> ExecuteAgentJob dispatches to adapter -> adapter streams output via broadcast_line! -> agent reports result via API -> task status updates and budget enforced.
