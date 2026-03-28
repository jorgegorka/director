# Project State

## Project Reference

See: .ariadna_planning/PROJECT.md (updated 2026-03-28)

**Core value:** Users can organize AI agents into a functioning company structure and confidently let them work autonomously -- knowing budgets are enforced, tasks are tracked, and humans retain control through governance.
**Current focus:** v1.4 Agent Execution -- Phase 22: AgentRun Data Model and Job Dispatch

## Current Position

Phase: 22 of 25 (AgentRun Data Model and Job Dispatch)
Plan: 0 of TBD in current phase
Status: Ready to plan
Last activity: 2026-03-28 -- v1.4 roadmap defined (4 phases, 26 requirements mapped)

Progress: [████████████████████░░░░░] 84% (21/25 phases complete)

## Performance Metrics

**Velocity:**
- Total plans completed: 41
- Average duration: ~7 minutes
- Total execution time: ~224 minutes

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

**Recent Trend:**
- Last 5 plans: 19-01 (~3 min), 19-02 (~3 min), 20-01 (~3 min), 21-01 (~4 min)
- Trend: consistent, stable. v1.0 COMPLETE. v1.1 COMPLETE. v1.2 COMPLETE. v1.3 COMPLETE.

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [v1.4-Roadmap]: 4 phases (22-25) derived from 26 requirements across 5 categories -- data model, HTTP adapter, Claude adapter, streaming UI + callbacks
- [v1.4-Roadmap]: Phase 22 (AgentRun + job dispatch) is foundation -- no streaming or execution can proceed without the persistent run record
- [v1.4-Roadmap]: Phase 23 (HTTP adapter) before Phase 24 (Claude) -- simpler adapter validates job dispatch chain without Claude-specific complexity adding noise
- [v1.4-Roadmap]: Phase 24 (Claude) before Phase 25 (streaming UI) -- live view is only meaningful when Claude is actually streaming; building UI against a stub wastes iteration cycles
- [v1.4-Roadmap]: tmux is the subprocess management layer for Claude Local adapter (HARD REQUIREMENT, deployment dependency) -- provides real TTY, session persistence, zombie-free lifecycle
- [v1.4-Roadmap]: Execution model: `tmux new-session -d -s "agent_run_42" "claude -p --bare ..."` then capture output via tmux capture-pane
- [v1.4-Roadmap]: No new gems for v1.4 -- Net::HTTP (stdlib), tmux (system dep), Turbo::StreamsChannel (already in Gemfile)
- [21-01]: action_config["target_agent_id"] returns string from SQLite JSON storage (not integer) -- assert with .to_i in tests

### Pending Todos

None.

### Blockers/Concerns

- [Phase 24 pre-check]: Verify tmux is available in the Kamal Docker image before coding ClaudeExecutionService
- [Phase 24 pre-check]: Confirm ANTHROPIC_API_KEY is available in the Kamal deployment environment (ENV or Rails credentials)
- [Phase 22 pre-check]: Verify Solid Cable uses a separate SQLite DB file (config/cable.yml) -- must not share primary DB before adding execution log writes

## Session Continuity

Last session: 2026-03-28
Stopped at: v1.4 roadmap created -- 4 phases (22-25), 26 requirements mapped, ready to plan Phase 22
Resume file: --
Next step: `/ariadna:plan-phase 22`
