---
phase: 08-budget-cost-control
plan: "04"
status: complete
completed_at: 2026-03-27T18:20:00Z
duration: ~11 minutes
tasks_completed: 1
files_changed: 10
tests_added: 7
total_tests: 540
---

# 08-04 Summary: Notification Bell UI

## Objective

Built the notification bell UI for Phase 8: Budget and Cost Control — bell icon with unread badge count in the app header, dropdown panel with recent notifications, NotificationsController with mark-read actions, and Stimulus controller for toggle/click-outside behavior.

## What Was Done

### Task 1: Notification bell, dropdown, controller, and Stimulus toggle

**New files:**
- `app/controllers/notifications_controller.rb` — `index`, `mark_read` (PATCH), `mark_all_read` (POST) actions; scoped to `Current.company.notifications.where(recipient: Current.user)`; cross-company isolation via `find` on company-scoped relation (raises RecordNotFound → 404); Turbo Stream responses for mark-read and mark-all-read
- `app/helpers/notifications_helper.rb` — `notification_icon` (warning/error/info by action), `notification_message` (formatted with `format_cents_as_dollars` for budget amounts), `notification_link` (routes to agent path for Agent notifiable)
- `app/javascript/controllers/notification_controller.js` — Stimulus controller: `toggle()` toggles `hidden` attribute on panel target; `connect`/`disconnect` adds/removes click-outside listener; auto-registered by `eagerLoadControllersFrom`
- `app/views/notifications/_dropdown.html.erb` — Bell SVG button with unread badge (shows count or hidden when 0), panel with header ("Mark all read" button when unread > 0), and notification list with N+1-safe includes
- `app/views/notifications/_notification.html.erb` — Individual notification with icon dot (color by severity), message link, relative timestamp, and mark-read button (shown only when unread)
- `app/views/notifications/index.html.erb` — Full-page notifications list view (required for HTML format response; avoids 406)

**Modified files:**
- `config/routes.rb` — added `resources :notifications, only: [:index]` with `member { patch :mark_read }` and `collection { post :mark_all_read }`
- `app/views/layouts/application.html.erb` — added `<%= render "notifications/dropdown" %>` inside `<% if Current.company %>` block, after Tasks nav link
- `app/assets/stylesheets/application.css` — added notification dropdown and notification item CSS inside `@layer components`: `.notification-dropdown`, `.notification-dropdown__trigger`, `.notification-dropdown__badge`, `.notification-dropdown__panel`, `.notification-dropdown__header`, `.notification-dropdown__list`, `.notification-dropdown__empty`, `.notification-item`, `.notification-item--unread`, `.notification-item__icon--{warning,error,info}`, `.notification-item__content`, `.notification-item__message`, `.notification-item__mark-read`, `.sr-only`, `.btn--xs`
- `test/controllers/notifications_controller_test.rb` — 7 controller tests

**Deviation (Rule 3 — auto-fixed blocking issue):** The `index` action with `respond_to do |format|; format.html; format.turbo_stream; end` returned 406 Not Acceptable without an `index.html.erb` template (Rails requires the template to exist for the HTML format). Fixed by creating `app/views/notifications/index.html.erb` as a full-page list view.

**Deviation (Rule 1 — auto-fix):** The plan's cross-company test used `assert_response :not_found do ... end` which is invalid Ruby (block on `assert_response` is ignored). Corrected to the established pattern: issue the request first, then call `assert_response :not_found` on the next line (consistent with [03-01] and [07-03] decisions).

## Key Links

- `app/views/layouts/application.html.erb` → `NotificationsController#index` — bell dropdown rendered on every page with `Current.company`; badge count from `User#unread_notification_count(company:)`
- `NotificationsController#mark_read` → `Notification#mark_as_read!` — PATCH action, Turbo Stream replaces the notification partial in-place
- `NotificationsController#mark_all_read` → `Notification.update_all(read_at: Time.current)` — POST action, Turbo Stream clears the badge
- `NotificationsHelper#notification_message` → `BudgetHelper#format_cents_as_dollars` — budget amounts formatted as dollars in notification text
- `notification_controller.js` → `data-notification-target="panel"` — Stimulus toggle targets the panel div by target name

## Commits

| Hash | Description |
|------|-------------|
| 4931ae7 | feat(08-04): add notification bell UI with dropdown, controller, and Stimulus toggle |

## Test Results

- Tests added: 7 (notifications controller)
- Total test suite: 540 tests, 0 failures, 0 errors
- Rubocop: 0 offenses on Ruby files (app/controllers/notifications_controller.rb, app/helpers/notifications_helper.rb)

## Self-Check: PASSED
