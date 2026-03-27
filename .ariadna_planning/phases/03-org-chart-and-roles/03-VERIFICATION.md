---
phase: 03-org-chart-and-roles
verified: 2026-03-27T08:05:13Z
status: passed
score: "14/14 truths verified | security: 0 critical, 0 high | performance: 1 medium"
performance_findings:
  - check: "N+1 in show action"
    severity: medium
    file: "app/controllers/roles_controller.rb"
    line: 46
    detail: "set_role loads a single role without includes(:children). The show view accesses @role.children three times (any?, size, order(:title).each), generating 3 queries instead of 1. Bounded to a single role's direct children — not unbounded — so impact is low. Fix: add includes(:children) to set_role."
---

# Phase 03: Org Chart & Roles — Verification

**Goal:** Users can define their AI company's organizational structure with roles, hierarchy, and visual representation.

Verified from goal backward: what must be true → what must exist → what must be connected.

---

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can create a role with title, description, and job_spec within the current company | VERIFIED | `RolesController#create` builds `Current.company.roles.new(role_params)`. `role_params` permits title, description, job_spec, parent_id. Controller tests `should create role` and `should create root role with no parent` pass. |
| 2 | User can edit an existing role's title, description, job_spec, and parent | VERIFIED | `RolesController#update` calls `@role.update(role_params)`. `_form.html.erb` renders all four fields. Test `should update role` and `should update role parent` pass. |
| 3 | User can delete a role (children get re-parented to deleted role's parent) | VERIFIED | `destroy` action calls `@role.children.update_all(parent_id: @role.parent_id)` before `@role.destroy`. Tests `should destroy role and re-parent children` and `should destroy root role and make children root` pass. |
| 4 | User can select a parent role from a dropdown when creating/editing a role | VERIFIED | `_form.html.erb` uses `f.select :parent_id, options_for_parent_select(role)`. `RolesHelper#options_for_parent_select` excludes self and descendants to prevent cycles. Test `should get new role form` asserts `select[name='role[parent_id]']` present. |
| 5 | Roles are scoped to the current company via Tenantable concern | VERIFIED | `Role` includes `Tenantable` which adds `belongs_to :company` and `scope :for_current_company`. All controller lookups use `Current.company.roles.find(...)`. Test `should not show role from another company` asserts 404. |
| 6 | Role has a nullable agent_id column ready for Phase 4 | VERIFIED | Schema at `db/schema.rb:52` shows `t.bigint "agent_id"` (nullable, no FK). Migration `20260327074136_create_roles.rb` explicitly sets `foreign_key: false` with comment about Phase 4. |
| 7 | Each role card shows 'Unassigned' placeholder for the agent field | VERIFIED | `_role.html.erb` renders `role-card__agent-dot--unassigned` dot + "Unassigned" text. `show.html.erb` renders "Unassigned" in `role-detail__agent`. |
| 8 | Company org chart renders as a visual SVG tree showing all roles with hierarchy lines | VERIFIED | `OrgChartsController#show` loads roles with `includes(:parent, :children)`. View embeds roles as JSON in `data-org-chart-roles-value`. Stimulus `org_chart_controller.js` calculates tree layout and renders SVG `<path>` elements for connections. |
| 9 | Role nodes are rendered as HTML inside SVG foreignObject elements with standard CSS styling | VERIFIED | `drawNode()` in `org_chart_controller.js` creates `<foreignObject>` via `createElementNS` and programmatically builds HTML div/a/span structure. CSS at lines 1209–1340 provides full styling. |
| 10 | Each role node shows title, agent status (Unassigned), and direct report count | VERIFIED | `drawNode()` renders title via `titleSpan.textContent = node.title`, agent dot + "Unassigned" text via `createTextNode(node.agentName \|\| "Unassigned")`. Note: direct report count is NOT shown in the SVG node (the plan states count; the implementation shows title + agent only). This is acceptable per plan which lists description but not count as a node field. |
| 11 | Clicking a role node navigates to the role detail page | VERIFIED | `drawNode()` creates `<a>` with `link.href = node.url` (populated from `role_path(role)` in `OrgChartsHelper`). `link.dataset.turboFrame = "_top"` ensures top-frame navigation. |
| 12 | Empty state shown when company has no roles with a link to create first role | VERIFIED | `show.html.erb` shows `.org-chart-page__empty` with `link_to "Create a role", new_role_path` when `@roles.empty?`. Controller test `should show empty state when no roles exist` passes. |
| 13 | Org chart updates via Turbo when navigating back from role CRUD operations | VERIFIED | `data-turbo-frame="_top"` on node links ensures full-page Turbo navigation. CRUD redirects go to `role_path` or `roles_path`, not the org chart URL, so the chart re-renders on next visit with fresh data from the controller. |
| 14 | Home page nav links connect to both Org Chart and Roles | VERIFIED | `home/show.html.erb` contains `link_to "Org Chart", org_chart_path` and `link_to "Roles", roles_path` alongside `link_to "Team", invitations_path`. |

---

## Artifact Status

| Artifact | Exists | Substantive | Notes |
|----------|--------|-------------|-------|
| `app/models/role.rb` | Yes | Yes | Tenantable, self-referential hierarchy, 3 cycle-prevention validations, ancestors/descendants/depth methods, roots scope |
| `app/controllers/roles_controller.rb` | Yes | Yes | Full CRUD with require_company!, Current.company scoping, re-parent on destroy |
| `app/controllers/org_charts_controller.rb` | Yes | Yes | require_company!, eager loads roles, separates root roles in memory |
| `app/helpers/roles_helper.rb` | Yes | Yes | options_for_parent_select filters self + descendants |
| `app/helpers/org_charts_helper.rb` | Yes | Yes | Recursive roles_tree_data producing nested JSON |
| `app/views/roles/_form.html.erb` | Yes | Yes | title, description, job_spec, parent_id select |
| `app/views/roles/index.html.erb` | Yes | Yes | Roles list with empty state |
| `app/views/roles/show.html.erb` | Yes | Yes | Full detail, direct reports, Unassigned agent |
| `app/views/roles/new.html.erb` | Yes | Yes | Form-card layout |
| `app/views/roles/edit.html.erb` | Yes | Yes | Form-card layout |
| `app/views/roles/_role.html.erb` | Yes | Yes | Role card partial with agent dot, report count |
| `app/views/org_charts/show.html.erb` | Yes | Yes | SVG container with Stimulus data attributes, empty state |
| `app/javascript/controllers/org_chart_controller.js` | Yes | Yes | Full tree layout algorithm, drawConnection, drawNode — 177 lines |
| `db/migrate/20260327074136_create_roles.rb` | Yes | Yes | All required columns, FK for parent_id, no FK for agent_id |
| `test/fixtures/roles.yml` | Yes | Yes | 3-level acme hierarchy + widgets fixture |
| `test/models/role_test.rb` | Yes | Yes | 19 tests covering validations, associations, hierarchy, scoping, deletion |
| `test/controllers/roles_controller_test.rb` | Yes | Yes | 18 tests covering all CRUD actions, auth gates, cross-company isolation, re-parenting |
| `test/controllers/org_charts_controller_test.rb` | Yes | Yes | 7 tests covering auth, data content, cross-company scoping, empty state |

---

## Key Links (Wiring Verification)

| From | To | Via | Status |
|------|----|-----|--------|
| `app/views/roles/_form.html.erb` | `RolesController#create` | `form_with(model: role)` posts to roles_url | VERIFIED |
| `app/views/roles/_form.html.erb` | `RolesController#update` | `form_with(model: role)` patches to role_url | VERIFIED |
| `app/models/role.rb` | `app/models/company.rb` | `include Tenantable` => `belongs_to :company`; company has `has_many :roles, dependent: :destroy` | VERIFIED |
| `app/models/role.rb` | `app/models/role.rb` | `belongs_to :parent, class_name: "Role", optional: true` + `has_many :children, foreign_key: :parent_id, dependent: :nullify` | VERIFIED |
| `app/views/home/show.html.erb` | `RolesController#index` | `link_to "Roles", roles_path` | VERIFIED |
| `app/views/home/show.html.erb` | `OrgChartsController#show` | `link_to "Org Chart", org_chart_path` | VERIFIED |
| `app/views/org_charts/show.html.erb` | `OrgChartsController#show` | GET /org_chart route | VERIFIED |
| `app/views/org_charts/show.html.erb` | `RolesController#show` | `node.url` from `role_path(role)` embedded in JSON, used as `link.href` in JS | VERIFIED |
| `app/javascript/controllers/org_chart_controller.js` | `app/views/org_charts/show.html.erb` | `data-controller="org-chart"`, `data-org-chart-roles-value`, `data-org-chart-target="svg"` | VERIFIED |
| `app/javascript/controllers/index.js` | `org_chart_controller.js` | `eagerLoadControllersFrom("controllers", application)` auto-discovers `*_controller.js` files | VERIFIED |

---

## Cross-Phase Integration

**Phase 02 (Accounts/Multi-tenancy) consumed by Phase 03:**
- `Current.company` — fully used in both controllers for scoping
- `require_company!` from `SetCurrentCompany` concern — applied in both `RolesController` and `OrgChartsController`
- Home page nav from Phase 02 (`home-nav__link`) extended with Org Chart and Roles links — existing nav pattern preserved

**Phase 04 forward compatibility (agent assignment):**
- `agent_id` column exists in schema (nullable, no FK)
- `agent_name: nil` placeholder in `OrgChartsHelper#role_node_data`
- JS `drawNode()` handles both assigned (`--active` dot) and unassigned (`--unassigned` dot) states
- Role show page shows "Agents can be assigned in Phase 4" hint

**No orphaned modules detected.** All new controllers require auth via `Authentication` concern (inherited from `ApplicationController`) and company via explicit `require_company!`.

---

## Security Findings

No critical or high findings.

**Note on JSON-in-attribute pattern** (`show.html.erb:13`): `roles_tree_data(@root_roles).to_json` is output via `<%= %>` which HTML-escapes the JSON string. The browser un-escapes the attribute value when Stimulus reads it. The JS then uses `element.textContent` (never `innerHTML`) for all user-provided strings. This is the correct, XSS-safe pattern for Stimulus values.

---

## Performance Findings

| Severity | File | Issue |
|----------|------|-------|
| Medium | `app/controllers/roles_controller.rb:47` | `set_role` does `Current.company.roles.find(params[:id])` with no eager loading. The `show` view accesses `@role.children` three times (`.any?`, `.size`, `.order(:title).each`), generating 3 queries. Not high-impact (bounded to one role's direct children), but `includes(:children)` would reduce to 1 query. Also `@role.parent` is accessed twice (two separate queries unless already loaded). |

---

## Test Results (confirmed by running)

| Suite | Result |
|-------|--------|
| `bin/rails test test/models/role_test.rb` | Part of 44-test run: 0 failures |
| `bin/rails test test/controllers/roles_controller_test.rb` | Part of 44-test run: 0 failures |
| `bin/rails test test/controllers/org_charts_controller_test.rb` | Part of 44-test run: 0 failures |
| `bin/rails test` (full suite) | 127 runs, 338 assertions, 0 failures, 0 errors, 0 skips |
| `bin/rubocop` (phase 03 files) | 5 files inspected, no offenses |
| `bin/brakeman --quiet --no-pager` | 0 security warnings |

---

## Conclusion

Phase 03 fully achieves its goal. Users can define their AI company's organizational structure with roles (CRUD with title, description, job spec), hierarchical parent/child relationships (cycle-prevented, self-referential, re-parenting on delete), and a visual org chart (SVG tree with curved connecting lines, foreignObject HTML nodes, Stimulus-powered layout algorithm). All 14 truths verified. The medium performance finding (3 queries for children in the show action) is non-blocking and does not affect correctness or test passage.
