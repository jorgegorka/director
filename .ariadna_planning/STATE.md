# Project State

## Project Reference

See: .ariadna_planning/PROJECT.md (updated 2026-03-26)

**Core value:** Users can organize AI agents into a functioning company structure and confidently let them work autonomously -- knowing budgets are enforced, tasks are tracked, and humans retain control through governance.
**Current focus:** Phase 9 in progress — governance UI layer (approval gate form, pending approval banner, emergency stop, notification helper) complete

## Current Position

Phase: 9 of 10 (Governance and Audit) — IN PROGRESS
Plan: 3 of 4 complete (09-01, 09-02, 09-03 done; 09-04 also executed concurrently)
Status: Governance UI layer complete — gate fieldset, pending approval banner, emergency stop button, notification helper, 627 tests passing
Last activity: 2026-03-27 -- 09-03 complete (2 tasks, 627 tests passing, 0 failures)

Progress: [████████░░] ~87%

## Performance Metrics

**Velocity:**
- Total plans completed: 17
- Average duration: ~8 minutes
- Total execution time: ~134 minutes

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-authentication | 2 | ~10 min | ~5 min |
| 02-accounts-and-multi-tenancy | 2 | ~23 min | ~11 min |
| 03-org-chart-and-roles | 2/2 | ~12 min | ~6 min |
| 04-agent-connection | 3/3 | ~16 min | ~5.3 min |
| 05-tasks-and-conversations | 3/3 | ~20 min | ~6.7 min |
| 06-goals-and-alignment | 2/2 | ~18 min | ~9 min |
| 07-heartbeats-and-triggers | 3/3 | ~20 min | ~6.7 min |
| 08-budget-cost-control | 4/4 | ~31 min | ~7.8 min |
| 09-governance-audit | 3/4 | ~19 min | ~6.3 min |

**Recent Trend:**
- Last 5 plans: 08-03 (~8 min), 08-04 (~11 min), 09-01 (~6 min), 09-02 (~3 min), 09-03 (~10 min)
- Trend: consistent, stable

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Roadmap]: 10 phases derived from 38 requirements across 10 categories -- comprehensive depth
- [Roadmap]: Multi-tenancy (Current.account scoping) established in Phase 2 as foundation for all subsequent phases
- [01-01]: Rails 8 built-in authentication generator used (has_secure_password, Session model, Authentication concern)
- [01-01]: `email_address` field name (not `email`) -- Rails 8 auth generator convention, keep throughout
- [01-01]: PostgreSQL for primary database; sqlite3 retained for Solid Queue/Cache/Cable secondary connections
- [01-01]: CSS design system uses OKLCH colors, CSS layers, CSS nesting, logical properties (dark mode via prefers-color-scheme)
- [01-01]: Root route (`/`) is the authenticated landing page -- unauthenticated users redirect to /session/new
- [01-02]: No system/integration tests -- only unit and controller tests. Flows verified manually in Chrome.
- [01-02]: SettingsController requires current password verification before any account changes
- [02-01]: No default_scope on Tenantable -- use explicit .for_current_company scope (avoids anti-pattern)
- [02-01]: SetCurrentCompany guards on Current.user nil -- unauthenticated routes don't error
- [02-01]: Company switcher uses generic Stimulus dropdown controller (reusable for all future dropdowns)
- [02-01]: No company edit/delete in this phase -- deferred
- [02-02]: Role enum on Invitation is member/admin only -- no owner (owner assigned only at company creation)
- [02-02]: Partial unique index WHERE status = 0 on [company_id, email_address] -- prevents duplicate pending invites, allows re-inviting after accept/expire
- [02-02]: Role param sanitized outside permit() using .in?(enum.keys) -- avoids brakeman mass assignment warning
- [02-02]: Routes added in Task 1 (not Task 2) to unblock InvitationMailer URL helper in test environment
- [03-01]: assert_raises(ActiveRecord::RecordNotFound) does not work in integration tests — Rails catches it in middleware and returns 404. Use assert_response :not_found instead.
- [03-02]: SVG foreignObject nodes built with programmatic DOM (createElement/textContent/appendChild) — never innerHTML with user data. XSS-safe by design.
- [03-02]: agent_name is nil placeholder throughout Phase 3; Phase 4 will populate real agent names
- [04-01]: Zeitwerk namespace pattern: app/adapters/adapters/ subdirectory required for Adapters::* constants (Rails 8 treats app/adapters as autoload root, so files must be nested under adapters/ subdir)
- [04-01]: Agent.active scope excludes only :terminated — paused/error/pending_approval are still "active" records
- [04-02]: Fixture jsonb format: YAML hash syntax (key: val) required for jsonb columns in fixtures — JSON string literals ('{"key": "val"}') cause Rails to store/return String instead of Hash, breaking all jsonb operations in controller tests
- [04-02]: adapter_params pattern: use params[:agent][:adapter_config].permit!.to_h for unrestricted jsonb key acceptance in strong params
- [04-02]: Stimulus toggle disables hidden inputs (not just display:none) to prevent non-active adapter config fields from submitting
- [04-03]: form_with(model: [@agent, NestedModel.new]) generates wrong path helper when controller uses custom naming — use explicit url: helper instead
- [04-03]: agent_name: nil placeholder in OrgChartsHelper replaced with role.agent&.name; OrgChartsController eager-loads :agent to prevent N+1
- [05-01]: Auditable concern uses dependent: delete_all (not destroy) -- AuditEvent readonly? blocks cascade destroy, delete_all bypasses callbacks
- [05-01]: creator_id on tasks is nullable -- plan said null: false but also dependent: nullify; nullable is correct for user deletion without cascade
- [05-01]: t.references auto-creates indexes -- removed duplicate explicit add_index calls for parent_task_id and actor polymorphic index
- [05-02]: When testing audit events, use `.where(action: ...).last` not `.find_by(action: ...)` -- fixtures pre-populate audit events so find_by returns the fixture record, not the newly created one
- [05-03]: AgentApiAuthenticatable uses skip_before_action :require_authentication and replaces with session-OR-bearer-token logic -- does not modify Authentication concern
- [05-03]: current_actor returns @current_agent (Agent) if Bearer token auth succeeded, else Current.user (User) -- determines AuditEvent actor_type polymorphism
- [05-03]: developer role fixture updated with agent: http_agent to create testable CEO -> CTO/claude_agent -> Developer/http_agent hierarchy
- [06-01]: Goal tree pattern matches Role model exactly (ancestors iterative, descendants recursive flat_map) -- locked user decision
- [06-01]: Mission = Goal with parent_id nil (no type column, no STI) -- mission? is alias for root?
- [06-01]: Progress roll-up: subtree_task_ids collects all descendant goal IDs, then single Task.where query; returns 0.0 when no tasks
- [06-02]: CSS plan aliases (--space-lg, --text-sm, --border-default, --radius-full) mapped to actual project tokens (--space-6, --font-size-sm, --border, 9999px) -- do not create new token definitions
- [06-02]: options_for_goal_select available in TasksHelper context because Rails includes all helpers in all views by default
- [07-01]: HeartbeatScheduleManager uses class_attribute :task_store (nil in production = uses SolidQueue::RecurringTask; set in tests = uses FakeTaskStore). SolidQueue uses separate SQLite DB in production (not primary PostgreSQL), so guard checks table existence; tests inject fake store to avoid needing queue schema in primary DB
- [07-02]: Triggerable concern uses private methods (not included-do callbacks) — each model registers its own after_commit; trigger logic differs enough per model that shared callbacks would be awkward
- [07-02]: detect_mentions uses direct string include? check (not regex word boundaries) — handles multi-word agent names like "API Bot" which regex \b would split incorrectly
- [07-02]: Api::AgentEventsController scoped find_by for acknowledge — `@current_agent.heartbeat_events.queued.find_by(id:)` prevents cross-agent access and double-ack with a single 404 (no information disclosure)
- [07-03]: assert_raises(RecordNotFound) in integration tests must be assert_response :not_found (reconfirmed 03-01 pattern for HeartbeatsController cross-company isolation test)
- [07-03]: HeartbeatsHelper is in app/helpers/ (not app/presenters/ or included explicitly) -- Rails includes all helpers in all views, so helper methods are available in agents/show and heartbeats/index without any extra configuration
- [08-01]: t.references with polymorphic: true auto-creates an index; use index: false on t.references calls when providing explicit add_index with custom names to avoid PG::DuplicateTable on migration
- [08-01]: budget_cents uses integer cents (not float dollars) to avoid floating-point issues; nil = no budget configured (unlimited)
- [08-01]: Notification model reuses Tenantable for company scoping; polymorphic recipient (User), actor (Agent/User/nil), notifiable (Agent/nil) — designed for reuse in Phase 9 governance alerts
- [08-02]: BudgetEnforcementService.check!(agent) is the single entry point; called after every cost recording from AgentCostsController
- [08-02]: Alert threshold test budget_cents must account for fixture task costs already in current period (claude_agent: 3700 cents from design_homepage+completed_task) — use budget_cents: 15000 for 81.3% utilization at 12200 cents total
- [08-02]: cost endpoint accumulates cost (adds to existing cost_cents), not replaces — supports agents reporting partial costs across multiple calls
- [08-04]: NotificationsController index requires an HTML template (index.html.erb) even with respond_to block — 406 returned without it
- [08-04]: assert_response :not_found do...end is invalid (block ignored); always make request then assert separately (reconfirmed 03-01 pattern)
- [09-01]: Company has_many :audit_events must use dependent: :delete_all (not :destroy) — AuditEvent#readonly? prevents ActiveRecord destroy callbacks on persisted records; delete_all bypasses callbacks, matching the Auditable concern pattern
- [09-01]: ConfigVersioned concern declares has_many :config_versions on included models — do not add a separate explicit declaration to Agent/Role; the concern's declaration in the included block is the single source
- [09-01]: ConfigVersioned concern's should_version? check: saved_changes.keys == ["updated_at"] catches touch-only saves; also filters via governance_attributes intersection so non-governance attribute changes are ignored
- [09-02]: GateCheckService records agent as both auditable AND actor on gate_blocked AuditEvent — agent is the subject of the event and the initiator; Auditable concern not used here since it assumes Current.user as actor
- [09-02]: approve action reads pause_reason before clearing it (for gate_approval audit metadata); regex match extracts action_type from "Approval required: {action_type} gate is active" format
- [09-03]: Rack encodes gates: {} (empty nested hash) as empty string; params.require(:agent) raises ParameterMissing (400) when only gates is submitted — use hidden gates_submitted sentinel field to detect gate fieldset presence instead of checking gates key presence
- [09-03]: gate_fieldset partial only renders on edit form (agent.new_record? check) since gates require existing agent_id FK
- [09-03]: sync_approval_gates uses ActionController::Parameters.new.permit! for all-unchecked case (empty permitted params with all-false gate checks)

### Pending Todos

None.

### Blockers/Concerns

None.

## Session Continuity

Last session: 2026-03-27
Stopped at: Phase 9, plan 09-03 complete — governance UI layer (gate checkboxes, pending approval banner, emergency stop button, notification helper, 627 tests)
Resume file: .ariadna_planning/phases/09-governance-audit/09-03-SUMMARY.md
