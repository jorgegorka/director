---
phase: 10-dashboard-real-time-ui
plan: "03"
status: complete
completed_at: 2026-03-28
duration: ~8 min
tasks_completed: 2
tasks_total: 2
files_changed: 6
tests_added: 8
tests_total: 655
---

# Plan 10-03 Summary: Activity Tab

## Objective

Build the Activity tab for the dashboard showing a unified timeline of all agent activity across the company (DASH-03). The feed aggregates AuditEvent records into a readable timeline, filterable by agent, reusing existing AuditLogsHelper formatting methods.

## Tasks Completed

### Task 1: Activity tab views with agent filter and controller data loading (f8d06c9)

- **DashboardController** — Added `@activity_events` loading from `AuditEvent.for_company(Current.company)` with agent_filter logic: `agents_only` filters by `actor_type: "Agent"`, numeric value filters by specific `actor_id`. Chain ends with `.reverse_chronological.includes(:actor, :auditable).limit(50)`. Added `@filter_agents` for dropdown.
- **show.html.erb** — Updated `data-tabs-active-tab-value` to `params[:tab] || "overview"` so tab param preserves active tab on filter submit. Removed hardcoded `dashboard-tab--active` from overview button (Stimulus handles it on connect). Replaced activity placeholder with `render "dashboard/activity_tab"`.
- **_activity_tab.html.erb** — Activity feed layout with header (h2 + filter form), timeline of events via `_activity_event` partial, "showing 50" notice with link to full audit log, empty state.
- **_activity_event.html.erb** — Individual timeline item: timeline dot, content card with action badge (via `audit_action_badge`), actor (via `audit_actor_display`), relative timestamp (`time_ago_in_words`), target (via `audit_auditable_display`), optional metadata (via `audit_metadata_display`).
- **application.css** — ~95 lines added: `.activity-feed__header`, `.activity-feed__filter`, `.activity-timeline` (vertical line), `.activity-event` + `.activity-event__dot` (timeline dot), `.activity-event__content`, `.activity-event__header`, `.activity-event__actor`, `.activity-event__time`, `.activity-event__target`, `.activity-event__metadata`, `.activity-feed__more`, `.activity-feed__empty`, `.form__select--sm`.

### Task 2: Activity tab controller tests (c52865a)

Added 8 tests to `test/controllers/dashboard_controller_test.rb`:

1. `activity tab shows audit events` — assert_select `.activity-event`, minimum: 1
2. `activity events show action badge` — assert_select `.audit-badge`, minimum: 1
3. `activity tab has agent filter dropdown` — assert_select `select[name='agent_filter']`
4. `agent filter narrows activity results` — GET with `agent_filter: agents(:claude_agent).id`, assert_response :success
5. `agents_only filter shows all agent activity` — GET with `agent_filter: "agents_only"`, assert_response :success
6. `activity tab respects company isolation` — assert_select `.activity-feed` (query-level isolation via `for_company` scope)
7. `tab param sets active tab` — GET with `tab: "activity"`, assert_select `[data-tabs-active-tab-value='activity']`
8. `activity shows link to full audit log` — assert_select `a[href='#{audit_logs_path}']`

## Deviations

None — the controller file had been modified by plan 10-02 (added kanban/task board data), so the activity data was appended after the existing code rather than added as written in the plan. This was an auto-merge with no behavior change.

## Key Decisions

- `@activity_events` uses `includes(:actor, :auditable)` to eager-load both polymorphic associations and avoid N+1 queries in the timeline
- Agent filter uses `params[:agent_filter]` — empty string maps to "all activity", "agents_only" to all agent-initiated events, numeric string to specific agent
- Tab active state driven by `params[:tab] || "overview"` in `data-tabs-active-tab-value` — allows filter form submission (which includes `?tab=activity`) to preserve the active tab
- Hardcoded `dashboard-tab--active` removed from overview button — Stimulus `connect()` now handles initial active state based on `activeTabValue`
- `form__select--sm` added as utility class for compact select elements, reusable beyond dashboard

## Artifacts Created

| File | Purpose |
|------|---------|
| `app/views/dashboard/_activity_tab.html.erb` | Activity feed layout with agent filter |
| `app/views/dashboard/_activity_event.html.erb` | Individual activity event in the timeline |

## Artifacts Modified

| File | Change |
|------|--------|
| `app/controllers/dashboard_controller.rb` | Added activity_events loading with agent_filter logic |
| `app/views/dashboard/show.html.erb` | Dynamic active tab value, render activity_tab partial |
| `app/assets/stylesheets/application.css` | ~95 lines of activity feed CSS |
| `test/controllers/dashboard_controller_test.rb` | 8 new activity tab tests |

## Test Results

- Task 1 verification: `bin/rails test test/controllers/dashboard_controller_test.rb` → **17 tests, 0 failures**
- Task 2 verification: `bin/rails test test/controllers/dashboard_controller_test.rb` → **17 tests, 0 failures**
- Full suite: **655 tests, 1624 assertions, 0 failures, 0 errors, 0 skips**

## Commits

| Hash | Message |
|------|---------|
| f8d06c9 | feat(10-03): add activity tab views, controller data loading, and CSS |
| c52865a | test(10-03): add 8 activity tab tests for dashboard controller |

## Self-Check: PASSED
