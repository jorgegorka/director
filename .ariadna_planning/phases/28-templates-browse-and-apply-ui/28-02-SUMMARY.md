---
phase: 28-templates-browse-and-apply-ui
plan: "02"
subsystem: testing + ui
tags: [rails, minitest, controller-tests, role-templates, hotwire]

# Dependency graph
requires:
  - phase: 28-01
    provides: RoleTemplatesController with index/show/apply, all view templates, CSS components

provides:
  - test/controllers/role_templates_controller_test.rb with 17 comprehensive tests
  - app/views/roles/index.html.erb updated with Browse Templates link (UI-04)

affects: [phase-28, testing, roles-ui]

# Tech tracking
tech-stack:
  added: []
  patterns: [ActionDispatch::IntegrationTest, assert_select, assert_difference, assert_no_difference]

key-files:
  created:
    - test/controllers/role_templates_controller_test.rb
  modified:
    - app/views/roles/index.html.erb
    - app/assets/stylesheets/application.css

key-decisions:
  - "button_to renders <button type=submit>, not <input type=submit> — use button[type=submit] CSS selector"
  - "Rails handles RecordNotFound as 404 response — use assert_response :not_found, not assert_raises"
  - "Engineering template has 5 roles; acme fixture already has CTO — first apply creates 4 (not 5)"
  - "users(:two) is a member of acme — auth guard test creates a fresh user with no memberships"

requirements_covered:
  - id: "UI-04"
    description: "Link from roles index page to templates browse page"
    evidence: "app/views/roles/index.html.erb — Browse Templates button in header and empty state"

# Metrics
duration: 10min
completed: 2026-03-29
---

# Plan 28-02: Controller Tests and Roles Index Link Summary

**17 controller tests for RoleTemplatesController and roles index page updated with Browse Templates discovery link**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-03-29
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Comprehensive controller tests covering all 3 actions with happy and error paths
- Discovered and corrected 3 test assertions during green-pass verification (button_to selector, 404 handling)
- Roles index header now has "Browse Templates" ghost button alongside "New Role" primary button
- Empty state updated to offer templates as primary CTA with "Create a role" as secondary
- `.roles-page__actions` CSS added to keep header buttons grouped in a flex row

## Task Commits

1. **Task 1: Write RoleTemplatesController tests** - `25bdb17` (test)
2. **Task 2: Add templates link to roles index page** - `b98bcd0` (feat)

## Tests Written

- **Total:** 17 tests, 43 assertions
- **Index coverage:** response success, 5 template cards, template names, role count badge
- **Show coverage:** response success, h1 heading, hierarchy tree nodes, role titles (CTO/Engineer), skill badges, apply button, 404 for unknown key
- **Apply coverage:** redirect with flash notice, creates 4 roles (CTO skipped), summary flash text, idempotent second apply skips all, 404 for unknown key
- **Auth guard:** fresh user with no company membership redirects to new_company_path

## Key Technical Findings

- `button_to` helper renders `<button type="submit">`, not `<input type="submit">` — selector must be `button[type=submit]`
- Rails rescues `ActiveRecord::RecordNotFound` and renders a 404 response in tests — `assert_response :not_found` is correct; `assert_raises` is not
- Acme fixture has a "CTO" role that matches engineering template — first apply creates 4 roles (VP Engineering, Tech Lead, Engineer, QA), not 5

## Files Created/Modified

- `test/controllers/role_templates_controller_test.rb` — 17 tests (new file)
- `app/views/roles/index.html.erb` — header and empty state updated with Browse Templates links
- `app/assets/stylesheets/application.css` — `.roles-page__actions` flex container styles added

## Deviations from Plan

- **Rule 1 (auto-fix):** Corrected `input[type=submit]` selector to `button[type=submit]` — button_to renders a button element
- **Rule 1 (auto-fix):** Changed 404 tests from `assert_raises` to `assert_response :not_found` — Rails handles RecordNotFound at the framework level
- **Rule 1 (auto-fix):** Changed `assert_difference(..., 5)` to `assert_difference(..., 4)` — plan noted this check was required; acme fixture has CTO already

## Issues Encountered

None after deviation corrections.

## User Setup Required

None.

---
*Phase: 28-templates-browse-and-apply-ui*
*Completed: 2026-03-29*

## Self-Check: PASSED

- test/controllers/role_templates_controller_test.rb — FOUND
- app/views/roles/index.html.erb — FOUND (Browse Templates link present)
- Commit 25bdb17 (Task 1) — FOUND
- Commit b98bcd0 (Task 2) — FOUND
- Full test suite: 1184 runs, 0 failures, 0 errors — PASSED
