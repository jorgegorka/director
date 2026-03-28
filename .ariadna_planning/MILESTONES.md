# Milestones: Director

## Active

None — planning next milestone.

## Completed

### v1.3 -- Agent Hooks
**Completed:** 2026-03-28
**Phases:** 18-21 (4 phases, 5 plans, 15 tasks)
**Summary:** Configurable agent hook system that fires at task lifecycle events (after_task_start, after_task_complete). Hooks can trigger other agents for validation or call webhooks for external integration. Validation feedback loop closes the cycle: Agent A completes → Agent B validates → results posted back → Agent A iterates. Full CRUD management UI.
**Stats:** 15 requirements, 5 plans, 878 tests, ~14 minutes total execution
**Archive:** [v1.3-ROADMAP.md](milestones/v1.3-ROADMAP.md) | [v1.3-REQUIREMENTS.md](milestones/v1.3-REQUIREMENTS.md)

### v1.0 -- Core Platform
**Completed:** 2026-03-28
**Phases:** 1-10 (all complete)
**Summary:** Full orchestration platform -- authentication, multi-tenancy, org chart, agent connection (HTTP + bash), tasks with conversations, goals with progress roll-up, heartbeats & triggers, budget enforcement, governance & audit, dashboard with real-time Turbo Streams.
**Stats:** 38 requirements, 22 plans, 674 tests, ~161 minutes total execution

### v1.2 -- Agent Skills
**Completed:** 2026-03-28
**Phases:** 13-17 (5 phases, 9 plans)
**Summary:** Company-level skill library with 50 builtin skill YAML packages, role-based auto-assignment on first agent assignment, full Skills CRUD with category filtering and builtin protection, per-agent skill management UI with checkboxes replacing agent_capabilities throughout.
**Stats:** 22 requirements, 9 plans, 742 tests, ~40 minutes total execution
**Archive:** [v1.2-ROADMAP.md](milestones/v1.2-ROADMAP.md) | [v1.2-REQUIREMENTS.md](milestones/v1.2-REQUIREMENTS.md)

## Archive

### v1.1 -- SQLite Migration & Cleanup
**Completed:** 2026-03-28
**Phases:** 11-12 (2 phases, 3 plans)
**Summary:** Migrated primary database from PostgreSQL to SQLite (8 jsonb->json columns, zero external DB dependencies), cleaned all project docs, removed dead scaffolding, verified CI green (668 tests).
**Stats:** 8 requirements, 3 plans, 668 tests, ~28 minutes total execution
**Archive:** [v1.1-ROADMAP.md](milestones/v1.1-ROADMAP.md) | [v1.1-REQUIREMENTS.md](milestones/v1.1-REQUIREMENTS.md)
