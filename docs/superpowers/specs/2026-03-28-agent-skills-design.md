# Agent Skills System Design

## Overview

Add a company-level skill library with full markdown instruction packages and role-based auto-assignment. Skills are rich documents injected into agent context that teach agents how to perform specific capabilities. When an agent is first assigned to a role, default skills for that role are automatically attached.

This extends beyond Paperclip's model (which has no role-based defaults) by shipping a built-in catalog of 44 curated skills across 11 roles and auto-assigning them on first role assignment.

## Data Model

### `skills` table (company-level skill library)

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | bigint | PK | auto-increment |
| `company_id` | bigint | FK, not null | Tenantable |
| `key` | string | not null | Machine identifier, e.g. `strategic_planning` |
| `name` | string | not null | Display name, e.g. "Strategic Planning" |
| `description` | text | | Short routing description |
| `markdown` | text | not null | Full instruction content |
| `category` | string | | Free-form string. Built-in skills use: `leadership`, `technical`, `creative`, `operations`, `research` |
| `builtin` | boolean | default: true | Distinguishes seeded vs user-created |
| `created_at` | datetime | not null | |
| `updated_at` | datetime | not null | |

**Indexes:**
- Unique on `(company_id, key)`
- Index on `(company_id, category)`

### `agent_skills` table (replaces `agent_capabilities`)

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | bigint | PK |
| `agent_id` | bigint | FK, not null |
| `skill_id` | bigint | FK, not null |
| `created_at` | datetime | not null |
| `updated_at` | datetime | not null |

**Indexes:**
- Unique on `(agent_id, skill_id)`

### Migration

- Create `skills` table
- Create `agent_skills` table
- Drop `agent_capabilities` table (no data migration needed)

## Role Default Mapping

Stored in `config/default_skills.yml`. Maps role titles (case-insensitive) to arrays of skill keys.

| Role | Default Skills |
|------|---------------|
| **CEO** | `strategic_planning`, `company_vision`, `stakeholder_communication`, `decision_making`, `risk_assessment` |
| **CTO** | `code_review`, `architecture_planning`, `technical_strategy`, `system_design`, `security_assessment` |
| **CMO** | `market_analysis`, `content_strategy`, `brand_management`, `campaign_planning`, `audience_research` |
| **CFO** | `financial_analysis`, `budget_planning`, `revenue_forecasting`, `cost_optimization`, `compliance_reporting` |
| **Engineer** | `code_review`, `implementation`, `debugging`, `testing`, `documentation` |
| **Designer** | `ui_design`, `ux_research`, `prototyping`, `design_systems`, `accessibility_review` |
| **PM** | `project_planning`, `requirements_gathering`, `sprint_management`, `stakeholder_communication`, `progress_reporting` |
| **QA** | `test_planning`, `bug_reporting`, `regression_testing`, `performance_testing`, `quality_standards` |
| **DevOps** | `infrastructure_management`, `ci_cd_pipelines`, `monitoring_alerting`, `deployment_automation`, `incident_response` |
| **Researcher** | `data_analysis`, `literature_review`, `experiment_design`, `report_writing`, `market_analysis` |
| **General** | `task_execution`, `communication`, `documentation`, `problem_solving` |

44 unique skills across 11 roles. Some skills are shared across roles (e.g., `code_review` for CTO and Engineer, `stakeholder_communication` for CEO and PM, `market_analysis` for CMO and Researcher, `documentation` for Engineer and General).

### Skill Categories

- **leadership** — strategic, vision, decision-making, stakeholder skills
- **technical** — code, architecture, security, infrastructure, testing skills
- **creative** — design, content, brand, UX skills
- **operations** — project management, process, deployment, quality skills
- **research** — analysis, experimentation, reporting skills

## Models

### `Skill`

```ruby
class Skill < ApplicationRecord
  include Tenantable

  has_many :agent_skills, dependent: :destroy
  has_many :agents, through: :agent_skills

  validates :key, presence: true,
                  uniqueness: { scope: :company_id }
  validates :name, presence: true
  validates :markdown, presence: true

  scope :by_category, ->(cat) { where(category: cat) }
  scope :builtin, -> { where(builtin: true) }
  scope :custom, -> { where(builtin: false) }
end
```

### `AgentSkill`

```ruby
class AgentSkill < ApplicationRecord
  belongs_to :agent
  belongs_to :skill

  validates :skill_id, uniqueness: { scope: :agent_id }
  validate :same_company

  private

  def same_company
    return unless agent && skill
    unless agent.company_id == skill.company_id
      errors.add(:skill, "must belong to the same company as the agent")
    end
  end
end
```

### `Agent` changes

- Replace `has_many :agent_capabilities, dependent: :destroy` with:
  - `has_many :agent_skills, dependent: :destroy`
  - `has_many :skills, through: :agent_skills`

### `Role` changes

Add `after_save` callback that fires only on first agent assignment:

```ruby
after_save :assign_default_skills_to_agent, if: :first_agent_assignment?

def first_agent_assignment?
  saved_change_to_agent_id? && agent_id.present? && agent_id_before_last_save.nil?
end
```

The callback:
1. Looks up `title` (case-insensitive) in `config/default_skills.yml`
2. Finds matching `Skill` records in the agent's company
3. Creates `AgentSkill` records for skills the agent doesn't already have
4. Unknown role titles or missing skills are silently skipped

### `Company` changes

Add `after_create :seed_default_skills!` callback.

`seed_default_skills!` reads all skill definition files from `db/seeds/skills/*.yml` and creates `Skill` records for the company. Idempotent — skips existing keys.

## Skill Content

Each skill has meaningful markdown instructions — not just labels. Stored as individual YAML files in `db/seeds/skills/`.

### File structure

```
db/seeds/skills/
  strategic_planning.yml
  company_vision.yml
  code_review.yml
  ... (44 files total)
```

### YAML format per skill

```yaml
key: code_review
name: Code Review
description: Review code for quality, bugs, and adherence to standards
category: technical
markdown: |
  # Code Review

  ## Purpose
  Analyze code changes for correctness, maintainability, security
  vulnerabilities, and adherence to project standards.

  ## Instructions
  1. Read the diff carefully, understanding the context of changes
  2. Check for correctness — does the code do what it claims?
  3. Review error handling and edge cases
  4. Assess readability and naming conventions
  5. Flag security concerns (injection, auth bypass, data exposure)
  6. Verify test coverage for new/changed behavior

  ## Guidelines
  - Focus on substance over style — automated linters handle formatting
  - Explain the "why" behind suggestions
  - Distinguish blocking issues from suggestions
  - Acknowledge good decisions, not just problems

  ## Output Format
  Structured review with: summary, blocking issues, suggestions, and approval status.
```

## Controllers & Routes

### `SkillsController`

Full CRUD for company skill library:
- `index` — list all skills for current company, filterable by category
- `show` — skill detail with markdown content and list of agents that have it
- `new` / `create` — create custom skill (`builtin: false`)
- `edit` / `update` — edit any skill (companies can customize builtin skills)
- `destroy` — only custom skills; builtin skills cannot be destroyed

### `AgentSkillsController`

Manage skill assignments on an agent:
- `create` — assign a skill to an agent
- `destroy` — remove a skill from an agent

### Routes

```ruby
resources :skills

resources :agents do
  resources :skills, only: [:create, :destroy], controller: "agent_skills"
  # ... existing member routes
end
```

Replaces the current `capabilities` routes. All views referencing capabilities updated to reference skills.

## Auto-Assignment Behavior

**Trigger:** `Role#after_save` when `agent_id` changes from `nil` to a non-nil value (first assignment only).

**Reassignment is not supported.** If `agent_id` was already set and changes to a different agent, no skill auto-assignment fires.

**Behavior:**
1. Look up role `title` in `config/default_skills.yml` (case-insensitive)
2. Find matching `Skill` records in the agent's company
3. Create `AgentSkill` records only for skills the agent doesn't already have
4. If role title isn't in defaults map — do nothing
5. If a skill key isn't found in company — skip it silently

**Skills are permanent on the agent regardless of future role changes.** Skill removal is always explicit via the UI.

## Seeding

### On company creation

`Company#after_create` calls `seed_default_skills!` which:
1. Reads all `db/seeds/skills/*.yml` files
2. Creates `Skill` records for the company (all 44 skills)
3. Skips any keys that already exist (idempotent)

### Rake task for existing companies

`bin/rails skills:reseed` — iterates all companies and runs `seed_default_skills!` on each. Safe to run multiple times.

## Testing Strategy

Unit and controller tests only (Minitest + fixtures, no system/integration tests).

### Model tests

- **`SkillTest`** — validations (key/name/markdown presence, key uniqueness per company), scopes (`by_category`, `builtin`, `custom`), tenantable behavior
- **`AgentSkillTest`** — validations (uniqueness per agent, same-company constraint)
- **`RoleTest`** — auto-assignment fires only on first agent assignment (nil -> agent), doesn't fire on reassignment (agent -> different agent), skips unknown role titles, skips missing skills
- **`CompanyTest`** — `seed_default_skills!` creates all 44 skills, idempotent on re-run
- **`AgentTest`** — `has_many :skills, through: :agent_skills` works correctly

### Controller tests

- **`SkillsControllerTest`** — CRUD operations, category filtering, prevents destroying builtin skills
- **`AgentSkillsControllerTest`** — assign and remove skills from agent

### Fixtures

- Skills: representative fixtures (one per category) for the `acme` company
- AgentSkills: link existing agent fixtures to skill fixtures

## Files Changed

### New files
- `db/migrate/TIMESTAMP_create_skills_and_agent_skills.rb`
- `app/models/skill.rb`
- `app/models/agent_skill.rb`
- `app/controllers/skills_controller.rb`
- `app/controllers/agent_skills_controller.rb`
- `app/views/skills/` (index, show, new, edit, _form, _skill)
- `app/views/agent_skills/` (partials for assign/remove)
- `config/default_skills.yml`
- `db/seeds/skills/*.yml` (44 files)
- `test/models/skill_test.rb`
- `test/models/agent_skill_test.rb`
- `test/controllers/skills_controller_test.rb`
- `test/controllers/agent_skills_controller_test.rb`
- `test/fixtures/skills.yml`
- `test/fixtures/agent_skills.yml`
- `lib/tasks/skills.rake`

### Modified files
- `app/models/agent.rb` — replace `agent_capabilities` with `agent_skills` / `skills`
- `app/models/role.rb` — add auto-assignment callback
- `app/models/company.rb` — add `seed_default_skills!` and `after_create` callback
- `config/routes.rb` — replace capability routes, add skill routes
- `app/views/agents/show.html.erb` — show skills instead of capabilities
- `app/views/agents/_agent.html.erb` — show skills instead of capabilities
- `app/controllers/agents_controller.rb` — remove capability references
- `test/models/agent_test.rb` — update capability tests to skill tests
- `test/models/role_test.rb` — add auto-assignment tests
- `test/models/company_test.rb` — add seeding tests

### Deleted files
- `app/models/agent_capability.rb`
- `app/controllers/agent_capabilities_controller.rb`
- `test/models/agent_capability_test.rb`
- `test/controllers/agent_capabilities_controller_test.rb`
- `test/fixtures/agent_capabilities.yml`

Note: The original `create_agent_capabilities` migration file is kept (never delete old migrations). The new migration drops the table.
