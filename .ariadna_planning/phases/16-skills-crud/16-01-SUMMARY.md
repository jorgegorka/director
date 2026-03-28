---
phase: 16-skills-crud
plan: 01
status: complete
completed_at: 2026-03-28
duration: ~8 min
tasks_completed: 3
tasks_total: 3
commits:
  - hash: 211c918
    message: "feat(16-01): add skill routes, SkillsController, and SkillsHelper"
  - hash: 9c5e148
    message: "feat(16-01): create all skill view templates"
  - hash: c3abe37
    message: "feat(16-01): add CSS for skills pages to application.css"
files_modified: 10
---

# 16-01 Summary: Skills CRUD UI

## Objective

Created the full Skills CRUD UI: routes, controller, views, helper, and CSS. Users can browse their company's skill catalog with category filtering, view skill details (including assigned agents), edit any skill's instruction content, create new custom skills, and destroy custom skills. Builtin skills can be edited but not destroyed.

## Tasks Completed

### Task 1: Skill routes, SkillsController, and SkillsHelper (commit 211c918)

**Files:** `config/routes.rb`, `app/controllers/skills_controller.rb`, `app/helpers/skills_helper.rb`

Added `resources :skills` to routes (7 RESTful routes active). Created SkillsController following established CRUD pattern from RolesController:

- `index`: loads company-scoped skills ordered by name, applies `by_category` scope from `params[:category]`, derives `@categories` from actual company data (not hardcoded)
- `show`: loads `@agents` via `skill.agents` through-association
- `create`: forces `builtin: false` after strong params to enforce CRUD-04 (users cannot set builtin)
- `update`: permits editing all skills including builtin (CRUD-03)
- `destroy`: guards with `builtin?` check — redirects with alert for builtin skills (CRUD-03), destroys custom skills (CRUD-04)
- `set_skill`: scoped to `Current.company.skills.find` for tenant isolation

SkillsHelper provides `SKILL_CATEGORIES` constant (5 categories), `skill_category_options` for form selects, and `skill_category_badge` for colored category spans.

### Task 2: All skill view templates (commit 9c5e148)

**Files:** 6 ERB templates in `app/views/skills/`

- `index.html.erb`: category filter nav (All + per-category links with active state), skills grid using `_skill` partial, empty state with contextual CTAs
- `show.html.erb`: skill detail with key/category/builtin badges, Edit button always shown, Delete button only for custom skills (with `turbo_confirm`), `simple_format` for markdown content, assigned agents list with status dots
- `_form.html.erb`: shared form partial; key field disabled for persisted builtin skills (disabled fields not submitted, preserving key); category select from `skill_category_options`; builtin not in form at all (server-side only)
- `_skill.html.erb`: card partial with category badge, builtin/custom indicator, agent count via `pluralize`
- `new.html.erb` / `edit.html.erb`: thin wrapper templates delegating to shared `_form` partial

### Task 3: CSS for skills pages (commit c3abe37)

**File:** `app/assets/stylesheets/application.css` (appended within `@layer components`)

Added 268 lines of CSS following project conventions (BEM, OKLCH, logical properties):

- `.skills-page` layout with `.skills-page__filters` category nav
- `.filter-link` / `.filter-link--active` reusable filter nav component
- `.skill-card` component with hover effect and BEM sub-elements
- `.skill-detail` detail page layout with `.skill-detail__markdown` container
- `.skill-category-badge--{category}` — 5 variants with distinct OKLCH hues:
  - leadership: oklch hue 300 (purple)
  - technical: oklch hue 265 (blue)
  - creative: oklch hue 75 (amber)
  - operations: oklch hue 150 (green)
  - research: oklch hue 210 (cyan)
- `.form__hint` utility following existing `.form__*` BEM pattern

## Must-Haves Verified

- [x] User can browse all skills in the company library at /skills, with the list filterable by category
- [x] User can view a skill's full markdown content at /skills/:id and see which agents have that skill assigned
- [x] User can edit any skill (including builtin skills) to customize the instruction content
- [x] User can create new custom skills (builtin: false) and destroy custom skills, but cannot destroy builtin skills
- [x] Skill routes are active under resources :skills (7 RESTful routes)

## Deviations

None. Plan executed as specified.

## Verification Results

- `bin/rails routes | grep skill`: 7 RESTful routes confirmed
- `ruby -c` syntax checks: all Ruby files pass
- ERB syntax checks: all 6 templates pass
- `bin/rubocop`: 180 files inspected, 0 offenses
- `bin/rails test`: 691 runs, 1691 assertions, 0 failures, 0 errors, 0 skips

## Self-Check: PASSED

Files confirmed present:
- /Users/jorge/Sites/rails/director/config/routes.rb (modified)
- /Users/jorge/Sites/rails/director/app/controllers/skills_controller.rb (created)
- /Users/jorge/Sites/rails/director/app/helpers/skills_helper.rb (created)
- /Users/jorge/Sites/rails/director/app/views/skills/index.html.erb (created)
- /Users/jorge/Sites/rails/director/app/views/skills/show.html.erb (created)
- /Users/jorge/Sites/rails/director/app/views/skills/new.html.erb (created)
- /Users/jorge/Sites/rails/director/app/views/skills/edit.html.erb (created)
- /Users/jorge/Sites/rails/director/app/views/skills/_form.html.erb (created)
- /Users/jorge/Sites/rails/director/app/views/skills/_skill.html.erb (created)
- /Users/jorge/Sites/rails/director/app/assets/stylesheets/application.css (modified)

Commits confirmed: 211c918, 9c5e148, c3abe37
