# Project State

## Project Reference

See: .ariadna_planning/PROJECT.md (updated 2026-03-29)

**Core value:** Users can organize AI agents into a functioning company structure and confidently let them work autonomously -- knowing budgets are enforced, tasks are tracked, and humans retain control through governance.
**Current focus:** v1.5 Role Templates -- builtin department structures users can apply to their companies.

## Current Position

Phase: 26 - Template Data and Registry
Plan: --
Status: Not started
Last activity: 2026-03-29 -- Roadmap created for v1.5

Progress: [░░░░░░░░░░░░░░░░░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**
- Total plans completed: 45
- Average duration: ~7 minutes
- Total execution time: ~257 minutes

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
| 18-hook-data-foundation | 1/1 | ~4 min | ~4 min |
| 19-hook-triggering-engine | 2/2 | ~6 min | ~3 min |
| 20-validation-feedback-loop | 1/1 | ~3 min | ~3 min |
| 21-hook-management-ui | 1/1 | ~4 min | ~4 min |
| 22-agentrun-data-model-and-job-dispatch | 1/1 | ~4 min | ~4 min |
| 23-http-adapter-real-execution | 1/1 | ~6 min | ~6 min |
| 24-claude-local-adapter-with-tmux | 1/1 | ~11 min | ~11 min |
| 25-live-streaming-ui-and-result-callbacks | 3/3 | ~22 min | ~7.3 min |

**Recent Trend:**
- Last 5 plans: 22-01 (~4 min), 23-01 (~6 min), 24-01 (~11 min), 25-01 (~18 min), 25-03 (~2 min)
- Trend: consistent, stable. v1.0 COMPLETE. v1.1 COMPLETE. v1.2 COMPLETE. v1.3 COMPLETE. v1.4 COMPLETE.

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [v1.5-Roadmap]: 3 phases (26-28) derived from 13 requirements across 4 categories -- template data, application service, UI, skill mappings
- [v1.5-Roadmap]: Phase 26 (Template Data + Registry) is foundation -- YAML files + registry class must exist before service or UI can function
- [v1.5-Roadmap]: Phase 27 (Application Service) before Phase 28 (UI) -- service logic tested in isolation before adding the HTTP layer
- [v1.5-Roadmap]: No new gems, no migrations, no new models -- YAML files + plain Ruby registry + service object + standard controller
- [v1.5-Roadmap]: SKILL-01 (default_skills.yml extensions) grouped with Phase 26 because skill mappings are data definitions, not service logic
- [v1.5-Roadmap]: Flat YAML with parent title references (matches db/seeds.rb pattern), not nested children
- [v1.5-Roadmap]: No transaction wrapper for template application -- partial success preferred over all-or-nothing (matches additive skip-duplicate philosophy)
- [v1.5-Research]: Critical pitfalls: parent ordering in YAML (validate at load time), cross-tenant skill lookup (always scope through company.skills), case-sensitive title matching (COLLATE NOCASE)

### Pending Todos

None.

### Blockers/Concerns

- Verify tmux is available in the Kamal Docker image (deployment dependency for ClaudeLocalAdapter)
- Confirm ANTHROPIC_API_KEY is available in the Kamal deployment environment

## Session Continuity

Last session: 2026-03-29
Stopped at: v1.5 roadmap created. Ready for phase 26 planning.
Resume file: --
Next step: `/ariadna:plan-phase 26`
