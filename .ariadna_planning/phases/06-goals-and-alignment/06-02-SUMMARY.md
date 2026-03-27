---
phase: 06-goals-and-alignment
plan: "02"
status: complete
completed_at: 2026-03-27T12:57:00Z
duration: ~10 minutes
tasks_completed: 2
tasks_total: 2
files_changed: 16
commits: 2
---

# Plan 06-02 Summary: GoalsController, Views, and Tests

## Objective

Built the full controller, views, and test layer for Phase 6: GoalsController with complete CRUD, recursive tree views, task-to-goal linking, mission display on the home page, and progress visualization.

## What Was Built

### Routes
- `resources :goals` added to `config/routes.rb` — 8 RESTful routes (index, show, new, create, edit, update, destroy)

### Controllers
- `app/controllers/goals_controller.rb` — Full CRUD with:
  - `before_action :require_company!` for tenant gating
  - `before_action :set_goal` scoped to `Current.company.goals`
  - `index`: eager loads 3 levels of children (`.includes(children: { children: :children })`)
  - `show`: loads ordered children and tasks with `by_priority`
  - `new`: accepts `parent_id` query param for "Add objective" flow
  - `create`/`update`: strong params with cycle-safe parent_id
  - `destroy`: flash message with title capture before destroy

- `app/controllers/home_controller.rb` — Updated to load `@mission` (first root goal for current company)
- `app/controllers/tasks_controller.rb` — Added `:goal_id` to `task_params`; `new` action accepts `goal_id` query param

### Helpers
- `app/helpers/goals_helper.rb`:
  - `options_for_parent_goal_select(goal)` — builds indented select options, excludes goal itself and descendants (prevents cycles)
  - `options_for_goal_select` — flat indented list for task form
  - `progress_bar_class(percentage)` — returns CSS modifier class based on progress percentage

### Views
- `app/views/goals/index.html.erb` — Goal tree with empty state
- `app/views/goals/_goal_tree_node.html.erb` — Recursive partial: renders goal card with Mission label, progress bar, and nested children
- `app/views/goals/show.html.erb` — Breadcrumb navigation, progress bar, child objectives section with "Add objective" link, tasks section with "Create task for this goal" link
- `app/views/goals/new.html.erb` — Title changes between "New Mission" and "New Objective" based on parent_id presence
- `app/views/goals/edit.html.erb` — Standard edit wrapper
- `app/views/goals/_form.html.erb` — Form with title, description, parent_id select (cycle prevention), position field
- `app/views/home/show.html.erb` — Updated with `home-mission` card (title, description, progress bar) and Goals nav link
- `app/views/tasks/_form.html.erb` — Added goal_id select dropdown after assignee field

### CSS
Added to `app/assets/stylesheets/application.css` `@layer components`:
- Goal tree styles (`.goal-tree`, `.goal-tree__node`, `.goal-tree__content`, `.goal-tree__info`, `.goal-tree__label`, `.goal-tree__title`, `.goal-tree__stats`, `.goal-tree__children`)
- Progress bar component (`.progress-bar`, `.progress-bar--lg`, `.progress-bar__fill`, color modifiers: `--empty`, `--low`, `--mid`, `--high`)
- Goal detail styles (`.goal-detail__header`, `.goal-detail__breadcrumb`, `.goal-detail__progress`, `.goal-detail__actions`, `.goal-detail__body`, `.goal-detail__section`)
- Home mission card (`.home-mission`, `.home-mission__label`, `.home-mission__title`, `.home-mission__description`, `.home-mission__progress`, `.home-mission__percentage`)

All CSS uses actual project token names (`--space-1..--space-12`, `--font-size-sm`, `--border`, `--text-base`, etc.) rather than the plan's semantic aliases.

### Tests
- `test/controllers/goals_controller_test.rb` — 26 tests:
  - Index: 3 (success, tenant isolation, mission label visible)
  - Show: 6 (success, mission label, progress, children, tasks, cross-company 404, breadcrumb)
  - New: 3 (success, parent_id param, form select)
  - Create: 5 (success, mission with no parent, objective with parent, blank title fails, cross-company parent fails)
  - Edit: 1 (success)
  - Update: 2 (success, blank title fails)
  - Destroy: 3 (success, children cascade, task goal_id nullified)
  - Auth: 2 (unauthenticated redirect, no company redirect)
- `test/controllers/home_controller_test.rb` — 3 new tests added (mission card display, Goals link, graceful fallback with no goals company)

## Patterns Used

- **Thin controller** — GoalsController delegates to `Current.company.goals` for all scoping; no business logic in controller
- **Tenantable scoping** — `set_goal` uses `Current.company.goals.find(params[:id])` so cross-company access raises `ActiveRecord::RecordNotFound` → 404
- **Recursive partial** — `_goal_tree_node.html.erb` renders children by calling itself recursively with `depth + 1`; CSS uses `--depth` custom property for `padding-inline-start`
- **Cycle prevention in helper** — `build_goal_options` skips the goal itself and all its descendants using `exclude_goal.descendants.map(&:id)`
- **Mission = root goal** — `goal.mission?` is an alias for `goal.root?` (no type column); displayed with "Mission" label badge
- **Progress roll-up** — Uses `goal.progress_percentage` which calls `subtree_task_ids` → single `Task.where` query for all descendant goals

## Test Coverage

| Category | Tests |
|----------|-------|
| GoalsController — Index | 3 |
| GoalsController — Show | 6 |
| GoalsController — New | 3 |
| GoalsController — Create | 5 |
| GoalsController — Edit | 1 |
| GoalsController — Update | 2 |
| GoalsController — Destroy | 3 |
| GoalsController — Auth | 2 |
| HomeController — Mission display | 3 |
| **New total** | **28** |

Full suite: 373 tests, 970 assertions, 0 failures, 0 errors.

## Commits

| Hash | Message |
|------|---------|
| c4f9932 | feat(06-02): GoalsController CRUD, views, task form goal select, home mission |
| 8cb6c7e | test(06-02): GoalsController tests (26) and HomeController mission tests (3) |

## Deviations

**CSS token mapping (Rule 2 - Auto-fix):** The plan specified CSS custom properties using semantic aliases (`--space-lg`, `--text-sm`, `--border-default`, `--text-primary`, `--radius-full`) that don't exist in the project's token layer. Mapped all references to the actual numeric-scale tokens (`--space-6`, `--font-size-sm`, `--border`, `--text-base`, `9999px`). Verified against existing components in `application.css`. No new token definitions created.

## Self-Check: PASSED
