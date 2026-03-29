---
phase: 28-templates-browse-and-apply-ui
verified: 2026-03-29T16:48:10Z
status: passed
score: "10/10 truths verified | security: 0 critical, 0 high | performance: 0 high"
gaps: []
security_findings: []
performance_findings: []
duplication_findings: []
human_verification: []
---

# Phase 28 Verification: Templates Browse and Apply UI

## Re-verification Context

This is a re-verification following a prior `gaps_found` result. The previous verification identified a single bug: the `prefix.empty? ? "" : ...` guard in `show.html.erb` line 43 permanently kept `new_prefix` empty, so tree-line characters (├──, └──) were never rendered for any child role. Commit `1ec2cda` fixed this by removing the empty-guard entirely:

```
- <% new_prefix = prefix.empty? ? "" : prefix + (is_last ? "&nbsp;&nbsp;&nbsp; " : "&#9474;&nbsp;&nbsp; ") %>
+ <% new_prefix = prefix + (is_last ? "&nbsp;&nbsp;&nbsp;&nbsp;" : "&#9474;&nbsp;&nbsp;&nbsp;") %>
```

This re-verification confirms the fix is correct and all 10 truths now pass.

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | GET /role_templates returns 200 and lists all 5 department templates as cards with name, description, and role count | PASS | Test `should display all 5 department templates` passes with `assert_select ".template-card", 5`; index.html.erb loops `@templates` with `.template-card`, `.template-card__name`, `.template-card__description`, `.template-card__role-count` |
| 2 | GET /role_templates/:id returns 200 and shows full role hierarchy tree with tree-line characters, descriptions, and skill badges | PASS | 200 response verified; `bin/rails runner` trace confirms tree renders correctly: root nodes get `connector=""`, depth-1+ nodes get `connector="└── "` or `connector="├── "`. Full engineering tree traced: CTO (root) → VP Engineering (└──) → Tech Lead (├──) + QA (└──) → Engineer (└──). Skill badges render via `.skill-badge` spans |
| 3 | POST /role_templates/:id/apply creates roles via ApplyRoleTemplateService and redirects to roles_path with flash summary | PASS | Tests `should apply template and redirect with notice` + `should create roles from template` both pass; controller delegates to `ApplyRoleTemplateService.call(company: Current.company, template_key: @template.key)` and redirects to `roles_path` with `notice: result.summary` |
| 4 | POST /role_templates/:id/apply with errors redirects back to template show page with alert | PASS | Controller line 21: `redirect_to role_template_path(@template.key), alert: "Template apply failed: #{result.errors.join(", ")}"` — error path wired correctly |
| 5 | Hierarchy tree uses indented list with tree-line characters (per locked decision) | PASS | Fix in commit 1ec2cda: line 43 is now `new_prefix = prefix + (is_last ? "&nbsp;&nbsp;&nbsp;&nbsp;" : "&#9474;&nbsp;&nbsp;&nbsp;")`. Runtime trace confirms all child roles receive non-empty prefixes and correct connectors (├──, └──, │). The locked decision is now honoured |
| 6 | Apply action uses standard POST redirect with flash (per locked decision) | PASS | `button_to` in show.html.erb POSTs to `apply_role_template_path`; controller uses `redirect_to` with `notice:`/`alert:` |
| 7 | Controller tests cover index, show, apply (success), apply (with skipped roles), and 404 for unknown template | PASS | 17 tests, 43 assertions — all pass green. Covers index (4 tests), show (7 tests), apply (5 tests), auth guard (1 test) |
| 8 | Roles index page has a visible link to /role_templates | PASS | `app/views/roles/index.html.erb` line 7: `link_to "Browse Templates", role_templates_path, class: "btn btn--ghost btn--sm"` in header; line 21: second link in empty state |
| 9 | Tests verify template cards appear on index, hierarchy tree appears on show, flash message appears after apply | PASS | `assert_select ".template-card", 5`; `assert_select ".hierarchy-tree"`; `assert_select ".flash--notice"` — all pass |
| 10 | Tests verify company scoping (require_company! guard) | PASS | Auth guard test creates a fresh user with no company membership, verifies redirect to `new_company_path` |

Score: 10/10 truths verified

## Fix Verification: Tree-Line Characters

The fix in commit `1ec2cda` removes the `prefix.empty? ? "" : ...` conditional that prevented `new_prefix` from ever becoming non-empty. The corrected line is:

```erb
<% new_prefix = prefix + (is_last ? "&nbsp;&nbsp;&nbsp;&nbsp;" : "&#9474;&nbsp;&nbsp;&nbsp;") %>
```

Logic trace for engineering template:
- Root call: `render_tree.call(root_roles, "")` — CTO gets `prefix=""`, `connector=""` (correct: root has no connector)
- CTO is only root, `is_last=true`, so `new_prefix = "" + "&nbsp;&nbsp;&nbsp;&nbsp;"` = 4 non-breaking spaces
- VP Engineering gets `prefix="    "` (non-empty), `connector="└── "` (last child, correct)
- VP is last under CTO, so `new_prefix = "    " + "&nbsp;&nbsp;&nbsp;&nbsp;"` = 8 spaces
- Tech Lead gets `prefix="        "`, `connector="├── "` (not last, correct)
- QA gets `prefix="        "`, `connector="└── "` (last, correct)
- Tech Lead has children, `is_last=false`, so `new_prefix = "        " + "&#9474;&nbsp;&nbsp;&nbsp;"` (│ + 3 spaces)
- Engineer gets `prefix` with │ indicator, `connector="└── "` (last, correct)

Full tree output verified via `bin/rails runner` with ASCII equivalents:
```
CTO
    └── VP Engineering
        ├── Tech Lead
        │   └── Engineer
        └── QA
```

The lambda signature was also cleaned up: the unused `is_last_set` third parameter was removed. Lambda is now `render_tree = ->(roles, prefix) do` and all call sites use 2 arguments.

## Artifact Status

| Artifact | Exists | Substantive | Notes |
|----------|--------|-------------|-------|
| config/routes.rb | YES | YES | `resources :role_templates, only: [:index, :show]` with `member { post :apply }` — generates 3 routes confirmed via `bin/rails routes` |
| app/controllers/role_templates_controller.rb | YES | YES | 32 lines, 3 actions, `require_company!`, `RoleTemplateRegistry`, `ApplyRoleTemplateService`, `TemplateNotFound` rescue |
| app/views/role_templates/index.html.erb | YES | YES | Card grid with `link_to` wrapper, `template.name`, `template.description`, `pluralize(template.roles.size, "role")` |
| app/views/role_templates/show.html.erb | YES | YES | Hierarchy tree lambda with fixed new_prefix (commit 1ec2cda), skill badges, `button_to` with `turbo_confirm` — tree connector logic now correct |
| app/assets/stylesheets/application.css | YES | YES | Lines 5348-5521: full `templates-page`, `templates-grid`, `template-card`, `template-detail`, `hierarchy-tree` CSS block |
| test/controllers/role_templates_controller_test.rb | YES | YES | 17 comprehensive tests, 43 assertions, all pass |
| app/views/roles/index.html.erb | YES | YES | `Browse Templates` link in header (line 7) AND in empty state (line 21) |

## Key Links

| Link | From | To | Via | Status |
|------|------|----|-----|--------|
| Template card → detail | index.html.erb | RoleTemplatesController#show | `link_to role_template_path(template.key)` | PASS |
| Apply button → apply action | show.html.erb | RoleTemplatesController#apply | `button_to apply_role_template_path(@template.key)` POST | PASS |
| Controller → RoleTemplateRegistry | role_templates_controller.rb | RoleTemplateRegistry.all / .find | `@templates = RoleTemplateRegistry.all`; `RoleTemplateRegistry.find(params[:id])` | PASS |
| Controller → ApplyRoleTemplateService | role_templates_controller.rb | ApplyRoleTemplateService.call | `ApplyRoleTemplateService.call(company: Current.company, template_key: @template.key)` | PASS |
| Roles index → Templates browse | roles/index.html.erb | RoleTemplatesController#index | `link_to "Browse Templates", role_templates_path` | PASS |

## Cross-Phase Integration

**Phase 26 (RoleTemplateRegistry):** Registry consumed correctly. `RoleTemplateRegistry.all` called in `index`, `RoleTemplateRegistry.find(params[:id])` in `set_template`. `TemplateNotFound` exception class used for 404 mapping. All 5 YAML templates loadable.

**Phase 27 (ApplyRoleTemplateService):** Service consumed correctly. `ApplyRoleTemplateService.call(company:, template_key:)` matches the service's `def self.call(**kwargs)` signature. `result.success?`, `result.summary`, and `result.errors` all consumed correctly in the controller.

**Auth guard:** `require_company!` from `SetCurrentCompany` concern is consistent with all other company-scoped controllers.

**Navigation integration:** Templates are reached through Roles. The "Roles" nav link leads users to the roles index which exposes "Browse Templates" in both the header actions and the empty state. Discovery path is complete.

## Security Findings

No security findings for phase 28 files. `raw()` in `show.html.erb` line 28 applies only to `prefix + connector`, which are built entirely from hardcoded HTML entity string literals — no user input reaches this call. Brakeman reports 0 warnings on phase 28 files (only pre-existing `permit!` warning in `role_hooks_controller.rb`, unrelated to this phase).

## Performance Findings

No performance concerns. `RoleTemplateRegistry` uses class-level memoization — YAML files are loaded once per process. The template detail view does an in-memory `group_by` and `select` over the template's roles array (max ~10 roles) — negligible cost.

## Test Results

- `bin/rails test test/controllers/role_templates_controller_test.rb`: **17 runs, 43 assertions, 0 failures, 0 errors**
- `bin/rails test test/controllers/roles_controller_test.rb`: **57 runs, 163 assertions, 0 failures, 0 errors** (no regressions)
- `bin/rails test` (full suite): **1184 runs, 3226 assertions, 0 failures, 0 errors**
