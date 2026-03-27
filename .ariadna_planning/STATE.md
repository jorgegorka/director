# Project State

## Project Reference

See: .ariadna_planning/PROJECT.md (updated 2026-03-26)

**Core value:** Users can organize AI agents into a functioning company structure and confidently let them work autonomously -- knowing budgets are enforced, tasks are tracked, and humans retain control through governance.
**Current focus:** Phase 8 plan 02 complete — budget enforcement service and cost reporting API built

## Current Position

Phase: 8 of 10 (Budget and Cost Control) — IN PROGRESS
Plan: 2 of 3 complete (08-01, 08-02 done)
Status: BudgetEnforcementService and POST /api/agent/tasks/:id/cost endpoint complete, 528 tests passing
Last activity: 2026-03-27 -- 08-02 complete (2 tasks, 528 tests passing, 0 failures)

Progress: [████████░░] ~82%

## Performance Metrics

**Velocity:**
- Total plans completed: 15
- Average duration: ~8 minutes
- Total execution time: ~123 minutes

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
| 08-budget-cost-control | 2/3 | ~12 min | ~6 min |

**Recent Trend:**
- Last 5 plans: 07-01 (~6 min), 07-02 (~6 min), 07-03 (~20 min), 08-01 (~4 min), 08-02 (~8 min)
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

### Pending Todos

None.

### Blockers/Concerns

None.

## Session Continuity

Last session: 2026-03-27
Stopped at: Phase 8, plan 2 complete — budget enforcement service and cost reporting API (BudgetEnforcementService, POST /api/agent/tasks/:id/cost, 528 tests)
Resume file: .ariadna_planning/phases/08-budget-cost-control/08-02-SUMMARY.md
