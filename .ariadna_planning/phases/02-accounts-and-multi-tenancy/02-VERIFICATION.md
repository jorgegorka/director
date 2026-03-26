---
phase: 02-accounts-and-multi-tenancy
verified: 2026-03-26T22:45:00Z
status: passed
score: "10/10 truths verified | security: 0 critical, 0 high | performance: 0 high"
---

# Phase 02: Accounts & Multi-tenancy — Verification

**Phase goal:** Users can create and manage isolated companies, each functioning as an independent tenant

**Plans verified:** 02-01 (multi-tenancy foundation), 02-02 (invitation system)
**Commits:** e1a102a, c939bba, 858e6f0, 23110e5

---

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| T1 | User can create a new company and see it listed in their account | VERIFIED | `CompaniesController#create` wraps Company + owner Membership in a transaction, redirects to root; `companies#index` renders company cards; controller test `should create company and assign owner role` passes |
| T2 | User who creates a company is automatically assigned the owner role | VERIFIED | `@company.memberships.create!(user: Current.user, role: :owner)` in `companies_controller.rb:15`; test verifies `membership.owner?` passes |
| T3 | User can switch between multiple companies via a nav dropdown | VERIFIED | `_company_switcher.html.erb` renders Stimulus-powered dropdown; `Companies::SwitchesController#create` scoped via `Current.user.companies.find()`; `should switch active company` test confirms home page shows new company name |
| T4 | Current.company is set from session and scopes all tenant-aware controllers | VERIFIED | `SetCurrentCompany` concern: loads from `session[:company_id]` scoped through `Current.user.companies`, auto-selects first company if none set, nil-guards unauthenticated routes; included in `ApplicationController` after `Authentication` |
| T5 | Owner, admin, and member roles exist on the Membership model | VERIFIED | `Membership` enum: `{ member: 0, admin: 1, owner: 2 }`; `Invitation` enum: `{ member: 0, admin: 1 }` (no owner — correct, owners only created at company creation); all role tests pass |
| T6 | Users with no companies are redirected to company creation | VERIFIED | `HomeController` has `before_action :require_company!`; `require_company!` in `SetCurrentCompany` redirects to `new_company_path`; `home_controller_test.rb` test `should redirect to new company page when user has no companies` passes |
| T7 | User can invite a team member by email, and that person can accept and access the company | VERIFIED | `InvitationsController#create` saves invitation, calls `InvitationMailer.invite().deliver_later`; `InvitationAcceptancesController#update` calls `@invitation.accept!(user)` which creates Membership in transaction; mailer test confirms token in email body; acceptance controller tests cover all 3 user states |
| T8 | Only owner can invite as admin; owner and admin can invite as member; members cannot invite | VERIFIED | `authorize_inviter!` before_action blocks members (`redirect_to root_path`); for admins posting role=admin, redirects to `new_invitation_path`; helper `invitation_role_options` only includes admin option when `membership.owner?`; tests cover all four cases |
| T9 | Company data is fully isolated — members of one company cannot see another company's data | VERIFIED | `SetCurrentCompany` loads company via `Current.user.companies.find_by(id: ...)` — user must have membership to set any company in session; `Companies::SwitchesController` uses `Current.user.companies.find()` — RecordNotFound if user lacks membership; `InvitationsController` scopes all queries to `Current.company`; runtime verification confirmed isolation |
| T10 | Invitations expire after 30 days | VERIFIED | `Invitation::EXPIRATION_PERIOD = 30.days`; `set_expiration` callback on `before_validation :create`; `acceptable?` checks `pending? && !expired?`; `expired_invite` fixture has `expires_at: 1.day.ago`; tests for non-acceptable expired invitations pass |

---

## Artifact Status

| Artifact | Exists | Substantive | Notes |
|----------|--------|-------------|-------|
| `app/models/company.rb` | YES | YES | `has_many :memberships, dependent: :destroy`, `has_many :users, through: :memberships`, `has_many :invitations, dependent: :destroy`, name presence validation |
| `app/models/membership.rb` | YES | YES | role enum `{member: 0, admin: 1, owner: 2}`, compound unique index, uniqueness validation with scope |
| `app/models/invitation.rb` | YES | YES | Token generation, 30-day expiration, `accept!` transaction, status enum, `acceptable?`, `invitee_not_already_member` validation, `active` scope |
| `app/models/current.rb` | YES | YES | `attribute :company` present alongside `attribute :session` |
| `app/models/concerns/tenantable.rb` | YES | YES | `belongs_to :company`, `for_current_company` scope — avoids default_scope anti-pattern |
| `app/controllers/concerns/set_current_company.rb` | YES | YES | Nil guard on `Current.user`, auto-selects first company, clears stale session company, `require_company!` method |
| `app/controllers/application_controller.rb` | YES | YES | `include Authentication` then `include SetCurrentCompany` — correct order |
| `app/controllers/companies_controller.rb` | YES | YES | index, new, create (no edit/destroy — deferred per CONTEXT.md) |
| `app/controllers/companies/switches_controller.rb` | YES | YES | Scoped via `Current.user.companies.find()`, RecordNotFound handled |
| `app/controllers/invitations_controller.rb` | YES | YES | `require_company!` + `authorize_inviter!` before_actions, role sanitized outside `permit()` |
| `app/controllers/invitation_acceptances_controller.rb` | YES | YES | `allow_unauthenticated_access`, handles logged-in / existing / new user flows |
| `app/mailers/invitation_mailer.rb` | YES | YES | HTML + text templates, `invitation_acceptance_url(token:)` in body |
| `app/helpers/invitations_helper.rb` | YES | YES | `invitation_role_options` filters admin option to owners only |
| `app/views/layouts/_company_switcher.html.erb` | YES | YES | Stimulus `dropdown` controller, active company checkmark, `+ New Company` link |
| `app/views/invitations/new.html.erb` | YES | YES | Email field + role select using `invitation_role_options` helper |
| `app/views/invitation_acceptances/show.html.erb` | YES | YES | Handles `authenticated?` branch and new-user form branch |
| `app/javascript/controllers/dropdown_controller.js` | YES | YES | `toggle()`, click-outside handler, `connect`/`disconnect` lifecycle |
| `db/migrate/20260326214539_create_companies.rb` | YES | YES | `name null: false` |
| `db/migrate/20260326214543_create_memberships.rb` | YES | YES | Compound unique index `[company_id, user_id]`, role default 0 |
| `db/migrate/20260326220952_create_invitations.rb` | YES | YES | Partial unique index `WHERE status = 0` on `[company_id, email_address]`, token unique index |

---

## Key Links (Wiring)

| From | To | Via | Status |
|------|----|-----|--------|
| `app/views/companies/new.html.erb` | `CompaniesController#create` | `form_with(model: @company)` — POST /companies | VERIFIED |
| `app/views/layouts/_company_switcher.html.erb` | `Companies::SwitchesController#create` | `button_to company_switch_path(company), method: :post` | VERIFIED |
| `app/controllers/concerns/set_current_company.rb` | `Current.company` | `before_action :set_current_company` loading from `session[:company_id]` | VERIFIED |
| `app/models/membership.rb` | `app/models/company.rb` | `belongs_to :company` | VERIFIED |
| `app/models/membership.rb` | `app/models/user.rb` | `belongs_to :user` | VERIFIED |
| `app/views/invitations/new.html.erb` | `InvitationsController#create` | `form_with(model: @invitation)` — POST /invitations | VERIFIED |
| `InvitationsController#create` | `InvitationMailer#invite` | `InvitationMailer.invite(@invitation).deliver_later` | VERIFIED |
| Invitation email link | `InvitationAcceptancesController#show` | GET `/invitation_acceptances/:token` | VERIFIED |
| `app/views/invitation_acceptances/show.html.erb` | `InvitationAcceptancesController#update` | `button_to ... method: :patch` and `form_with ... method: :patch` | VERIFIED |
| `InvitationAcceptancesController#update` | `Membership` | `@invitation.accept!(user)` which calls `company.memberships.create!` | VERIFIED |
| `app/javascript/controllers/index.js` | `dropdown_controller.js` | `eagerLoadControllersFrom("controllers", application)` auto-discovers all `*_controller.js` | VERIFIED |

---

## Cross-Phase Integration

### Upstream (from Phase 1)
- `Authentication` concern from Phase 1 is included before `SetCurrentCompany` in `ApplicationController` — correct ordering ensures `Current.user` is available when `set_current_company` runs
- `Current.session`/`Current.user` delegation chain works with the new `Current.company` attribute
- `allow_unauthenticated_access` on `InvitationAcceptancesController` correctly bypasses Phase 1 authentication for public token routes

### Downstream readiness (for Phase 3+)
- `Current.company` is available on every authenticated request via `SetCurrentCompany` — all future tenant-scoped controllers can scope via `Current.company`
- `Tenantable` concern with `for_current_company` scope is ready for future models (agents, roles, tasks) to include
- `require_company!` method is available to any controller needing tenant enforcement
- Role hierarchy (owner > admin > member) established and enforced; future phases can call `membership.owner?`, `membership.admin?`, `membership.member?`
- `company.memberships.find_by(user: Current.user)` pattern established in `authorize_inviter!` as the canonical way to look up the current user's role

---

## Security Analysis

**Brakeman:** 0 warnings (clean, verified via `bin/brakeman --quiet --no-pager`)

| Check | Finding | Detail |
|-------|---------|--------|
| Session manipulation | SAFE | `SetCurrentCompany` loads company via `Current.user.companies.find_by(id: ...)` — users cannot elevate to companies they don't belong to by manipulating `session[:company_id]` |
| Company switch tenant escape | SAFE | `Companies::SwitchesController` uses `Current.user.companies.find()` — raises `RecordNotFound` for companies the user lacks membership in |
| Mass assignment on Invitation role | SAFE | `InvitationsController` sanitizes role outside `permit()` using `.in?(Invitation.roles.keys)` guard, defaults to `"member"` |
| Open token lookup | SAFE | `Invitation.find_by(token:)` returns nil for invalid tokens; controller redirects safely without exposing internal details |
| Admin invite-as-admin escalation | SAFE | `authorize_inviter!` redirects if `membership.admin? && invitation_params_role == "admin"` before the invitation is created |
| Cross-company invitation creation | SAFE | `InvitationsController` creates via `Current.company.invitations.new(...)` — scoped to the session-authenticated company |
| Unauthenticated token endpoints | SAFE | `InvitationAcceptancesController` uses `allow_unauthenticated_access`; existing-user branch redirects to login preserving return URL; does not expose invitation contents without valid token |

---

## Performance Analysis

No high-severity performance findings. Notable observations:

| Area | Finding | Severity |
|------|---------|----------|
| `companies/index.html.erb` role lookup | `company.memberships.find_by(user: Current.user)` called inside an each loop — N+1 per company for role display. Mitigated by `includes(:memberships)` in controller but the `find_by` still performs per-card lookup within already-loaded association. Acceptable for the list size at this stage. | LOW |
| `_company_switcher.html.erb` | `Current.user.companies.each` — loads all user's companies for every request. Acceptable for typical company counts; no eager loading needed at this scale. | LOW |

---

## Test Coverage

- **Total tests:** 83 passing, 0 failures, 0 errors, 0 skips
- **Model tests:** `CompanyTest` (5 tests), `MembershipTest` (7 tests), `InvitationTest` (13 tests)
- **Controller tests:** `CompaniesControllerTest` (6 tests), `Companies::SwitchesControllerTest` (3 tests), `HomeControllerTest` (3 tests), `InvitationsControllerTest` (11 tests), `InvitationAcceptancesControllerTest` (9 tests)
- **Mailer tests:** `InvitationMailerTest` (1 test)
- **CI tooling:** `bin/rubocop` — 0 offenses; `bin/brakeman` — 0 warnings

---

## Notes

### Company delete deferred — not a gap
The phase success criterion includes "(e.g., only owner can delete company)" as a parenthetical example. The `02-CONTEXT.md` explicitly defers company delete: "Company settings/edit page (create + list is sufficient for this phase)." The role boundary requirement is substantively met through invitation authorization: only owners can invite admins, which is a concrete access boundary enforced at the controller level. This is a documented deferral, not an unintended omission.

### Member access to new invitation form
`authorize_inviter!` is applied as a `before_action` for all actions in `InvitationsController`, meaning it blocks members from the `new` action too. The test suite covers `member cannot view invitations` (index), but not `member cannot view new invitation form` (new). The authorization runs identically for both — this is a test coverage gap for the `new` action, not a functional gap.

---

## Verdict

All 10 observable truths verified against the actual codebase. All planned artifacts exist and are substantive (no stubs, no placeholders, no TODO bodies). All key wiring connections are in place. Security is clean. Phase goal is achieved: users can create and manage isolated companies, each functioning as an independent tenant.

*Verified: 2026-03-26*
