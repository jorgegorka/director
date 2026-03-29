# Technology Stack: v1.5 Role Templates

**Project:** Director -- Role Templates milestone
**Researched:** 2026-03-29
**Confidence:** HIGH (entire codebase read; all patterns verified in existing code)

---

## Executive Decision

**No new gems. No new migrations. No new system dependencies.**

Role templates are a pure-Rails feature built entirely on YAML loading (stdlib), existing ActiveRecord models (Role, Skill, RoleSkill), and the service object pattern already established in the codebase. The pattern is a direct extension of the v1.2 skill seeding approach.

---

## Recommended Stack

### Core (No Changes)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Ruby | 3.3+ | Runtime | Already in use |
| Rails | 8.1 | Framework | Already in use |
| SQLite | 3.x | Database | Already in use |
| YAML (stdlib) | -- | Template definitions | Already used for skill YAML files and default_skills.yml |

### New Components (Zero Gems)

| Component | Type | Purpose | Precedent |
|-----------|------|---------|-----------|
| `RoleTemplateRegistry` | Plain Ruby class | Load, cache, expose YAML template data | `AdapterRegistry` pattern; `Company.default_skill_definitions` caching |
| `ApplyRoleTemplateService` | Service object | Create role hierarchy + assign skills for a company | `WakeRoleService`, `GoalEvaluationService` (self.call pattern) |
| 5 YAML files in `db/seeds/role_templates/` | Data files | Template definitions | `db/seeds/skills/*.yml` (48 files, same convention) |
| `RoleTemplatesController` | Rails controller | Browse, preview, apply actions | Standard RESTful controller (same as SkillsController) |
| Views in `app/views/role_templates/` | ERB templates | UI for browsing and previewing templates | Existing role/skill views |

### Existing Infrastructure Reused

| Infrastructure | How Templates Use It |
|----------------|---------------------|
| Role model (TreeHierarchy, Tenantable, ConfigVersioned) | Created roles get full concern behavior automatically |
| Skill model (Tenantable) | Skills looked up by key for assignment |
| RoleSkill join table | Skill assignments created via existing association |
| `config/default_skills.yml` | Template role titles trigger auto-assignment on agent config |
| Turbo Drive | Standard page navigation for browse/preview/apply flow |
| Flash messages | Feedback after apply (created X, skipped Y) |
| CSS icon system (mask-based) | Template card icons on browse page |

---

## Why No New Model / Migration

The natural question is whether templates need a `role_templates` database table. They do not:

1. **Templates are static** -- shipped with the app, not user-editable. A database table for 5 read-only records is wasted infrastructure.
2. **No runtime state** -- templates have no mutable attributes, no associations, no timestamps that change. YAML captures them completely.
3. **Precedent** -- skills use YAML files as source of truth with no SkillTemplate model. Same pattern works here.
4. **Future-proof** -- if v2 adds user-created templates ("Clipmart"), adding a model then is straightforward. Starting with YAML keeps v1.5 focused.

---

## YAML Structure Decision

### Chosen: Flat Roles with Parent Title References

```yaml
key: engineering
name: Engineering Department
description: Full engineering department with CTO leading development, QA, and DevOps.
icon: code
roles:
  - title: CTO
    description: Chief Technology Officer.
    job_spec: |
      Lead technical vision and architecture decisions.
    parent: ~
    skills: [code_review, architecture_planning, technical_strategy]

  - title: Backend Lead
    description: Leads backend engineering team.
    job_spec: |
      Architect server-side systems and APIs.
    parent: CTO
    skills: [code_review, architecture_planning, implementation]
```

### Why Flat with `parent` References (Not Nested `children`)

After examining the codebase patterns:

1. **Matches `db/seeds.rb`** -- the seed file uses a flat structure with parent references, not nested children. The template format should match.
2. **Simpler service logic** -- flat array processed in order, parent looked up by title from already-created roles. No recursive tree walking needed.
3. **Easier to read** -- YAML indentation depth stays constant. Nested structures with 3-4 levels become hard to scan.
4. **Easier to validate** -- each role definition has the same shape. No variable nesting depth to handle.

### Why `parent: ~` (null) for template roots

`parent: ~` means "top of this template's hierarchy." At apply time, the service maps this to the user-selected parent role (e.g., CEO) or nil (creates a root role). This keeps the YAML format clean -- no special "attach_to" field on the template, just a parameter on the apply action.

### Why skill references use keys

```yaml
skills: [code_review, implementation, debugging]
```

Not names, not IDs. Keys are:
- Stable identifiers (survive skill renames)
- Unique per company (indexed on `[company_id, key]`)
- Consistent with `config/default_skills.yml` format
- Consistent with `db/seeds/skills/*.yml` `key` field

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Template storage | YAML files in repo | Database `RoleTemplate` model | Static data, no mutation needed; adds migration for no benefit |
| Template loading | Plain Ruby class (`RoleTemplateRegistry`) | ActiveHash gem | New gem for a 30-line class is unjustified |
| YAML structure | Flat array with `parent` references | Nested `children` arrays | Flat matches seeds.rb pattern; simpler service; easier to read |
| Skip-duplicate key | Role `title` (existing uniqueness constraint) | New `template_origin_key` column on roles | Title uniqueness already exists; new column adds migration |
| Result object | `Data.define(:created, :skipped, :errors)` | OpenStruct / plain Hash | Data.define is immutable, typed, Ruby-native |
| Hierarchy creation | Sequential `find_or_create_by!` | `insert_all` bulk insert | Bulk insert skips validations, callbacks, TreeHierarchy checks |
| Skill assignment | Per-role `where(key:)` + `create!` | Bulk `RoleSkill.insert_all` | Need role IDs first; scale is tiny; callbacks matter |
| Transaction strategy | No transaction (partial success OK) | Full transaction (all or nothing) | If role 5 of 8 fails, user should keep roles 1-4; additive is better |

---

## Installation

```bash
# Nothing to install. All dependencies already present.

# Create template directory (matches existing db/seeds/skills/ convention)
mkdir -p db/seeds/role_templates

# Template files are hand-authored YAML -- no generator, no migration
```

---

## Sources

- Existing skill YAML pattern: `db/seeds/skills/*.yml`, `app/models/company.rb` lines 20-34 -- HIGH confidence (read directly)
- Role model with TreeHierarchy: `app/models/role.rb`, `app/models/concerns/tree_hierarchy.rb` -- HIGH confidence (read directly)
- Service object pattern: `app/services/wake_role_service.rb` -- HIGH confidence (read directly)
- Registry class pattern: `AdapterRegistry` usage in `app/models/role.rb` line 56 -- HIGH confidence (read directly)
- Default skills mapping: `config/default_skills.yml` -- HIGH confidence (read directly)
- Seed hierarchy creation: `db/seeds.rb` -- HIGH confidence (read directly)
- RoleSkill uniqueness: `app/models/role_skill.rb` -- HIGH confidence (read directly)
