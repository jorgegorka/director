---
phase: 05-tasks-and-conversations
plan: "03"
subsystem: api
tags: [rails, bearer-token, dual-auth, delegation, escalation, org-chart, audit-trail, json-api]

# Dependency graph
requires:
  - phase: 05-tasks-and-conversations/01
    provides: Task model with Auditable concern, AuditEvent polymorphic records, task fixtures
  - phase: 05-tasks-and-conversations/02
    provides: TasksController, MessagesController, tasks/show.html.erb, audit trail display
  - phase: 03-org-chart-and-roles
    provides: Role model with parent/children hierarchy, agent_id on roles
  - phase: 04-agent-connection
    provides: Agent model with api_token, AgentApiAuthenticatable interface

provides:
  - AgentApiAuthenticatable concern (dual auth: session cookie OR Bearer token)
  - TaskDelegationsController (POST /tasks/:id/delegate, validates org chart subordinate)
  - TaskEscalationsController (POST /tasks/:id/escalate, walks org chart to manager)
  - Delegation/escalation UI forms on task show page
  - AuditEvent records for delegated/escalated actions with correct actor (User or Agent)
  - JSON API endpoints for agent callers; HTML redirects for human UI callers

affects:
  - phase-06 and beyond: AgentApiAuthenticatable pattern available for all future agent API endpoints
  - Any controller needing dual (session + Bearer token) authentication

# Tech tracking
tech-stack:
  added: []
  patterns:
    - AgentApiAuthenticatable concern for dual-auth controllers (session OR Bearer token)
    - current_actor helper returning User or Agent based on auth method
    - respond_success/respond_error/respond_not_found with format-aware responses
    - Org chart hierarchy traversal via Role#parent/children for delegation validation

key-files:
  created:
    - app/controllers/concerns/agent_api_authenticatable.rb
    - app/controllers/task_delegations_controller.rb
    - app/controllers/task_escalations_controller.rb
    - app/views/task_delegations/_form.html.erb
    - app/views/task_escalations/_form.html.erb
    - test/controllers/task_delegations_controller_test.rb
    - test/controllers/task_escalations_controller_test.rb
  modified:
    - config/routes.rb
    - app/helpers/tasks_helper.rb
    - app/views/tasks/show.html.erb
    - test/fixtures/roles.yml

key-decisions:
  - "AgentApiAuthenticatable skips require_authentication and replaces it with session-OR-bearer-token logic — does not modify Authentication concern"
  - "current_actor returns @current_agent if agent API call, else Current.user — determines AuditEvent actor_type and actor_id"
  - "valid_delegation_target? uses role.children.where.not(agent_id: nil).pluck(:agent_id) to find subordinate agents"
  - "find_manager_agent walks up parent chain (while loop) to find nearest ancestor role with an assigned agent"
  - "developer fixture updated with agent: http_agent creating testable hierarchy: CEO -> CTO/claude_agent -> Developer/http_agent"

patterns-established:
  - "Dual-auth pattern: include AgentApiAuthenticatable in any controller needing both session + Bearer token auth"
  - "Agent API callers (format: :json + Bearer token) receive JSON responses; HTML callers get redirects"
  - "Org chart traversal: role.children for delegation targets, role.parent walking for escalation targets"
  - "AuditEvent actor polymorphism: actor_type 'User' for humans, 'Agent' for API callers"

requirements_covered:
  - id: "TASK-03"
    description: "Agents delegate/escalate through org chart hierarchy"
    evidence: "TaskDelegationsController, TaskEscalationsController with hierarchy validation"
  - id: "TASK-04"
    description: "All task actions logged in immutable audit trail with correct actors"
    evidence: "record_audit_event! calls in both controllers with actor: current_actor"

# Metrics
duration: 5min
completed: 2026-03-27
---

# Phase 05 Plan 03: Task Delegation and Escalation Summary

**Dual-authentication task delegation/escalation via org chart traversal — agents call via Bearer token API (JSON), humans call via session UI (HTML redirects), both record immutable AuditEvents with the correct actor**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-03-27T10:48:10Z
- **Completed:** 2026-03-27T10:52:50Z
- **Tasks:** 2 completed
- **Files modified:** 10

## Accomplishments

- AgentApiAuthenticatable concern enables dual authentication (session cookie OR Bearer token) for any controller, setting `@current_agent` for API callers and `current_actor` returns the appropriate polymorphic actor for AuditEvent recording
- TaskDelegationsController validates target is in a subordinate role via `role.children`, reassigns task, records "delegated" AuditEvent — JSON responses for agents, HTML redirects for humans
- TaskEscalationsController walks org chart upward via `parent_role` chain to find nearest ancestor with an assigned agent, records "escalated" AuditEvent — same dual-format responses
- 22 controller tests pass: 12 delegation (6 human/session + 6 agent/Bearer) and 10 escalation (6 human/session + 4 agent/Bearer); full suite 311 tests, 0 failures

## Requirements Covered

| REQ-ID | Requirement | Evidence |
|--------|-------------|----------|
| TASK-03 | Agents delegate/escalate through org chart hierarchy | `TaskDelegationsController`, `TaskEscalationsController` |
| TASK-04 | All task actions logged in immutable audit trail with correct actors | `record_audit_event!(actor: current_actor, ...)` in both controllers |

## Task Commits

Each task was committed atomically:

1. **Task 1: AgentApiAuthenticatable concern and delegation/escalation controllers with dual auth** - `dfb413d` (feat)
2. **Task 2: Delegation/escalation UI forms, fixture updates, and comprehensive controller tests** - `fa02a16` (feat)

## Files Created/Modified

- `app/controllers/concerns/agent_api_authenticatable.rb` - Dual-auth concern: session OR Bearer token, current_actor, format-aware response helpers
- `app/controllers/task_delegations_controller.rb` - Delegate action with subordinate role validation and audit recording
- `app/controllers/task_escalations_controller.rb` - Escalate action with upward org chart traversal and audit recording
- `app/views/task_delegations/_form.html.erb` - Subordinate agent dropdown with optional reason
- `app/views/task_escalations/_form.html.erb` - One-click escalate to named manager with optional reason
- `app/views/tasks/show.html.erb` - Added Workflow Actions section (conditional on assignee present)
- `config/routes.rb` - Added member routes: POST /tasks/:id/delegate and POST /tasks/:id/escalate
- `app/helpers/tasks_helper.rb` - Added delegation_targets_for, can_escalate?, escalation_target_name helpers
- `test/fixtures/roles.yml` - Developer role now has http_agent (CEO -> CTO/claude_agent -> Developer/http_agent)
- `test/controllers/task_delegations_controller_test.rb` - 12 tests (6 human + 6 agent API)
- `test/controllers/task_escalations_controller_test.rb` - 10 tests (6 human + 4 agent API)

## Decisions Made

- AgentApiAuthenticatable uses `skip_before_action :require_authentication` and replaces it with `require_session_or_agent_token` — the existing Authentication concern is untouched
- `find_session_by_cookie` memoized via `@_cached_session` to avoid double DB query when setting Current.session
- `valid_delegation_target?` uses `current_role.children.where.not(agent_id: nil).pluck(:agent_id)` for efficient subordinate lookup
- For `find_manager_agent`, the while-loop traversal (not recursive) avoids stack concerns on deep hierarchies

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 5 success criteria fully met:
- (1) Create/assign tasks via TasksController — done in 05-01/05-02
- (2) Threaded conversation via MessagesController — done in 05-02
- (3) Delegate/escalate through org chart via both UI and API — done in this plan
- (4) Immutable audit trail with correct actors (User or Agent) — done in this plan

Phase 6 can build on AgentApiAuthenticatable for any additional agent API endpoints. No blockers.

---
*Phase: 05-tasks-and-conversations*
*Completed: 2026-03-27*

## Self-Check: PASSED

All created files found. Both task commits verified (dfb413d, fa02a16). 311 tests, 0 failures.
