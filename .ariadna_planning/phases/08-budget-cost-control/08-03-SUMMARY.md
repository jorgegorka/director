---
phase: 08-budget-cost-control
plan: "03"
status: complete
completed_at: 2026-03-27T18:20:00Z
duration: ~8 minutes
tasks_completed: 1
files_changed: 8
tests_added: 5
total_tests: 533
---

# 08-03 Summary: Budget and Cost UI

## Objective

Built the budget and cost UI for Phase 8: (1) budget configuration fieldset on the agent form, (2) budget spend visualization on the agent show page, and (3) task cost display on task show and index (card) views.

## What Was Done

### Task 1: Agent form budget fields, agent show budget display, task cost views

**New file:** `app/helpers/budget_helper.rb`

Three helper methods:
- `format_cents_as_dollars(cents)` — returns `"---"` for nil, otherwise `"$X.XX"` formatted string
- `budget_bar_class(utilization)` — maps utilization percentage to CSS modifier: `budget-bar--empty` (0), `budget-bar--low` (0.1-49.9), `budget-bar--mid` (50-79.9), `budget-bar--high` (80-99.9), `budget-bar--exhausted` (100+)
- `budget_status_text(agent)` — returns human-readable status string using `budget_configured?`, `budget_exhausted?`, `budget_alert_threshold?`, and `budget_utilization` from Agent model (Plan 08-01)

**Updated `app/controllers/agents_controller.rb`:**

Extended `agent_params` to permit `:budget_dollars` (virtual dollar-value field from form). Conversion logic:
- If `budget_dollars` is present and non-blank: `budget_cents = (dollars.to_f * 100).round`, `budget_period_start = Date.current.beginning_of_month`
- If `budget_dollars` is blank: `budget_cents = nil`, `budget_period_start = nil` (clears budget)
- Dollar conversion extracted before adapter_config handling to keep logic clean

**Updated `app/views/agents/_form.html.erb`:**

Added Monthly Budget fieldset after the Heartbeat Schedule fieldset. Uses `form__input-group` layout with a `$` prefix span (`form__input-prefix`) and the number field styled with `form__input--with-prefix` to visually join prefix to input. Value pre-populated from `agent.budget_cents / 100.0` for edit form. Field is `budget_dollars` (virtual — controller converts to cents).

**Updated `app/views/agents/show.html.erb`:**

Added Budget section between Heartbeat and Capabilities sections:
- When `budget_configured?`: renders `budget-display` with a progress bar using CSS custom property `--budget-fill`, amounts (spent / of limit), remaining, utilization status text, and conditional alert banners at 80% threshold and exhaustion
- When no budget: shows empty note with link to edit page
- Bar color driven by `budget_bar_class(@agent.budget_utilization)`: green → yellow-green → orange → red
- Warning/danger modifier classes on utilization text at 80%+ and 100%+

**Updated `app/views/tasks/show.html.erb`:**

Added a Cost row to the Details `<dl>` after the Completed row, conditionally shown when `@task.cost_cents.present?`. Value displayed as `<strong class="task-cost">$X.XX</strong>`.

**Updated `app/views/tasks/_task.html.erb`:**

Added a cost badge (`task-card__cost task-cost`) to the task card meta section, conditionally rendered when `task.cost_cents.present?`. Displays `format_cents_as_dollars(task.cost_cents)` inline with other meta info.

**CSS additions to `app/assets/stylesheets/application.css`:**

Two additions inside `@layer components`:
1. Form input prefix styles (appended to existing form layer block):
   - `.form__input-group` — flex container for prefix + input
   - `.form__input-prefix` — styled prefix label with joined border
   - `.form__input--with-prefix` — removes start border-radius to merge with prefix

2. New budget components layer block:
   - `.budget-display` — flex column with gap
   - `.budget-display__bar-container` / `.budget-display__bar` — progress bar using `clamp(0%, var(--budget-fill), 100%)`
   - `.budget-bar--{empty,low,mid,high,exhausted}` — OKLCH color variants (green to red)
   - `.budget-display__details`, `.budget-display__amounts`, `.budget-display__status`, `.budget-display__remaining` — layout and typography
   - `.budget-display__utilization--{warning,danger}` — orange/red text with weight
   - `.budget-display__alert--{warning,exhausted}` — info banner backgrounds
   - `.task-cost` — bold neutral-700 for cost values

**New controller tests (5)** in `test/controllers/agents_controller_test.rb`:
- `should create agent with budget` — verifies budget_cents=25000 and budget_period_start=beginning_of_month
- `should update agent budget` — verifies budget_cents=75000 after patch
- `should clear budget when empty string submitted` — verifies both budget_cents and budget_period_start nil after empty submit
- `should show budget section on agent detail page` — asserts `.budget-display` present for claude_agent (has budget)
- `should show no-budget message for agent without budget` — asserts `.agent-detail__empty-note` /No budget configured/ for process_agent (no budget)

## Key Links

- `BudgetHelper` included automatically in all views (Rails includes all helpers)
- `Agent#budget_configured?`, `#budget_utilization`, `#monthly_spend_cents`, `#budget_remaining_cents`, `#budget_exhausted?`, `#budget_alert_threshold?` all come from Plan 08-01 data layer
- `AgentsController#agent_params` → converts `budget_dollars` form field → `budget_cents` + `budget_period_start` columns
- Task cost display reads `Task#cost_cents` populated by Plan 08-02's cost reporting API endpoint

## Commits

| Hash | Description |
|------|-------------|
| a718f03 | feat(08-03): add budget UI to agent form/show and cost display to task views |

## Test Results

- Tests added: 5 (controller tests for budget CRUD and display)
- Total test suite: 533 tests, 0 failures, 0 errors
- Rubocop: 0 offenses on app/helpers/budget_helper.rb and app/controllers/agents_controller.rb

## Self-Check: PASSED
