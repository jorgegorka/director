# Project State

## Project Reference

See: .ariadna_planning/PROJECT.md (updated 2026-03-26)

**Core value:** Users can organize AI agents into a functioning company structure and confidently let them work autonomously -- knowing budgets are enforced, tasks are tracked, and humans retain control through governance.
**Current focus:** Phase 5 in progress — data layer complete, controllers/UI next

## Current Position

Phase: 5 of 10 (Tasks and Conversations) — COMPLETE
Plan: 3 of 3 complete (05-01, 05-02, 05-03 done)
Status: All phase 5 success criteria met — task CRUD, threaded conversations, delegation/escalation, full audit trail
Last activity: 2026-03-27 -- 05-03 complete (2 tasks, 311 tests passing, 0 failures)

Progress: [████░░░░░░] ~40%

## Performance Metrics

**Velocity:**
- Total plans completed: 10
- Average duration: ~7 minutes
- Total execution time: ~35 minutes

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-authentication | 2 | ~10 min | ~5 min |
| 02-accounts-and-multi-tenancy | 2 | ~23 min | ~11 min |
| 03-org-chart-and-roles | 2/2 | ~12 min | ~6 min |
| 04-agent-connection | 3/3 | ~16 min | ~5.3 min |
| 05-tasks-and-conversations | 3/3 | ~20 min | ~6.7 min |

**Recent Trend:**
- Last 5 plans: 03-02 (~3 min), 04-01 (~5 min), 04-02 (~6 min), 04-03 (~5 min)
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

### Pending Todos

None.

### Blockers/Concerns

None.

## Session Continuity

Last session: 2026-03-27
Stopped at: Phase 5, plan 03 complete — ALL of phase 5 complete (task CRUD, threaded conversations, delegation/escalation, dual auth, audit trail)
Resume file: .ariadna_planning/phases/05-tasks-and-conversations/05-03-SUMMARY.md
