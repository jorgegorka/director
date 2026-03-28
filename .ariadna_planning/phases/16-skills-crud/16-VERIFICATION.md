---
phase: 16-skills-crud
verified: 2026-03-28T13:20:00Z
status: gaps_found
score: "10/11 truths verified | security: 0 critical, 0 high | performance: 1 high"
gaps:
  - truth: "Navigation entry point — Skills CRUD is reachable by URL but not linked from the application nav bar"
    status: partial
    reason: "The application layout (app/views/layouts/application.html.erb) contains nav links for Dashboard, Agents, Tasks, and Audit Log but no link to /skills. Users who do not already know the URL have no discoverable path to the skill catalog. This was not explicitly required by the phase plan (which defined no nav-link task), so it is an integration gap rather than a phase execution failure — but it breaks the E2E user flow of 'browse the skill catalog' from the running app."
    artifacts:
      - path: "app/views/layouts/application.html.erb"
        issue: "No link_to skills_path in the nav block (lines 36-58). Zero references to skills_path exist outside of app/views/skills/ itself."
    missing:
      - "Add `link_to 'Skills', skills_path` to the nav in app/views/layouts/application.html.erb (same pattern as the existing Agents/Tasks/Audit Log links)"
performance_findings:
  - check: "N+1 query on index"
    severity: high
    file: "app/views/skills/_skill.html.erb"
    line: 20
    detail: "skill.agents.size is called for every skill card on the index page. SkillsController#index loads `@skills = Current.company.skills.order(:name)` with no eager loading of the agents association. For a company with N skills this fires N+1 SQL queries (1 for skills, 1 per skill for agent count). Fix: add `.includes(:agents)` to the index query in SkillsController, or add a counter cache column `agents_count` to the skills table."

---

# Phase 16: Skills CRUD — Verification Report

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can browse all skills at /skills, filterable by category | PASS | `SkillsController#index` applies `by_category` scope from `params[:category]`; index view renders `.skills-page__filters` nav with per-category links; 7 index tests pass |
| 2 | User can view skill's full markdown at /skills/:id with assigned agents | PASS | `show` action loads `@agents = @skill.agents.order(:name)`; `show.html.erb` renders `simple_format(@skill.markdown)` and `.skill-detail__agents-list`; 10 show tests pass |
| 3 | User can edit any skill including builtin | PASS | `edit`/`update` actions have no builtin guard; `builtin` not in `skill_params`; test "should update builtin skill content" asserts `builtin` flag unchanged after update |
| 4 | User can create custom skills (builtin: false) and destroy custom skills; cannot destroy builtin skills | PASS | `create` forces `@skill.builtin = false` after params; `destroy` guards with `if @skill.builtin?`; 7 create tests + 3 destroy tests all pass |
| 5 | Skill routes active under `resources :skills` (7 routes) | PASS | `bin/rails routes` confirms all 7 RESTful routes: GET /skills, POST /skills, GET /skills/new, GET /skills/:id/edit, GET /skills/:id, PATCH /skills/:id, DELETE /skills/:id |
| 6 | Index filters skills to current company only (tenant isolation) | PASS | `set_skill` and index use `Current.company.skills`; test "should not show skill from another company" returns 404 |
| 7 | Controller tests verify category filtering | PASS | Tests: "should filter by category", "should highlight active category filter", "should show empty state for category with no skills" all pass |
| 8 | Controller tests verify cross-company isolation (show/update/destroy) | PASS | 3 cross-company 404 tests pass: show, update, destroy with `widgets_strategic_planning` fixture |
| 9 | Builtin protection: edit allowed, destroy blocked with flash alert | PASS | Destroy guard redirects to `skill_url(@builtin_skill)` with `alert: "Built-in skills cannot be deleted."`; test asserts exact flash message |
| 10 | Auth guards: unauthenticated redirect and no-company redirect | PASS | `before_action :require_company!`; 2 auth tests pass — unauthenticated → `new_session_url`, no company → `new_company_url` |
| 11 | Skills CRUD is reachable via application navigation | PARTIAL | Feature works at /skills but no link exists in application layout nav bar — zero references to `skills_path` outside `app/views/skills/` itself |

## Artifact Status

| Artifact | Status | Notes |
|----------|--------|-------|
| `config/routes.rb` | PASS | `resources :skills` at line 31, generates all 7 routes |
| `app/controllers/skills_controller.rb` | PASS | 62 lines, full CRUD with builtin guard and tenant scoping |
| `app/helpers/skills_helper.rb` | PASS | `SKILL_CATEGORIES` constant, `skill_category_options`, `skill_category_badge` |
| `app/views/skills/index.html.erb` | PASS | Category filter nav, skills grid, empty state |
| `app/views/skills/show.html.erb` | PASS | Markdown display, agents list, builtin/custom indicator, conditional delete button |
| `app/views/skills/new.html.erb` | PASS | Thin wrapper delegating to `_form` partial |
| `app/views/skills/edit.html.erb` | PASS | Thin wrapper delegating to `_form` partial |
| `app/views/skills/_form.html.erb` | PASS | Category select, key disabled for persisted builtins, `builtin` field absent |
| `app/views/skills/_skill.html.erb` | PASS | Card with category badge, builtin/custom indicator, agent count |
| `app/assets/stylesheets/application.css` | PASS | All classes present: `.skills-page`, `.skill-card`, `.skill-detail`, `.skill-category-badge--{5 variants}`, `.filter-link`, `.form__hint` |
| `test/controllers/skills_controller_test.rb` | PASS | 35 tests, 103 assertions, 0 failures |

## Key Links

| Link | Status | Notes |
|------|--------|-------|
| `config/routes.rb` → `SkillsController` via `resources :skills` | PASS | Confirmed by `bin/rails routes` |
| `index.html.erb` → `SkillsController#index` via `?category=` param | PASS | `@skills = @skills.by_category(params[:category])` |
| `show.html.erb` → `Skill#agents` via through-association | PASS | `@skill.agents.order(:name)` in controller; `has_many :agents, through: :agent_skills` on model |
| `_form.html.erb` → `SkillsController#create` and `#update` via `form_with(model: skill)` | PASS | Standard Rails routing; form POSTs to `/skills`, PATCHes to `/skills/:id` |
| `SkillsController#destroy` → `Skill#builtin?` guard | PASS | `if @skill.builtin?` at line 43 redirects with alert |
| `SkillsHelper#skill_category_badge` → views | PASS | Called in `_skill.html.erb` and `show.html.erb`; helper confirmed defined |
| `show.html.erb` → `AgentsHelper#agent_status_badge` | PASS | Helper defined in `app/helpers/agents_helper.rb` line 2; called in show view |

## Cross-Phase Integration

**Consumed upstream (phase 13, 14, 15):**
- `Skill` model with `Tenantable`, `by_category` scope, `builtin`/`custom` scopes — all present and used correctly
- `Company#skills` `has_many` association — confirmed in `company.rb` line 7
- `AgentSkill` join model — `has_many :agents, through: :agent_skills` on Skill; fixtures `claude_code_review` and `http_data_analysis` referenced in tests
- Phase 14 skill catalog fixtures (`acme_code_review`, `acme_strategic_planning`, etc.) — all 7 fixture references in test setup resolve

**Downstream consumers (phase 17 prerequisite):**
- Agent show page (`app/views/agents/show.html.erb`) already displays `.skill-badge` elements for agent skills (lines 174-187) — this was added in a prior phase
- The `skills_path` route is navigable and all CRUD actions are reachable by URL

**Navigation gap (integration observation):**
`app/views/layouts/application.html.erb` does not include a Skills nav link. The phase plan did not specify one, so this is not a phase execution failure. However, it means the E2E user flow "user navigates to skill catalog" requires knowing the URL. Phase 17 (Agent Skill Management UI) may be the appropriate place to add this, but it should be tracked.

## Security

Brakeman reports 0 security warnings across all 25 controllers and 73 templates (run confirmed above).

- Strong parameters: `skill_params` permits only `[:key, :name, :description, :markdown, :category]` — `builtin` is excluded (CRUD-03/04 enforcement)
- Tenant isolation: `set_skill` uses `Current.company.skills.find(params[:id])` — cross-company access raises `ActiveRecord::RecordNotFound` (returns 404)
- `simple_format(@skill.markdown)` in show view: Rails' `simple_format` HTML-escapes input by default; user-controlled markdown content is not rendered as raw HTML

## Performance

| Finding | Severity | File | Detail |
|---------|----------|------|--------|
| N+1 agent count on index | HIGH | `app/views/skills/_skill.html.erb:20` | `skill.agents.size` called per card; `SkillsController#index` loads skills with no `.includes(:agents)`. Fix: `.includes(:agents)` in index action, or counter cache. |

No eager loading concern on `show` action — `@agents` is loaded once as a dedicated query.

## Rubocop

`bin/rubocop` on `skills_controller.rb`, `skills_helper.rb`, and `skills_controller_test.rb`: 3 files, 0 offenses.

## Commits Verified

| Hash | Message | Verified |
|------|---------|----------|
| `211c918` | feat(16-01): add skill routes, SkillsController, and SkillsHelper | YES |
| `9c5e148` | feat(16-01): create all skill view templates | YES |
| `c3abe37` | feat(16-01): add CSS for skills pages to application.css | YES |
| `b86febf` | test(16-02): add SkillsController tests (35 tests) | YES |

## Gap Narrative

Phase 16 successfully delivers all specified CRUD mechanics: the controller, all views, the helper, the CSS, and comprehensive tests (35 tests, 103 assertions). The five must-have truths from the phase plan are met. Brakeman reports no security warnings.

Two findings prevent a `passed` status:

1. **Performance (High):** The skill index page has an N+1 query pattern — `skill.agents.size` in `_skill.html.erb` fires one SQL query per skill card because `SkillsController#index` does not call `.includes(:agents)`. For a company with 50 skills (the phase 14 default catalog), this is 51 queries per page load. The fix is a one-line change in the index action.

2. **Navigation gap (Partial truth):** `/skills` is not linked from the application nav bar. The feature is discoverable only by direct URL. This was not in the phase 16 plan scope, but it is an integration gap that leaves the feature inaccessible in a normal user session. It should be addressed in phase 17 or as a standalone fix.
