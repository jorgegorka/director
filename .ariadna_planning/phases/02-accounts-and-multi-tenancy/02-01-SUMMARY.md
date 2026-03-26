---
phase: 02-accounts-and-multi-tenancy
plan: "01"
subsystem: database
tags: [rails, activerecord, multi-tenancy, postgresql, stimulus, hotwire, concerns]

# Dependency graph
requires:
  - phase: 01-authentication
    provides: User model, Session model, Authentication concern, Current.session/user
provides:
  - Company model with name validation, has_many memberships and users through memberships
  - Membership model with role enum (member/admin/owner), compound unique index
  - Current.company attribute for tenant scoping throughout the app
  - SetCurrentCompany concern that loads Current.company from session for all authenticated requests
  - CompaniesController with index/new/create; auto-assigns owner membership on creation
  - Companies::SwitchesController to switch active company in session
  - Company switcher dropdown in nav (Stimulus dropdown controller)
  - Tenantable concern with for_current_company scope for future tenant-scoped models
affects:
  - 02-02 (invitations/memberships)
  - all future phases (Current.company used everywhere for tenant scoping)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - concern-driven tenant scoping (SetCurrentCompany)
    - transaction wrapping company + membership creation
    - session-based active company with auto-select
    - Tenantable concern with for_current_company scope

key-files:
  created:
    - app/models/company.rb
    - app/models/membership.rb
    - app/models/concerns/tenantable.rb
    - app/controllers/concerns/set_current_company.rb
    - app/controllers/companies_controller.rb
    - app/controllers/companies/switches_controller.rb
    - app/views/layouts/_company_switcher.html.erb
    - app/javascript/controllers/dropdown_controller.js
  modified:
    - app/models/current.rb
    - app/models/user.rb
    - app/controllers/application_controller.rb
    - app/controllers/home_controller.rb
    - config/routes.rb
    - app/assets/stylesheets/application.css

key-decisions:
  - "Role enum: member(0)/admin(1)/owner(2) -- integer-backed for DB efficiency"
  - "No default_scope on Tenantable -- uses explicit for_current_company scope to avoid anti-pattern"
  - "SetCurrentCompany guards on Current.user nil -- prevents errors on unauthenticated routes (login, registration, password reset)"
  - "Auto-select first company if session has none -- reduces friction for returning users"
  - "Company creation scoped through Current.user.companies.find_by -- prevents session hijacking to access other tenants"
  - "No company edit/delete in this phase -- deferred per CONTEXT.md"

patterns-established:
  - "Tenant scoping: Current.company set by SetCurrentCompany before_action; query with .for_current_company scope"
  - "require_company! pattern: separate method controllers call when they need a company to be present"
  - "Nested controller namespace: Companies::SwitchesController under app/controllers/companies/"
  - "Stimulus dropdown controller: generic open/close with click-outside handler for all future dropdowns"

requirements_covered:
  - id: "ACCT-01"
    description: "Create companies as isolated tenants"
    evidence: "app/models/company.rb, app/controllers/companies_controller.rb"
  - id: "ACCT-03"
    description: "Owner/admin/member roles on Membership"
    evidence: "app/models/membership.rb (role enum: member/admin/owner)"

# Metrics
duration: 7min
completed: 2026-03-26
---

# Phase 02-01: Multi-Tenancy Foundation Summary

**Company and Membership models with session-based Current.company scoping, owner auto-assignment, nav dropdown switcher via Stimulus, and redirect flow for users without a company**

## Performance

- **Duration:** 7 min
- **Started:** 2026-03-26T21:45:35Z
- **Completed:** 2026-03-26T21:52:18Z
- **Tasks:** 2
- **Files modified:** 20

## Accomplishments
- Company and Membership models with correct schema, role enum, uniqueness constraints, and cascading deletes
- SetCurrentCompany concern loads tenant from session for all authenticated requests, auto-selects first company, and guards unauthenticated routes
- CompaniesController creates company + owner membership in a transaction, sets session, redirects to root
- Company switcher dropdown in nav using a generic Stimulus dropdown controller with click-outside behavior
- All 49 tests pass; rubocop clean; brakeman 0 warnings

## Requirements Covered
| REQ-ID | Requirement | Evidence |
|--------|-------------|----------|
| ACCT-01 | Create companies as isolated tenants | `app/models/company.rb`, `app/controllers/companies_controller.rb` |
| ACCT-03 | Owner/admin/member roles on Membership | `app/models/membership.rb` role enum |

## Task Commits

Each task was committed atomically:

1. **Task 1: Company and Membership models with migrations and tests** - `e1a102a` (feat)
2. **Task 2: CompaniesController, tenant switching concern, and company switcher UI** - `c939bba` (feat)

**Plan metadata:** (committed with STATE.md update)

## Files Created/Modified
- `app/models/company.rb` - Company with name validation, has_many :memberships and :users
- `app/models/membership.rb` - Membership with role enum (member/admin/owner), uniqueness constraint
- `app/models/concerns/tenantable.rb` - Tenantable concern with for_current_company scope
- `app/models/current.rb` - Added `attribute :company` for tenant scoping
- `app/models/user.rb` - Added has_many :memberships and :companies through memberships
- `app/controllers/concerns/set_current_company.rb` - Loads Current.company from session, auto-selects, guards nil user
- `app/controllers/application_controller.rb` - Include SetCurrentCompany after Authentication
- `app/controllers/companies_controller.rb` - index/new/create with owner membership transaction
- `app/controllers/companies/switches_controller.rb` - POST switch scoped through user memberships
- `app/controllers/home_controller.rb` - require_company! before_action
- `app/views/companies/new.html.erb` - Company creation form with form-card layout
- `app/views/companies/index.html.erb` - Company cards with active indicator and switch buttons
- `app/views/layouts/_company_switcher.html.erb` - Nav dropdown with checkmark on active company
- `app/javascript/controllers/dropdown_controller.js` - Stimulus controller for open/close with click-outside
- `app/assets/stylesheets/application.css` - form-card, company-switcher, company-card, companies-list components
- `config/routes.rb` - companies resources with nested switch resource
- `db/migrate/20260326214539_create_companies.rb` - companies table with null: false name
- `db/migrate/20260326214543_create_memberships.rb` - memberships table with role default, compound unique index
- `test/fixtures/companies.yml` - acme and widgets companies
- `test/fixtures/memberships.yml` - one=owner/acme, two=member/acme, one=admin/widgets

## Decisions Made
- No `default_scope` on Tenantable — use explicit `.for_current_company` scope to avoid the default_scope anti-pattern (test isolation issues)
- `SetCurrentCompany` guards on `Current.user` being nil so unauthenticated routes (login, registration, password reset) don't error
- Company switcher uses generic Stimulus `dropdown` controller that can be reused for any dropdown in the future
- No company edit/delete in this phase — deferred per CONTEXT.md

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Nil guard on Current.user in set_current_company**
- **Found during:** Task 2 (running full test suite after implementation)
- **Issue:** `set_current_company` called `Current.user.companies` without checking if `Current.user` was nil, causing `NoMethodError` on unauthenticated routes (PasswordsController, RegistrationsController, SessionsController)
- **Fix:** Added `return unless Current.user` at top of `set_current_company` method
- **Files modified:** `app/controllers/concerns/set_current_company.rb`
- **Verification:** All 16 previously-failing tests now pass
- **Committed in:** `c939bba` (Task 2 commit)

**2. [Rule 1 - Bug] Registration tests updated for new post-signup redirect flow**
- **Found during:** Task 2 (running full test suite)
- **Issue:** Existing registration tests asserted `follow_redirect!; assert_response :success` after registration, but new users now get redirected from root to `/companies/new` (no company yet)
- **Fix:** Updated 2 registration tests to assert the correct redirect chain (`root_url` -> `new_company_url`)
- **Files modified:** `test/controllers/registrations_controller_test.rb`
- **Verification:** All 49 tests pass
- **Committed in:** `c939bba` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (2x Rule 1 - Bug)
**Impact on plan:** Both auto-fixes necessary for correctness. The nil guard is a required defensive check; the test updates reflect intended new behavior. No scope creep.

## Issues Encountered
None beyond the auto-fixed deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Current.company is available via `SetCurrentCompany` for all authenticated requests
- `require_company!` method ready for any controller that needs tenant enforcement
- `Tenantable` concern ready to be included by future models (agents, tasks, roles, etc.)
- Membership roles (owner/admin/member) ready for authorization logic in phase 02-02+
- Company switcher dropdown in nav fully functional

---
*Phase: 02-accounts-and-multi-tenancy*
*Completed: 2026-03-26*

## Self-Check: PASSED

All 13 files verified present. Commits e1a102a and c939bba confirmed. 49 tests pass, 0 failures, 0 errors.
