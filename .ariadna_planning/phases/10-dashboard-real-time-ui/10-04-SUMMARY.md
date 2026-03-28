---
phase: 10-dashboard-real-time-ui
plan: "04"
status: complete
completed_at: 2026-03-28
duration: ~3 min
tasks_completed: 2
tasks_total: 2
files_changed: 13
tests_added: 13
tests_total: 674
---

# Plan 10-04 Summary: Real-time Dashboard via Turbo Streams

## Objective

Wire up real-time updates via Turbo Streams and Action Cable so the dashboard updates live when agent status, task status, or audit events change. Uses `turbo_stream_from` + `Turbo::StreamsChannel.broadcast_*_to` — the standard Rails 8 / Turbo 8 pattern. No custom JavaScript needed.

## Tasks Completed

### Task 1: Turbo Stream broadcasts from models and dashboard subscription (805b169)

- **ApplicationCable::Channel** (`app/channels/application_cable/channel.rb`) — Created base channel class (was missing from project).
- **Dashboard subscription** (`app/views/dashboard/show.html.erb`) — Added `turbo_stream_from "dashboard_company_#{Current.company.id}"` inside the `<section>` tag. Generates a `<turbo-cable-stream-source>` element that auto-subscribes to `Turbo::StreamsChannel`.
- **Agent broadcasts** (`app/models/agent.rb`) — Added `after_commit :broadcast_dashboard_update, if: :saved_change_to_status?`. Private method `broadcast_overview_stats` uses `Turbo::StreamsChannel.broadcast_replace_to` to update the `#dashboard-overview-stats` target with live agent/task counts.
- **Task broadcasts** (`app/models/task.rb`) — Added `after_commit :broadcast_kanban_update` (create/update) and `after_commit :broadcast_kanban_remove` (destroy). Uses remove+append pattern to move kanban cards between columns by targeting `kanban-column-body-{status}`.
- **AuditEvent broadcasts** (`app/models/audit_event.rb`) — Added `after_create_commit :broadcast_activity_event`. Uses `broadcast_prepend_to` to push new events to the top of `#activity-timeline`.
- **View partial updates:**
  - `_kanban_card.html.erb` — Added `id="kanban-task-<%= task.id %>"` for targeted remove/replace.
  - `_activity_event.html.erb` — Added `id="activity-event-<%= event.id %>"` for targeted DOM operations.
  - `_overview_tab.html.erb` — Wrapped stats grid with `id="dashboard-overview-stats"` for broadcast replace target.
  - `_tasks_tab.html.erb` — Added `id="kanban-column-body-<%= status %>"` to each column body for append target.
  - `_activity_tab.html.erb` — Added `id="activity-timeline"` to the timeline div for prepend target.
- **`_overview_stats.html.erb`** — New partial rendering the 4 stat cards (Total Agents, Active Tasks, Tasks Completed, Agents Online) as the broadcast replace payload.

### Task 2: Broadcast and channel tests (c949fed)

Added 13 tests across 5 test files:

- **test/models/agent_test.rb** (2 tests): `broadcast_dashboard_update` private method exists; status change does not error.
- **test/models/task_test.rb** (2 tests): `broadcast_kanban_update` private method exists; status change does not error.
- **test/models/audit_event_test.rb** (2 tests): `broadcast_activity_event` private method exists; creating audit event does not error.
- **test/controllers/dashboard_controller_test.rb** (5 tests): `turbo-cable-stream-source` element present; `[id^='kanban-task-']` elements present; `[id^='activity-event-']` elements present; `#dashboard-overview-stats` element present; `[id^='kanban-column-body-']` × 5 present.
- **test/channels/dashboard_stream_test.rb** (2 tests, new file): stream name includes company id; stream names are unique per company.

## Deviations

None — plan executed as specified. `Turbo::StreamsChannel` is provided by turbo-rails (already a project dependency) so no additional gem or importmap pin was needed.

## Key Decisions

- `turbo_stream_from` helper + `Turbo::StreamsChannel` — standard Rails 8 / Turbo 8 pattern; no custom Action Cable channel JS file needed since turbo-rails handles auto-subscription via the `<turbo-cable-stream-source>` element.
- Stream name convention: `"dashboard_company_#{company_id}"` — simple string ensures company-scoped isolation without cross-tenant leakage.
- Agent broadcasts use `broadcast_replace_to` to replace the entire stats grid — simpler than per-card updates and ensures all four counters stay in sync.
- Task broadcasts use remove+append pattern (not replace) — allows cards to "move" between kanban columns by removing from old position and appending to the new column.
- AuditEvent broadcasts use `broadcast_prepend_to` — new events appear at the top of the timeline (most recent first), matching the `reverse_chronological` display order.
- `after_create_commit` used for AuditEvent (not `after_commit`) — AuditEvent is readonly after persist, so only the initial create is relevant.
- `ApplicationCable::Channel` base class created — was missing from the project's `app/channels/` directory; required for Action Cable to function.

## Artifacts Created

| File | Purpose |
|------|---------|
| `app/channels/application_cable/channel.rb` | Action Cable base channel class |
| `app/views/dashboard/_overview_stats.html.erb` | Broadcast replace partial for overview stats grid |
| `test/channels/dashboard_stream_test.rb` | Stream name convention tests |

## Artifacts Modified

| File | Change |
|------|--------|
| `app/models/agent.rb` | Added `broadcast_dashboard_update` after_commit callback |
| `app/models/task.rb` | Added `broadcast_kanban_update`/`broadcast_kanban_remove` after_commit callbacks |
| `app/models/audit_event.rb` | Added `broadcast_activity_event` after_create_commit callback |
| `app/views/dashboard/show.html.erb` | Added `turbo_stream_from` subscription tag |
| `app/views/dashboard/_overview_tab.html.erb` | Added `id="dashboard-overview-stats"` to stats wrapper |
| `app/views/dashboard/_tasks_tab.html.erb` | Added `id="kanban-column-body-{status}"` to each column body |
| `app/views/dashboard/_kanban_card.html.erb` | Added `id="kanban-task-{id}"` to card wrapper |
| `app/views/dashboard/_activity_event.html.erb` | Added `id="activity-event-{id}"` to event wrapper |
| `app/views/dashboard/_activity_tab.html.erb` | Added `id="activity-timeline"` to timeline div |
| `test/models/agent_test.rb` | 2 broadcast callback tests |
| `test/models/task_test.rb` | 2 broadcast callback tests |
| `test/models/audit_event_test.rb` | 2 broadcast callback tests |
| `test/controllers/dashboard_controller_test.rb` | 5 turbo stream target tests |

## Test Results

- Task 1 verification: `bin/rails test test/controllers/dashboard_controller_test.rb` → **28 tests, 0 failures**
- Task 2 verification: `bin/rails test test/models/agent_test.rb test/models/task_test.rb test/models/audit_event_test.rb test/controllers/dashboard_controller_test.rb test/channels/dashboard_stream_test.rb` → **150 tests, 0 failures**
- Full suite: **674 tests, 1663 assertions, 0 failures, 0 errors, 0 skips**

## Commits

| Hash | Message |
|------|---------|
| 805b169 | feat(10-04): add Turbo Stream broadcasts and dashboard real-time subscription |
| c949fed | test(10-04): add broadcast callback and turbo stream target tests |

## Self-Check: PASSED

All 3 created files verified present. Both commits (805b169, c949fed) confirmed in git log. Full test suite green (674 tests, 0 failures).
