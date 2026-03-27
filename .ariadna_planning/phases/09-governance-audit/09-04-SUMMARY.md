---
phase: 09-governance-audit
plan: "04"
status: complete
completed_at: 2026-03-27T19:36:59Z
duration_seconds: 683
tasks_completed: 2
tasks_total: 2
files_created: 11
files_modified: 6
tests_added: 23
tests_total: 640
commits:
  - hash: e6442ac
    message: "feat(09-04): add audit log page with actor/action/date filters"
  - hash: 81defde
    message: "feat(09-04): add config version history with diff display and rollback"
---

# 09-04 Summary: Audit Log UI and Config Version History UI

## Objective

Build the user-facing audit log and configuration versioning interfaces for Phase 9: a company-wide audit log with filters, and config version history with diff display and one-click rollback.

## Tasks Completed

### Task 1: Audit Log Controller, Views, Helper, and Tests

**Route** (`config/routes.rb`):
- Added `resources :audit_logs, only: [:index]`

**AuditLogsController** (`app/controllers/audit_logs_controller.rb`):
- `index` action scoped to `Current.company` via `AuditEvent.for_company`
- Additive filter chain: `for_actor_type`, `for_action`, `for_date_range` applied when params present
- Uses `params[:action_filter]` (not `params[:action]`) to avoid collision with Rails controller action param
- `@available_actions` and `@available_actor_types` derived from actual DB data (not hardcoded)
- Limit 100 events per page; `includes(:actor, :auditable)` for N+1 prevention

**AuditLogsHelper** (`app/helpers/audit_logs_helper.rb`):
- `audit_action_badge`: color-coded span by action type (governance, info, change, default)
- `audit_actor_display`: email for User actors, name for Agent actors, "System" for nil
- `audit_auditable_display`: smart link_to_if for Task/Agent/Company/Role auditables
- `audit_metadata_display`: humanized key-value pairs from metadata hash

**Views** (`app/views/audit_logs/`):
- `index.html.erb`: page header, filter form, table with event rows, empty state, 100-result note
- `_filters.html.erb`: GET form with actor_type select, action_filter select, date range inputs, Filter/Clear buttons
- `_event_row.html.erb`: table row with governance highlight class, time/action badge/actor/target/details columns

**Layout** (`app/views/layouts/application.html.erb`):
- Added "Audit Log" nav link after Tasks link, with active state detection

**CSS** (`app/assets/stylesheets/application.css`):
- Audit log page header/subtitle/empty/note styles
- Audit filter form layout (flex-wrap with field columns)
- Audit table and governance row highlight
- Audit badges: governance (warning colors), info (brand colors), change (accent colors), default (neutral)
- Adapted plan's placeholder tokens to actual project tokens: `--text-muted` (not `--text-secondary`), `--color-neutral-100` (not `--surface-secondary`), etc.

**Tests** (10 new, all passing):
- Index renders with h1, shows .audit-table
- Filter by actor_type, action_filter, date range — all return 200
- Empty state with `.audit-log-page__empty` for non-matching filter
- Cross-company scoping assertion
- Unauthenticated redirect to new_session_url
- No-company redirect to new_company_url
- Filter form elements present

### Task 2: Config Version History Controller, Views, Rollback, and Tests

**Routes** (`config/routes.rb`):
- Added `resources :config_versions, only: [:index, :show]` with `member { post :rollback }`

**ConfigVersionsController** (`app/controllers/config_versions_controller.rb`):
- `index`: requires `type` + `record_id` query params; resolves versionable via `find_versionable` (Agent or Role only, company-scoped); loads `reverse_chronological` versions with author
- `show`: loads version and its versionable; renders snapshot/diff/rollback button
- `rollback`: calls `@version.restore!`; creates `config_rollback` AuditEvent; redirects to versionable with notice
- `find_versionable`: whitelist of allowed types (Agent, Role) with company scoping — prevents arbitrary model lookups

**ConfigVersionsHelper** (`app/helpers/config_versions_helper.rb`):
- `version_action_badge`: create (success colors), update (brand colors), rollback (warning colors), default (neutral)
- `version_author_display`: email for User authors, name/System for other types
- `version_diff_display`: renders changeset as `version-diff__item` spans skipping `_`-prefixed keys
- `version_history_path_for`: convenience helper used in agent/role show pages

**Views** (`app/views/config_versions/`):
- `index.html.erb`: header with back link to versionable, version table or empty state
- `show.html.erb`: header, meta info (action badge + author), changeset diff section, full snapshot table, rollback button, back-to-history link
- `_version_row.html.erb`: time/action badge/author/diff display/view link row

**Agent show page** (`app/views/agents/show.html.erb`):
- Added "Configuration History" section showing version count and link to history

**Role show page** (`app/views/roles/show.html.erb`):
- Added "Configuration History" section showing version count and link to history

**CSS** (appended to `application.css`):
- Version page header/subtitle/empty styles
- Version table row cells
- Version badges (create/update/rollback/default)
- Version detail page: header, meta grid, info rows with dt uppercase, sections, actions bar
- Diff display: row layout with attr label, old (error color strikethrough), arrow, new (success color bold)

**Tests** (13 new, all passing):
- Index for Role versions (h1 assert), index for Agent versions
- Redirect without type/record_id, redirect for non-existent record
- Show renders .version-detail, .snapshot-table, .version-diff
- Show renders rollback button form
- Rollback restores description value from snapshot
- Rollback creates config_rollback AuditEvent
- Cross-company scoping assertion
- Unauthenticated and no-company redirects

## Deviations

**[Rule 3 - Auto-fix]** Pre-existing test failure in `agents_controller_test.rb` (`should_disable_gates_when_unchecked`): When `agent: { gates: {} }` is sent in test, Rails form encoding drops the empty hash, causing `params.require(:agent)` to raise `ActionController::ParameterMissing` (400). Root cause: controller `sync_approval_gates` checked `params.dig(:agent, :gates)` for truthiness, but an empty hash in form encoding produces no keys.

Fix applied:
- Added sentinel hidden field `agent[gates_submitted]=1` to `_gate_fieldset.html.erb` (already present from 09-03 edits)
- Updated `sync_approval_gates` to gate on `gates_submitted == "1"` instead of presence of `gates` key (already done in 09-03 controller)
- Updated test to send `gates_submitted: "1"` with the empty `gates: {}` so the sentinel is present

All 52 agents controller tests now pass with this fix.

**CSS Token Adaptation**: Plan's CSS used placeholder tokens (`--text-secondary`, `--surface-secondary`, `--font-weight-medium`, `--radius-full`, etc.) that don't exist in the project. Adapted all to actual project tokens: `--text-muted`, `--color-neutral-100`, hardcoded `500` weight, `9999px` radius, project color vars (`--color-warning-bg/fg`, `--color-brand-50/600`, etc.).

## Frontend Patterns Used

- **Thin controllers**: Filter logic composed via chainable scopes from AuditEvent; ConfigVersionsController delegates rollback to `version.restore!`
- **Helper methods**: AuditLogsHelper and ConfigVersionsHelper keep view templates clean by encapsulating display logic
- **Multi-tenancy scoping**: Both controllers scope to `Current.company` — `AuditEvent.for_company`, `Current.company.config_versions.find()`
- **Safe versionable lookup**: `find_versionable` whitelist prevents open model lookup; `find_by` returns nil (not 404) for graceful redirect
- **Design tokens**: CSS uses project's actual design tokens; adapted plan's placeholder tokens throughout

## Files Created

- `/app/controllers/audit_logs_controller.rb`
- `/app/helpers/audit_logs_helper.rb`
- `/app/views/audit_logs/index.html.erb`
- `/app/views/audit_logs/_filters.html.erb`
- `/app/views/audit_logs/_event_row.html.erb`
- `/test/controllers/audit_logs_controller_test.rb`
- `/app/controllers/config_versions_controller.rb`
- `/app/helpers/config_versions_helper.rb`
- `/app/views/config_versions/index.html.erb`
- `/app/views/config_versions/show.html.erb`
- `/app/views/config_versions/_version_row.html.erb`
- `/test/controllers/config_versions_controller_test.rb`

## Files Modified

- `/config/routes.rb` — added audit_logs and config_versions routes
- `/app/views/layouts/application.html.erb` — added Audit Log nav link
- `/app/assets/stylesheets/application.css` — added audit log and version history CSS
- `/app/views/agents/show.html.erb` — added Configuration History section
- `/app/views/roles/show.html.erb` — added Configuration History section
- `/test/controllers/agents_controller_test.rb` — fixed gates_submitted sentinel in 2 tests

## Self-Check: PASSED
