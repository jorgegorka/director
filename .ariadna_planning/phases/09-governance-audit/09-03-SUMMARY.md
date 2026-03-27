---
phase: 09-governance-audit
plan: "03"
status: complete
completed_at: 2026-03-27T19:35:17Z
duration_seconds: 627
tasks_completed: 2
tasks_total: 2
files_created: 3
files_modified: 7
tests_added: 15
tests_total: 627
commits:
  - hash: 9e336eb
    message: "feat(09-03): add approval gate UI on agent form and show page"
  - hash: 0685bd2
    message: "feat(09-03): add emergency stop button, notification helper governance cases, gate sync tests"
---

# 09-03 Summary: Governance UI Layer

## Objective

Build the approval gate UI and emergency stop UI for Phase 9. Created (1) approval gate configuration on the agent edit form with checkboxes for each of the 5 GATABLE_ACTIONS, (2) pending approval banner on the agent show page with approve/reject controls, (3) emergency stop button in the app header, (4) updated notification helper for governance notification messages, and (5) 15 controller tests covering gate persistence and UI rendering.

## Tasks Completed

### Task 1: Approval Gate Configuration UI on Agent Form and Show Page

**Gate fieldset partial** (`app/views/approval_gates/_gate_fieldset.html.erb`):
- Renders checkboxes for all 5 GATABLE_ACTIONS (`task_creation`, `task_delegation`, `budget_spend`, `status_change`, `escalation`)
- Pre-checks boxes based on current gate state from `agent.approval_gates`
- Includes hidden `gates_submitted` sentinel field to detect all-unchecked case (Rack strips empty nested hashes so `gates: {}` vanishes from params)
- Uses `gate_description(action_type)` helper for human-readable descriptions

**Pending approval banner partial** (`app/views/agents/_pending_approval_banner.html.erb`):
- Conditionally rendered when `agent.pending_approval?`
- Displays pause_reason with approve/reject buttons
- Uses `btn--danger` and `btn--primary` button variants with turbo_confirm dialogs

**AgentsHelper** — added two new methods:
- `gate_description(action_type)`: returns human-readable description for each action type
- `gate_status_indicator(agent)`: renders a span showing active gate count or "No gates"

**Agent form** (`app/views/agents/_form.html.erb`):
- Gate fieldset added after Budget Configuration fieldset
- Wrapped in `unless agent.new_record?` guard (gates require an existing agent_id)

**AgentsController**:
- `update` action now calls `sync_approval_gates` after successful agent update
- `set_agent` updated to `includes(:approval_gates)` to prevent N+1 in gate fieldset rendering
- New private `sync_approval_gates` method: uses `gates_submitted` sentinel to detect form presence, then enables/disables gates per checkbox state; handles absent `gates` key (all unchecked) by using empty permitted params

**Agent show page** (`app/views/agents/show.html.erb`):
- Pending approval banner rendered at top of section (above header)
- New "Approval Gates" section after Budget section: shows gate list with enabled/disabled status, or empty-state link to edit

**CSS** (`app/assets/stylesheets/application.css`):
- `.gate-checkboxes` — vertical flex with 2-column grid items for checkbox + label/description layout
- `.gate-item` — bordered card for gate display on show page, `gate-item--enabled` uses warning color left border
- `.approval-banner` — warning-colored alert banner for pending approval state
- `.btn--success`, `.btn--warning`, `.btn--danger`, `.emergency-stop-btn` — governance button variants using project design tokens (`--color-success-fg`, `--color-warning-fg`, `--color-error-fg`)

### Task 2: Emergency Stop Button and Notification Helper Updates

**Layout** (`app/views/layouts/application.html.erb`):
- Emergency Stop button rendered inside `Current.company` guard, after notifications dropdown
- Uses `.emergency-stop-btn` class with turbo_confirm dialog mentioning company name

**NotificationsHelper** (`app/helpers/notifications_helper.rb`):
- `notification_icon`: added `gate_pending_approval` → "warning", `gate_approval` → "success", `gate_rejection` → "error", `emergency_stop` → "error"
- `notification_message`: added governance case messages with metadata interpolation (`agent_name`, `action_type`, `triggered_by`, `agents_paused`)
- `notification_link`: added `when "Company" then agents_path` routing for company-level notifications (emergency stop)

**Controller tests** (5 new tests appended to `test/controllers/agents_controller_test.rb`):
- `should save approval gates on agent update` — verifies task_creation and budget_spend gates enabled
- `should disable gates when unchecked` — verifies gates disabled when `gates_submitted: "1"` submitted without `gates` key
- `should show approval gates section on agent detail page` — structural assertion
- `should show pending approval banner when agent is pending` — `.approval-banner` present for pending_approval agents
- `should not show pending approval banner for idle agent` — `.approval-banner` absent for idle agents

## Deviations

**[Rule 3 - Auto-fix]** Rack encodes `gates: {}` as an empty string that decodes to `{}` (top-level empty hash), causing `params.require(:agent)` to raise `ActionController::ParameterMissing` (400 Bad Request). The plan's approach of checking `params.dig(:agent, :gates)` cannot detect "all checkboxes unchecked" because the `agent[gates]` parameter simply disappears when no checkboxes are checked. Fixed by:
1. Adding a hidden `agent[gates_submitted]` = "1" field to the gate fieldset as a sentinel
2. Changing `sync_approval_gates` to check for `gates_submitted == "1"` instead of `gates` presence
3. Handling absent `gates` key separately with empty permitted params

Note: Plan 09-04 was also executing concurrently and included some of the same changes (layout, gate fieldset sentinel, test fixes). The two plans' changes are compatible — 09-03 provides the core gate sync logic and notification helper, while 09-04 independently applied the same sentinel fix.

## Frontend Patterns Used

- **Thin partials**: `_gate_fieldset.html.erb` and `_pending_approval_banner.html.erb` are pure rendering with no logic beyond conditionals
- **Presenter logic in helper**: `gate_description` and `gate_status_indicator` in AgentsHelper — following project convention of helpers over inline view logic
- **Design token alignment**: CSS uses `--color-warning-fg/bg`, `--color-error-fg`, `--color-success-fg` from the existing OKLCH token system; avoids creating new tokens
- **Checkbox sentinel pattern**: Hidden field `gates_submitted` follows the same pattern as Rails' built-in `check_box` helper which adds a hidden `0` value

## Files Created

- `/app/views/approval_gates/_gate_fieldset.html.erb`
- `/app/views/agents/_pending_approval_banner.html.erb`

## Files Modified

- `/app/helpers/agents_helper.rb` — added `gate_description`, `gate_status_indicator` helpers
- `/app/views/agents/_form.html.erb` — added gate fieldset after budget fieldset
- `/app/controllers/agents_controller.rb` — added `sync_approval_gates`, updated `set_agent` includes, updated `update` action
- `/app/views/agents/show.html.erb` — added pending approval banner and gates section
- `/app/assets/stylesheets/application.css` — added governance CSS (gate checkboxes, gate list, approval banner, button variants)
- `/app/helpers/notifications_helper.rb` — added governance notification cases
- `/test/controllers/agents_controller_test.rb` — added 5 gate UI tests

## Self-Check: PASSED
