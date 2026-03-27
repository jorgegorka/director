---
phase: 08-budget-cost-control
verified: 2026-03-27T19:20:00Z
status: passed
score: "4/4 truths verified | security: 0 critical, 0 high | performance: 1 medium"
---

# Phase 08 Verification: Budget and Cost Control

## Goal

Users can set and enforce per-agent spending limits with full cost visibility.

## Observable Truths Table

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can set a monthly budget for each agent and see current spend vs. limit | VERIFIED | `AgentsController#agent_params` converts `budget_dollars` form field → `budget_cents` + `budget_period_start`. Agent show page renders `budget-display` section with spend bar, amounts, and remaining. Controller tests at lines 338-376 of `agents_controller_test.rb` cover create, update, clear, and display. |
| 2 | When an agent's budget is exhausted, the system atomically stops the agent — no further actions until budget is replenished or increased | VERIFIED | `BudgetEnforcementService#pause_agent!` calls `agent.update!` in a single DB call (status: paused, pause_reason, paused_at). `AgentCostsController#cost` returns 403 if agent is budget-paused before recording any cost. Service is idempotent — won't re-pause if already paused with "Budget exhausted" in reason. 11 service tests and 12 controller tests cover all cases. |
| 3 | Costs are tracked and displayed per task and per session so the user can see what each piece of work cost | VERIFIED | `tasks.cost_cents` column exists in schema. Cost is displayed on task show page (lines 62-67) and in task card partial (`_task.html.erb` lines 23-25). Cost reporting API accumulates (does not replace) costs per task. Note: "per session" from the requirement maps to per-task in the locked decision (sessions are not tracked separately — this is an accepted scope reduction per 08-01 plan: "Per locked decision: cost tracked per task only"). |
| 4 | User receives an alert (in-app notification) before an agent's budget limit is reached (at 80%) | VERIFIED | `BudgetEnforcementService#notify_budget_alert!` creates Notification records at 80% threshold. Deduplication via `already_notified?` prevents spam per budget period. Bell icon in layout (lines 42-43 of `application.html.erb`) shows unread badge count. Dropdown shows notifications with `notification_message` formatting the agent name and percentage. `NotificationsController#mark_read` and `mark_all_read` let users dismiss alerts. |

## Artifact Status

| File | Status | Notes |
|------|--------|-------|
| `db/migrate/20260327175600_add_budget_columns_to_agents.rb` | PRESENT, SUBSTANTIVE | Adds budget_cents (integer, nullable) and budget_period_start (date, nullable) |
| `db/migrate/20260327175601_add_cost_cents_to_tasks.rb` | PRESENT, SUBSTANTIVE | Adds cost_cents (integer, nullable) |
| `db/migrate/20260327175602_create_notifications.rb` | PRESENT, SUBSTANTIVE | Full notifications table with polymorphic associations, jsonb metadata, indexes |
| `app/models/agent.rb` | PRESENT, SUBSTANTIVE | All 8 budget methods present: budget_configured?, current_budget_period_start/end, monthly_spend_cents, budget_remaining_cents, budget_utilization, budget_exhausted?, budget_alert_threshold?. Validation present. |
| `app/models/task.rb` | PRESENT, SUBSTANTIVE | cost_cents validation (>= 0, allow_nil) and cost_in_dollars helper present |
| `app/models/notification.rb` | PRESENT, SUBSTANTIVE | Tenantable, polymorphic associations, unread/read/recent scopes, read?/unread?/mark_as_read! methods |
| `app/models/concerns/notifiable.rb` | PRESENT, SUBSTANTIVE | has_many :notifications, as: :notifiable, dependent: :destroy |
| `app/models/user.rb` | PRESENT, SUBSTANTIVE | has_many :notifications (as: :recipient, dependent: :destroy) + unread_notification_count helper |
| `app/models/company.rb` | PRESENT, SUBSTANTIVE | has_many :notifications, dependent: :destroy |
| `app/services/budget_enforcement_service.rb` | PRESENT, SUBSTANTIVE | Full service with check!, pause_agent!, notify_budget_exhausted!, notify_budget_alert!, already_notified?, company_recipients |
| `app/controllers/api/agent_costs_controller.rb` | PRESENT, SUBSTANTIVE | cost action with budget-pause gate, cost accumulation, audit event, enforcement trigger, budget summary response |
| `app/controllers/notifications_controller.rb` | PRESENT, SUBSTANTIVE | index, mark_read (PATCH), mark_all_read (POST); company-scoped; Turbo Stream responses |
| `app/helpers/budget_helper.rb` | PRESENT, SUBSTANTIVE | format_cents_as_dollars, budget_bar_class, budget_status_text |
| `app/helpers/notifications_helper.rb` | PRESENT, SUBSTANTIVE | notification_icon, notification_message, notification_link |
| `app/javascript/controllers/notification_controller.js` | PRESENT, SUBSTANTIVE | toggle, close, connect/disconnect with click-outside handler |
| `app/views/agents/_form.html.erb` | PRESENT, SUBSTANTIVE | Budget fieldset with dollar amount input and $ prefix |
| `app/views/agents/show.html.erb` | PRESENT, SUBSTANTIVE | Budget section with bar, amounts, remaining, status text, alert banners |
| `app/views/tasks/show.html.erb` | PRESENT, SUBSTANTIVE | Cost row in Details section, conditionally shown when cost_cents present |
| `app/views/tasks/_task.html.erb` | PRESENT, SUBSTANTIVE | Cost badge in task card meta, conditionally shown |
| `app/views/notifications/_dropdown.html.erb` | PRESENT, SUBSTANTIVE | Bell button with badge, panel with header, list with mark-all-read |
| `app/views/notifications/_notification.html.erb` | PRESENT, SUBSTANTIVE | Icon, message link, timestamp, mark-read button |
| `app/views/notifications/index.html.erb` | PRESENT, SUBSTANTIVE | Full-page list view (required for HTML format response) |
| `app/views/layouts/application.html.erb` | UPDATED | Notification dropdown rendered inside `if Current.company` block |
| `test/fixtures/agents.yml` | PRESENT, SUBSTANTIVE | claude_agent and http_agent have budget_cents and budget_period_start |
| `test/fixtures/tasks.yml` | PRESENT, SUBSTANTIVE | design_homepage (1500), fix_login_bug (800), completed_task (2200) have cost_cents |
| `test/fixtures/notifications.yml` | PRESENT, SUBSTANTIVE | budget_alert_claude (unread), budget_exhausted_http (read), read_notification (read) |
| `test/models/notification_test.rb` | PRESENT, SUBSTANTIVE | 18 tests covering validations, associations, scopes, methods, deletion cascades |
| `test/services/budget_enforcement_service_test.rb` | PRESENT, SUBSTANTIVE | 11 tests covering pause, notifications, dedup, edge cases |
| `test/controllers/api/agent_costs_controller_test.rb` | PRESENT, SUBSTANTIVE | 12 tests covering success, budget enforcement, validation, auth, isolation |
| `test/controllers/notifications_controller_test.rb` | PRESENT, SUBSTANTIVE | 7 tests covering index, mark_read, mark_all_read, cross-company isolation, bell display |
| `config/routes.rb` | UPDATED | notifications resource (index, mark_read, mark_all_read) + cost_api_agent_task route |

## Key Links Verification

| From | To | Via | Status |
|------|----|-----|--------|
| `AgentCostsController#cost` | `BudgetEnforcementService.check!(@current_agent)` | Called after recording cost (line 37) | VERIFIED |
| `BudgetEnforcementService` | `Agent#budget_exhausted?`, `#budget_alert_threshold?` | Reads calculation methods from model | VERIFIED |
| `BudgetEnforcementService` | `Notification.create!` | Creates budget_exhausted and budget_alert notifications | VERIFIED |
| `AgentCostsController` | `AgentApiAuthenticatable` | include sets `@current_agent` and `Current.company` | VERIFIED |
| `AgentCostsController` | `Task#record_audit_event!` | Auditable concern records cost events | VERIFIED |
| `Agent#monthly_spend_cents` | `Task#cost_cents` | Sums costs on assigned_tasks within budget period | VERIFIED |
| `Notification` belongs_to `:notifiable` polymorphic | `Agent` | Budget alerts reference agent | VERIFIED |
| `NotificationsHelper#notification_message` | `BudgetHelper#format_cents_as_dollars` | Calls format helper for budget amounts — works because Rails auto-includes all helpers in view context | VERIFIED |
| `app/views/layouts/application.html.erb` | `notifications/dropdown` partial | Rendered inside `if Current.company` block | VERIFIED |
| `notification_controller.js` | `data-notification-target="panel"` | Stimulus toggle targets panel div | VERIFIED |

## Cross-Phase Integration

- Plan 08-01 data layer (Agent budget methods, Notification model) is consumed by Plan 08-02 service and Plan 08-03/04 UI — confirmed.
- `BudgetEnforcementService` reads `Agent#budget_exhausted?` and `#budget_alert_threshold?` from Phase 08-01 — confirmed working.
- `AgentApiAuthenticatable` concern from Phase 07 is reused correctly for Bearer token auth — confirmed.
- `Task#record_audit_event!` from `Auditable` concern (Phase 05) is called by `AgentCostsController` — confirmed.
- Stimulus controller registration uses `eagerLoadControllersFrom` pattern (auto-discovers all `*_controller.js` in `controllers/`) — `notification_controller.js` is in the correct location and will be auto-discovered.
- `for_company` scope listed in Plan 08-01 must_haves: the actual scope is `for_current_company` (provided by Tenantable). No code references a nonexistent `for_company` scope — this is a plan naming inconsistency only; the functionality is fully covered by `for_current_company`.

## Test Suite Results

```
540 tests, 1330 assertions, 0 failures, 0 errors, 0 skips
```

Brakeman: 0 security warnings.

## Security Findings

No security findings. Notable points:
- `notification_message` outputs a plain Ruby string auto-escaped by ERB — no XSS risk.
- `AgentCostsController` enforces task ownership (assignee_id check) and company scope (`Current.company.tasks.find_by`) before recording cost.
- `NotificationsController` uses company-scoped `find` for mark_read, preventing cross-company access (raises RecordNotFound → 404).
- Bearer token auth handled by `AgentApiAuthenticatable` with timing-safe token lookup via `find_by`.

## Performance Findings

| Severity | Location | Detail |
|----------|----------|--------|
| medium | `app/views/notifications/_dropdown.html.erb` lines 9, 25 | The notification dropdown is rendered on every authenticated page that has `Current.company` set (i.e., every page after company selection). This executes two queries per request: (1) COUNT for badge, (2) SELECT with includes for the list. Both are indexed and bounded (`.recent` limits to 20), but it means 2 queries per page load regardless of whether the dropdown is open. Acceptable for current scale but worth noting as usage grows. |

## Scope Note: "Per Session" Cost Tracking

The phase goal mentions "per task and per session" cost tracking. The locked decision in Plan 08-01 explicitly narrows scope to per-task only ("Per locked decision: cost tracked per task only (no sessions)"). This is a documented scope reduction, not a gap. The task-level granularity is sufficient to meet the observable goal: users can see what each piece of work cost.

## Conclusion

All four success criteria are fully met. The data layer, enforcement service, cost API, and notification UI are all substantive, correctly wired, and tested. The full test suite (540 tests) passes with zero failures. No security issues found. One medium-performance note regarding layout-level queries in the notification dropdown (acceptable at current scale, indexed and bounded).
