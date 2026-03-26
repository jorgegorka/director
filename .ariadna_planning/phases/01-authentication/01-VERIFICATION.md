---
phase: 01-authentication
verified: 2026-03-26T23:00:00Z
status: gaps_found
score: "4/5 truths verified | security: 0 critical, 1 high | performance: 0 high"
gaps:
  - truth: "User can request a password reset email and use the link to set a new password"
    status: partial
    reason: "Flow is implemented and wired correctly. PasswordsController, PasswordsMailer, and token-based reset views exist and are functional. However, the password reset edit form uses method: :put while PasswordsController#update is routed via PATCH (resources :passwords, param: :token). Rails treats PUT and PATCH as equivalent in routing, so the route works, but it is a minor semantic inconsistency."
    artifacts:
      - path: "app/views/passwords/edit.html.erb"
        issue: "Uses method: :put but resources routing defaults PATCH to #update. Functionally equivalent; semantically imprecise."
    missing: []
  - truth: "System tests covering complete auth lifecycle exist and are committed"
    status: failed
    reason: "Commit 0febfe4 added test/system/authentication_test.rb (11 tests: sign-up, login, logout, session persistence, password reset, email update, password update, wrong-password rejection, unauthenticated redirect, nav state). However, the file is currently DELETED from the working tree (unstaged deletion — not committed). The file exists in git history but not on disk. Plan 01-02 required this artifact."
    artifacts:
      - path: "test/system/authentication_test.rb"
        issue: "Deleted from working tree (git status shows 'deleted: test/system/authentication_test.rb'). Committed in 0febfe4 but not present on disk."
    missing:
      - "Restore test/system/authentication_test.rb from git history and commit the restoration, OR commit the deletion intentionally if system tests are excluded by policy."
security_findings:
  - check: "session-cookie-no-secure-flag"
    severity: high
    file: "app/controllers/concerns/authentication.rb"
    line: 44
    detail: "cookies.signed.permanent[:session_id] is set with httponly: true and same_site: :lax but no secure: Rails.env.production? flag. In production this cookie will be transmitted over HTTP if SSL is not enforced. Production config has config.force_ssl commented out, so the cookie is not guaranteed to be secure-only. Rails default does not add Secure automatically unless config.force_ssl is true."
performance_findings: []
---

# Phase 01 — Authentication: Verification Report

**Phase goal:** Users can securely create and manage their accounts
**Plans verified:** 01-01 (Authentication Foundation), 01-02 (Account Settings)
**Commits in scope:** 644db3b, 6d3d67c, a948f92, b1b0208, 0febfe4

---

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can sign up with email and password and land on a logged-in page | PASS | `RegistrationsController#create` calls `start_new_session_for(@user)` then `redirect_to root_path`. `HomeController#show` requires auth. Auto-login after registration is confirmed by test "should automatically log in after registration". |
| 2 | User can log out and log back in, with session persisting across browser refresh | PASS | `SessionsController#destroy` calls `terminate_session` (destroys Session record, deletes cookie). `SessionsController#create` calls `start_new_session_for`. Session cookie is permanent/signed; `resume_session` finds session by cookie on each request. Tests confirm login redirects to root and logout redirects to new_session. |
| 3 | User can request a password reset email and use the link to set a new password | PARTIAL | Full flow is implemented: `PasswordsController#create` calls `PasswordsMailer.reset(user).deliver_later`; mailer generates `edit_password_url(@user.password_reset_token)`; `PasswordsController#update` calls `@user.update` then destroys all sessions. One minor issue: `passwords/edit.html.erb` uses `method: :put` while routes map PATCH to `#update`. Rails treats them equivalently; flow works. |
| 4 | User can change their email and password from an account settings page | PASS | `SettingsController` at `/settings` (GET/PATCH) requires `current_password` verification via `@user.authenticate`. Email and password updates work independently. Blank password fields are filtered before `update` to preserve existing password_digest. All 7 settings controller tests pass. |
| 5 | Logged-in users see a landing page with nav; logged-out users are redirected to login | PASS | `HomeController` inherits `require_authentication` from ApplicationController. Root route points to `home#show`. Layout header conditionally renders user email + Settings + Log out (authenticated) or Log in + Sign up (unauthenticated). Test "should redirect unauthenticated user to login" confirms redirect to `new_session_url`. |

---

## Artifact Status

| Artifact | Exists | Substantive | Notes |
|----------|--------|-------------|-------|
| `app/models/user.rb` | YES | YES | `has_secure_password`, `normalizes :email_address`, `validates :email_address` (presence, uniqueness, format) |
| `app/models/session.rb` | YES | YES | `belongs_to :user` |
| `app/models/current.rb` | YES | YES | `attribute :session`, delegates `user` |
| `app/controllers/concerns/authentication.rb` | YES | YES | Full authentication concern: `require_authentication`, `resume_session`, `start_new_session_for`, `terminate_session`, `after_authentication_url` |
| `app/controllers/registrations_controller.rb` | YES | YES | `allow_unauthenticated_access`, new/create with `start_new_session_for` |
| `app/controllers/home_controller.rb` | YES | YES | Protected by inherited `require_authentication` |
| `app/controllers/sessions_controller.rb` | YES | YES | Login/logout with rate limiting |
| `app/controllers/passwords_controller.rb` | YES | YES | Full reset flow with rate limiting and token validation |
| `app/controllers/settings_controller.rb` | YES | YES | Email/password update with `authenticate` verification, blank-password guard |
| `app/mailers/passwords_mailer.rb` | YES | YES | `reset(user)` method with subject and `mail to:` |
| `app/views/passwords_mailer/reset.html.erb` | YES | YES | `edit_password_url(@user.password_reset_token)` with expiry text |
| `app/views/passwords_mailer/reset.text.erb` | YES | YES | Plain text version |
| `app/views/settings/show.html.erb` | YES | YES | Three fieldsets: Email, Change Password, Verify Identity |
| `app/assets/stylesheets/application.css` | YES | YES | CSS layers, OKLCH tokens, dark mode, no Tailwind |
| `db/migrate/20260326201846_create_users.rb` | YES | YES | `email_address NOT NULL`, `password_digest NOT NULL`, unique index |
| `db/migrate/20260326201847_create_sessions.rb` | YES | YES | `user_id` FK, `ip_address`, `user_agent` |
| `test/system/authentication_test.rb` | NO (on disk) | N/A | Committed in 0febfe4 (146 lines, 11 tests) but DELETED from working tree. Unstaged deletion. |

**Minor CSS gap:** `app/views/settings/show.html.erb` uses `class="field-group"` on `<fieldset>` elements, but `.field-group` is not defined in `application.css`. This does not break functionality (fieldsets render without special styling) but the CSS component referenced in the view has no definition. `.auth-card` wraps the page correctly regardless.

---

## Key Links (Wiring)

| Link | Status | Evidence |
|------|--------|----------|
| `registrations/new.html.erb` → `RegistrationsController#create` via `form_with(url: registration_path)` | PASS | Form uses `registration_path` (POST /registration). Controller creates user and starts session. |
| `sessions/new.html.erb` → `SessionsController#create` via `form_with(url: session_path)` | PASS | Form posts to `session_path`. Controller calls `User.authenticate_by`. |
| `passwords/new.html.erb` → `PasswordsController#create` via `form_with(url: passwords_path)` | PASS | Form posts to `passwords_path`. Controller queues `PasswordsMailer`. |
| `passwords/edit.html.erb` → `PasswordsController#update` via form | PASS | Form uses `password_path(params[:token])` with `method: :put`. Routed to `#update`. Functional. |
| `Authentication concern` → `HomeController#show` via `after_authentication_url` | PASS | `after_authentication_url` returns `session.delete(:return_to_after_authenticating) \|\| root_url`. Root route → `home#show`. |
| `PasswordsController#create` → `PasswordsMailer#reset` via `deliver_later` | PASS | `PasswordsMailer.reset(user).deliver_later` at line 11. |
| `SettingsController` → `User` via `Current.user.authenticate` + `update` | PASS | `@user = Current.user`, `@user.authenticate(params[:current_password])`, `@user.update(settings_params)`. |
| Layout nav → `settings_path` link | PASS | `link_to "Settings", settings_path` present in `layouts/application.html.erb` for `Current.user` branch. |
| `sessions/new.html.erb` → `new_registration_path` | PASS | "Sign up" link present. |
| `registrations/new.html.erb` → `new_session_path` | PASS | "Log in" link present. |

---

## Cross-Phase Integration

Phase 01 is the foundation phase. Downstream phases (companies, agents, etc.) will depend on:

- `Current.user` — correctly set via `Authentication` concern; will be available to all future controllers.
- `require_authentication` as a default before_action — all future controllers inherit protection unless they explicitly call `allow_unauthenticated_access`.
- `root_url` pointing to `home#show` — future phases may change the root route or add navigation links; foundation is wired correctly.

No orphaned modules. No broken downstream consumers at this stage (Phase 01 is the first phase).

---

## Security Findings

| Severity | Finding | File | Detail |
|----------|---------|------|--------|
| HIGH | Session cookie missing `secure:` flag | `app/controllers/concerns/authentication.rb:44` | `cookies.signed.permanent[:session_id]` sets `httponly: true, same_site: :lax` but omits `secure: Rails.env.production?`. Production `config.force_ssl` is commented out. Without either the `secure:` cookie attribute or `config.force_ssl`, the session cookie can be transmitted over HTTP in production, enabling session hijacking. Fix: add `secure: Rails.env.production?` to the cookie options, and/or uncomment `config.force_ssl = true` in `config/environments/production.rb`. |

**No critical findings.** Additional positive observations:
- CSRF protection is active (default `ActionController::Base` behavior; `csrf_meta_tags` in layout).
- Rate limiting on `SessionsController#create` and `PasswordsController#create` (10 requests / 3 minutes).
- Password reset uses signed token (`password_reset_token`) with expiry; invalid/expired tokens redirect safely.
- `PasswordsController#create` does not reveal whether an email exists (same response regardless).
- `email_address` is normalized (strip + downcase) before persistence.
- Strong parameters enforced in all controllers.
- No SQL injection vectors found; no `html_safe`/`raw` usage in views.

---

## Performance Findings

No high-severity performance concerns. Phase 01 operates on single-record lookups (User by email, Session by id) — both are indexed. No N+1 query vectors exist in the current codebase.

---

## Anti-Pattern Scan

- No TODO/FIXME/HACK/STUB comments in `app/`.
- No debug statements (`byebug`, `binding.pry`, `debugger`).
- No Tailwind CSS classes in any view.
- No `permit!` or unsafe mass assignment.
- CSS uses OKLCH colors, CSS layers, logical properties as required by `docs/style-guide.md`.

---

## Gaps Narrative

**Gap 1 — System test file deleted from working tree (CRITICAL for plan completeness)**

Commit `0febfe4` added `test/system/authentication_test.rb` (146 lines, 11 browser-level tests covering the full auth lifecycle). This file is tracked in git but has been deleted from the working tree as an unstaged change. The summary for plan 01-02 contradicts itself: Task 2 header says "System tests (removed)" while the commit record shows `0febfe4` added them. The file must be restored and the deletion either committed intentionally or reverted. As-of-disk, system test coverage for the auth lifecycle is absent.

**Gap 2 — Session cookie missing `secure:` flag (SECURITY HIGH)**

The session cookie is set with `httponly: true, same_site: :lax` but without `secure: Rails.env.production?`. Since `config.force_ssl` is also commented out in production, the session cookie can travel over HTTP in production, creating a session-hijacking surface. This should be resolved before any production deployment.

**Gap 3 — `field-group` CSS class undefined (cosmetic)**

The settings view uses `class="field-group"` on `<fieldset>` elements, but this class has no definition in `application.css`. Fieldsets render with browser-default styling. This is a cosmetic gap only — it does not affect functionality.

**What passed cleanly:** All four auth user stories (sign-up, login/logout, password reset, account settings) are correctly implemented and wired. The model layer, controller layer, routing, views, mailer, CSS design system, and controller-level tests are all present, substantive, and properly connected. The core goal — "users can securely create and manage their accounts" — is functionally achieved. The two actionable gaps are the missing system test file on disk and the session cookie security flag.
