# Seed Data Design: Director AI Company

## Overview

Replace `db/seeds.rb` with a comprehensive seed script that creates a self-referential company — "Director AI" — whose mission is to make Director the best AI orchestration platform. The seed data populates every major feature: org chart, goal tree, kanban board, budget tracking, governance, audit trail, notifications, and message threads.

## User & Company

- **User:** `admin@director.ai` / `password123` — Owner membership
- **Company:** "Director AI"
- Company creation triggers `seed_default_skills!`, auto-seeding 50 builtin skills from `db/seeds/skills/*.yml`

## Org Chart (12 Agents, 12 Roles)

```
CEO
├── CTO
│   ├── Backend Engineer
│   ├── Frontend Engineer
│   ├── Security Engineer
│   ├── DevOps Engineer
│   └── QA Engineer
├── CMO
│   ├── SEO Specialist
│   └── Content Strategist
└── Product Manager
    └── UX Researcher
```

### Agent Details

| Role Title         | Agent Name         | Adapter      | Status  | Budget  |
|--------------------|--------------------|--------------|---------|---------|
| CEO                | CEO                | claude_local | running | $2,000  |
| CTO                | CTO                | claude_local | running | $1,500  |
| Backend Engineer   | Backend Engineer   | claude_local | running | $800    |
| Frontend Engineer  | Frontend Engineer  | claude_local | running | $800    |
| Security Engineer  | Security Engineer  | claude_local | idle    | $500    |
| DevOps Engineer    | DevOps Engineer    | claude_local | running | $600    |
| QA Engineer        | QA Engineer        | claude_local | idle    | $400    |
| CMO                | CMO                | claude_local | running | $1,200  |
| SEO Specialist     | SEO Specialist     | claude_local | idle    | $300    |
| Content Strategist | Content Strategist | claude_local | running | $500    |
| Product Manager    | Product Manager    | claude_local | running | $1,000  |
| UX Researcher      | UX Researcher      | claude_local | idle    | $400    |

### Skill Assignment Strategy

Role titles map to `config/default_skills.yml` keys where exact matches exist:

- CEO → `ceo` (strategic_planning, company_vision, stakeholder_communication, decision_making, risk_assessment)
- CTO → `cto` (code_review, architecture_planning, technical_strategy, system_design, security_assessment)
- CMO → `cmo` (market_analysis, content_strategy, brand_management, campaign_planning, audience_research)
- Product Manager → `pm` (project_planning, requirements_gathering, sprint_management, stakeholder_communication, progress_reporting)
- Backend/Frontend/Security Engineers → `engineer` (code_review, implementation, debugging, testing, documentation)
- DevOps Engineer → `devops` (infrastructure_management, ci_cd_pipelines, monitoring_alerting, deployment_automation, incident_response)
- QA Engineer → `qa` (test_planning, bug_reporting, regression_testing, performance_testing, quality_standards)
- UX Researcher → `researcher` (data_analysis, literature_review, experiment_design, report_writing, market_analysis)

Skills auto-assign via the `Role#after_save :assign_default_skills_to_agent` callback when agent is linked to role.

For agents without exact `default_skills.yml` matches (SEO Specialist, Content Strategist), manually assign relevant builtin skills after role assignment:

- **SEO Specialist:** content_strategy, market_analysis, data_analysis, audience_research, report_writing
- **Content Strategist:** content_strategy, brand_management, audience_research, documentation, communication

## Goal Tree

```
Mission: Make Director the best AI orchestration platform
├── Objective: Launch public marketing website
│   ├── Build landing page with compelling value proposition
│   ├── Implement SEO strategy for organic growth
│   └── Create content marketing pipeline
├── Objective: Deliver excellent product experience
│   ├── Establish user feedback loop
│   ├── Define and prioritize product roadmap
│   └── Conduct competitive analysis
├── Objective: Build a robust and secure platform
│   ├── Achieve comprehensive test coverage
│   ├── Pass security audit with zero critical findings
│   └── Optimize performance to sub-200ms response times
└── Objective: Ship reliable infrastructure
    ├── Automate CI/CD pipeline
    └── Set up monitoring and alerting
```

4 objectives, 11 sub-objectives. Each sub-objective has tasks assigned to it.

## Tasks (~30 tasks)

### Marketing Tasks

| Title | Status | Priority | Assignee | Cost | Goal | Notes |
|---|---|---|---|---|---|---|
| Design landing page wireframes | completed | high | CMO | $45 | Build landing page | |
| Implement landing page HTML/CSS | in_progress | high | Frontend Engineer | $120 | Build landing page | Has 2 subtasks |
| - Add responsive mobile styles | open | medium | Frontend Engineer | — | Build landing page | Subtask |
| - Optimize hero section images | open | low | Frontend Engineer | — | Build landing page | Subtask |
| Write landing page copy | completed | medium | Content Strategist | $30 | Build landing page | |
| Research target keywords | completed | medium | SEO Specialist | $15 | Implement SEO strategy | |
| Implement meta tags and structured data | in_progress | medium | SEO Specialist | $20 | Implement SEO strategy | |
| Create blog content calendar | open | medium | Content Strategist | — | Create content pipeline | |
| Set up analytics tracking | open | high | CMO | — | Implement SEO strategy | |
| Design email capture flow | blocked | medium | Frontend Engineer | — | Create content pipeline | Blocked by landing page |

### Product Tasks

| Title | Status | Priority | Assignee | Cost | Goal |
|---|---|---|---|---|---|
| Write product requirements document | completed | high | Product Manager | $35 | Define product roadmap |
| Map competitor feature matrix | completed | medium | UX Researcher | $25 | Conduct competitive analysis |
| Conduct user interviews | in_progress | high | UX Researcher | $40 | Establish user feedback loop |
| Prioritize Q2 roadmap | open | urgent | Product Manager | — | Define product roadmap |
| Define success metrics and KPIs | in_progress | medium | Product Manager | $15 | Establish user feedback loop |
| Create user persona documents | open | medium | UX Researcher | — | Establish user feedback loop |

### Engineering Tasks

| Title | Status | Priority | Assignee | Cost | Goal |
|---|---|---|---|---|---|
| Implement API rate limiting | completed | high | Backend Engineer | $60 | Optimize performance |
| Add request input validation | completed | medium | Backend Engineer | $40 | Pass security audit |
| Fix N+1 query on dashboard | in_progress | urgent | Backend Engineer | $25 | Optimize performance |
| Run OWASP dependency scan | completed | high | Security Engineer | $20 | Pass security audit |
| Audit authentication flow | in_progress | urgent | Security Engineer | $35 | Pass security audit |
| Write controller test suite | in_progress | high | QA Engineer | $50 | Achieve test coverage |
| Set up performance benchmarks | open | medium | QA Engineer | — | Optimize performance |
| Refactor CSS to use design tokens | open | low | Frontend Engineer | — | Build landing page |

### DevOps Tasks

| Title | Status | Priority | Assignee | Cost | Goal |
|---|---|---|---|---|---|
| Configure GitHub Actions CI pipeline | completed | high | DevOps Engineer | $30 | Automate CI/CD pipeline |
| Set up staging environment | completed | high | DevOps Engineer | $45 | Automate CI/CD pipeline |
| Implement zero-downtime deploys | in_progress | medium | DevOps Engineer | $55 | Automate CI/CD pipeline |
| Configure error monitoring | open | high | DevOps Engineer | — | Set up monitoring |
| Set up uptime alerting | open | medium | DevOps Engineer | — | Set up monitoring |

### Leadership Tasks

| Title | Status | Priority | Assignee | Cost | Goal |
|---|---|---|---|---|---|
| Review Q1 technical debt report | completed | medium | CTO | $10 | Build robust platform |
| Approve marketing budget allocation | completed | low | CEO | $5 | Launch marketing website |
| Define hiring plan for Q3 | open | medium | CEO | — | Mission (top-level) |

### Status Distribution

- Completed: 12
- In-progress: 8
- Open: 11
- Blocked: 1
- Total: 32 tasks
- Completed costs: $360 (sum of all completed task costs)
- In-progress costs: $360 (sum of all in-progress task costs)

## Message Threads

5 active tasks get message threads with 2-3 messages each, mixing User and Agent authors:

1. **"Fix N+1 query on dashboard"** — Backend Engineer reports issue → CTO asks for impact → Backend Engineer replies with metrics
2. **"Audit authentication flow"** — Security Engineer flags concern → CEO asks for timeline → Security Engineer estimates 2 days
3. **"Conduct user interviews"** — UX Researcher shares initial findings → Product Manager suggests adding more participants
4. **"Implement landing page HTML/CSS"** — Frontend Engineer asks about design specs → CMO links to wireframes → Frontend Engineer confirms approach
5. **"Implement zero-downtime deploys"** — DevOps Engineer proposes blue-green strategy → CTO approves approach

## Approval Gates

| Agent | Gates |
|---|---|
| Backend Engineer | budget_spend, task_creation |
| Security Engineer | status_change, escalation |
| DevOps Engineer | task_delegation, budget_spend |
| CEO | budget_spend |

~10 approval gate records total.

## Audit Events (~15 records)

Backdated timestamps spread over the past 2 weeks for a realistic activity timeline:

- Agent status changes (CEO started running, Security Engineer went idle after scan)
- Gate approvals (CEO approved Backend Engineer budget_spend, CTO approved DevOps task_delegation)
- Gate rejections (CTO rejected an escalation request)
- Cost recordings on completed tasks
- Config change (CTO budget increased from $1,000 to $1,500)
- Emergency stop + resume (QA Engineer paused for config fix, then resumed)

## Notifications (~13 records)

Mix of 8 unread + 5 read notifications for the admin user:

**Unread:**
- Budget threshold alert: Backend Engineer at 75% utilization
- Gate approval request: DevOps Engineer budget_spend pending
- Gate approval request: Security Engineer status_change pending
- Task completed: "Run OWASP dependency scan"
- Task completed: "Set up staging environment"
- Agent status change: Security Engineer went idle
- Agent status change: QA Engineer resumed
- New task assigned: "Prioritize Q2 roadmap"

**Read:**
- Budget allocation approved by CEO
- CTO budget updated
- Gate approved: Backend Engineer budget_spend
- Task completed: "Implement API rate limiting"
- Task completed: "Design landing page wireframes"

## Implementation Details

### File

Single `db/seeds.rb` — full replace of existing file.

### Strategy

1. Wipe all data: `Company.destroy_all` (cascades), `User.destroy_all`, `Session.destroy_all`
2. Create user + company (triggers `seed_default_skills!`) + owner membership
3. Create 12 agents with budgets, statuses, adapter configs
4. Create role hierarchy and assign agents (triggers skill auto-assignment)
5. Manually assign skills to SEO Specialist and Content Strategist
6. Create goal tree (mission → objectives → sub-objectives)
7. Create tasks with assignments, costs, statuses, subtask relationships
8. Create message threads on 5 active tasks
9. Create approval gates
10. Create audit events with backdated timestamps
11. Create notifications (read/unread mix)
12. Print summary: credentials, agent count, task count, goal count

### Data Integrity

- All `create!` calls (fail fast on validation errors)
- No `find_or_create_by` — clean slate each run
- Budget in cents (e.g., $2,000 = 200_000)
- `budget_period_start` set to beginning of current month
- Completed tasks get `completed_at` set via status callback
- All foreign keys respected (company, parent, assignee, goal)
