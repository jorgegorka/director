---
phase: 09-governance-audit
plan: "01"
status: complete
completed_at: 2026-03-27T19:15:59Z
duration_seconds: 332
tasks_completed: 3
tasks_total: 3
files_created: 10
files_modified: 7
tests_added: 41
tests_total: 581
commits:
  - hash: 48f6094
    message: "feat(09-01): add ApprovalGate and ConfigVersion models with migrations"
  - hash: 3cd3c61
    message: "feat(09-01): add AuditEvent company scoping and ConfigVersioned concern"
  - hash: 372fd79
    message: "test(09-01): add model tests for ApprovalGate, ConfigVersion, AuditEvent, and ConfigVersioned concern"
---

# 09-01 Summary: Governance Data Layer

## Objective

Establish the data layer for Phase 9 Governance and Audit: ApprovalGate model for per-agent action gating, ConfigVersion model for lightweight JSON snapshot versioning, AuditEvent company scoping, and the ConfigVersioned concern for automatic governance change tracking.

## Tasks Completed

### Task 1: ApprovalGate and ConfigVersion Models

- Created `approval_gates` table with `agent_id` FK, `action_type` string, `enabled` boolean, timestamps; unique index on `[agent_id, action_type]`
- Created `config_versions` table with `company_id` FK, polymorphic `versionable`/`author`, `action` string, `snapshot`/`changeset` jsonb, timestamps; index on `[versionable_type, versionable_id, created_at]`
- `ApprovalGate` model with `GATABLE_ACTIONS = %w[task_creation task_delegation budget_spend status_change escalation]`, validations (presence, inclusion, uniqueness scoped to agent), `enabled`/`disabled`/`for_action` scopes, `gate_active?` method
- `ConfigVersion` model with `Tenantable`, polymorphic `versionable`/optional `author`, `restore!`, `restorable_attributes` (excludes id/timestamps/company_id), `diff_summary`
- Added `has_many :approval_gates, dependent: :destroy` to `Agent`; added `gate_enabled?(action_type)` and `has_any_gates?` helper methods
- Added `has_many :config_versions, dependent: :destroy` to `Company`
- Created `approval_gates.yml` and `config_versions.yml` fixtures

### Task 2: AuditEvent Company Scoping and ConfigVersioned Concern

- Added `company_id` FK to `audit_events` with backfill SQL (sets from `tasks.company_id` for existing Task events); added `[company_id, created_at]` and `[company_id, action]` indexes
- Updated `AuditEvent` with `belongs_to :company, optional: true`, new scopes: `for_company`, `for_actor_type`, `for_date_range`, `for_action`; added `GOVERNANCE_ACTIONS` constant (9 action types) and `governance_action?` predicate
- Updated `Auditable` concern: `record_audit_event!` now accepts `company:` param; auto-resolves via `company || try(:company) || Current.company` for backward compatibility
- Added `has_many :audit_events, dependent: :delete_all` to `Company` (uses `delete_all` because `AuditEvent#readonly?` blocks destroy callbacks)
- Created `ConfigVersioned` concern: `after_save :create_config_version` only when `should_version?` is true (filters updated_at-only changes, checks against `governance_attributes`); `rollback_to!(version)`, `version_history`; stores rollback source in `changeset["_rollback_source"]`
- Included `ConfigVersioned` in `Role` with `governance_attributes = %w[title description job_spec parent_id agent_id]`
- Included `ConfigVersioned` in `Agent` with `governance_attributes = %w[name budget_cents budget_period_start status]`
- Updated `audit_events.yml` fixtures with `company: acme` on all existing events; added `gate_approval_event` and `emergency_stop_event` governance fixtures

### Task 3: Model Tests

- **18 ApprovalGate tests**: validations (blank, inclusion, uniqueness/scope, cross-agent allowed, all GATABLE_ACTIONS), associations, cascade destroy, enabled/disabled/for_action scopes, gate_active?, Agent helper methods (gate_enabled?, has_any_gates?)
- **17 ConfigVersion tests**: validations (action required, inclusion, create/update/rollback accepted), associations (Tenantable company, polymorphic versionable/author, optional author), scopes (reverse_chronological, for_versionable), restorable_attributes, diff_summary, restore!, cascade delete from company; ConfigVersioned concern integration tests: auto-creates version on governance attribute update, changeset captures old/new values, non-governance (updated_at only) changes do not create versions
- **6 new AuditEvent tests** (appended to existing file): for_company, for_actor_type, for_date_range, governance_action? true/false, GOVERNANCE_ACTIONS constant completeness

## Deviations

**[Rule 3 - Auto-fix]** After adding `company_id` FK to `audit_events`, existing tests that destroyed Company records failed with `PG::ForeignKeyViolation` because audit_events referenced the company. Fixed by adding `has_many :audit_events, dependent: :delete_all` to `Company`. Used `delete_all` (not `destroy`) because `AuditEvent#readonly?` prevents ActiveRecord callbacks from running on persisted records — matching the same pattern already used in `Auditable` concern.

## Backend Patterns Used

- **Concern architecture**: `ConfigVersioned` is a shared concern in `app/models/concerns/` following the project's concern-driven approach; each model overrides `governance_attributes` to customize which attributes trigger versioning
- **Current context**: `ConfigVersioned` uses `Current.company` and `Current.user` for author/company resolution without parameter passing
- **Tenantable**: `ConfigVersion` uses `Tenantable` for consistent company scoping with `for_current_company` scope
- **Polymorphic associations**: `versionable` and `author` on `ConfigVersion`; `auditable` and `actor` on `AuditEvent`
- **Immutability pattern**: `AuditEvent#readonly?` continues to protect existing records; `delete_all` used consistently to bypass callbacks when cascading

## Files Created

- `/app/models/approval_gate.rb`
- `/app/models/config_version.rb`
- `/app/models/concerns/config_versioned.rb`
- `/db/migrate/20260327191032_create_approval_gates.rb`
- `/db/migrate/20260327191037_create_config_versions.rb`
- `/db/migrate/20260327191216_add_company_id_to_audit_events.rb`
- `/test/fixtures/approval_gates.yml`
- `/test/fixtures/config_versions.yml`
- `/test/models/approval_gate_test.rb`
- `/test/models/config_version_test.rb`

## Files Modified

- `/app/models/agent.rb` — added `include ConfigVersioned`, `has_many :approval_gates`, `gate_enabled?`, `has_any_gates?`, `governance_attributes`
- `/app/models/company.rb` — added `has_many :config_versions`, `has_many :audit_events`
- `/app/models/role.rb` — added `include ConfigVersioned`, `governance_attributes`
- `/app/models/audit_event.rb` — added company association, scopes, GOVERNANCE_ACTIONS, `governance_action?`
- `/app/models/concerns/auditable.rb` — updated `record_audit_event!` to accept and resolve `company:` param
- `/test/fixtures/audit_events.yml` — added company to existing fixtures, added governance event fixtures
- `/test/models/audit_event_test.rb` — appended 6 new company-scoping tests

## Self-Check: PASSED

All created files verified present. All 3 commits verified in git log. 581 tests passing, 0 failures, 0 errors.
