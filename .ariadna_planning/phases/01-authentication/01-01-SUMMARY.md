# Plan 01-01 Summary: Authentication Foundation

**Phase:** 01-authentication
**Plan:** 01
**Status:** Complete
**Duration:** ~5 minutes (2026-03-26T20:18:17Z - 2026-03-26T20:23:12Z)
**Tasks:** 3/3
**Files changed:** 33

---

## Objective

Set up the full authentication foundation for Director: database switch to PostgreSQL, Rails 8 auth generator scaffold, user registration (sign-up), authenticated landing page, and session-aware layout. Delivers AUTH-01 (sign up), AUTH-02 (login/logout), and AUTH-03 (password reset).

---

## Tasks Executed

### Task 1: Switch to PostgreSQL and run Rails 8 authentication generator
**Commit:** 644db3b

- Replaced `sqlite3` (primary database) with `pg ~> 1.5` in Gemfile; kept sqlite3 for Solid Queue/Cache/Cable
- Uncommented `bcrypt ~> 3.1.7` (required by has_secure_password)
- Updated `config/database.yml`: PostgreSQL adapter for development/test/production primary; sqlite3 retained for cache/queue/cable secondary connections in production
- Ran `bin/rails db:create` to create `director_development` and `director_test`
- Ran `bin/rails generate authentication`: generated User, Session, Current models; SessionsController, PasswordsController, Authentication concern; PasswordsMailer; migrations; test fixtures and helpers
- Added email validation to User model: presence, uniqueness, format (URI::MailTo::EMAIL_REGEXP)
- Ran `bin/rails db:migrate`: both create_users and create_sessions migrations up
- Added root route (`home#show`) and stub HomeController/view to fix `root_url` reference needed by SessionsController (Rule 3: auto-fix blocking issue)
- All 12 generated tests pass

**Deviation:** Added root route and stub HomeController in Task 1 (not Task 3) because the SessionsController's `after_authentication_url` references `root_url` at test time, causing a NameError. Fixed inline under Rule 3.

### Task 2: Build user registration (sign-up) flow
**Commit:** 6d3d67c

- Created `app/controllers/registrations_controller.rb` with `allow_unauthenticated_access`, new/create actions
- `create` calls `start_new_session_for(@user)` for auto-login after sign-up, redirects to `root_path` with welcome notice
- Created `app/views/registrations/new.html.erb` using `auth-card` CSS component with error display
- Updated `app/views/sessions/new.html.erb` with improved markup, consistent form styling, and "Sign up" link
- Route: `resource :registration, only: [:new, :create]`
- All 6 registration controller tests pass

### Task 3: Add authenticated landing page, layout navigation, and flash messages
**Commit:** a948f92

- Expanded `app/views/home/show.html.erb`: welcome message, user email display (`Current.user.email_address`), tagline placeholder
- Updated `app/views/layouts/application.html.erb`:
  - Sticky `<header>` with app logo and conditional nav (user email + logout button when authenticated; login/signup links when not)
  - Flash messages section (`notice`/`alert`) with ARIA role attributes
  - `<main class="app-main">` wrapper for page content
- Built complete CSS design system in `app/assets/stylesheets/application.css`:
  - CSS layers: `reset, tokens, base, layout, components, utilities`
  - OKLCH color tokens (brand, neutral, success, error palettes) with automatic dark mode via `prefers-color-scheme`
  - Typography, spacing, radius, shadow custom properties
  - Components: `.btn` (primary/ghost/sm/full variants), `.flash` (notice/alert), `.field`, `.auth-card`, `.home-hero`, `.error-list`, `.auth-footer`
  - CSS nesting and logical properties throughout (no Tailwind)
- Updated `passwords/new.html.erb` and `passwords/edit.html.erb` to use `auth-card` component
- All 21 tests pass (0 failures, 0 errors)

---

## Artifacts Produced

| Path | Provides |
|------|----------|
| `app/models/user.rb` | User model with has_secure_password, email validation, normalizes email |
| `app/models/session.rb` | Session model belonging to User for cookie-based auth |
| `app/models/current.rb` | Current attributes: session, delegates user |
| `app/controllers/concerns/authentication.rb` | Authentication concern: require_authentication, resume_session, start_new_session_for, terminate_session |
| `app/controllers/sessions_controller.rb` | SessionsController for login/logout |
| `app/controllers/passwords_controller.rb` | PasswordsController for password reset flow |
| `app/controllers/registrations_controller.rb` | RegistrationsController for sign-up |
| `app/controllers/home_controller.rb` | HomeController#show as authenticated landing page (root route) |
| `app/mailers/passwords_mailer.rb` | PasswordsMailer#reset for password reset emails |
| `app/assets/stylesheets/application.css` | Complete CSS design system (OKLCH, CSS layers, dark mode) |
| `config/database.yml` | PostgreSQL primary database configuration |
| `db/migrate/20260326201846_create_users.rb` | Users table migration |
| `db/migrate/20260326201847_create_sessions.rb` | Sessions table migration |

---

## Routes Established

| Verb | Path | Action |
|------|------|--------|
| GET | / | home#show (root, requires auth) |
| GET | /session/new | sessions#new (login form) |
| POST | /session | sessions#create (login) |
| DELETE | /session | sessions#destroy (logout) |
| GET | /registration/new | registrations#new (sign-up form) |
| POST | /registration | registrations#create (sign-up) |
| GET | /passwords/new | passwords#new (request reset) |
| POST | /passwords | passwords#create (send reset email) |
| GET | /passwords/:token/edit | passwords#edit (reset form) |
| PATCH | /passwords/:token | passwords#update (set new password) |

---

## Deviations

1. **[Rule 3 - Blocking Issue] Added root route + stub HomeController in Task 1**
   SessionsController's `after_authentication_url` calls `root_url` at test time. Without a root route defined, `bin/rails test` fails with `NameError: undefined local variable or method 'root_url'`. Fixed by adding root route and stub HomeController during Task 1 verification step, rather than waiting for Task 3.

---

## Success Criteria Check

- [x] `bin/rails test` passes: 21 tests, 0 failures, 0 errors
- [x] Database uses PostgreSQL for primary adapter
- [x] User can sign up at /registration/new, is auto-logged-in, lands on root
- [x] User can log out via nav bar and log back in at /session/new
- [x] User can request password reset at /passwords/new and reset via link
- [x] Unauthenticated access to / redirects to /session/new
- [x] Flash messages display for all auth actions
- [x] Layout shows appropriate nav based on authentication state
- [x] All views use modern CSS (no Tailwind classes)

---

## Commits

| Hash | Message |
|------|---------|
| 644db3b | feat(01-01): switch to PostgreSQL and run Rails 8 authentication generator |
| 6d3d67c | feat(01-01): add user registration (sign-up) flow |
| a948f92 | feat(01-01): add authenticated landing page, layout navigation, and CSS design system |

---

## Self-Check: PASSED

All files exist. All commits exist. 21 tests pass (0 failures, 0 errors).
