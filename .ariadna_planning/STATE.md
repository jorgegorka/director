# Project State

## Project Reference

See: .ariadna_planning/PROJECT.md (updated 2026-03-28)

**Core value:** Users can organize AI agents into a functioning company structure and confidently let them work autonomously -- knowing budgets are enforced, tasks are tracked, and humans retain control through governance.
**Current focus:** v1.3 Agent Hooks -- Phase 18

## Current Position

Phase: 18 - Hook Data Foundation
Plan: --
Status: Planning
Last activity: 2026-03-28 -- v1.3 roadmap created (phases 18-21)

## Performance Metrics

**Velocity:**
- Total plans completed: 38
- Average duration: ~7 minutes
- Total execution time: ~220 minutes

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
| 09-governance-audit | 4/4 | ~30 min | ~7.5 min |
| 10-dashboard-real-time-ui | 4/4 | ~19 min | ~4.8 min |
| 11-sqlite-migration | 2/2 | ~13 min | ~6.5 min |
| 12-cleanup-verification | 1/1 | ~15 min | ~15 min |
| 13-skill-data-model | 2/2 | ~11 min | ~5.5 min |
| 14-skill-catalog-seeding | 2/2 | ~12 min | ~6 min |
| 15-role-auto-assignment | 1/1 | ~2 min | ~2 min |
| 16-skills-crud | 2/2 | ~13 min | ~6.5 min |
| 17-agent-skill-management | 2/2 | ~7 min | ~3.5 min |

**Recent Trend:**
- Last 5 plans: 16-01 (~8 min), 16-02 (~5 min), 17-01 (~4 min), 17-02 (~3 min)
- Trend: consistent, stable. v1.0 COMPLETE. v1.1 COMPLETE. v1.2 COMPLETE. All milestones shipped.

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Roadmap]: 10 phases derived from 38 requirements across 10 categories -- comprehensive depth
- [Roadmap]: Multi-tenancy (Current.account scoping) established in Phase 2 as foundation for all subsequent phases
- [v1.1-Roadmap]: 2 phases (11-12) derived from 8 requirements across 2 categories -- DB migration then cleanup
- [v1.1-Roadmap]: Phase 11 covers all 5 DB-* requirements as one coherent deliverable (gem swap + config + column migration + deploy)
- [v1.1-Roadmap]: Phase 12 covers all 3 CLN-* requirements (docs + dead code + test verification) -- depends on Phase 11
- [v1.2-Roadmap]: 5 phases (13-17) derived from 22 requirements across 6 categories -- data model, seeding, auto-assignment, CRUD, agent management
- [v1.2-Roadmap]: Phase 13 (data model) is foundation -- all other phases depend on it
- [v1.2-Roadmap]: Phase 14 (seeding) before Phase 15 (auto-assignment) because auto-assignment needs skills to exist in the company
- [v1.2-Roadmap]: Phase 16 (skills CRUD) and Phase 17 (agent skill management) are the UI layer -- depend on data model but could theoretically parallelize; sequenced for simplicity
- [v1.3-Roadmap]: 4 phases (18-21) derived from 15 requirements across 5 categories -- data foundation, triggering engine, feedback loop, management UI
- [v1.3-Roadmap]: Phase 18 (data foundation) includes UI-03 (HeartbeatEvent enum extension) because it modifies an existing model alongside new model creation
- [v1.3-Roadmap]: Phase 19 combines triggering (TRIG-01, TRIG-02) with actions (ACT-01, ACT-02, ACT-03) because the concern and service are tightly coupled -- Hookable detects transitions, ExecuteHookService dispatches them
- [v1.3-Roadmap]: Phase 20 (feedback loop) depends on Phase 19 because validation subtasks must be created by trigger_agent hooks before feedback can be processed
- [v1.3-Roadmap]: Phase 21 (management UI) is last because hooks should fire correctly before exposing CRUD to users
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
- [09-04]: AuditLogsController uses params[:action_filter] not params[:action] to avoid collision with Rails' own controller :action param
- [09-04]: ConfigVersionsController find_versionable whitelist (Agent, Role only) prevents arbitrary model lookups; uses find_by (not find) so nil triggers graceful redirect instead of 404
- [10-01]: `resource :dashboard` routes to `DashboardsController` (plural) by default — must add `controller: "dashboard"` to force singular controller; root route uses `dashboard#show` directly which is fine
- [10-01]: tabs_controller.js uses `hidden` attribute (not CSS display:none) for panel toggling — semantically correct, accessible, consistent with existing dropdown_controller.js pattern
- [09-04]: Plan CSS tokens (--text-secondary, --surface-secondary, --font-weight-medium, etc.) are planning placeholders — map to actual project tokens (--text-muted, --color-neutral-100, literal 500, etc.)
- [10-02]: @all_tasks loaded once with includes(:assignee, :creator); in-memory grouping via @tasks_by_status avoids 5 separate status-filtered queries
- [10-02]: kanban_controller.js auto-discovered by eagerLoadControllersFrom naming convention — no manual registration needed
- [10-02]: PATCH on drop uses fetch with CSRF meta tag; page.reload() on failure to restore server-authoritative state
- [10-04]: turbo_stream_from + Turbo::StreamsChannel.broadcast_*_to — standard Rails 8 / Turbo 8 pattern; no custom Action Cable channel JS needed; turbo-rails handles auto-subscription via turbo-cable-stream-source element
- [10-04]: Stream name convention "dashboard_company_{company_id}" — simple string for company-scoped isolation
- [10-04]: ApplicationCable::Channel base class created — was missing from app/channels/; required for Action Cable
- [10-04]: after_create_commit (not after_commit) used on AuditEvent — readonly after persist so only initial create triggers broadcast
- [11-01]: db:prepare fails when schema.rb has jsonb columns (SQLite rejects them at schema:load). Fix: manually update schema.rb then use db:create + db:migrate + db:schema:dump sequence
- [11-01]: SQLite uses t.json (not t.jsonb) for hash/object columns — jsonb is PostgreSQL-only; json works identically for storing Ruby hashes in fixtures and AR operations
- [11-01]: bigint declarations are preserved in SQLite schema.rb — cosmetic only; SQLite stores all integers natively regardless of declared size
- [11-02]: Dockerfile was already SQLite-clean (Rails 8 generator defaults); only deploy.yml needed cleanup (DB_HOST comment block + mysql/db accessory removed)
- [11-02]: No SQLite-specific test failures in full CI run — json column migration from 11-01 was sufficient for all 674 tests
- [12-01]: Rephrase (not just checkbox) PostgreSQL references to achieve zero grep matches: requirement text and key decision table entry renamed
- [12-01]: Removing :test group from Gemfile leaves trailing blank line — rubocop auto-fix required; stage Gemfile before committing
- [12-01]: Test count after removing 7 home_controller tests: landed at 668 (not 667 as predicted), all passing with 0 failures
- [13-01]: Agent needs has_many :agent_skills, dependent: :destroy and Company needs has_many :skills, dependent: :destroy -- FK cascade constraints block destroy tests otherwise
- [13-01]: Skill uniqueness: unique index on [company_id, key] enforced at DB + model level; two companies can share a key, one company cannot duplicate it
- [13-02]: Skills section in agent show view is read-only (no add/remove UI) -- Phase 17 adds agent skill management UI; this plan only wires associations and updates display
- [13-02]: Company has_many :skills was already in place from Plan 01 Rule 3 auto-fix; no changes needed to company.rb in this plan
- [14-01]: 50 unique skill keys extracted from role mapping table (spec text says "44" but the actual table yields 50 distinct keys); authoritative count is 50
- [14-01]: general role maps to 4 skills (task_execution, communication, documentation, problem_solving) exactly as specified in design spec table
- [14-01]: task_execution, communication, problem_solving assigned to operations category per plan's explicit category assignment list
- [14-02]: Company#seed_default_skills! uses find_or_create_by!(key:) -- the block only runs on create, so existing skills are never overwritten; method is idempotent by design
- [14-02]: after_create callback does not fire during fixture loading (Rails fixtures use bulk INSERT bypassing AR callbacks) -- acme/widgets fixture companies unaffected by seeding logic
- [15-01]: Role uses saved_change_to_agent_id? and agent_id_before_last_save for post-save dirty tracking -- correct pattern for after_save callbacks (vs will_save_change_to_* which is pre-save)
- [15-01]: after_save with :if guard is more idiomatic than checking conditions inside the callback method; guard is a pure predicate method
- [15-01]: default_skills_config memoized at class level (@default_skills_config ||=) -- YAML file read once per process, not on every role save
- [17-01]: AgentSkillsController create uses find_or_create_by!(skill:) for idempotency -- assigning an already-assigned skill is a safe no-op
- [17-01]: @assigned_skill_ids = @agent.skill_ids.to_set in AgentsController#show -- Set membership for O(1) lookup per skill in checkbox loop
- [17-01]: Checkbox toggle UI pattern: button_to DELETE for checked (assigned) skills, button_to POST with skill_id param for unchecked -- no JS required
- [17-01]: AgentSkill lookup for destroy path uses in-memory find on @agent.agent_skills (already loaded via includes) -- no extra DB query per skill row
- [17-02]: Idempotency test for create uses assert_no_difference + assert_redirected_to -- find_or_create_by! is silent no-op, redirect is the expected outcome
- [17-02]: Cross-agent destroy test: use http_data_analysis fixture via claude_agent nested route -- @agent.agent_skills.find scopes the lookup, gives 404 for mismatched parent
- [17-02]: Skill UI assertions use css_select size comparison (total toggles > assigned toggles) rather than hardcoded counts -- resilient to fixture changes

### Pending Todos

None.

### Blockers/Concerns

None.

## Session Continuity

Last session: 2026-03-28
Stopped at: v1.3 roadmap created (phases 18-21)
Resume file: .ariadna_planning/ROADMAP.md
Next step: /ariadna:plan-phase 18
