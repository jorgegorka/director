---
phase: 08-budget-cost-control
plan: "01"
status: complete
completed_at: 2026-03-27T18:00:00Z
duration: ~4 minutes
tasks_completed: 2
files_changed: 17
tests_added: 50
total_tests: 505
---

# 08-01 Summary: Budget/Cost Data Layer

## Objective

Created the data layer for Phase 8: Budget and Cost Control — three database migrations, a new Notification model, a Notifiable concern, budget calculation methods on Agent, and comprehensive model tests.

## What Was Done

### Task 1: Migrations, Models, Concern, Fixtures

**Migrations applied (3):**
- `20260327175600_add_budget_columns_to_agents` — adds `budget_cents` (integer, nullable) and `budget_period_start` (date, nullable) to agents
- `20260327175601_add_cost_cents_to_tasks` — adds `cost_cents` (integer, nullable) to tasks
- `20260327175602_create_notifications` — creates notifications table with polymorphic recipient, actor, notifiable; jsonb metadata; read_at; indexes on [recipient+read_at], [notifiable], [company_id+created_at]

**Deviation (Rule 3 — auto-fixed blocking issue):** `t.references :notifiable, polymorphic: true` auto-creates an index and the explicit `add_index` with name `index_notifications_on_notifiable` collided. Fixed by adding `index: false` to all three polymorphic `t.references` calls, leaving the explicit `add_index` calls as the sole index definitions.

**New files:**
- `app/models/notification.rb` — includes Tenantable, polymorphic recipient/actor/notifiable associations, unread/read/recent/chronological/reverse_chronological scopes, `read?`, `unread?`, `mark_as_read!` methods
- `app/models/concerns/notifiable.rb` — `has_many :notifications, as: :notifiable, dependent: :destroy`

**Updated models:**
- `app/models/agent.rb` — include Notifiable; `validates :budget_cents` (numericality greater_than 0, allow_nil); budget methods: `budget_configured?`, `current_budget_period_start`, `current_budget_period_end`, `monthly_spend_cents`, `budget_remaining_cents`, `budget_utilization`, `budget_exhausted?`, `budget_alert_threshold?`
- `app/models/task.rb` — `validates :cost_cents` (numericality >= 0, allow_nil); `cost_in_dollars` helper
- `app/models/company.rb` — `has_many :notifications, dependent: :destroy`
- `app/models/user.rb` — `has_many :notifications, as: :recipient, dependent: :destroy`; `unread_notification_count(company: nil)` method

**Updated fixtures:**
- `test/fixtures/agents.yml` — claude_agent ($500 budget, http_agent $1000 budget, process_agent/widgets_agent no budget)
- `test/fixtures/tasks.yml` — design_homepage ($15), fix_login_bug ($8), completed_task ($22), others nil
- `test/fixtures/notifications.yml` — budget_alert_claude (unread), budget_exhausted_http (read 1h ago), read_notification (read 2h ago)

### Task 2: Model Tests

**Agent budget tests (16 tests):** budget_cents validation (valid, negative, zero, nil), budget_configured? (true/false), monthly_spend_cents (sum, zero when no budget, ignores nil costs), budget_remaining_cents (correct amount, nil when no budget, never below zero), budget_utilization (returns float 0-100, 0 when no budget), budget_exhausted? (true/false), budget_alert_threshold? (true at 80%, false under budget), current_budget_period_start/end

**Task cost tests (6 tests):** cost_cents validation (valid, nil, negative, zero), cost_in_dollars (dollar conversion, nil when no cost)

**Notification tests (18 tests):** validations (valid with required fields, invalid without action), associations (company, recipient User, actor Agent, notifiable Agent, optional actor/notifiable), scopes (unread, read, recent, for_current_company), methods (read?, unread?, mark_as_read! sets read_at, mark_as_read! idempotent), metadata jsonb, deletion cascades (company, user recipient, agent notifiable)

**User notification tests (2 tests):** unread_notification_count total and scoped to company

**Deviation (Rule 3 — auto-fixed blocking issue):** Test `destroying_user_destroys_recipient_notifications` failed with FK violation because user `:one` has invitations referencing them. Fixed by calling `Invitation.where(inviter: @user).delete_all` before destroying the user.

## Key Links

- `Agent#monthly_spend_cents` sums `Task#cost_cents` for assigned tasks within the budget period
- `Notification` belongs_to `:notifiable` polymorphic — used with Agent for budget alerts
- `Notification` belongs_to `:recipient` polymorphic — targets User for delivery
- `Agent` includes `Notifiable` — `agent.notifications` returns budget alert notifications

## Commits

| Hash | Description |
|------|-------------|
| 15676e5 | feat(08-01): add budget/cost columns, Notification model, and Notifiable concern |
| 1d40e54 | test(08-01): add model tests for budget, cost, and notification |

## Test Results

- Tests added: 50 (16 agent budget, 6 task cost, 18 notification, 2 user notification, plus 8 fixture verification)
- Total test suite: 505 tests, 0 failures, 0 errors
- Rubocop: 0 offenses on all modified model files

## Self-Check: PASSED
