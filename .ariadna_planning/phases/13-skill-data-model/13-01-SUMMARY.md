---
phase: 13-skill-data-model
plan: 01
status: complete
completed_at: 2026-03-28T10:35:24Z
duration: ~3 minutes
tasks_completed: 3
files_changed: 9
commits: 3
---

# Plan 13-01 Summary: Skill Data Model

## Objective

Created the skills and agent_skills tables, models, validations, and test fixtures — establishing the data foundation for the v1.2 Agent Skills milestone.

## Tasks Completed

### Task 1: Migration (commit 03c7ff9)
Created `CreateSkillsAndAgentSkills` migration with:
- `skills` table: company_id FK, key (not null), name (not null), markdown (not null), description, category, builtin (default: true)
- Unique index on `[company_id, key]` for per-company key uniqueness
- Composite index on `[company_id, category]` for efficient filtering
- `agent_skills` join table: agent_id FK, skill_id FK
- Unique index on `[agent_id, skill_id]` to prevent duplicate assignments

### Task 2: Models and Fixtures (commit 5a510da)
- `Skill` model with `Tenantable`, validates key/name/markdown presence, key uniqueness scoped to company_id, and `by_category`/`builtin`/`custom` scopes
- `AgentSkill` join model with uniqueness per agent and `same_company` validation rejecting cross-tenant links
- 7 skill fixtures across acme (6) and widgets (1) companies covering 5 categories, including 1 custom (non-builtin) skill
- 3 agent_skill fixtures linking claude_agent and http_agent to acme skills

### Task 3: Model Tests (commit 83ed9e8)
- 14 `SkillTest` tests: presence validations, cross-company key uniqueness (same key allowed across different companies), builtin default, Tenantable company association, agent associations via has_many through, and all 4 scopes
- 7 `AgentSkillTest` tests: same-company validation, duplicate skill prevention per agent, cross-company rejection with specific error message, widget-agent/acme-skill rejection, and association accessors

## Deviations

**Rule 3 auto-fix:** When the full test suite was run after Task 2, 14 existing tests failed with `FOREIGN KEY constraint failed`. The root cause: `Agent` lacked `has_many :agent_skills, dependent: :destroy` and `Company` lacked `has_many :skills, dependent: :destroy`. Without these, SQLite FK constraints blocked destroy operations tested across the codebase. Both associations were added as part of Task 3, restoring full test suite passage.

## Artifacts

| File | Purpose |
|------|---------|
| `db/migrate/20260328103248_create_skills_and_agent_skills.rb` | Tables and indexes |
| `app/models/skill.rb` | Skill model with Tenantable, validations, scopes |
| `app/models/agent_skill.rb` | AgentSkill join model with cross-company validation |
| `app/models/agent.rb` | Added has_many :agent_skills and :skills (through) |
| `app/models/company.rb` | Added has_many :skills dependent: destroy |
| `test/fixtures/skills.yml` | 7 skill fixtures (acme + widgets) |
| `test/fixtures/agent_skills.yml` | 3 agent_skill fixtures |
| `test/models/skill_test.rb` | 14 Skill model tests |
| `test/models/agent_skill_test.rb` | 7 AgentSkill model tests |

## Key Design Decisions

- `Tenantable` included on Skill for `belongs_to :company` and `for_current_company` scope — consistent with all other company-scoped models
- Key uniqueness scoped to `company_id` at both DB level (unique index) and model level (validates uniqueness scope) — two companies can have `strategic_planning`, one cannot have it twice
- `same_company` validation on AgentSkill uses direct `company_id` comparison (not association load) — fast and prevents cross-tenant data leaks
- `builtin` defaults to `true` at DB level and model default — new skills are builtin unless explicitly marked custom

## Test Results

```
21 runs, 44 assertions, 0 failures, 0 errors, 0 skips  (skill + agent_skill tests)
689 runs, 1688 assertions, 0 failures, 0 errors, 0 skips  (full suite)
```

## Self-Check: PASSED

All 7 artifact files found. All 3 commits verified (03c7ff9, 5a510da, 83ed9e8).
