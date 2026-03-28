---
phase: 13-skill-data-model
verified: 2026-03-28T11:45:00Z
status: passed
score: "12/12 truths verified | security: 0 critical, 0 high | performance: 0 high"
---

# Phase 13 Verification: Skill Data Model

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Skill records can be created for a company with key, name, description, markdown, category, and builtin flag | PASS | `skills` table in schema.rb has all columns; `test "valid with key, name, markdown, and company"` passes |
| 2 | Key uniqueness is enforced per company — cross-company duplicates allowed, same-company duplicates rejected | PASS | Unique index `index_skills_on_company_id_and_key` in schema; `validates :key, uniqueness: { scope: :company_id }`; tests pass for both cases |
| 3 | AgentSkill join records link agents to skills, with uniqueness enforced per agent | PASS | `validates :skill_id, uniqueness: { scope: :agent_id }`; unique index `index_agent_skills_on_agent_id_and_skill_id`; `test "invalid with duplicate skill on same agent"` passes |
| 4 | AgentSkill validates that agent and skill belong to the same company — cross-tenant links are rejected | PASS | `same_company` validation uses `agent.company_id == skill.company_id`; `test "invalid when agent and skill from different companies"` and `test "invalid when widget agent assigned acme skill"` both pass |
| 5 | Skill.by_category, Skill.builtin, and Skill.custom scopes work correctly | PASS | All three scope tests pass; scopes defined correctly in `skill.rb` |
| 6 | Agent has_many :agent_skills and has_many :skills through :agent_skills | PASS | `agent.rb` lines 7-8; `test "has many skills through agent_skills"` confirms 2 Skill records returned for claude_agent |
| 7 | The agent_capabilities table no longer exists in the database | PASS | Not present in `schema.rb` (version `2026_03_28_103718`); `DropAgentCapabilities` migration applied |
| 8 | AgentCapability model file no longer exists | PASS | `ls app/models/agent_capability.rb` → No such file |
| 9 | AgentCapabilitiesController file no longer exists | PASS | `ls app/controllers/agent_capabilities_controller.rb` → No such file |
| 10 | Capability routes are removed from config/routes.rb | PASS | `grep agent_capabilit config/routes.rb` → 0 matches; agents resource block has no nested capabilities |
| 11 | Agent show page and agent card partial no longer reference capabilities | PASS | show.html.erb has Skills section with skill-badge components; _agent.html.erb uses `agent-card__skills`; zero ERB capability references |
| 12 | Company has_many :skills association exists for tenant-scoped skill queries | PASS | `company.rb` line 7: `has_many :skills, dependent: :destroy` |

## Artifact Status

| Artifact | Exists | Substantive | Notes |
|----------|--------|-------------|-------|
| `db/migrate/20260328103248_create_skills_and_agent_skills.rb` | YES | YES | Both tables with FK, indexes, unique constraints |
| `db/migrate/20260328103718_drop_agent_capabilities.rb` | YES | YES | Reversible drop migration |
| `app/models/skill.rb` | YES | YES | Tenantable, 3 validations, 3 scopes, 2 associations |
| `app/models/agent_skill.rb` | YES | YES | 2 belongs_to, uniqueness validation, same_company cross-tenant guard |
| `app/models/agent.rb` | YES | YES | has_many :agent_skills + :skills; agent_capabilities removed |
| `app/models/company.rb` | YES | YES | has_many :skills, dependent: :destroy added |
| `test/models/skill_test.rb` | YES | YES | 14 tests: validations, associations, all 4 scopes |
| `test/models/agent_skill_test.rb` | YES | YES | 7 tests: uniqueness, cross-company, association accessors |
| `test/fixtures/skills.yml` | YES | YES | 7 fixtures — 6 acme (5 categories, 1 custom), 1 widgets |
| `test/fixtures/agent_skills.yml` | YES | YES | 3 fixtures linking claude_agent and http_agent |

## Key Links Verified

| Link | Status | Evidence |
|------|--------|---------|
| `Skill` → `AgentSkill` via `has_many :agent_skills, dependent: :destroy` | PASS | skill.rb line 4 |
| `Skill` → `Tenantable` via `include Tenantable` | PASS | skill.rb line 2; Tenantable provides `belongs_to :company` + `for_current_company` scope |
| `AgentSkill` → `Agent` via `belongs_to :agent` | PASS | agent_skill.rb line 2 |
| `AgentSkill` → `Skill` via `belongs_to :skill` | PASS | agent_skill.rb line 3 |
| `Agent` → `AgentSkill` via `has_many :agent_skills, dependent: :destroy` | PASS | agent.rb line 7 |
| `Agent` → `Skill` via `has_many :skills, through: :agent_skills` | PASS | agent.rb line 8 |
| `Company` → `Skill` via `has_many :skills, dependent: :destroy` | PASS | company.rb line 7 |

## Cross-Phase Integration

**Upstream consumers of new associations:**
- `AgentsController#index` uses `includes(:skills, :roles)` — N+1 safe for index list
- `AgentsController#set_agent` uses `includes(:skills, :roles, :approval_gates)` — N+1 safe for show/edit
- `agents/show.html.erb` Skills section reads `@agent.skills.size`, `.skills.order(:name).each`, `.skills.empty?`
- `agents/_agent.html.erb` reads `agent.skills.any?` and `agent.skills.size` (safe: association preloaded via index includes)

**Zero orphaned references:** `grep -r "agent_capabilit" app/ test/ config/routes.rb` returns 0 matches. Only the two expected migration files retain the string.

**Test suite:** 675 runs, 1653 assertions, 0 failures, 0 errors, 0 skips (full suite post-phase).

## Security Findings

Brakeman scan: **0 warnings**. No SQL injection, XSS bypass, CSRF skip, or unscoped find patterns in changed files. The `same_company` validation compares integer `company_id` values directly — no string interpolation.

## Performance Findings

**Low-severity observation (not blocking):** In `agents/show.html.erb`, `@agent.skills.order(:name)` (line 176) chains `.order()` onto an `includes`-preloaded has_many-through association. ActiveRecord will fire a fresh SQL query for this rather than sorting in-memory. The impact is one extra query per show page. Not an N+1 (it fires once per page load), and skills collections are expected to be small. Consider sorting in the controller or using `agent.skills.sort_by(&:name)` for in-memory sort if desired, but this does not block passage.

## Rubocop

All 7 modified Ruby files: **0 offenses detected**.

## Conclusion

Phase 13 fully achieves its goal. Both plans executed correctly:

- Plan 01 created the skills and agent_skills tables with proper schema, the Skill and AgentSkill models with all required validations and scopes, comprehensive fixtures, and 21 passing model tests.
- Plan 02 dropped agent_capabilities, removed all capability-related files (model, controller, tests, fixtures), removed capability routes, updated views to display skills, and updated the agent model and controller — with zero remaining capability references outside the preserved original migration.

The data model transition from capabilities to skills is complete and the full test suite passes.
