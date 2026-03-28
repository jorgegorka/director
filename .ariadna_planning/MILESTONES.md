# Milestones: Director

## Completed

### v1.0 -- Core Platform
**Completed:** 2026-03-28
**Phases:** 1-10 (all complete)
**Summary:** Full orchestration platform -- authentication, multi-tenancy, org chart, agent connection (HTTP + bash), tasks with conversations, goals with progress roll-up, heartbeats & triggers, budget enforcement, governance & audit, dashboard with real-time Turbo Streams.
**Stats:** 38 requirements, 22 plans, 674 tests, ~161 minutes total execution

## Active

### v1.2 -- Agent Skills
**Started:** 2026-03-28
**Phases:** 13-17 (5 phases, 0/22 requirements complete)
**Goal:** Add a company-level skill library with rich markdown instruction packages, role-based auto-assignment, and full CRUD -- replacing agent_capabilities.
**Status:** Roadmap created, ready to plan Phase 13

| Phase | Name | Requirements | Status |
|-------|------|-------------|--------|
| 13 | Skill Data Model | DATA-01..06 | Not started |
| 14 | Skill Catalog & Seeding | SEED-01..04 | Not started |
| 15 | Role Auto-Assignment | AUTO-01..03 | Not started |
| 16 | Skills CRUD | CRUD-01..04, ROUT-01 | Not started |
| 17 | Agent Skill Management | ASKL-01..03, ROUT-02 | Not started |

## Archive

### v1.1 -- SQLite Migration & Cleanup
**Completed:** 2026-03-28
**Phases:** 11-12 (2 phases, 3 plans)
**Summary:** Migrated primary database from PostgreSQL to SQLite (8 jsonb->json columns, zero external DB dependencies), cleaned all project docs, removed dead scaffolding, verified CI green (668 tests).
**Stats:** 8 requirements, 3 plans, 668 tests, ~28 minutes total execution
**Archive:** [v1.1-ROADMAP.md](milestones/v1.1-ROADMAP.md) | [v1.1-REQUIREMENTS.md](milestones/v1.1-REQUIREMENTS.md)
