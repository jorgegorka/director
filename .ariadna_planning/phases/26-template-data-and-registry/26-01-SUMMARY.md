---
phase: 26-template-data-and-registry
plan: 01
subsystem: database
tags: [yaml, seeds, role-templates, skills, data]

# Dependency graph
requires:
  - phase: 14-skill-catalog-seeding
    provides: db/seeds/skills/*.yml with 48 skill definitions by key
  - phase: 15-role-auto-assignment
    provides: config/default_skills.yml and Role.default_skill_keys_for lookup
provides:
  - Five department YAML template files in db/seeds/role_templates/
  - 18 new role-title-to-skill mappings in config/default_skills.yml (total: 29)
affects:
  - 26-02 (RoleTemplateRegistry reads these YAML files)
  - 27-xx (ApplicationService uses registry to apply templates)
  - 28-xx (UI displays template names and role counts from these files)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - YAML role template format with key/name/description/roles array
    - Parent reference by title string (null for root), dependency order enforced
    - skill_keys array referencing db/seeds/skills/*.yml keys by identifier

key-files:
  created:
    - db/seeds/role_templates/engineering.yml
    - db/seeds/role_templates/marketing.yml
    - db/seeds/role_templates/operations.yml
    - db/seeds/role_templates/finance.yml
    - db/seeds/role_templates/hr.yml
  modified:
    - config/default_skills.yml

key-decisions:
  - "Roles listed in parent-before-child dependency order (validated by registry in plan 02)"
  - "Parent references use title strings, not keys or indices -- matches db/seeds.rb flat role_defs pattern"
  - "Keys in default_skills.yml use spaces not underscores (matching Role.default_skill_keys_for lookup)"

patterns-established:
  - "Template YAML format: key, name, description, roles[] with title/description/job_spec/parent/skill_keys"
  - "Dependency order: all parents listed before their children in every template"

requirements_covered:
  - id: "TMPL-01"
    description: "5 department templates (Engineering, Marketing, Operations, Finance, HR)"
    evidence: "db/seeds/role_templates/{engineering,marketing,operations,finance,hr}.yml"
  - id: "TMPL-03"
    description: "4-7 roles per template with parent refs and skill assignments"
    evidence: "23 roles total: 5+5+5+4+4 across five templates, each with 3-5 skill_keys"
  - id: "SKILL-01"
    description: "default_skills.yml extended with template role title mappings"
    evidence: "config/default_skills.yml, 29 total entries (18 new)"

# Metrics
duration: 2min
completed: 2026-03-29
---

# Phase 26-01: Template Data Summary

**Five YAML department templates (23 roles total) and 18 new role-to-skill mappings enabling auto-assignment when templates are applied**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-03-29T14:49:19Z
- **Completed:** 2026-03-29T14:51:29Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Created db/seeds/role_templates/ directory with 5 department YAML files covering Engineering, Marketing, Operations, Finance, and HR
- 23 total roles across templates, each with multi-paragraph job_spec, parent reference, and 3-5 skill_keys
- Extended config/default_skills.yml from 11 to 29 entries, covering all 18 new template role titles
- All skill_keys verified against the 48 existing db/seeds/skills/*.yml definitions
- All templates validated: dependency order correct (parents before children), YAML parses cleanly

## Requirements Covered
| REQ-ID | Requirement | Evidence |
|--------|-------------|----------|
| TMPL-01 | 5 department templates | db/seeds/role_templates/{engineering,marketing,operations,finance,hr}.yml |
| TMPL-03 | 4-7 roles per template with parent refs and skill assignments | 23 roles total: 5+5+5+4+4, each with 3-5 skill_keys |
| SKILL-01 | default_skills.yml extended for template role titles | config/default_skills.yml, 29 entries (18 new) |

## Task Commits

Each task was committed atomically:

1. **Task 1: Create five department YAML template files** - `66dbc0d` (feat)
2. **Task 2: Extend default_skills.yml with mappings for all new template role titles** - `9ed552f` (feat)

## Files Created/Modified
- `db/seeds/role_templates/engineering.yml` - 5 roles: CTO, VP Engineering, Tech Lead, Engineer, QA
- `db/seeds/role_templates/marketing.yml` - 5 roles: CMO, Content Manager, SEO Specialist, Social Media Manager, Marketing Analyst
- `db/seeds/role_templates/operations.yml` - 5 roles: COO, Operations Manager, Project Manager, Business Analyst, Executive Assistant
- `db/seeds/role_templates/finance.yml` - 4 roles: CFO, Controller, Compliance Officer, Financial Analyst
- `db/seeds/role_templates/hr.yml` - 4 roles: HR Director, Recruiter, Training Specialist, Compensation Analyst
- `config/default_skills.yml` - Extended with 18 new entries grouped by department (total: 29)

## Decisions Made
None - plan executed exactly as written. All content, structure, and skill_key values were specified in the plan.

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All 5 template YAML files exist with correct structure and valid skill_keys
- config/default_skills.yml has mappings for all template role titles
- Plan 26-02 (RoleTemplateRegistry) can now load and validate these files
- The registry will verify dependency order at load time -- this data already satisfies that constraint

---
*Phase: 26-template-data-and-registry*
*Completed: 2026-03-29*

## Self-Check: PASSED

All created files verified present. All task commits verified in git history.
