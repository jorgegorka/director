---
phase: 07-heartbeats-and-triggers
plan: "03"
status: complete
started_at: 2026-03-27T14:00:00Z
completed_at: 2026-03-27T14:20:00Z
duration_seconds: 1200
tasks_completed: 2
tasks_total: 2
files_created: 5
files_modified: 5
commits:
  - hash: c92453d
    message: "feat(07-03): heartbeat schedule UI on agent form and show page"
  - hash: 13a6074
    message: "feat(07-03): HeartbeatsController, history view, routes, and controller tests"
tests_before: 412
tests_after: 445
tests_added: 33
---

# Plan 07-03 Summary: Heartbeat UI — Agent Form, Show Page, and History View

## Objective

Delivered the user-facing UI for Phase 7 heartbeats: per-agent schedule configuration on the agent edit form, a real heartbeat section on the agent show page (replacing the placeholder), and a dedicated heartbeat history page. This completes BEAT-01, BEAT-03, and BEAT-04 from the project requirements.

## Tasks Completed

### Task 1: Heartbeat schedule fields on agent form and updated show page

**HeartbeatsHelper** (`app/helpers/heartbeats_helper.rb`) — new file:
- `heartbeat_trigger_badge(event)` — renders a colored span badge with CSS class `heartbeat-badge heartbeat-badge--{trigger_type}` and a human-readable label ("Scheduled", "Task Assigned", "Mentioned")
- `heartbeat_status_indicator(event)` — renders a span with CSS class `heartbeat-status heartbeat-status--{status}` showing humanized status
- `heartbeat_schedule_label(agent)` — converts interval minutes to human label ("Every 15 minutes", "Every hour", "Every 2 hours")

**Agent form** (`app/views/agents/_form.html.erb`) — heartbeat schedule fieldset added after adapter config fieldsets:
- `heartbeat_enabled` checkbox with toggle layout
- `heartbeat_interval` select with 9 options (5, 10, 15, 30, 60, 120, 360, 720, 1440 minutes)
- Always visible (not adapter-type-specific)

**AgentsController** (`app/controllers/agents_controller.rb`):
- `show` action now sets `@recent_heartbeats = @agent.heartbeat_events.reverse_chronological.limit(5)`
- `agent_params` now permits `:heartbeat_enabled` and `:heartbeat_interval`

**Agent show page** (`app/views/agents/show.html.erb`) — placeholder heartbeat section replaced with:
- Schedule status (`.agent-detail__heartbeat-config` dl) showing interval label or "Disabled"
- Last activity timestamp or "No activity yet"
- Table of up to 5 recent heartbeat events (trigger badge, status indicator, source, time ago)
- Link to full heartbeat history: `agent_heartbeats_path(@agent)`
- Empty state message when no events exist

**CSS** (`app/assets/stylesheets/application.css`) — new `@layer components` block:
- `.heartbeat-badge` + variant classes (`--scheduled`, `--task_assigned`, `--mention`) using OKLCH colors
- `.heartbeat-status` + variant classes (`--queued`, `--delivered`, `--failed`) using project semantic color variables
- `.heartbeat-active` for enabled schedule indicator
- `.heartbeat-table` margin utilities
- `.heartbeats-history` + child classes for the history page layout
- `.form__toggle`, `.form__toggle-label`, `.form__hint` for the form fieldset

### Task 2: HeartbeatsController, history view, routes, and tests

**Routes** (`config/routes.rb`):
- Added `resources :heartbeats, only: [ :index ]` nested under `resources :agents`
- Route: `GET /agents/:agent_id/heartbeats` → `heartbeats#index` → `agent_heartbeats_path`

**HeartbeatsController** (`app/controllers/heartbeats_controller.rb`):
- `before_action :require_company!` + `before_action :set_agent`
- `set_agent` scopes to `Current.company.agents.find(params[:agent_id])` for multi-tenant isolation
- `index` uses offset-based pagination: 25 per page, `page` param clamped to minimum 1 via `[params[:page].to_i, 1].max`
- Exposes `@heartbeat_events`, `@total_count`, `@current_page`, `@total_pages`

**Heartbeat history view** (`app/views/heartbeats/index.html.erb`):
- Header with agent name link, total event count, and "Back to Agent" button
- Table with trigger badge, status indicator, source, delivered time, created time for each event
- Pagination nav (previous/next links + page X of Y) when `@total_pages > 1`
- Empty state section (`.heartbeats-history__empty`) with trigger type descriptions

**HeartbeatsController tests** (`test/controllers/heartbeats_controller_test.rb`) — 11 tests:
- `should get index for agent with heartbeat events` — 200, h1 present, table present
- `should show empty state for agent without events` — 200, `.heartbeats-history__empty` present
- `should show trigger type badges` — `.heartbeat-badge` present
- `should show status indicators` — `.heartbeat-status` present
- `should show total event count` — subtitle matches `/total events/`
- `should link back to agent` — `a[href=agent_path]` present
- `should not show heartbeats for agent from another company` — 404 (not_found)
- `should redirect unauthenticated user` — redirect to new_session_url
- `should redirect user without company` — redirect to new_company_url
- `should handle page parameter` — page=1 returns 200
- `should handle invalid page gracefully` — page=-1 clamped to 1, returns 200

**AgentsController tests** (`test/controllers/agents_controller_test.rb`) — 6 new tests added:
- `should create agent with heartbeat schedule` — heartbeat_enabled? true, interval 15
- `should update agent heartbeat schedule` — patch updates enabled + interval
- `should disable agent heartbeat` — sending "0" disables heartbeat_enabled
- `should show heartbeat section on agent detail page` — `.agent-detail__heartbeat-config` present
- `should show heartbeat events on agent detail page` — `.heartbeat-table` present (claude_agent has fixtures)
- `should link to heartbeat history from agent page` — `a[href=agent_heartbeats_path]` present

## Deviations

### [Rule 1 - Auto-fix] Cross-company isolation test uses assert_response not assert_raises

**Issue:** Plan specified `assert_raises ActiveRecord::RecordNotFound` for the cross-company isolation test. This pattern doesn't work in ActionDispatch integration tests — Rails middleware catches `RecordNotFound` and returns a 404 response.

**Fix:** Changed to `assert_response :not_found` following the documented project decision from 03-01: "assert_raises(ActiveRecord::RecordNotFound) does not work in integration tests — Rails catches it in middleware and returns 404. Use assert_response :not_found instead."

**Impact:** None. The test verifies the same security property (agents from other companies are inaccessible) using the correct integration test pattern.

## Key Patterns Used

- **HeartbeatsHelper in `app/helpers/`** — Rails includes all helpers in all views, so `heartbeat_trigger_badge` is available in both agents/show and heartbeats/index without explicit include
- **Offset-based pagination** — simple `[page.to_i, 1].max` clamp avoids negative offsets; no external gem required
- **CSS layers** — heartbeat styles added in a new `@layer components` block at end of file, following existing pattern of multiple layer declarations in application.css
- **OKLCH semantic variables** — used `var(--color-success-fg)` and `var(--color-error-fg)` for delivered/failed status (picks up dark mode automatically via token layer)
- **Multi-tenant scoping** — `Current.company.agents.find(params[:agent_id])` in `set_agent` ensures cross-company isolation

## Test Counts

| File | Tests |
|------|-------|
| test/controllers/heartbeats_controller_test.rb | 11 |
| test/controllers/agents_controller_test.rb (new) | 6 |
| **Total added** | **17** |

Wait — the full suite went from 412 to 445, which is 33 new tests. The additional 16 tests came from plan 07-02 (Triggerable concern) which was already in the working tree but not yet committed separately. Full suite: 445 tests, 1141 assertions, 0 failures, 0 errors, 0 skips.

## Files Created

- `app/helpers/heartbeats_helper.rb`
- `app/controllers/heartbeats_controller.rb`
- `app/views/heartbeats/index.html.erb`
- `test/controllers/heartbeats_controller_test.rb`

## Files Modified

- `app/views/agents/_form.html.erb` — heartbeat schedule fieldset added
- `app/views/agents/show.html.erb` — placeholder replaced with real heartbeat section
- `app/controllers/agents_controller.rb` — show action + agent_params updated
- `app/assets/stylesheets/application.css` — heartbeat component styles added
- `config/routes.rb` — nested heartbeats resource added
- `test/controllers/agents_controller_test.rb` — 6 heartbeat schedule tests added

## Self-Check: PASSED
