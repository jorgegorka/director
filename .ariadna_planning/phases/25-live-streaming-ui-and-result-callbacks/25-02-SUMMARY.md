---
phase: 25-live-streaming-ui-and-result-callbacks
plan: 02
subsystem: ui
tags: [rails, turbo, turbo-streams, action-cable, agent-runs, cancel, broadcasting]

# Dependency graph
requires:
  - phase: 25-01
    provides: "AgentRun#broadcast_line!, turbo_stream_from subscription in show view, AgentRunsController index/show"
provides:
  - "Agent status badge real-time updates on agent show page via turbo_stream_from agent_#{id} (STREAM-02)"
  - "Tool-use content_block_start events render with visual indicator showing tool name (STREAM-03)"
  - "Cancel functionality: POST /agents/:agent_id/agent_runs/:id/cancel kills tmux and marks cancelled (STREAM-04)"
  - "Broadcast batching 100ms minimum interval prevents Action Cable flooding (STREAM-05)"
  - "broadcast_flush! removes live indicator and cleans state when run reaches terminal status"
affects: [25-03, future-streaming-ui]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "after_commit callback for terminal status broadcast flush"
    - "Class-level hash for per-run broadcast timestamp tracking (Thread-safe via GIL)"
    - "define_singleton_method stubs for tmux kill_session in tests"

key-files:
  created:
    - app/views/agents/_status_badge.html.erb
  modified:
    - app/models/agent_run.rb
    - app/models/agent.rb
    - app/controllers/agent_runs_controller.rb
    - app/views/agent_runs/show.html.erb
    - app/views/agent_runs/_log_line.html.erb
    - app/views/agents/show.html.erb
    - app/assets/stylesheets/application.css
    - config/routes.rb
    - test/models/agent_run_test.rb
    - test/controllers/agent_runs_controller_test.rb

key-decisions:
  - "assert_raises(ActiveRecord::RecordNotFound) does not work in Rails integration tests -- use assert_response :not_found (consistent with STATE.md decision from 25-01)"
  - "cancel! raises on terminal? (not just completed/failed) to handle all 3 terminal states consistently"
  - "broadcast_flush! fires via after_commit not inside mark_completed!/mark_failed! -- cleaner, fires after DB commit"

patterns-established:
  - "Agent status badge partial pattern: _status_badge.html.erb with id=agent-status-badge-{id} for Turbo replacement"
  - "Cancel action pattern: controller checks terminal?, delegates to model cancel!, redirects with flash"
  - "Broadcast batching via @@last_broadcast_at class-level hash keyed by run ID"

requirements_covered:
  - id: "STREAM-02"
    description: "Agent status badge updates in real time on agent show page"
    evidence: "Agent#broadcast_agent_status + turbo_stream_from in agents/show.html.erb"
  - id: "STREAM-03"
    description: "Tool-use events render with distinct visual indicator showing tool name"
    evidence: "app/views/agent_runs/_log_line.html.erb JSON parsing + CSS tool-indicator badge"
  - id: "STREAM-04"
    description: "Cancel button kills tmux session and marks run cancelled within seconds"
    evidence: "AgentRun#cancel! + AgentRunsController#cancel + POST /cancel route"
  - id: "STREAM-05"
    description: "Broadcast batching enforces 100ms minimum interval between Action Cable broadcasts"
    evidence: "AgentRun#broadcast_line! with BROADCAST_MIN_INTERVAL + @@last_broadcast_at"

# Metrics
duration: 4min
completed: 2026-03-28
---

# Phase 25 Plan 02: Agent Status Broadcasting, Cancel, Tool Indicators, Batching Summary

**Real-time agent status badge on show page, tool-use visual indicators in log output, one-click cancel with tmux kill, and 100ms broadcast batching -- completing the STREAM-02 through STREAM-05 requirements**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-28T20:24:39Z
- **Completed:** 2026-03-28T20:28:56Z
- **Tasks:** 2
- **Files modified:** 10 + 1 created

## Accomplishments
- Agent status badge now updates in real time on the agent show page (STREAM-02): `turbo_stream_from "agent_#{id}"` subscription + `broadcast_agent_status` method added to `Agent#broadcast_dashboard_update`
- Tool-use JSON events (`content_block_start` with `type: "tool_use"`) render as styled badge with tool name, plain text lines pass through unchanged (STREAM-03)
- Cancel button on running/queued AgentRun POSTs to new `cancel` member action, which calls `cancel!` to kill the tmux session and mark the run cancelled; agent returns to idle (STREAM-04)
- Broadcast batching enforces minimum 100ms interval between Action Cable pushes while persisting every line via `append_log!` (STREAM-05); `broadcast_flush!` cleans up tracking state and removes live indicator when run reaches terminal status

## Requirements Covered
| REQ-ID | Requirement | Evidence |
|--------|-------------|----------|
| STREAM-02 | Agent status badge real-time update on show page | `Agent#broadcast_agent_status`, `agents/_status_badge.html.erb`, `turbo_stream_from` in agents/show |
| STREAM-03 | Tool-use events display with visual indicator | `_log_line.html.erb` JSON parsing, `.agent-run-output__tool-indicator` CSS |
| STREAM-04 | Cancel kills tmux session and marks cancelled | `AgentRun#cancel!`, `AgentRunsController#cancel`, POST /cancel route |
| STREAM-05 | Broadcast batching 100ms minimum interval | `BROADCAST_MIN_INTERVAL`, `@@last_broadcast_at` hash, `broadcast_flush!` callback |

## Task Commits

Each task was committed atomically:

1. **Task 1: Agent status broadcasting, tool-use indicators, broadcast batching** - `c67911d` (feat)
2. **Task 2: Cancel action for running AgentRuns** - `347c000` (feat)

## Files Created/Modified
- `app/views/agents/_status_badge.html.erb` - New partial with `id="agent-status-badge-{id}"` for Turbo replacement
- `app/models/agent.rb` - `broadcast_agent_status` method in `broadcast_dashboard_update`
- `app/models/agent_run.rb` - `BROADCAST_MIN_INTERVAL`, `@@last_broadcast_at`, batching in `broadcast_line!`, `broadcast_flush!`, `cancel!`, `terminal_status_reached?`, `after_commit :broadcast_flush!`
- `app/controllers/agent_runs_controller.rb` - `cancel` action, updated `before_action` to include `:cancel`
- `app/views/agent_runs/show.html.erb` - `id="agent-run-live-indicator"` on live indicator, Cancel Run button
- `app/views/agent_runs/_log_line.html.erb` - Tool-use JSON detection, conditional rendering
- `app/views/agents/show.html.erb` - `turbo_stream_from "agent_#{@agent.id}"`, use `_status_badge` partial
- `app/assets/stylesheets/application.css` - `.agent-run-output__line--tool` and `.agent-run-output__tool-indicator` CSS
- `config/routes.rb` - `member { post :cancel }` inside `agent_runs` resource block
- `test/models/agent_run_test.rb` - Tests for cancel!, broadcast batching, tool-use handling, terminal flush
- `test/controllers/agent_runs_controller_test.rb` - Tests for cancel action (auth, state, scoping)

## Decisions Made
- Used `assert_response :not_found` (not `assert_raises`) in controller tests -- consistent with STATE.md decision from Plan 01: Rails integration tests catch RecordNotFound and return 404
- `cancel!` checks `terminal?` (covers all 3 terminal statuses) rather than just `completed? || failed?` -- more defensive and consistent
- `broadcast_flush!` fires via `after_commit` callback rather than inside `mark_completed!`/`mark_failed!` -- fires only after DB transaction commits, prevents premature live indicator removal

## Deviations from Plan

None - plan executed exactly as written with one minor adaptation: the controller test for "cancel scopes to current company" was updated to use `assert_response :not_found` instead of `assert_raises(ActiveRecord::RecordNotFound)` because Rails integration tests catch the exception and return HTTP 404 (pre-existing pattern documented in STATE.md from Plan 01 execution).

## Issues Encountered
- None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- STREAM-02 through STREAM-05 complete; live streaming UI feature set is fully implemented
- Phase 25 Plan 03 (if it exists) can build on complete cancel + streaming infrastructure
- All 1124 tests passing with 0 failures

## Self-Check: PASSED

- `app/views/agents/_status_badge.html.erb` -- FOUND
- `app/models/agent_run.rb` -- FOUND
- `app/controllers/agent_runs_controller.rb` -- FOUND
- `.ariadna_planning/phases/25-live-streaming-ui-and-result-callbacks/25-02-SUMMARY.md` -- FOUND
- Commit `c67911d` (Task 1) -- FOUND
- Commit `347c000` (Task 2) -- FOUND
- 1124 tests, 0 failures, 0 errors -- VERIFIED

---
*Phase: 25-live-streaming-ui-and-result-callbacks*
*Completed: 2026-03-28*
