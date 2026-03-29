# Feature Landscape: Role Templates (Builtin Department Hierarchies)

**Domain:** AI agent company orchestration -- department template system
**Researched:** 2026-03-29
**Overall confidence:** HIGH (grounded in existing codebase analysis + industry patterns)

## Table Stakes

Features users expect from a template system. Missing = templates feel incomplete or unusable.

| Feature | Why Expected | Complexity | Dependencies |
|---------|--------------|------------|--------------|
| Pre-built department hierarchies (5 departments) | Core value prop -- users skip manual org chart setup | Medium | Role model with parent_id |
| Stackable application | Users apply multiple departments incrementally | Low | Unique title constraint per company |
| Duplicate-skip on re-application | Applying "Engineering" twice should not create duplicate roles | Low | Role title uniqueness scope: company_id |
| CEO as shared root node | All departments report to CEO; CEO created once, reused | Low | TreeHierarchy concern |
| Skill auto-assignment per template role | Roles come pre-wired with relevant builtin skills | Low | Existing default_skills.yml + assign_default_skills |
| Role descriptions and job specs | Every template role has a meaningful description and job_spec | Medium (content) | Role model description/job_spec fields |
| Correct reporting lines within departments | VP Engineering -> CTO, not VP Engineering -> CEO | Low | parent_id FK |
| Template preview before applying | Users see what will be created before committing | Low | Read-only rendering of YAML |
| Idempotent application | Safe to run multiple times without side effects | Low | find_or_create_by on title+company_id |
| Flash feedback after apply | User sees "Created 7 roles, skipped 2 existing" | Low | Service tracks created vs found counts |

## Department Templates -- Concrete Structures

Each template below is designed to be written as a single YAML file. The hierarchy uses 3-4 levels: C-suite -> VP/Director -> Manager/Lead -> Individual Contributor. This mirrors both traditional org structures and how AI agent platforms (Paperclip, CrewAI) model hierarchical delegation chains.

**Design principle:** Keep departments at 4-8 roles each. Too few roles and the template adds no value over manual creation. Too many and it overwhelms the org chart before users have agents to fill them. The Paperclip Company Wizard uses 5-12 roles per preset; we target the lower end because Director users manually connect agents to roles.

---

### Department 1: Engineering

**Reports to:** CEO (via CTO)
**Roles:** 7 (including CTO)

```
CEO (shared root -- created if missing)
  CTO
    VP Engineering
      Tech Lead
      Senior Engineer
      QA Lead
    DevOps Engineer
```

| Role | Description | Job Spec Summary | Skills (from builtin catalog) |
|------|-------------|------------------|-------------------------------|
| CTO | Sets technical vision, evaluates build-vs-buy decisions, owns architecture standards | Defines technology strategy, reviews architecture decisions, evaluates technical risks, ensures engineering quality standards across the organization | technical_strategy, architecture_planning, system_design, security_assessment, decision_making |
| VP Engineering | Manages engineering execution, sprint cadence, and team delivery | Owns engineering delivery: sprint planning, resource allocation, technical hiring priorities, cross-team coordination, engineering metrics and velocity tracking | project_planning, sprint_management, progress_reporting, requirements_gathering |
| Tech Lead | Hands-on technical leader who reviews code, mentors engineers, and owns implementation quality | Reviews all pull requests, sets coding standards, leads technical design discussions, unblocks engineers on hard problems, owns the codebase health | code_review, implementation, system_design, debugging, documentation |
| Senior Engineer | Primary implementer of features and systems | Implements features end-to-end, writes tests, debugs production issues, contributes to architecture discussions, mentors junior engineers | implementation, debugging, testing, code_review, documentation |
| QA Lead | Owns quality assurance strategy and test coverage | Defines test strategy, creates test plans, runs regression testing, tracks defect trends, ensures release quality, manages performance testing | test_planning, bug_reporting, regression_testing, performance_testing, quality_standards |
| DevOps Engineer | Owns infrastructure, CI/CD, and operational reliability | Manages deployment pipelines, monitors system health, responds to incidents, automates infrastructure provisioning, maintains uptime and performance | infrastructure_management, ci_cd_pipelines, monitoring_alerting, deployment_automation, incident_response |

**Why this structure:** The CTO-as-department-head pattern matches how AI agent companies work -- the CTO makes strategic technical decisions and delegates execution through a VP. The VP handles sprint cadence and delivery. Below that, a Tech Lead owns code quality while a QA Lead owns testing. DevOps reports directly to CTO because infrastructure decisions are strategic, not just execution.

**Skill mapping notes:** All skills listed exist in the current 48-skill builtin catalog. Every role maps to 4-6 skills. The `default_skills.yml` already maps `cto`, `engineer`, `qa`, and `devops` titles; the template system should extend these mappings to cover VP Engineering, Tech Lead, Senior Engineer, and QA Lead.

---

### Department 2: Marketing

**Reports to:** CEO (via CMO)
**Roles:** 6 (including CMO)

```
CEO (shared root)
  CMO
    Content Strategist
    SEO Analyst
    Social Media Manager
    Brand Designer
```

| Role | Description | Job Spec Summary | Skills (from builtin catalog) |
|------|-------------|------------------|-------------------------------|
| CMO | Drives marketing strategy, brand positioning, and go-to-market execution | Owns marketing strategy and brand direction: market positioning, campaign portfolio management, marketing budget allocation, competitive intelligence, growth metrics | market_analysis, content_strategy, brand_management, campaign_planning, audience_research |
| Content Strategist | Plans and creates content that drives awareness and engagement | Develops content calendar, writes blog posts and thought leadership, ensures brand voice consistency, measures content performance, manages editorial workflow | content_strategy, documentation, report_writing, communication |
| SEO Analyst | Optimizes discoverability and organic traffic through data-driven analysis | Conducts keyword research, audits site structure for SEO, tracks ranking performance, analyzes competitor content strategies, recommends content optimizations | data_analysis, market_analysis, audience_research, report_writing |
| Social Media Manager | Manages brand presence and engagement across social platforms | Creates and schedules social content, monitors engagement metrics, responds to community interactions, runs social campaigns, tracks brand sentiment | campaign_planning, communication, audience_research, content_strategy |
| Brand Designer | Owns visual identity, design systems, and creative assets | Creates marketing visuals, maintains brand design system, designs campaign assets, ensures visual consistency across channels, produces presentation materials | ui_design, design_systems, prototyping, brand_management |

**Why this structure:** The CMO owns strategy; below that, roles map to the core marketing functions an AI company actually needs. Content Strategist and SEO Analyst handle inbound; Social Media Manager handles distribution; Brand Designer handles visual identity. This is the "Hub-and-Agent" model described in AI marketing team research -- a senior strategist (CMO) directing specialist agents.

**Skill mapping notes:** CMO skills already exist in `default_skills.yml`. Content Strategist and SEO Analyst use research + creative skills. Brand Designer reuses designer skills. New entries needed in `default_skills.yml` for: content_strategist, seo_analyst, social_media_manager, brand_designer.

---

### Department 3: Operations

**Reports to:** CEO (via COO)
**Roles:** 5 (including COO)

```
CEO (shared root)
  COO
    Project Manager
    Operations Analyst
    Process Coordinator
```

| Role | Description | Job Spec Summary | Skills (from builtin catalog) |
|------|-------------|------------------|-------------------------------|
| COO | Oversees daily operations, resource allocation, and cross-department coordination | Executes strategy set by CEO: manages operational processes, coordinates between departments, tracks company-wide KPIs, identifies workflow inefficiencies, ensures resource utilization | project_planning, sprint_management, progress_reporting, decision_making, risk_assessment |
| Project Manager | Plans and tracks projects from initiation to completion | Defines project scope and milestones, manages timelines and dependencies, runs status meetings, tracks deliverables against deadlines, escalates blockers | project_planning, requirements_gathering, sprint_management, progress_reporting, communication |
| Operations Analyst | Analyzes operational data to surface insights and improvement opportunities | Monitors operational metrics, identifies bottlenecks and inefficiencies, produces weekly operations reports, benchmarks performance against targets, recommends process improvements | data_analysis, report_writing, problem_solving, cost_optimization |
| Process Coordinator | Ensures processes run smoothly and documentation stays current | Maintains process documentation, coordinates handoffs between teams, tracks SLA compliance, manages operational checklists, onboards new processes and tools | documentation, task_execution, communication, quality_standards |

**Why this structure:** Operations is the "glue" department. The COO orchestrates -- in AI agent terms, this is the agent that runs daily standups and maintains the sprint board (as described by practitioners running AI companies). The PM handles project execution, the analyst handles data, and the coordinator handles process hygiene. This is deliberately lean; operations roles expand based on company size.

**Skill mapping notes:** COO maps to a mix of leadership + operations skills. PM reuses the existing `pm` mapping in `default_skills.yml`. New entries needed for: coo, operations_analyst, process_coordinator.

---

### Department 4: Finance

**Reports to:** CEO (via CFO)
**Roles:** 5 (including CFO)

```
CEO (shared root)
  CFO
    Financial Analyst
    Budget Controller
    Revenue Analyst
```

| Role | Description | Job Spec Summary | Skills (from builtin catalog) |
|------|-------------|------------------|-------------------------------|
| CFO | Owns financial strategy, budgeting, and fiscal governance | Sets financial strategy: budget allocation, cash flow management, revenue forecasting, cost structure optimization, financial risk assessment, board-level financial reporting | financial_analysis, budget_planning, revenue_forecasting, cost_optimization, compliance_reporting |
| Financial Analyst | Produces financial analyses that inform leadership decisions | Analyzes financial statements and trends, calculates key performance ratios, benchmarks against industry averages, models scenarios for strategic decisions, produces monthly financial reports | financial_analysis, data_analysis, report_writing, risk_assessment |
| Budget Controller | Monitors and enforces spending against approved budgets | Tracks actual spend vs. budget across departments, flags overruns and variances, manages budget reallocation requests, produces budget utilization reports, enforces spending policies | budget_planning, cost_optimization, compliance_reporting, progress_reporting |
| Revenue Analyst | Tracks revenue performance and forecasts future growth | Monitors revenue streams and growth rates, builds revenue forecasting models, analyzes customer acquisition costs and lifetime value, tracks conversion funnel metrics, identifies revenue optimization opportunities | revenue_forecasting, data_analysis, market_analysis, report_writing |

**Why this structure:** Finance departments in AI companies focus on the metrics that matter for autonomous operations: budget enforcement (already a core Director feature), cost optimization, and revenue analysis. The CFO sits at C-level making strategic calls; below that, three specialist roles cover the core financial functions. Budget Controller maps naturally to Director's existing budget_cents and spend tracking features.

**Skill mapping notes:** CFO skills already exist in `default_skills.yml`. Financial Analyst and Revenue Analyst use existing research-category skills. New entries needed for: financial_analyst, budget_controller, revenue_analyst.

---

### Department 5: Human Resources

**Reports to:** CEO (via CHRO)
**Roles:** 5 (including CHRO)

```
CEO (shared root)
  CHRO
    Talent Acquisition Lead
    People Operations Manager
    Learning & Development Lead
```

| Role | Description | Job Spec Summary | Skills (from builtin catalog) |
|------|-------------|------------------|-------------------------------|
| CHRO | Sets people strategy, organizational design, and culture standards | Owns people strategy: workforce planning, organizational design, culture definition, performance framework design, agent lifecycle management (onboarding through retirement) | strategic_planning, decision_making, risk_assessment, communication |
| Talent Acquisition Lead | Manages recruitment pipeline and agent onboarding | Defines role requirements, evaluates candidate agents, manages the hiring pipeline, conducts capability assessments, runs onboarding workflows for new agents | requirements_gathering, quality_standards, communication, task_execution |
| People Operations Manager | Runs day-to-day people processes and agent lifecycle operations | Manages agent performance reviews, tracks agent utilization and satisfaction metrics, handles agent reassignment requests, maintains agent capability inventory, runs offboarding processes | project_planning, progress_reporting, documentation, problem_solving |
| Learning & Development Lead | Designs and delivers training programs and skill development | Identifies skill gaps across the organization, designs training curricula and skill-building programs, evaluates training effectiveness, manages the company skill library, recommends new skill additions | experiment_design, documentation, quality_standards, literature_review |

**Why this structure:** HR in an AI agent company means managing agent lifecycles rather than employee benefits. The CHRO role maps to the emerging "HR for agents" function described in industry research -- organizations must create an "HR for agents" function for recruiting, onboarding, evaluating, retraining, and retiring AI agents. Talent Acquisition handles agent sourcing and onboarding. People Ops runs the operational side. L&D manages skill development -- which maps directly to Director's existing skills system.

**Why "CHRO" not "VP HR":** In an AI company, the head of people strategy sits at C-level because agent lifecycle management is a core strategic function, not a support function. This matches the Moderna model (merged tech + HR) and the industry trend of elevating agent management to the C-suite.

**Skill mapping notes:** CHRO uses leadership skills. Other roles use operations + research skills. New entries needed for: chro, talent_acquisition, people_operations, learning_development.

---

## Feature Dependencies

```
Template YAML files
  -> Template Application Service (reads YAML, creates roles)
    -> Role model (title, description, job_spec, parent_id, company_id)
    -> Skill auto-assignment (role_skills via default_skills.yml mappings)
    -> Duplicate detection (find_or_create_by title within company)

Template Preview UI
  -> Template YAML files (read-only parse + render)

CEO Shared Root
  -> All templates depend on CEO existing or being created
  -> CEO is always the root; departments are subtrees under CEO
```

**Key dependency chain:** Templates depend on the existing Role model, Skill model, and the `default_skills.yml` skill-mapping config. No new models are needed. The primary new code is a service that reads template YAML and creates/links roles.

**Prerequisites (already met):**
- Company has builtin skills seeded (v1.2 `Company#after_create`)
- Role model supports hierarchy (v1.0 TreeHierarchy concern)
- RoleSkill join table exists (v1.2)

## Differentiators

Features that set Director's templates apart from manual setup. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Template preview with diff | Show which roles will be created vs. which already exist before applying | Low | Parse YAML, compare against existing company roles |
| Skill-wired roles on creation | Template roles arrive with skills already assigned -- no manual skill setup | Low | Extend default_skills.yml with new role titles |
| Stackable partial application | Apply Engineering now, Marketing later; CEO shared | Low | Idempotent find_or_create_by |
| Job spec content quality | Rich, AI-agent-specific job specs (not generic HR copy) | Medium (content) | Each role needs a multi-paragraph job_spec |
| "Quick start" one-click full company | Apply all 5 departments at once for instant org chart | Low | Loop over all template files |
| Template count badge | Show "3 new roles, 2 existing" before applying | Low | Count new vs. existing |

## Anti-Features

Features to explicitly NOT build in this milestone.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Custom template creation by users | Scope creep; users can already create roles manually | Defer to a future milestone if requested |
| Template marketplace / sharing | Requires user-generated content infrastructure, moderation | Note as future consideration only |
| Template versioning / updates | Templates are applied once; updating applied templates is complex and risky | Templates are seed data, not live-linked; users customize after applying |
| Auto-connecting agents to template roles | Agent connection requires adapter configuration that is user-specific | Roles are created empty; users connect agents at their own pace |
| Goal templates bundled with departments | Goals are company-specific strategy; generic goals would be misleading | Users define goals after seeing their org structure |
| Budget auto-assignment to template roles | Budget amounts are highly context-dependent | Users configure budgets per-role after applying templates |
| Department deletion / rollback | Roles may have agents, tasks, or skills attached after creation | Not safe to bulk-delete; users remove roles individually |
| Nested department templates (sub-departments) | Over-engineering for 3-4 level hierarchies | Keep templates flat: C-suite -> VP -> IC, max 4 levels |
| Partial template application ("just QA Lead") | Adds subtree picker UI complexity for marginal value | Apply full template; user deletes unwanted roles |
| Auto-apply on company creation | Seeding default roles for every new company is presumptuous | Let users browse and choose. Empty company is valid starting state. |
| Template editing/customization before apply | "Adjust titles before applying" adds form complexity | Apply standard template, then edit individual roles via existing edit UI. |

## Content Guidance for Job Specs

Each role's `job_spec` field should follow this structure (matching the quality bar set by existing builtin skill YAML files):

```markdown
## Responsibilities
- 4-6 bullet points describing what this agent does day-to-day
- Written in active voice, specific to AI agent context
- Example: "Review all pull requests within 4 hours of submission"

## Decision Authority
- What this agent can decide autonomously
- What requires escalation to their manager
- Example: "Can approve deployments to staging; production deploys require CTO approval"

## Key Metrics
- 2-4 measurable outcomes this role is accountable for
- Example: "Code review turnaround time < 4 hours, test coverage > 90%"

## Collaboration
- Which roles this agent works with most frequently
- Expected handoff patterns
- Example: "Receives task assignments from VP Engineering, reviews work from Senior Engineers"
```

**Why this format:** It gives agents (and the humans managing them) clear boundaries. The "Decision Authority" section maps directly to Director's approval gate feature. The "Collaboration" section maps to the org chart hierarchy and delegation patterns.

## Mapping to default_skills.yml

The template system needs to extend `config/default_skills.yml` with new role-title-to-skill mappings. All skill keys below already exist in the 48-skill builtin catalog. No new skills need to be created.

**New mappings required (17 total):**

```yaml
vp_engineering:
  - project_planning
  - sprint_management
  - progress_reporting
  - requirements_gathering

tech_lead:
  - code_review
  - implementation
  - system_design
  - debugging
  - documentation

senior_engineer:
  - implementation
  - debugging
  - testing
  - code_review
  - documentation

qa_lead:
  - test_planning
  - bug_reporting
  - regression_testing
  - performance_testing
  - quality_standards

content_strategist:
  - content_strategy
  - documentation
  - report_writing
  - communication

seo_analyst:
  - data_analysis
  - market_analysis
  - audience_research
  - report_writing

social_media_manager:
  - campaign_planning
  - communication
  - audience_research
  - content_strategy

brand_designer:
  - ui_design
  - design_systems
  - prototyping
  - brand_management

coo:
  - project_planning
  - sprint_management
  - progress_reporting
  - decision_making
  - risk_assessment

operations_analyst:
  - data_analysis
  - report_writing
  - problem_solving
  - cost_optimization

process_coordinator:
  - documentation
  - task_execution
  - communication
  - quality_standards

financial_analyst:
  - financial_analysis
  - data_analysis
  - report_writing
  - risk_assessment

budget_controller:
  - budget_planning
  - cost_optimization
  - compliance_reporting
  - progress_reporting

revenue_analyst:
  - revenue_forecasting
  - data_analysis
  - market_analysis
  - report_writing

chro:
  - strategic_planning
  - decision_making
  - risk_assessment
  - communication

talent_acquisition:
  - requirements_gathering
  - quality_standards
  - communication
  - task_execution

people_operations:
  - project_planning
  - progress_reporting
  - documentation
  - problem_solving

learning_development:
  - experiment_design
  - documentation
  - quality_standards
  - literature_review
```

**Existing mappings that already cover template roles (no changes needed):**
- `ceo` -> strategic_planning, decision_making, risk_assessment
- `cto` -> code_review, architecture_planning, technical_strategy, system_design, security_assessment
- `cmo` -> market_analysis, content_strategy, brand_management, campaign_planning, audience_research
- `cfo` -> financial_analysis, budget_planning, revenue_forecasting, cost_optimization, compliance_reporting
- `engineer` -> code_review, implementation, debugging, testing, documentation
- `pm` -> project_planning, requirements_gathering, sprint_management, progress_reporting
- `qa` -> test_planning, bug_reporting, regression_testing, performance_testing, quality_standards
- `devops` -> infrastructure_management, ci_cd_pipelines, monitoring_alerting, deployment_automation, incident_response
- `designer` -> ui_design, ux_research, prototyping, design_systems, accessibility_review
- `researcher` -> data_analysis, literature_review, experiment_design, report_writing, market_analysis

## MVP Recommendation

**Must ship:**
1. Five department YAML template files with full role definitions (title, description, job_spec, skills, parent references)
2. Extended `default_skills.yml` with 17 new role-title-to-skill mappings
3. Template application service (idempotent, stackable, CEO-sharing, wrapped in transaction)
4. Templates index page showing available departments with role count and hierarchy preview
5. "Apply template" action with confirmation and flash summary of created/skipped roles

**Ship together if time permits:**
6. Diff preview showing new-vs-existing roles before applying
7. "Apply all departments" one-click action for instant full company setup
8. Audit events for template application (leverages existing Auditable concern)

**Defer entirely:**
- Custom template creation
- Template marketplace
- Goal templates bundled with departments
- Template versioning

## Role Count Summary

| Department | Roles (excl. shared CEO) | New default_skills mappings needed |
|------------|--------------------------|-------------------------------------|
| Engineering | 6 | 3 (vp_engineering, tech_lead, senior_engineer -- qa_lead can reuse qa; cto/devops already mapped) |
| Marketing | 5 | 4 (content_strategist, seo_analyst, social_media_manager, brand_designer -- cmo already mapped) |
| Operations | 4 | 3 (coo, operations_analyst, process_coordinator -- pm already mapped) |
| Finance | 4 | 3 (financial_analyst, budget_controller, revenue_analyst -- cfo already mapped) |
| HR | 4 | 4 (chro, talent_acquisition, people_operations, learning_development) |
| **Total** | **23 + 1 CEO = 24** | **17 new mappings** |

## Sources

- [Paperclip AI GitHub](https://github.com/paperclipai/paperclip) -- reference architecture for AI agent companies
- [Paperclip Company Wizard Plugin](https://github.com/yesterday-ai/paperclip-plugin-company-wizard) -- template preset patterns (fast, quality, startup, secure, gtm)
- [CrewAI Hierarchical Process Docs](https://docs.crewai.com/en/learn/hierarchical-process) -- manager-agent delegation model
- [Fortune: AI is changing the corporate org chart](https://fortune.com/2025/08/07/ai-corporate-org-chart-workplace-agents-flattening/) -- org flattening trends
- [DEV Community: Solo company with AI agent departments](https://dev.to/setas/i-run-a-solo-company-with-ai-agent-departments-50nf) -- practical department structure (CEO, CFO, COO, CTO, Marketing, Accountant, Lawyer, Improver)
- [Heinz Marketing: AI-Enhanced Org Chart](https://www.heinzmarketing.com/blog/ai-enhanced-marketing-org-chart/) -- Hub-and-Agent marketing model
- [DOJO AI: AI-First Marketing Team Structure 2026](https://www.dojoai.com/blog/ai-first-marketing-team-structure-guide-2025) -- marketing role evolution
- [PWC: AI agents for finance](https://www.pwc.com/us/en/tech-effect/ai-analytics/ai-agents-for-finance.html) -- CFO and finance agent functions
- [HR Executive: AI agents need human managers and job descriptions](https://hrexecutive.com/why-every-ai-agent-needs-a-human-manager-and-clear-job-description/) -- agent lifecycle management
- [MIT Sloan: The Emerging Agentic Enterprise](https://sloanreview.mit.edu/projects/the-emerging-agentic-enterprise-how-leaders-must-navigate-a-new-age-of-ai/) -- cross-functional AI governance
- Existing codebase: `config/default_skills.yml`, `db/seeds/skills/*.yml`, `app/models/role.rb`, `app/models/skill.rb`, `db/schema.rb`
