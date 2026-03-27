---
phase: 03-org-chart-and-roles
plan: "01"
status: complete
started_at: 2026-03-27T07:41:29Z
completed_at: 2026-03-27T07:50:46Z
duration_seconds: 557
tasks_completed: 2
tasks_total: 2
files_changed: 18
---

# Plan 03-01 Summary: Role Model and CRUD Interface

## Objective

Built the Role model with hierarchical parent/child relationships and full CRUD interface for managing organizational roles within a company. Delivers ORG-01 (create/edit roles), ORG-02 foundation (agent_id placeholder), and ORG-03 (hierarchical reporting lines).

## Tasks Completed

### Task 1: Role model with migration, associations, validations, and tests
**Commit:** `2ca4fd3`

- **Migration** `20260327074136_create_roles`: roles table with title (NOT NULL), description, job_spec, company_id FK, parent_id self-referential FK (nullable), agent_id (nullable, no FK — agents table does not exist until Phase 4), unique index on [company_id, title]
- **Role model** (`app/models/role.rb`): Tenantable concern for company scoping, self-referential `belongs_to :parent` / `has_many :children` with `dependent: :nullify`, three hierarchy validations (same company, not self, not descendant cycle), `ancestors`/`descendants`/`depth` methods using Ruby traversal, `roots` scope
- **Company model**: added `has_many :roles, dependent: :destroy`
- **Fixtures** (`test/fixtures/roles.yml`): 3-level hierarchy for acme (CEO→CTO→Senior Developer) and single root for widgets (Operations Lead)
- **19 model tests**: validations, associations, hierarchy methods, scoping, deletion behavior — all pass

### Task 2: RolesController, views, routes, CSS, and controller tests
**Commit:** `d518278`

- **Routes** (`config/routes.rb`): `resources :roles` — 7 standard RESTful routes
- **RolesController** (`app/controllers/roles_controller.rb`): full CRUD scoped to `Current.company`, `require_company!` guard, destroy re-parents children to deleted role's parent via `update_all` before destroy (bypasses `dependent: :nullify` callback)
- **RolesHelper** (`app/helpers/roles_helper.rb`): `options_for_parent_select` filters self and descendants from parent dropdown to prevent cycles
- **Views** (6 files in `app/views/roles/`):
  - `index.html.erb`: roles list with role cards, empty state
  - `show.html.erb`: full detail with direct reports section, Unassigned agent placeholder
  - `new.html.erb` / `edit.html.erb`: form-card layout
  - `_form.html.erb`: title, description, job_spec fields + parent_id select dropdown
  - `_role.html.erb`: role card partial with title, reports-to, description preview, agent dot + "Unassigned", direct report count
- **Home page**: added "Org Chart" link to `home-nav` alongside "Team"
- **CSS** (`app/assets/stylesheets/application.css`): textarea/select form styles, `.roles-page`, `.roles-list`, `.role-card`, `.role-detail` — all using OKLCH design system, CSS nesting, logical properties
- **18 controller tests**: all CRUD actions, auth gates, cross-company isolation, re-parenting on delete — all pass

## Deviations

### [Rule 1 - Test Fix] assert_raises replaced with assert_response :not_found

**Found:** Plan specified `assert_raises(ActiveRecord::RecordNotFound)` for the cross-company isolation test. Rails catches `ActiveRecord::RecordNotFound` at the middleware level and renders a 404 response — the exception does NOT propagate to the integration test.

**Fixed:** Changed `assert_raises(ActiveRecord::RecordNotFound)` to `assert_response :not_found`. The security behavior is identical (roles from other companies return 404); only the test assertion was wrong.

## Verification Results

| Check | Result |
|-------|--------|
| `bin/rails test` | 120 tests, 316 assertions, 0 failures |
| `bin/rails db:migrate:status` | `up 20260327074136 Create roles` |
| Role column names | agent_id, company_id, created_at, description, id, job_spec, parent_id, title, updated_at |
| 7 RESTful role routes | Verified via `bin/rails routes | grep role` |
| `bin/rubocop` | No offenses (74 files inspected) |
| `bin/brakeman` | 0 security warnings |

## Key Design Decisions

- **agent_id column present, no FK**: agents table doesn't exist until Phase 4. Column is there per locked decision in plan.
- **Unique index [company_id, title]**: enforced at DB level — duplicate role titles within a company are rejected
- **Cycle prevention**: three model validations (same company, not self, not descendant) prevent invalid hierarchy configurations
- **Re-parenting on destroy**: controller uses `update_all(parent_id: @role.parent_id)` BEFORE `destroy` to preserve hierarchy continuity when a role is deleted. This intentionally overrides the model's `dependent: :nullify` which would set children to root.
- **options_for_parent_select helper**: filters self and descendants from the select dropdown, preventing cycles at the UI level (model validations are the safety net)
- **Cross-company 404**: `Current.company.roles.find(id)` scopes all lookups to the current company — other-company IDs return 404

## Success Criteria Status

- [x] `bin/rails test` passes with zero failures (120 tests)
- [x] Roles table with: id, title, description, job_spec, company_id, parent_id, agent_id, created_at, updated_at
- [x] Unique index on [company_id, title]
- [x] User can create a role at /roles/new
- [x] User can edit a role at /roles/:id/edit
- [x] User can delete a role — children are re-parented to deleted role's parent
- [x] Roles index at /roles shows all company roles with cards
- [x] Role detail at /roles/:id shows full info, direct reports, Unassigned agent
- [x] Roles scoped to Current.company — cross-company access returns 404
- [x] Home page nav includes "Org Chart" link
- [x] Views use modern CSS (OKLCH, CSS layers, CSS nesting) — no Tailwind
- [x] `bin/rubocop` and `bin/brakeman` pass clean

## Commits

| Hash | Description |
|------|-------------|
| `2ca4fd3` | feat(03-01): Role model with hierarchy, validations, and tests |
| `d518278` | feat(03-01): RolesController, views, routes, CSS, and controller tests |

## Self-Check: PASSED

All 17 files verified present. Both commits (2ca4fd3, d518278) confirmed in git log.
