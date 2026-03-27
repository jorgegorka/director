---
phase: 08-budget-cost-control
plan: "02"
status: complete
completed_at: 2026-03-27T18:10:00Z
duration: ~8 minutes
tasks_completed: 2
files_changed: 5
tests_added: 23
total_tests: 528
---

# 08-02 Summary: Budget Enforcement Service and Cost Reporting API

## Objective

Built the budget enforcement logic and cost reporting API for Phase 8: (1) BudgetEnforcementService that atomically pauses agents when their budget is exhausted and fires 80% threshold alerts, and (2) the API endpoint for agents to report task costs.

## What Was Done

### Task 1: BudgetEnforcementService with atomic pause and threshold alerts

**New file:** `app/services/budget_enforcement_service.rb`

Service class following the `.check!(agent)` class method pattern (consistent with `WakeAgentService.call()`):

- `BudgetEnforcementService.check!(agent)` — entry point, called after any cost is recorded
- `pause_agent!` — atomic `update!` setting status: paused, pause_reason, and paused_at in one DB call; idempotent (guards against re-pausing already budget-paused agents by checking pause_reason includes "Budget exhausted")
- `notify_budget_exhausted!` — creates Notification records for all company owners and admins when agent is paused for budget exhaustion
- `notify_budget_alert!` — creates Notification records at 80% threshold
- `already_notified?(action)` — deduplication: queries Notification table for existing notification with same action, notifiable, created in current budget period (prevents spam)
- `company_recipients` — fetches all memberships with role: owner or admin, includes :user to avoid N+1
- Guards: skips agents without budget configured, terminated agents

**Deviation (Rule 2 — auto-added missing functionality):** The plan's test assumed `budget_cents: 10000` with a newly created 8500-cent task would trigger the alert threshold. However, `claude_agent` fixture already has tasks assigned (`design_homepage` 1500 + `completed_task` 2200 = 3700 cents in current period). Total spend would be 12200 > 10000, triggering exhaustion instead of alert. Fixed by setting `budget_cents: 15000` so utilization = 12200/15000 = 81.3% (above 80% alert threshold, below 100% exhaustion). Comment added to test explaining the arithmetic.

**New test file:** `test/services/budget_enforcement_service_test.rb` — 11 tests:
- Pauses agent when budget exhausted (status, pause_reason, paused_at verified)
- Creates budget_exhausted notification when pausing
- Creates budget_alert notification at 80% threshold
- Does not create duplicate alert in same budget period
- Does not create duplicate exhausted notification in same period
- Does nothing when agent has no budget configured
- Does nothing for terminated agent
- Does not re-pause already budget-paused agent (paused_at unchanged)
- Notifies all company owners and admins (count-based assertion)
- Does not alert when well under budget
- Notification metadata includes all budget details (budget_cents, spent_cents, period_start, agent_id)

### Task 2: Agent cost reporting API endpoint with budget enforcement trigger

**New file:** `app/controllers/api/agent_costs_controller.rb`

Controller in `Api` module, includes `AgentApiAuthenticatable` for Bearer token auth:

- `cost` action: POST /api/agent/tasks/:id/cost
- Budget-pause gate: returns 403 if agent's pause_reason includes "Budget exhausted"
- Negative cost guard: returns 422 for cost_cents < 0
- Cost accumulation: `new_cost = (task.cost_cents || 0) + cost_cents` — adds to existing, not replace
- Audit event via `task.record_audit_event!(actor: @current_agent, action: "cost_recorded", metadata: {...})`
- Calls `BudgetEnforcementService.check!(@current_agent)` after cost is recorded
- Returns JSON with status, task_id, cost_cents, total_cost_cents, agent_budget summary
- `find_agent_task` handles: task not found (404), task not assigned to this agent (403)
- `budget_summary` reloads agent after enforcement check to reflect current state

**Updated file:** `config/routes.rb` — added cost route inside `namespace :api, scope :agent`:
```
resources :tasks, only: [], controller: "agent_costs", as: "agent_tasks" do
  member { post :cost }
end
```
Route helper: `cost_api_agent_task_url(task)` → POST `/api/agent/tasks/:id/cost`

**New test file:** `test/controllers/api/agent_costs_controller_test.rb` — 12 tests:
- Reports cost for assigned task (success, returns status: "ok")
- Accumulates cost on subsequent reports (total_cost_cents verified)
- Returns budget summary in response (budget_cents, spent_cents, remaining_cents)
- Records audit event for cost (metadata verified)
- Pauses agent when cost exhausts budget (status, pause_reason verified)
- Returns 403 when agent is budget-paused (error message matches)
- Returns 404 for non-existent task
- Returns 403 for task not assigned to this agent (error message matches)
- Returns 422 for negative cost_cents
- Returns 401 without authentication
- Returns 401 with invalid token
- Returns 404 for task in different company (cross-company isolation)

## Key Links

- `AgentCostsController#cost` → `BudgetEnforcementService.check!(@current_agent)` — enforcement triggered after every cost report
- `BudgetEnforcementService` → `Agent#budget_exhausted?`, `Agent#budget_alert_threshold?` — reads budget calculation methods from Plan 08-01
- `BudgetEnforcementService` → `Notification.create!` — creates budget_exhausted and budget_alert notifications
- `AgentCostsController` → `AgentApiAuthenticatable` — Bearer token auth sets `@current_agent` and `Current.company`
- `AgentCostsController` → `Task#record_audit_event!` — Auditable concern records cost events

## Commits

| Hash | Description |
|------|-------------|
| 68f7d69 | feat(08-02): add BudgetEnforcementService with atomic pause and threshold alerts |
| 7085f66 | feat(08-02): add agent cost reporting API endpoint with budget enforcement trigger |

## Test Results

- Tests added: 23 (11 service, 12 controller)
- Total test suite: 528 tests, 0 failures, 0 errors
- Rubocop: 0 offenses on all modified files

## Self-Check: PASSED
