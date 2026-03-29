# Architecture Patterns: v1.5 Role Templates

**Domain:** Builtin role template system — YAML-defined department hierarchies applied to companies
**Researched:** 2026-03-29
**Confidence:** HIGH (entire existing codebase read; skill seeding pattern verified as working precedent)

---

## Current Architecture (What Exists)

### Skill Seeding Pattern (The Precedent)

The v1.2 skill system established the exact pattern role templates should follow:

```
db/seeds/skills/*.yml          → 48 individual YAML files, one per skill
config/default_skills.yml      → role-title-to-skill-key mapping
Company#seed_default_skills!   → instance method, called after_create + rake task
Company.default_skill_definitions → class method, loads + caches YAML at boot
skills.rake                    → rake skills:reseed (for existing companies)
```

**Key characteristics of the skill pattern:**
- YAML files are the source of truth (not a database table)
- Each company gets its own copies of builtin skills (company-scoped via Tenantable)
- `find_or_create_by!(key:)` provides idempotent seeding (skip-duplicate)
- No separate "SkillTemplate" model exists — YAML files ARE the templates
- Class-level caching (`@default_skill_definitions ||=`) avoids re-reading YAML on every call

### Role Model (The Target)

Roles already have everything templates need to populate:

| Attribute | Source | Template Populates? |
|-----------|--------|---------------------|
| `title` | User input | YES — template defines it |
| `description` | User input | YES — template defines it |
| `job_spec` | User input | YES — template defines it |
| `parent_id` | User selects | YES — template defines hierarchy |
| `company_id` | Current.company | Automatic (Tenantable) |
| `adapter_type` | Agent config | NO — agent assignment is separate |
| `adapter_config` | Agent config | NO |
| `budget_cents` | User input | NO — budget is operational, not structural |
| `status` | System | NO — defaults to :idle |

### Existing Role Uniqueness

Role titles are unique per company: `validates :title, uniqueness: { scope: :company_id }`. This is the natural skip-duplicate key, exactly analogous to `Skill#key` uniqueness.

### Default Skills Auto-Assignment

`config/default_skills.yml` maps role titles (case-insensitive) to skill keys. When a role gets its first agent assignment, `Role#assign_default_skills` uses this mapping. Role templates can leverage this existing mapping — if a template role is titled "CTO", it already gets CTO skills on agent assignment.

---

## Recommended Architecture

### Design Decision: YAML-Only Templates (No New Model)

**Use YAML files as templates. Do NOT create a RoleTemplate model.**

Rationale:
1. **Precedent:** Skills use YAML-only with no SkillTemplate model. Same pattern = less cognitive load.
2. **Builtin-only scope:** v1.5 is explicitly builtin templates only. Custom templates are out of scope (deferred to v2 "Clipmart"). A database model for 3-5 static definitions is over-engineering.
3. **No runtime state:** Templates have no mutable state — they are read-only definitions applied to create roles. A model adds migration, associations, tests, and maintenance burden for a glorified config file.
4. **Easy to add later:** If v2 needs user-created templates, adding a `RoleTemplate` model then (with migration from YAML) is straightforward. Starting with YAML keeps v1.5 focused.

### Overview

```
db/seeds/role_templates/engineering.yml     → Template definitions (YAML)
db/seeds/role_templates/marketing.yml
db/seeds/role_templates/operations.yml
db/seeds/role_templates/finance.yml
db/seeds/role_templates/hr.yml

RoleTemplateRegistry (Plain Ruby class)     → Loads, caches, exposes template data
ApplyRoleTemplateService (Service object)   → Creates roles from template for a company

RoleTemplatesController                     → Browse + preview + apply (3 actions)
  GET  /role_templates                      → index (browse all templates)
  GET  /role_templates/:id                  → show (preview a template)
  POST /role_templates/:id/apply            → apply (create roles in company)
```

### Component Architecture

```
User clicks "Apply Engineering"
        │
        ▼
RoleTemplatesController#apply
        │
        ▼
ApplyRoleTemplateService.call(
  company: Current.company,
  template_key: "engineering",
  parent_role: @ceo_role      ← optional, attach under existing role
)
        │
        ├── Load template from RoleTemplateRegistry
        │
        ├── For each role definition (topological order):
        │     ├── Check: company.roles.exists?(title: role_def["title"])
        │     │     YES → skip, record as "skipped"
        │     │     NO  → create role with description + job_spec
        │     │
        │     ├── Resolve parent_id:
        │     │     top-level in template? → use parent_role param (or nil)
        │     │     has template parent?   → look up just-created role by title
        │     │
        │     └── Assign skills:
        │           role_def["skills"] → company.skills.where(key: skill_keys)
        │           → RoleSkill.create! for each
        │
        └── Return result object:
              { created: [...], skipped: [...], errors: [...] }
```

---

## Component Boundaries

### RoleTemplateRegistry (New — Plain Ruby Class)

Not a model. A registry class that loads and caches YAML template definitions. Follows the same pattern as `Company.default_skill_definitions` but as a standalone class.

**Location:** `app/models/role_template_registry.rb` (or `app/services/role_template_registry.rb` — either works, but `app/models/` matches how `AdapterRegistry` lives in the codebase)

```ruby
class RoleTemplateRegistry
  TEMPLATES_PATH = Rails.root.join("db/seeds/role_templates")

  class << self
    def all
      @all ||= load_all_templates.freeze
    end

    def find(key)
      all.fetch(key.to_s) { raise KeyError, "Unknown role template: #{key}" }
    end

    def keys
      all.keys
    end

    def reset!  # For tests
      @all = nil
    end

    private

    def load_all_templates
      Dir[TEMPLATES_PATH.join("*.yml")].each_with_object({}) do |file, hash|
        data = YAML.load_file(file)
        hash[data.fetch("key")] = data.freeze
      end
    end
  end
end
```

### YAML Template Format

Each template file defines a complete department hierarchy:

```yaml
# db/seeds/role_templates/engineering.yml
key: engineering
name: Engineering Department
description: >
  A full engineering department with CTO, team leads,
  and individual contributors across backend, frontend,
  QA, and DevOps.
icon: code  # For UI display (maps to CSS icon system)
roles:
  - title: CTO
    description: Chief Technology Officer. Oversees all engineering and technical strategy.
    job_spec: |
      Lead technical vision and architecture decisions.
      Manage engineering team leads and set coding standards.
      Evaluate and adopt new technologies.
      Report technical progress to the CEO.
    parent: ~  # null = top of this template's hierarchy
    skills:
      - code_review
      - architecture_planning
      - technical_strategy
      - system_design
      - security_assessment

  - title: Backend Lead
    description: Leads the backend engineering team.
    job_spec: |
      Architect server-side systems and APIs.
      Mentor backend engineers on best practices.
      Own backend code review and deployment pipeline.
    parent: CTO  # References title of another role in this template
    skills:
      - code_review
      - architecture_planning
      - implementation
      - system_design

  - title: Backend Engineer
    description: Implements server-side features, APIs, and data models.
    job_spec: |
      Write clean, tested backend code.
      Fix bugs and optimize query performance.
      Participate in code reviews.
    parent: Backend Lead
    skills:
      - code_review
      - implementation
      - debugging
      - testing
      - documentation

  # ... more roles
```

**Design decisions in the YAML format:**

1. **`parent` uses title string, not index** — More readable than array indices. Resolved at apply-time by looking up the just-created role with that title.
2. **`parent: ~` (null)** — Means this role is the top of the template hierarchy. At apply-time, this attaches to the user-specified parent (CEO) or becomes a root role.
3. **`skills` uses skill keys** — Same keys as `db/seeds/skills/*.yml`. Looked up via `company.skills.where(key: keys)`.
4. **Roles listed in dependency order** — Parents appear before children. The service processes them in array order, so parent roles exist by the time children reference them.
5. **No `adapter_type` or `budget_cents`** — Templates define organizational structure only. Agent configuration and budgets are operational concerns set after template application.

### ApplyRoleTemplateService (New — Service Object)

Follows the established service pattern (`self.call` class method, instance `#call`).

```ruby
class ApplyRoleTemplateService
  Result = Data.define(:created, :skipped, :errors)

  attr_reader :company, :template_key, :parent_role

  def initialize(company:, template_key:, parent_role: nil)
    @company = company
    @template_key = template_key
    @parent_role = parent_role
  end

  def self.call(**args)
    new(**args).call
  end

  def call
    template = RoleTemplateRegistry.find(template_key)
    created = []
    skipped = []
    errors = []
    title_to_role = {}  # Maps template title → created Role record

    template["roles"].each do |role_def|
      title = role_def["title"]

      # Skip-duplicate: check if role with this title already exists
      existing = company.roles.find_by(title: title)
      if existing
        skipped << title
        title_to_role[title] = existing  # Still track for child references
        next
      end

      # Resolve parent
      parent_id = resolve_parent_id(role_def, title_to_role)

      # Create role
      role = company.roles.create!(
        title: title,
        description: role_def["description"],
        job_spec: role_def["job_spec"],
        parent_id: parent_id
      )

      # Assign skills
      assign_skills(role, role_def["skills"] || [])

      created << title
      title_to_role[title] = role
    rescue ActiveRecord::RecordInvalid => e
      errors << { title: title, error: e.message }
    end

    Result.new(created: created, skipped: skipped, errors: errors)
  end

  private

  def resolve_parent_id(role_def, title_to_role)
    template_parent = role_def["parent"]

    if template_parent.nil?
      # Top of template hierarchy — attach to user-specified parent
      parent_role&.id
    else
      # Look up the parent role (already created or existing)
      title_to_role[template_parent]&.id
    end
  end

  def assign_skills(role, skill_keys)
    return if skill_keys.empty?

    company_skills = company.skills.where(key: skill_keys)
    company_skills.each do |skill|
      role.role_skills.create!(skill: skill)
    end
  end
end
```

**Key design choices:**

1. **Sequential processing, not bulk insert** — Role creation triggers `ConfigVersioned` callbacks, `Auditable` hooks, and validates `TreeHierarchy` constraints. Bulk insert would skip all of this. With 5-10 roles per template, sequential creation is fast enough.
2. **`title_to_role` hash for parent resolution** — When a child references `parent: "CTO"`, we look up the just-created CTO role. If the CTO was skipped (already existed), we still track it so children can attach correctly.
3. **`Result` data class** — Returns structured result with created/skipped/errors arrays. The controller uses this for flash messages and redirect logic.
4. **No transaction wrapping** — Partial application is acceptable. If roles 1-3 succeed and role 4 fails, the user keeps roles 1-3 and gets an error message about role 4. This matches the skip-duplicate philosophy (additive, not atomic).
5. **Skills assigned at creation time** — Unlike the default_skills.yml auto-assignment (which fires on first agent config), template skills are assigned immediately. The template explicitly declares which skills each role needs.

### RoleTemplatesController (New)

Three actions: browse, preview, apply.

```ruby
class RoleTemplatesController < ApplicationController
  before_action :require_company!

  def index
    @templates = RoleTemplateRegistry.all
    @existing_titles = Current.company.roles.pluck(:title).to_set
  end

  def show
    @template = RoleTemplateRegistry.find(params[:id])
    @existing_titles = Current.company.roles.pluck(:title).to_set
    @root_roles = Current.company.roles.roots.order(:title)
  end

  def apply
    template = RoleTemplateRegistry.find(params[:id])
    parent_role = params[:parent_role_id].present? ?
      Current.company.roles.find(params[:parent_role_id]) : nil

    result = ApplyRoleTemplateService.call(
      company: Current.company,
      template_key: params[:id],
      parent_role: parent_role
    )

    if result.errors.empty?
      notice = build_success_message(result)
      redirect_to roles_path, notice: notice
    else
      alert = "Some roles could not be created: #{result.errors.map { |e| e[:title] }.join(', ')}"
      redirect_to role_template_path(params[:id]), alert: alert
    end
  end

  private

  def build_success_message(result)
    parts = []
    parts << "Created #{result.created.size} roles" if result.created.any?
    parts << "Skipped #{result.skipped.size} existing" if result.skipped.any?
    parts.join(". ") + "."
  end
end
```

---

## Data Flow: Browse -> Preview -> Apply -> Roles Created

### Step 1: Browse Templates (GET /role_templates)

```
User visits /role_templates
  → RoleTemplatesController#index
  → RoleTemplateRegistry.all (cached Hash of template data)
  → @existing_titles = Current.company.roles.pluck(:title).to_set
  → Render index: grid of template cards
     Each card shows: name, description, role count, "X of Y roles already exist"
```

### Step 2: Preview Template (GET /role_templates/:id)

```
User clicks a template card
  → RoleTemplatesController#show
  → RoleTemplateRegistry.find("engineering")
  → @existing_titles for visual skip indicators
  → @root_roles for "attach under" dropdown
  → Render show:
     - Template name + description
     - Visual hierarchy tree of roles
     - Each role shows: title, description snippet, skill badges
     - Roles already existing in company: grayed out with "Already exists" badge
     - "Attach under" dropdown (root roles + None)
     - "Apply Template" button (POST)
```

### Step 3: Apply Template (POST /role_templates/:id/apply)

```
User clicks "Apply Template"
  → POST /role_templates/engineering/apply
     params: { parent_role_id: 42 }  (optional)
  → ApplyRoleTemplateService.call(
      company: Current.company,
      template_key: "engineering",
      parent_role: roles.find(42)    (CEO role)
    )
  → Service iterates role definitions:
     1. CTO → not exists → create(parent: CEO) → assign 5 skills
     2. Backend Lead → not exists → create(parent: CTO) → assign 4 skills
     3. Backend Engineer → not exists → create(parent: Backend Lead) → assign 5 skills
     ...
  → Returns Result(created: ["CTO", "Backend Lead", ...], skipped: [], errors: [])
  → Redirect to /roles with flash: "Created 8 roles."
```

### Step 4: Re-Apply (Idempotent)

```
User applies Engineering template again
  → ApplyRoleTemplateService runs
  → CTO → exists → skip
  → Backend Lead → exists → skip
  → ... all skipped
  → Returns Result(created: [], skipped: ["CTO", "Backend Lead", ...], errors: [])
  → Redirect with flash: "Skipped 8 existing."
```

---

## Routes

```ruby
# config/routes.rb (addition)
resources :role_templates, only: [:index, :show] do
  member do
    post :apply
  end
end
```

This produces:
- `GET    /role_templates`          → `role_templates#index`
- `GET    /role_templates/:id`      → `role_templates#show`
- `POST   /role_templates/:id/apply` → `role_templates#apply`

The `:id` param is the template key (string), not a database ID. Rails routing handles string IDs fine.

---

## Integration Points with Existing Architecture

### TreeHierarchy Concern

Templates create parent-child relationships. The concern validates:
- `parent_belongs_to_same_company` — Always true (all roles created for `Current.company`)
- `parent_is_not_self` — Always true (new roles have no `id` yet when parent is set)
- `parent_is_not_descendant` — Always true (parents created before children in template order)

No changes to TreeHierarchy needed.

### ConfigVersioned Concern

Every role creation triggers `create_config_version` via `after_save`. Template-applied roles will generate ConfigVersion records automatically. This is correct behavior — the audit trail should reflect template-created roles.

The `author` will be `Current.user` (the person who clicked "Apply"). The `action` will be `"create"`. No changes needed.

### Tenantable Concern

Roles created via `company.roles.create!` automatically get `company_id` set. No changes needed.

### Default Skills (config/default_skills.yml)

The existing `assign_default_skills` callback fires on first agent configuration (`after_save :assign_default_skills, if: :first_agent_configuration?`). Template roles get skills assigned at creation by the service. When an agent is later configured on a template role, `assign_default_skills` will try to add default skills but `RoleSkill` uniqueness (`validates :skill_id, uniqueness: { scope: :role_id }`) prevents duplicates. The two systems coexist without conflict.

### Auditable Concern

Template application does NOT need to fire audit events per role. The `ConfigVersioned` audit trail is sufficient. However, a single audit event on the company (or the top-level created role) recording "template_applied" with metadata `{ template: "engineering", created: 8, skipped: 0 }` would be valuable. This can be added as an optional enhancement.

### Skill Seeding

Templates reference skill keys. Skills must exist in the company before template application. Since `Company#seed_default_skills!` runs `after_create`, all builtin skills are present. If a template references a skill key that does not exist (typo or custom skill), the service silently skips that skill assignment — it does not error. This is the defensive approach.

---

## New Components

| Component | Type | Location | Purpose |
|-----------|------|----------|---------|
| `RoleTemplateRegistry` | Plain Ruby class | `app/models/role_template_registry.rb` | Load, cache, expose YAML templates |
| `ApplyRoleTemplateService` | Service object | `app/services/apply_role_template_service.rb` | Create roles + skills from template |
| `RoleTemplatesController` | Controller | `app/controllers/role_templates_controller.rb` | Browse, preview, apply UI |
| Template YAML files (5) | Data | `db/seeds/role_templates/*.yml` | Template definitions |
| `role_templates/index.html.erb` | View | `app/views/role_templates/` | Browse grid |
| `role_templates/show.html.erb` | View | `app/views/role_templates/` | Preview with hierarchy tree |
| `role_templates/_template_card.html.erb` | Partial | `app/views/role_templates/` | Card for index grid |
| `role_templates/_role_tree.html.erb` | Partial | `app/views/role_templates/` | Recursive tree for preview |
| `test/models/role_template_registry_test.rb` | Test | `test/models/` | Registry loading + caching |
| `test/services/apply_role_template_service_test.rb` | Test | `test/services/` | Service: create, skip, hierarchy, skills |
| `test/controllers/role_templates_controller_test.rb` | Test | `test/controllers/` | Controller: index, show, apply |

## Modified Components

| Component | Change | Why |
|-----------|--------|-----|
| `config/routes.rb` | Add `resources :role_templates` | Routes for browse/preview/apply |
| `app/views/roles/index.html.erb` | Add "Browse Templates" link | Discovery entry point |
| `app/views/dashboard/show.html.erb` | Optional: add templates CTA in empty state | Onboarding flow |

**No model changes. No migrations. No schema changes.**

This is a zero-migration feature. All data lives in YAML files and existing tables.

---

## Patterns to Follow

### Pattern 1: Registry Class (Match AdapterRegistry)

The codebase already has `AdapterRegistry` as a class-level registry. `RoleTemplateRegistry` follows the same pattern: class methods, no instances, cached data.

### Pattern 2: Service with self.call (Match WakeRoleService)

```ruby
class ApplyRoleTemplateService
  def self.call(**args)
    new(**args).call
  end
end
```

Every service in the codebase uses this exact pattern.

### Pattern 3: find_or_skip by Title (Match Skill Seeding)

Skills use `find_or_create_by!(key:)`. Roles use `find_by(title:)` + skip. The logic is equivalent: idempotent application with duplicate detection by natural key.

### Pattern 4: Structured Result Object

Use `Data.define` for the result (Ruby 3.2+ immutable value object). Cleaner than returning a hash, more lightweight than a full Result class.

### Pattern 5: YAML in db/seeds/ (Match Skills)

Template YAML files live in `db/seeds/role_templates/`, parallel to `db/seeds/skills/`. Consistent project structure.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Creating a RoleTemplate Model

**Why bad:** Over-engineering for 3-5 static definitions. Adds migration, model, associations, tests, and maintenance. The data never changes at runtime.
**Instead:** YAML files + registry class. If user-created templates are needed later (v2), add the model then.

### Anti-Pattern 2: Wrapping Template Application in a Transaction

**Why bad:** If role 5 of 8 fails, a transaction rolls back roles 1-4 too. The user gets nothing. With skip-duplicate logic, partial success is expected and useful.
**Instead:** Process sequentially, collect errors, return Result with created/skipped/errors.

### Anti-Pattern 3: Using Array Indices for Parent References

```yaml
# BAD
roles:
  - title: CTO
    parent_index: ~
  - title: Backend Lead
    parent_index: 0  # Fragile, unreadable
```

**Instead:** Use title strings (`parent: CTO`). Readable, self-documenting, robust to reordering.

### Anti-Pattern 4: Duplicating Skill Definitions in Templates

Templates should reference skill keys, not embed full skill markdown. Skills are already seeded. Templates just reference them by key.

### Anti-Pattern 5: Applying Templates Without Company Scoping

The service receives `company:` explicitly. Never rely on `Current.company` inside the service — pass it as a parameter. This makes the service testable without thread-local state.

---

## Build Order

Dependencies drive the order. Three phases, all lightweight:

### Phase 1: Template Data + Registry (Foundation)

**Why first:** Everything depends on being able to load template definitions.

- Write 5 YAML template files in `db/seeds/role_templates/`
- Implement `RoleTemplateRegistry` (load, cache, find, keys)
- Tests: registry loading, find, unknown key error, reset for test isolation

### Phase 2: Application Service (Core Logic)

**Why second:** The service is the heart of the feature. Needs templates to exist (Phase 1).

- Implement `ApplyRoleTemplateService`
- Tests: fresh apply (all created), re-apply (all skipped), partial overlap, hierarchy construction, skill assignment, missing parent handling, missing skill key handling

### Phase 3: Controller + Views (UI)

**Why third:** Needs both registry (Phase 1) and service (Phase 2).

- Routes
- `RoleTemplatesController` with index, show, apply
- Views: index (card grid), show (hierarchy preview + apply form), flash messages
- Link from roles index page
- Tests: controller actions, flash messages, redirect targets

---

## Template Content Plan

Five departments, 3-8 roles each, covering the standard AI company structure:

| Template | Key | Roles | Top Role |
|----------|-----|-------|----------|
| Engineering | `engineering` | CTO, Backend Lead, Frontend Lead, Backend Engineer, Frontend Engineer, QA Engineer, DevOps Engineer | CTO |
| Marketing | `marketing` | CMO, Content Lead, SEO Specialist, Social Media Manager, Campaign Manager | CMO |
| Operations | `operations` | COO, Project Manager, Operations Analyst, Customer Support Lead | COO |
| Finance | `finance` | CFO, Financial Analyst, Budget Controller, Compliance Officer | CFO |
| Human Resources | `hr` | CHRO, Recruiter, People Ops Manager | CHRO |

Total: ~25-27 roles across 5 templates. Each role gets a description, a 4-8 line job spec, and 3-5 skill key assignments referencing existing builtin skills.

---

## Sources

- Role model with TreeHierarchy, Tenantable, ConfigVersioned: `app/models/role.rb` — HIGH confidence (read directly)
- Skill model and seeding pattern: `app/models/skill.rb`, `app/models/company.rb` — HIGH confidence (read directly)
- RoleSkill join table with company validation: `app/models/role_skill.rb` — HIGH confidence (read directly)
- TreeHierarchy concern validations: `app/models/concerns/tree_hierarchy.rb` — HIGH confidence (read directly)
- Default skills auto-assignment: `app/models/role.rb` lines 41-47, 226-241 — HIGH confidence (read directly)
- Skill seeding rake task pattern: `lib/tasks/skills.rake` — HIGH confidence (read directly)
- Service object pattern: `app/services/wake_role_service.rb` — HIGH confidence (read directly)
- Routes structure: `config/routes.rb` — HIGH confidence (read directly)
- Schema (no migration needed): `db/schema.rb` — HIGH confidence (read directly)
