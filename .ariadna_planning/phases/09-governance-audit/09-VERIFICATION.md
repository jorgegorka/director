---
phase: 09-governance-audit
verified: 2026-03-27T20:45:00Z
status: gaps_found
score: "11/12 truths verified | security: 0 critical, 0 high | performance: 0 high"
gaps:
  - truth: "GateCheckService.check!(agent:, action_type:) pauses agent with pending_approval status when a gate is active for that action type — AND this enforcement is invoked by actual agent action flows"
    status: partial
    reason: "GateCheckService exists and is fully implemented and tested in isolation (8 tests pass). However, it is NEVER called by any business logic controller or service. Tasks controller, task_delegations_controller, task_escalations_controller, and agent_costs_controller do not invoke GateCheckService. The automated gate enforcement path — where an agent performing a gatable action (task_creation, task_delegation, budget_spend, etc.) is automatically paused — does not exist. Only manual pause via the UI works."
    artifacts:
      - path: "app/services/gate_check_service.rb"
        issue: "Service is fully implemented but orphaned — not called from any task or action flow"
    missing:
      - "Call GateCheckService.check!(agent: ..., action_type: 'task_creation') in TasksController#create (for task creation gate)"
      - "Call GateCheckService.check!(agent: ..., action_type: 'task_delegation') in TaskDelegationsController#create"
      - "Call GateCheckService.check!(agent: ..., action_type: 'escalation') in TaskEscalationsController#create"
      - "Call GateCheckService.check!(agent: ..., action_type: 'budget_spend') in Api::AgentCostsController#cost"
security_findings: []
performance_findings: []
duplication_findings: []
human_verification:
  - test: "Toggle an approval gate for an agent (e.g., task_creation), then attempt to create a task assigned to that agent — confirm the agent does NOT automatically enter pending_approval state (because GateCheckService is not called)"
    expected: "Agent should enter pending_approval status automatically before the task creation is processed"
    why_human: "Automated tests only test GateCheckService in isolation; the broken integration requires a human to observe the missing gate enforcement in the actual task creation flow"
---

# Phase 9 Governance & Audit — Verification Report

## Phase Goal

Users can control agent autonomy through approval gates, kill switches, and comprehensive audit logging.

**Success Criteria from ROADMAP.md:**
1. User can define approval gates that pause an agent before high-impact actions and require human approval to proceed
2. User can pause, resume, or terminate any agent at any time from any page where the agent appears
3. All actions across the system are recorded in an immutable audit log that the user can browse and filter
4. Configuration changes (role edits, budget changes, gate modifications) are versioned and the user can roll back to a previous version

## Observable Truths Table

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | ApprovalGate model exists with agent_id, action_type, enabled, GATABLE_ACTIONS constant | PASS | `app/models/approval_gate.rb` — GATABLE_ACTIONS = %w[task_creation task_delegation budget_spend status_change escalation], full validations, scopes, gate_active? |
| 2 | ConfigVersion model exists with versionable (polymorphic), company_id, snapshot (jsonb), restore! method | PASS | `app/models/config_version.rb` — Tenantable, polymorphic versionable/author, restore!, restorable_attributes, diff_summary |
| 3 | AuditEvent has company_id with scopes for_company, for_actor_type, for_action, for_date_range | PASS | `app/models/audit_event.rb` line 10-13 — all 4 filter scopes present; company_id FK in schema |
| 4 | ConfigVersioned concern auto-creates snapshots on governance-relevant attribute changes | PASS | `app/models/concerns/config_versioned.rb` — after_save :create_config_version, should_version? filters updated_at-only changes; Role and Agent include it with governance_attributes |
| 5 | Agent model has gate_enabled? and has_any_gates? methods | PASS | `app/models/agent.rb` lines 131-137 |
| 6 | GateCheckService.check!(agent:, action_type:) pauses agent when gate is active, notifies, records audit | PASS (isolation) | `app/services/gate_check_service.rb` fully implemented; 8 unit tests pass |
| 7 | GateCheckService is invoked by actual task/action flows (task creation, delegation, escalation, budget spend) | FAIL | No invocation in tasks_controller.rb, task_delegations_controller.rb, task_escalations_controller.rb, or agent_costs_controller.rb |
| 8 | EmergencyStopService.call!(company:, user:) bulk-pauses all active agents, records audit, notifies owners/admins | PASS | `app/services/emergency_stop_service.rb`; CompaniesController#emergency_stop calls it; route exists |
| 9 | Agent show page has Pause/Resume/Terminate/Approve/Reject buttons based on agent status | PASS | `app/views/agents/show.html.erb` lines 15-30; conditional rendering verified |
| 10 | Audit log page with filter form (actor_type, action_filter, date range) is browsable at /audit_logs | PASS | `app/controllers/audit_logs_controller.rb`, `app/views/audit_logs/index.html.erb`, route registered |
| 11 | Config version history is viewable at /config_versions and rollback restores the snapshot | PASS | `app/controllers/config_versions_controller.rb` — index/show/rollback; `config_versions/show.html.erb` has rollback button |
| 12 | Emergency stop button in app header with company guard; navigation includes Audit Log link | PASS | `app/views/layouts/application.html.erb` lines 42-47 — both Emergency Stop and Audit Log links present |

**Verified: 11/12 truths**

## Artifact Status

| Artifact | Status | Notes |
|----------|--------|-------|
| app/models/approval_gate.rb | PRESENT — substantive | GATABLE_ACTIONS, validations, scopes, gate_active? |
| app/models/config_version.rb | PRESENT — substantive | Tenantable, restore!, restorable_attributes, diff_summary |
| app/models/audit_event.rb | PRESENT — substantive | company_id, 4 filter scopes, GOVERNANCE_ACTIONS, readonly? |
| app/models/concerns/config_versioned.rb | PRESENT — substantive | after_save callback, should_version?, create_config_version, rollback_to! |
| app/services/gate_check_service.rb | PRESENT — substantive but orphaned | Fully implemented, not wired into action flows |
| app/services/emergency_stop_service.rb | PRESENT — substantive | Wired into CompaniesController#emergency_stop |
| app/controllers/agents_controller.rb | PRESENT — substantive | pause/resume/terminate/approve/reject + sync_approval_gates |
| app/controllers/audit_logs_controller.rb | PRESENT — substantive | for_company scope, all 3 filters, includes(:actor, :auditable) |
| app/controllers/config_versions_controller.rb | PRESENT — substantive | index/show/rollback, find_versionable whitelist |
| app/views/audit_logs/index.html.erb | PRESENT — substantive | Table, filters partial, empty state |
| app/views/audit_logs/_filters.html.erb | PRESENT — substantive | actor_type select, action_filter select, date inputs |
| app/views/config_versions/index.html.erb | PRESENT — substantive | Version table or empty state |
| app/views/config_versions/show.html.erb | PRESENT — substantive | Meta, diff section, snapshot table, rollback button |
| app/views/agents/_gate_fieldset.html.erb | PRESENT — substantive | Checkboxes for all 5 GATABLE_ACTIONS, sentinel field |
| app/views/agents/_pending_approval_banner.html.erb | PRESENT — substantive | Conditional render, approve/reject buttons |
| app/helpers/agents_helper.rb | PRESENT — substantive | gate_description, gate_status_indicator |
| app/helpers/notifications_helper.rb | PRESENT — substantive | gate_pending_approval, gate_approval, gate_rejection, emergency_stop cases |
| app/helpers/audit_logs_helper.rb | PRESENT — substantive | audit_action_badge, audit_actor_display, audit_auditable_display |
| app/helpers/config_versions_helper.rb | PRESENT — substantive | version_action_badge, version_author_display, version_diff_display, version_history_path_for |
| db/migrate/20260327191032_create_approval_gates.rb | PRESENT — up | FK, unique index on [agent_id, action_type] |
| db/migrate/20260327191037_create_config_versions.rb | PRESENT — up | jsonb columns, composite index |
| db/migrate/20260327191216_add_company_id_to_audit_events.rb | PRESENT — up | FK, [company_id+created_at] and [company_id+action] indexes |
| test/models/approval_gate_test.rb | PRESENT — 18 tests |  |
| test/models/config_version_test.rb | PRESENT — 17 tests including concern integration |  |
| test/models/audit_event_test.rb | PRESENT — 6 new tests appended |  |
| test/services/gate_check_service_test.rb | PRESENT — 8 tests |  |
| test/services/emergency_stop_service_test.rb | PRESENT — 7 tests |  |
| test/controllers/agents_controller_test.rb | PRESENT — 17 status + 5 gate UI tests added |  |
| test/controllers/audit_logs_controller_test.rb | PRESENT — 10 tests |  |
| test/controllers/config_versions_controller_test.rb | PRESENT — 13 tests |  |

## Key Links / Wiring

| From | To | Via | Status |
|------|----|-----|--------|
| app/models/approval_gate.rb | app/models/agent.rb | belongs_to :agent | PASS |
| app/models/agent.rb | app/models/approval_gate.rb | has_many :approval_gates, gate_enabled?, has_any_gates? | PASS |
| app/models/config_version.rb | app/models/role.rb | polymorphic versionable | PASS |
| app/models/config_version.rb | app/models/agent.rb | polymorphic versionable | PASS |
| app/models/audit_event.rb | app/models/company.rb | belongs_to :company | PASS |
| app/models/concerns/config_versioned.rb | app/models/config_version.rb | after_save creates ConfigVersion | PASS |
| app/services/gate_check_service.rb | app/models/approval_gate.rb | agent.gate_enabled? | PASS |
| app/services/gate_check_service.rb | task/delegation/escalation flows | caller integration | FAIL — not wired |
| app/services/emergency_stop_service.rb | app/controllers/companies_controller.rb | EmergencyStopService.call! | PASS |
| app/controllers/agents_controller.rb | app/models/audit_event.rb | record_agent_audit | PASS |
| app/controllers/audit_logs_controller.rb | app/models/audit_event.rb | AuditEvent.for_company | PASS |
| app/controllers/config_versions_controller.rb | app/models/config_version.rb | Current.company.config_versions | PASS |
| app/views/agents/show.html.erb | config_versions#index | version_history_path_for | PASS |
| app/views/roles/show.html.erb | config_versions#index | version_history_path_for | PASS |
| app/views/layouts/application.html.erb | CompaniesController#emergency_stop | button_to emergency_stop_company_path | PASS |
| app/views/agents/_form.html.erb | AgentsController#update | sync_approval_gates via gates_submitted sentinel | PASS |

## Cross-Phase Integration

**Phase 5 (Auditable concern):** Updated `record_audit_event!` now accepts `company:` param with backward-compatible auto-resolution via `try(:company) || Current.company`. Existing callers unaffected. PASS.

**Phase 4 (Agent status enum):** `pending_approval: 5` already existed in the enum from Phase 4. GateCheckService correctly uses `:pending_approval`. PASS.

**Phase 8 (BudgetEnforcementService pattern):** GateCheckService and EmergencyStopService follow the same class-method-delegating-to-instance pattern as BudgetEnforcementService. PASS.

**Notification system (Phase 8):** `gate_pending_approval` and `emergency_stop` notification actions render correctly via updated NotificationsHelper. PASS.

## Gap Analysis: GateCheckService Not Wired

The critical gap is that `GateCheckService.check!` is never called from any application flow. The service is a complete and tested component but functions only as a library — it requires a human to invoke it explicitly via tests or manual calls.

The ROADMAP success criterion 1 states: "User can define approval gates that **pause an agent before high-impact actions** and require human approval to proceed." The emphasis on "before high-impact actions" implies automatic enforcement at the point of action — not just manual pause via the UI.

The 09-CONTEXT.md decision confirms this interpretation: "Agent hits a gated action → pauses with `pending_approval` status → user approves/rejects → agent continues or stays paused." This causation chain is broken: no action hits the gate because GateCheckService is never called.

What works correctly:
- Users CAN configure which gates are active per agent
- Users CAN manually pause agents (setting them to `paused` status)
- Users CAN approve/reject agents in `pending_approval` status
- Emergency stop works end-to-end

What is missing:
- Automatic gate enforcement at the point of action (task creation, delegation, escalation, budget spend)

**Affected files that need calls added:**
- `app/controllers/tasks_controller.rb` — task_creation gate for the assigned agent
- `app/controllers/task_delegations_controller.rb` — task_delegation gate
- `app/controllers/task_escalations_controller.rb` — escalation gate
- `app/controllers/api/agent_costs_controller.rb` — budget_spend gate

## Test Suite

640 tests, 0 failures, 0 errors, 0 skips. All phase 9 tests pass individually and as part of the full suite.

## Security

Brakeman scan: 0 warnings. RuboCop (Ruby files): 0 offenses across all 69 inspected files.

Notable security positives:
- `ConfigVersionsController#find_versionable` uses a whitelist (`Agent`, `Role` only) preventing open model reflection attacks
- All new controllers use `require_company!` (which depends on `require_authentication` from `Authentication` concern in ApplicationController)
- `AuditEvent#readonly?` enforces immutability on persisted audit records
- Gate parameter handling uses `permit(*ApprovalGate::GATABLE_ACTIONS)` — no mass assignment risk

## Performance

- `AuditLogsController#index` uses `includes(:actor, :auditable)` to prevent N+1 on event rows
- `ConfigVersionsController#index` uses `includes(:author)`
- `AgentsController#set_agent` uses `includes(:agent_capabilities, :roles, :approval_gates)` — N+1 prevention for gate fieldset
- All three new tables have appropriate indexes: composite `[company_id, created_at]` on audit_events, `[versionable_type, versionable_id, created_at]` on config_versions, unique `[agent_id, action_type]` on approval_gates
- `EmergencyStopService` uses `find_each` for batch processing

## Summary of Gaps

**1 gap (partial failure):** GateCheckService is fully built and tested but is orphaned — it is never called by task creation, delegation, escalation, or cost recording flows. The gate infrastructure (model, service, UI configuration, approve/reject) is complete, but the automated enforcement trigger — the "agent hits a gated action and is automatically paused" behavior — is absent from all actual action flows. Success Criterion 1 is partially met: the configuration and manual approval path works, but the automatic gate enforcement at action time does not.
