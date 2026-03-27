---
phase: 06-goals-and-alignment
plan: "01"
status: complete
completed_at: 2026-03-27T11:46:00Z
duration: ~8 minutes
tasks_completed: 2
tasks_total: 2
files_changed: 9
commits: 2
---

# Plan 06-01 Summary: Goal Data Layer

## Objective

Created the data layer for Phase 6: Goal model with self-referential tree hierarchy, goal_id FK on tasks, and recursive progress roll-up calculation.

## What Was Built

### Migrations
- `20260327114314_create_goals.rb` — goals table with company_id (FK), parent_id (self-referential FK to goals), title (not null), description, position (default 0), timestamps, composite index on [company_id, parent_id]
- `20260327114317_add_goal_id_to_tasks.rb` — nullable goal_id FK column on tasks table

### Models
- `app/models/goal.rb` — new model with:
  - `Tenantable` concern (company scoping via `for_current_company`)
  - Self-referential tree: `belongs_to :parent`, `has_many :children`, `has_many :tasks`
  - Tree traversal methods: `ancestors`, `descendants`, `root?`, `depth`, `mission?`, `ancestry_chain`
  - Progress roll-up: `progress` (0.0-1.0 float), `progress_percentage` (0-100 integer)
  - Validations: title presence, title uniqueness within [company_id, parent_id] scope, same-company parent, no self-reference, no descendant-as-parent
- `app/models/task.rb` — extended with `belongs_to :goal, optional: true` and cross-company validation
- `app/models/company.rb` — extended with `has_many :goals, dependent: :destroy`

### Fixtures
- `test/fixtures/goals.yml` — 5 goals: acme_mission (root), acme_objective_one + acme_objective_two (children of mission), acme_sub_objective (child of objective_one), widgets_mission (separate tenant)
- `test/fixtures/tasks.yml` — updated 4 tasks with goal references to enable progress testing

### Tests
- `test/models/goal_test.rb` — 33 tests, 79 assertions

## Patterns Used

- **Same tree pattern as Role model** — `ancestors`/`descendants` via iterative/recursive traversal; `root?`, `depth`, validation methods follow Role verbatim (locked user decision)
- **Tenantable concern** — `belongs_to :company` + `for_current_company` scope, no default_scope
- **Subtree progress** — `subtree_task_ids` collects goal IDs for self + descendants, then queries Task.where(goal_id: goal_ids) once per invocation; avoids N+1 on task counts
- **Mission = root goal** — no type column, `mission?` is alias for `root?`; top-level goals have parent_id = nil

## Test Coverage

| Category | Tests |
|----------|-------|
| Validations | 7 |
| Associations | 6 |
| Scopes | 3 |
| Tree traversal | 8 |
| Progress calculation | 6 |
| Task-Goal association | 3 |
| **Total** | **33** |

Full suite: 344 tests, 885 assertions, 0 failures, 0 errors.

## Commits

| Hash | Message |
|------|---------|
| bfdd079 | feat(06-01): Goal model/migrations, Task goal association, Company has_many goals |
| 198a32d | test(06-01): Goal fixtures and comprehensive model tests (33 tests) |

## Self-Check: PASSED

All created files verified present:
- [x] app/models/goal.rb
- [x] db/migrate/20260327114314_create_goals.rb
- [x] db/migrate/20260327114317_add_goal_id_to_tasks.rb
- [x] test/fixtures/goals.yml
- [x] test/models/goal_test.rb

All commits verified:
- [x] bfdd079 — feat(06-01) Task 1
- [x] 198a32d — test(06-01) Task 2

## Deviations

None. All tasks executed as specified.
