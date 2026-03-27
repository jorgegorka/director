---
phase: 09-governance-audit
plan: "02"
status: complete
completed_at: 2026-03-27T19:21:47Z
duration_seconds: 191
tasks_completed: 2
tasks_total: 2
files_created: 5
files_modified: 5
tests_added: 31
tests_total: 612
commits:
  - hash: 3a4b7d9
    message: "feat(09-02): add GateCheckService and EmergencyStopService"
  - hash: dca94e5
    message: "feat(09-02): add agent pause/resume/terminate/approve/reject actions and emergency stop"
---

# 09-02 Summary: Governance Logic Layer

## Objective

Build the governance logic layer for Phase 9: GateCheckService for checking approval gates before agent actions, EmergencyStopService for company-level bulk pause, and agent status control actions (pause/resume/terminate/approve/reject) on the AgentsController with full audit logging.

## Tasks Completed

### Task 1: GateCheckService and EmergencyStopService

**GateCheckService** (`app/services/gate_check_service.rb`):
- `GateCheckService.check!(agent:, action_type:, context: {})` returns `true` (allowed) or `false` (blocked)
- When gate is active: updates agent to `pending_approval` status with descriptive `pause_reason` ("Approval required: {action_type} gate is active") and sets `paused_at`
- Creates `gate_pending_approval` Notification for all company owners/admins with `action_type`, `agent_name`, `agent_id`, and optional `context` in metadata
- Records `gate_blocked` AuditEvent with `action_type`, `agent_name`, and `context`; agent is both `auditable` and `actor`
- Short-circuits (returns `true`) for terminated agents to avoid gate-blocking an already-stopped agent
- Follows `BudgetEnforcementService` pattern: class method entry point delegating to instance

**EmergencyStopService** (`app/services/emergency_stop_service.rb`):
- `EmergencyStopService.call!(company:, user:)` bulk-pauses all active non-paused/non-terminated agents
- Uses `find_each` to update each agent individually with `PAUSE_REASON` constant and `paused_at` timestamp
- Records a single `emergency_stop` AuditEvent on the company (actor is the triggering User)
- Creates `emergency_stop` Notifications for all company owners/admins with `agents_paused` count and `triggered_by` email
- Returns count of agents paused (used for flash message in controller)
- Cross-company isolation inherent: queries `company.agents.active`

**Tests** (15 service tests, all passing):
- 8 GateCheckService tests: blocked/allowed/disabled-gate cases, notification creation, audit event recording, terminated agent bypass, context passthrough, agent-with-no-gates
- 7 EmergencyStopService tests: bulk pause, count returned, already-paused skipped, terminated skipped, audit event on company, notifications for owners/admins, cross-company isolation

### Task 2: Agent Status Control Actions and Emergency Stop Route

**Routes** (`config/routes.rb`):
- Added 5 member routes to `resources :agents`: `POST :pause`, `POST :resume`, `POST :terminate`, `POST :approve`, `POST :reject`
- Added `POST :emergency_stop` member route to `resources :companies`

**AgentsController** (`app/controllers/agents_controller.rb`):
- Updated `before_action :set_agent` to cover all 5 new member actions
- `pause`: guards against already-paused/terminated, updates status with reason+timestamp, records `agent_paused` AuditEvent
- `resume`: accepts both `paused?` and `pending_approval?` states, sets `idle` with cleared pause fields, records `agent_resumed`
- `terminate`: guards against already-terminated, sets `terminated` status, records `agent_terminated`
- `approve`: only for `pending_approval?` agents, sets `idle` with cleared pause fields, records `gate_approval` AuditEvent
- `reject`: only for `pending_approval?` agents, sets `paused` with rejection reason, records `gate_rejection` AuditEvent
- Private `record_agent_audit(action, extra_metadata)` helper creates `AuditEvent` with `Current.user` as actor and `Current.company`

**CompaniesController** (`app/controllers/companies_controller.rb`):
- Added `emergency_stop` action: finds company via `Current.user.companies.find(params[:id])` (scoped to user's companies), validates it matches `Current.company`, delegates to `EmergencyStopService`, redirects to `agents_path`

**Agent Show View** (`app/views/agents/show.html.erb`):
- Approve/Reject buttons shown only when `@agent.pending_approval?`
- Resume button shown when `paused?` or `pending_approval?` (i.e., not running/idle)
- Pause button shown when agent is not already paused/pending_approval
- Terminate button shown unless `terminated?`
- All buttons use `button_to` with appropriate `turbo_confirm` dialogs

**Tests** (17 new controller tests, 47 total agents controller):
- Status action tests: pause, not-pause-if-paused, resume, resume-from-pending_approval, terminate, not-terminate-if-terminated, approve, reject
- Audit event tests: pause/resume/terminate/approve/reject each records correct audit action
- Emergency stop tests: bulk pause, cross-company isolation, 404 for other company agents

## Deviations

None. Implementation followed plan exactly.

## Backend Patterns Used

- **Service object pattern**: Both services follow the established `BudgetEnforcementService` pattern with class method entry point (`self.check!`/`self.call!`) delegating to instance method, `attr_reader` for dependencies, private helpers for distinct steps
- **AuditEvent direct creation**: Services create `AuditEvent` directly (not via `Auditable` concern) because the agent is simultaneously auditable and actor — matching the pattern established in Phase 5 for cases where the concern's `record_audit_event!` doesn't fit
- **Thin controllers**: Status change logic is minimal in the controller (guard check + `update!` + audit record); all business logic for bulk operations lives in services
- **Current context**: `record_agent_audit` uses `Current.user` and `Current.company` for actor/company without parameter passing
- **Cross-company isolation**: `set_agent` uses `Current.company.agents.find(params[:id])` — raises `RecordNotFound` (404) automatically for agents from other companies

## Files Created

- `/app/services/gate_check_service.rb`
- `/app/services/emergency_stop_service.rb`
- `/test/services/gate_check_service_test.rb`
- `/test/services/emergency_stop_service_test.rb`
- (No new model files — data layer from 09-01)

## Files Modified

- `/config/routes.rb` — added member routes for agents (pause/resume/terminate/approve/reject) and companies (emergency_stop)
- `/app/controllers/agents_controller.rb` — added 5 status actions, updated before_action, added record_agent_audit helper
- `/app/controllers/companies_controller.rb` — added emergency_stop action
- `/app/views/agents/show.html.erb` — added conditional status control buttons
- `/test/controllers/agents_controller_test.rb` — appended 17 new tests

## Self-Check: PASSED
