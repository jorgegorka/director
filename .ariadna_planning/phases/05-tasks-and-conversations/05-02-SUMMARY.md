---
phase: 05-tasks-and-conversations
plan: "02"
status: complete
completed_at: 2026-03-27T10:45:30Z
duration: ~6 minutes
tasks_completed: 2
files_changed: 19
---

# Plan 05-02 Summary: TasksController, MessagesController, Views, and Tests

## Objective

Build the TasksController with full CRUD, MessagesController for conversation threading, and all associated views. Users can create tasks, assign them to agents, track status/priority, and have threaded conversations on each task. Audit events are automatically recorded on task creation and significant changes.

## What Was Built

### Controllers

**`app/controllers/tasks_controller.rb`**
- Full CRUD scoped to `Current.company` via `before_action :require_company!`
- `index`: loads roots tasks ordered by priority, eager-loads creator and assignee
- `show`: loads root messages with nested replies and authors (`includes(:author, replies: :author)`) to avoid N+1
- `create`: records `created` audit event; records second `assigned` event if assignee present
- `update`: records `status_changed` audit event on status transitions; records `assigned` event on assignment changes
- `set_task` uses `Current.company.tasks.find` — returns 404 for cross-company access automatically

**`app/controllers/messages_controller.rb`**
- `create` action nested under tasks, scoped to `Current.company`
- Sets `author` to `Current.user`
- On success: redirects with anchor to new message (`#message_ID`)
- On failure: reloads task show page state and re-renders with `:unprocessable_entity`

### Helper

**`app/helpers/tasks_helper.rb`**
- `task_status_badge(task)` — renders span with `status-badge--{status}` CSS class
- `task_priority_badge(task)` — renders span with `priority-badge--{priority}` CSS class
- `options_for_task_status` — maps Task.statuses to select-friendly array
- `options_for_task_priority` — maps Task.priorities to select-friendly array
- `options_for_assignee_select` — loads `Current.company.agents.active.order(:name)`
- `audit_event_description(event)` — handles: `created`, `assigned`, `status_changed`, `delegated`, `escalated` (future Plan 03 events pre-handled)

### Views

**Task views (`app/views/tasks/`):**
- `index.html.erb` — task list page with "New Task" button, empty state
- `_task.html.erb` — task card with title link, status/priority badges, assignee, creator, due date, message count
- `new.html.erb` — wraps `_form` partial
- `edit.html.erb` — wraps `_form` partial
- `_form.html.erb` — `form_with(model: task)`, fields: title, description, priority select, assignee select (with blank), due_at datetime-local; conditional status select on edit only
- `show.html.erb` — full detail: header with badges and edit/delete actions, meta dl, threaded conversation with message form, audit trail timeline

**Message views (`app/views/messages/`):**
- `_form.html.erb` — `form_with(url: task_messages_path(task))`, supports `parent_id` hidden field for replies
- `_message.html.erb` — displays author (with Agent badge for agent authors), timestamp, body, reply toggle button using Stimulus `reply` controller
- `_thread.html.erb` — recursive: renders message + indented replies via `message.replies.chronological`

### Stimulus Controller

**`app/javascript/controllers/reply_controller.js`**
- Targets: `form`
- `toggle()` action: toggles `message-reply-form--hidden` CSS class on the reply form container
- Eagerly loaded via the existing `eagerLoadControllersFrom` index

### Navigation Updates

- `app/views/layouts/application.html.erb`: Added "Tasks" link after "Agents" with active state detection (`controller_name == "tasks"`)
- `app/views/home/show.html.erb`: Added "Tasks" link to company home nav

### CSS

Added to `app/assets/stylesheets/application.css` (two additional `@layer components` blocks):

**Tasks styles:**
- `.tasks-page`, `.tasks-page__header`, `.tasks-page__empty`
- `.task-list`, `.task-card`, `.task-card__title`, `.task-card__meta`, `.task-card__unassigned`, `.task-card__messages`
- `.status-badge` with modifiers: `--open` (brand blue), `--in_progress` (teal/accent), `--blocked` (error red), `--completed` (success green), `--cancelled` (neutral gray)
- `.priority-badge` with modifiers: `--low` (neutral), `--medium` (brand blue), `--high` (warning amber), `--urgent` (error red)
- `.task-detail`, `.task-detail__header`, `.task-detail__badges`, `.task-detail__actions`, `.task-detail__body`, `.task-detail__section`, `.task-detail__meta`, `.task-detail__meta-row`, `.task-detail__unassigned`, `.task-detail__empty-note`
- `.audit-trail`, `.audit-trail__event`, `.audit-trail__action`, `.audit-trail__meta`, `.audit-trail__time`

**Messages styles:**
- `.message-thread`, `.message-thread__replies` (indented with left border)
- `.message`, `.message--reply`, `.message__header`, `.message__author`, `.message__author-type`, `.message__timestamp`, `.message__body`, `.message__actions`
- `.message-form`, `.message-form__field`, `.message-form__textarea`, `.message-form__actions`
- `.message-reply-form`, `.message-reply-form--hidden` (display: none for Stimulus toggle)

### Tests

**`test/controllers/tasks_controller_test.rb`** — 17 tests:
- Index: success, company scoping (acme tasks visible, widgets task not)
- Show: success with task title, cross-company returns 404
- New: form renders
- Create: Task.count +1, attributes, creator, assignee, redirect; audit event on create; two events when created with assignee; blank title returns unprocessable_entity
- Update: redirect and attribute update; audit event on status change (uses `.last` to avoid finding fixture event); audit event on assignment change; blank title returns unprocessable_entity
- Destroy: Task.count -1, redirect to index
- Auth: unauthenticated redirects to login; no-company redirects to new_company

**`test/controllers/messages_controller_test.rb`** — 7 tests:
- Create: Message.count +1, redirect with anchor
- Author: author_type "User", author_id matches current user
- Reply: parent association set correctly
- Blank body: unprocessable_entity
- Cross-company task: 404
- Unauthenticated: redirect to login

## Deviations from Plan

### Rule 1: Auto-fix — test assertion for status_changed audit event
The test `should_create_audit_event_on_status_change` initially asserted `event.metadata["from"] == "in_progress"` by using `.find_by(action: "status_changed")`. However, the `design_homepage` task fixture already has a `task_status_changed` audit event fixture with `from: open`. The `find_by` returns the first match (the fixture record), not the newly created one. Fixed by using `.where(action: "status_changed").last` to get the most recently created event, and testing only the `"to"` value (`"blocked"`) which is unambiguous.

## Verification Results

```
bin/rails routes | grep task     -- 7 RESTful task routes + POST /tasks/:task_id/messages (confirmed)
TasksController instance methods -- create, destroy, edit, index, new, show, update (confirmed)
Views in app/views/tasks/        -- _form, _task, edit, index, new, show (confirmed)
bin/rubocop (tasks files)        -- 2 files inspected, no offenses
bin/rails test (controller tests) -- 24 runs, 73 assertions, 0 failures, 0 errors, 0 skips
bin/rails test (full suite)      -- 289 runs, 715 assertions, 0 failures, 0 errors, 0 skips
bin/rubocop                      -- 110 files inspected, no offenses detected
bin/brakeman --quiet --no-pager  -- 0 warnings
```

## Commits

- `04a6cc0` - feat(05-02): TasksController CRUD with routes, views, and audit integration
- `1e5bbcf` - feat(05-02): MessagesController, threaded conversation UI, and controller tests

## Self-Check: PASSED
