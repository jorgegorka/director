# Project State

## Project Reference

See: .ariadna_planning/PROJECT.md (updated 2026-03-26)

**Core value:** Users can organize AI agents into a functioning company structure and confidently let them work autonomously -- knowing budgets are enforced, tasks are tracked, and humans retain control through governance.
**Current focus:** Phase 2 complete — ready for Phase 3

## Current Position

Phase: 2 of 10 (Accounts and Multi-Tenancy) — COMPLETE
Plan: 2 of 2 in current phase (all complete)
Status: Phase verified and complete
Last activity: 2026-03-26 -- Phase 2 verified (10/10 truths, all 4 success criteria met).

Progress: [██░░░░░░░░] ~20%

## Performance Metrics

**Velocity:**
- Total plans completed: 4
- Average duration: ~6 minutes
- Total execution time: ~17 minutes

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-authentication | 2 | ~10 min | ~5 min |
| 02-accounts-and-multi-tenancy | 2 | ~23 min | ~11 min |

**Recent Trend:**
- Last 5 plans: 01-01 (~5 min), 01-02 (~5 min), 02-01 (~7 min), 02-02 (~16 min)
- Trend: consistent

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

### Pending Todos

None.

### Blockers/Concerns

None.

## Session Continuity

Last session: 2026-03-26
Stopped at: Phase 2 complete, verified
Resume file: .ariadna_planning/phases/02-accounts-and-multi-tenancy/02-VERIFICATION.md
