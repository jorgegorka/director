# Requirements: Director

**Defined:** 2026-03-26
**Core Value:** Users can organize AI agents into a functioning company structure and confidently let them work autonomously -- knowing budgets are enforced, tasks are tracked, and humans retain control through governance.

## v1.0 Requirements (Complete)

All 38 requirements shipped in v1.0 (phases 1-10). See git history for details.

- [x] AUTH-01 through AUTH-04 -- Authentication (Phase 1)
- [x] ACCT-01 through ACCT-03 -- Accounts & Multi-tenancy (Phase 2)
- [x] ORG-01 through ORG-04 -- Org Chart & Roles (Phase 3)
- [x] AGNT-01 through AGNT-04 -- Agent Connection (Phase 4)
- [x] TASK-01 through TASK-04 -- Tasks & Conversations (Phase 5)
- [x] GOAL-01 through GOAL-03 -- Goals & Alignment (Phase 6)
- [x] BEAT-01 through BEAT-04 -- Heartbeats & Triggers (Phase 7)
- [x] BUDG-01 through BUDG-04 -- Budget & Cost Control (Phase 8)
- [x] GOVR-01 through GOVR-04 -- Governance & Audit (Phase 9)
- [x] DASH-01 through DASH-04 -- Dashboard & Real-time UI (Phase 10)

## v1.1 Requirements

Requirements for SQLite migration and cleanup. Each maps to roadmap phases.

### Database Migration

- [x] **DB-01**: Primary database uses SQLite instead of PostgreSQL -- *simplifies deployment, eliminates external DB dependency*
- [x] **DB-02**: All jsonb columns migrated to json type compatible with SQLite -- *8 columns across 5 tables*
- [x] **DB-03**: Gemfile removes pg gem and uses sqlite3 as sole database adapter -- *single DB engine*
- [x] **DB-04**: All environments (dev/test/prod) use SQLite in database.yml -- *consistent behavior across environments*
- [x] **DB-05**: Dockerfile and deploy config updated for SQLite-only stack -- *no PostgreSQL packages needed*

### Cleanup

- [x] **CLN-01**: CLAUDE.md and project docs updated to reflect SQLite stack -- *docs match reality*
- [x] **CLN-02**: Unused code, dead helpers, and leftover scaffolding removed -- *reduce maintenance surface*
- [x] **CLN-03**: All existing tests pass after migration -- *no regressions*

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Multi-Company

- **MCMP-01**: User can switch between companies from a single account
- **MCMP-02**: Company-level billing and usage reports

### Plugins & Extensions

- **PLUG-01**: Plugin system for extending agent capabilities
- **PLUG-02**: Knowledge base plugins for agent context
- **PLUG-03**: Custom tracing and observability plugins

### Company Templates

- **TMPL-01**: Pre-built company templates with roles, goals, and agent configs
- **TMPL-02**: Template marketplace ("Clipmart")
- **TMPL-03**: Export company as template

### Advanced Agent Features

- **ADVG-01**: Agent skills learning at runtime
- **ADVG-02**: Cross-company agent sharing
- **ADVG-03**: Agent performance scoring and analytics

## Out of Scope

| Feature | Reason |
|---------|--------|
| Mobile app | Web-first, responsive later |
| Hosting AI models | Agents are always external (BYOA) |
| Enterprise SSO/SAML | Standard email/password auth sufficient for v1 |
| Real-time video/voice with agents | Text-based interaction only |
| Tailwind CSS | User preference for modern CSS |
| UUIDs | User preference for integer IDs, no distributed ID needs |
| React/SPA frontend | Hotwire provides sufficient interactivity |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

### v1.0 (Complete)

All 38 requirements mapped to phases 1-10. Complete.

### v1.1

| Requirement | Phase | Status |
|-------------|-------|--------|
| DB-01 | 11 - SQLite Migration | Complete |
| DB-02 | 11 - SQLite Migration | Complete |
| DB-03 | 11 - SQLite Migration | Complete |
| DB-04 | 11 - SQLite Migration | Complete |
| DB-05 | 11 - SQLite Migration | Complete |
| CLN-01 | 12 - Cleanup & Verification | Complete |
| CLN-02 | 12 - Cleanup & Verification | Complete |
| CLN-03 | 12 - Cleanup & Verification | Complete |

**Coverage:**
- v1.1 requirements: 8 total
- Mapped to phases: 8/8 (100%)
- Unmapped: 0

---
*Requirements defined: 2026-03-26*
*Last updated: 2026-03-28 after v1.1 roadmap created (phases 11-12)*
