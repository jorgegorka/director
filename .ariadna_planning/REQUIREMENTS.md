# Requirements: Director

**Defined:** 2026-03-28
**Core Value:** Users can organize AI agents into a functioning company structure and confidently let them work autonomously — knowing budgets are enforced, tasks are tracked, and humans retain control through governance.

## v1.2 Requirements

Requirements for Agent Skills milestone. Each maps to roadmap phases.

### Data Model

- [ ] **DATA-01**: Skills table created with key, name, description, markdown, category, builtin columns — *foundation for skill library*
- [ ] **DATA-02**: AgentSkills join table created linking agents to skills — *replaces agent_capabilities*
- [ ] **DATA-03**: AgentCapabilities table dropped and model removed — *cleans up replaced feature*
- [ ] **DATA-04**: Skill model validates key uniqueness per company, presence of key/name/markdown — *ensures data integrity*
- [ ] **DATA-05**: AgentSkill model validates uniqueness per agent and same-company constraint — *prevents cross-tenant leaks*
- [ ] **DATA-06**: Agent model updated with has_many skills through agent_skills — *replaces capability associations*

### Seeding

- [ ] **SEED-01**: 44 skill YAML files created in db/seeds/skills/ with meaningful markdown content — *provides builtin skill catalog*
- [ ] **SEED-02**: Default skills mapping stored in config/default_skills.yml (11 roles) — *defines role-skill relationships*
- [ ] **SEED-03**: Company after_create seeds all builtin skills from YAML files — *new companies get full catalog*
- [ ] **SEED-04**: Rake task skills:reseed available for existing companies — *backfills skills for pre-existing tenants*

### Auto-Assignment

- [ ] **AUTO-01**: Role after_save assigns default skills on first agent assignment (nil→agent) — *agents get role-appropriate skills automatically*
- [ ] **AUTO-02**: Reassignment (agent→different agent) does not trigger auto-assignment — *skills are permanent, removal is explicit*
- [ ] **AUTO-03**: Unknown role titles and missing skill keys are silently skipped — *graceful degradation*

### Skills CRUD

- [ ] **CRUD-01**: SkillsController with full CRUD (index, show, new, create, edit, update, destroy) — *company manages skill library*
- [ ] **CRUD-02**: Skills index filterable by category — *navigable skill catalog*
- [ ] **CRUD-03**: Builtin skills can be edited but not destroyed — *companies customize but can't break defaults*
- [ ] **CRUD-04**: Custom skills (builtin: false) can be created and destroyed — *extensible skill library*

### Agent Skill Management

- [ ] **ASKL-01**: AgentSkillsController create/destroy to assign/remove skills — *manage per-agent skills*
- [ ] **ASKL-02**: Agent show page displays assigned skills instead of capabilities — *replaces old UI*
- [ ] **ASKL-03**: Agent partial updated to show skills — *consistent skill display*

### Routes

- [ ] **ROUT-01**: Skill routes added, capability routes removed — *clean URL structure*
- [ ] **ROUT-02**: Nested agent skill routes (create/destroy) — *RESTful skill assignment*

## Future Requirements

### Skill Analytics
- **ANAL-01**: Track which skills are most assigned across agents
- **ANAL-02**: Skill usage metrics in dashboard

### Skill Sharing
- **SHAR-01**: Export/import custom skills between companies
- **SHAR-02**: Public skill marketplace

## Out of Scope

| Feature | Reason |
|---------|--------|
| Skill versioning/history | Adds complexity — companies can edit skills directly for now |
| Skill dependencies (skill A requires skill B) | Over-engineering for v1.2 — skills are independent |
| AI-generated skill content | Focus on curated content first |
| Skill templates marketplace ("Clipmart") | Deferred to v2 per PROJECT.md |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DATA-01 | — | Pending |
| DATA-02 | — | Pending |
| DATA-03 | — | Pending |
| DATA-04 | — | Pending |
| DATA-05 | — | Pending |
| DATA-06 | — | Pending |
| SEED-01 | — | Pending |
| SEED-02 | — | Pending |
| SEED-03 | — | Pending |
| SEED-04 | — | Pending |
| AUTO-01 | — | Pending |
| AUTO-02 | — | Pending |
| AUTO-03 | — | Pending |
| CRUD-01 | — | Pending |
| CRUD-02 | — | Pending |
| CRUD-03 | — | Pending |
| CRUD-04 | — | Pending |
| ASKL-01 | — | Pending |
| ASKL-02 | — | Pending |
| ASKL-03 | — | Pending |
| ROUT-01 | — | Pending |
| ROUT-02 | — | Pending |

**Coverage:**
- v1.2 requirements: 22 total
- Mapped to phases: 0
- Unmapped: 22 ⚠️

---
*Requirements defined: 2026-03-28*
*Last updated: 2026-03-28 after initial definition*
