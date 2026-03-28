---
phase: 25-live-streaming-ui-and-result-callbacks
plan: 03
subsystem: api
tags: [rails, api, agent_runs, callbacks, budget_enforcement, turbo]

# Dependency graph
requires:
  - phase: 25-01
    provides: AgentRun#broadcast_line! for live log streaming
  - phase: 22-01
    provides: AgentRun model with mark_completed!, agent_id FK, task association
  - phase: 08-budget-cost-control
    provides: BudgetEnforcementService.check! for budget tracking after cost reporting

provides:
  - POST /api/agent_runs/:id/result — marks run completed, updates task, posts conversation message, triggers budget enforcement (CALLBACK-01, CALLBACK-03, CALLBACK-04)
  - POST /api/agent_runs/:id/progress — broadcasts progress as log line to subscribed browsers (CALLBACK-02)
  - Api::AgentRunsController with Bearer token auth via AgentApiAuthenticatable

affects: [future agent adapter implementations, v1.5 planning]

# Tech tracking
tech-stack:
  added: []
  patterns: [api-callback-controller, agent-run-result-lifecycle]

key-files:
  created:
    - app/controllers/api/agent_runs_controller.rb
    - test/controllers/api/agent_runs_controller_test.rb
  modified:
    - config/routes.rb

key-decisions:
  - "Agent run callbacks are outside scope :agent block — identified by AgentRun ID, not agent token scope. Auth still via Bearer token through AgentApiAuthenticatable."
  - "record_cost_on_task accumulates cost on the Task model (same as AgentCostsController pattern) before calling BudgetEnforcementService.check!"
  - "update_task_on_completion posts a message from the agent as author — Message model's polymorphic author accepts both User and Agent."

patterns-established:
  - "Api callback controller pattern: include AgentApiAuthenticatable, before_action :set_agent_run with ownership check, validate run state before mutation"
  - "Agent run lifecycle: result callback returns agent to idle, marks run completed, updates task status, posts completion message"

requirements_covered:
  - id: "CALLBACK-01"
    description: "Agent can POST to /api/agent_runs/:id/result with exit_code, cost_cents, and session_id to mark run completed"
    evidence: "app/controllers/api/agent_runs_controller.rb#result"
  - id: "CALLBACK-02"
    description: "Agent can POST to /api/agent_runs/:id/progress with a message to log intermediate progress"
    evidence: "app/controllers/api/agent_runs_controller.rb#progress"
  - id: "CALLBACK-03"
    description: "When result callback reports completion, task status updates to completed and message is posted to conversation"
    evidence: "app/controllers/api/agent_runs_controller.rb#update_task_on_completion"
  - id: "CALLBACK-04"
    description: "When result callback includes cost_cents, budget tracking is updated via BudgetEnforcementService"
    evidence: "app/controllers/api/agent_runs_controller.rb#record_cost_on_task + BudgetEnforcementService.check!"

# Metrics
duration: 2min
completed: 2026-03-28
---

# Plan 25-03: Agent Run Callback Endpoints Summary

**Result and progress callback API endpoints that close the autonomous execution loop: agents report task completion, triggering task status updates, conversation messages, and budget enforcement**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-28T20:24:17Z
- **Completed:** 2026-03-28T20:26:26Z
- **Tasks:** 2
- **Files modified:** 3 (1 created controller, 1 created test, 1 modified routes)

## Accomplishments
- POST /api/agent_runs/:id/result endpoint marks run completed with exit_code, cost_cents, session_id and returns agent to idle (CALLBACK-01)
- Result callback updates task status to completed and posts a completion message authored by the agent to the task conversation (CALLBACK-03)
- Result callback accumulates cost on the task and triggers BudgetEnforcementService.check! (CALLBACK-04)
- POST /api/agent_runs/:id/progress endpoint appends progress messages as log lines via broadcast_line! for real-time streaming (CALLBACK-02)
- 18 integration tests covering all four callbacks, auth, ownership scoping, and error paths — full suite at 1116 tests passing

## Requirements Covered
| REQ-ID | Requirement | Evidence |
|--------|-------------|----------|
| CALLBACK-01 | Agent POSTs result with exit_code/cost_cents/session_id to mark run completed | `Api::AgentRunsController#result` |
| CALLBACK-02 | Agent POSTs progress message for intermediate log output | `Api::AgentRunsController#progress` |
| CALLBACK-03 | Task status updates to completed, message posted to conversation | `#update_task_on_completion` |
| CALLBACK-04 | Cost reported feeds budget tracking via BudgetEnforcementService | `#record_cost_on_task` + `BudgetEnforcementService.check!` |

## Task Commits

Each task was committed atomically:

1. **Task 1: Api::AgentRunsController with result and progress endpoints** - `f31978e` (feat)
2. **Task 2: Integration tests for result and progress callback endpoints** - `39e2bdc` (test)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `app/controllers/api/agent_runs_controller.rb` - Result and progress callback endpoints with Bearer token auth and agent run ownership validation
- `config/routes.rb` - Added `resources :agent_runs` with `result` and `progress` member routes inside `namespace :api`
- `test/controllers/api/agent_runs_controller_test.rb` - 18 integration tests covering CALLBACK-01 through CALLBACK-04, auth, error cases

## Decisions Made
- Agent run callbacks placed outside the `scope :agent` block in routes — runs are identified by their integer ID, not by agent token scoping. Bearer token auth still enforced via AgentApiAuthenticatable.
- The `record_cost_on_task` and `update_task_on_completion` methods are private helpers on the controller, consistent with the thin-controller pattern. Heavy lifting delegated to existing model methods (`mark_completed!`, `broadcast_line!`) and services (`BudgetEnforcementService`).
- No audit event recorded on result callback (unlike AgentCostsController) — the mark_completed! transition itself is the audit trail via the completed_at timestamp.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed redundant `return` at end of `set_agent_run` forbidden branch**
- **Found during:** Task 1 (controller creation)
- **Issue:** rubocop reported `Style/RedundantReturn` — the last `return` inside the unless block was at the end of the method and therefore redundant
- **Fix:** Removed the redundant `return` statement
- **Files modified:** app/controllers/api/agent_runs_controller.rb
- **Verification:** `bin/rubocop app/controllers/api/agent_runs_controller.rb` — no offenses
- **Committed in:** f31978e (Task 1 commit, fixed before committing)

---

**Total deviations:** 1 auto-fixed (1 rubocop/style fix caught pre-commit)
**Impact on plan:** Style-only fix, no functional change. No scope creep.

## Issues Encountered
- One transient SQLite database lock (`database is locked`) appeared in a full suite run during test parallelization. Re-running the suite immediately produced 1116 tests passing, 0 failures, 0 errors. This is a known SQLite parallelism artifact unrelated to this plan's changes.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All four agent run callback requirements (CALLBACK-01 through CALLBACK-04) are implemented and tested
- The autonomous execution loop is now complete: agent receives task via /api/agent/events, executes it, streams progress via /api/agent_runs/:id/progress, and reports completion via /api/agent_runs/:id/result
- v1.4 Agent Execution feature is fully complete across all 25 phases
- Consider v1.5 planning or production deployment review

---
*Phase: 25-live-streaming-ui-and-result-callbacks*
*Completed: 2026-03-28*

## Self-Check: PASSED

All created files confirmed present:
- FOUND: app/controllers/api/agent_runs_controller.rb
- FOUND: test/controllers/api/agent_runs_controller_test.rb
- FOUND: .ariadna_planning/phases/25-live-streaming-ui-and-result-callbacks/25-03-SUMMARY.md

All task commits confirmed:
- FOUND: f31978e (feat: controller and routes)
- FOUND: 39e2bdc (test: integration tests)
