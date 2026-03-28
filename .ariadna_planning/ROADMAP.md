# Roadmap: Director

## Overview

Director transforms the chaos of managing multiple AI agents into a structured business with org charts, accountability, and cost control. This roadmap builds that capability layer by layer -- starting with identity and tenancy, then organizational structure, then agent connectivity, then the operational machinery (tasks, goals, schedules, budgets, governance), and finally a unified dashboard that ties it all together with real-time updates.

**Product vision:** Users can set up an AI company, assign agents to roles, define goals, set budgets, and walk away -- checking in periodically to approve decisions, review work, and adjust course.
**Building for:** Solo AI builders running multiple agents across providers, small teams prototyping zero-human workflows, and developers who need self-hostable orchestration infrastructure.

## Milestones

- v1.0 Core Platform - Phases 1-10 (shipped 2026-03-28)
- v1.1 SQLite Migration & Cleanup - Phases 11-12 (shipped 2026-03-28)
- v1.2 Agent Skills - Phases 13-17 (in progress)

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

<details>
<summary>v1.0 Core Platform (Phases 1-10) - SHIPPED 2026-03-28</summary>

- [x] **Phase 1: Authentication** - Users can create accounts, log in, and manage credentials
- [x] **Phase 2: Accounts & Multi-tenancy** - Users can create isolated companies with team access
- [x] **Phase 3: Org Chart & Roles** - Users can define company structure with hierarchical roles
- [x] **Phase 4: Agent Connection** - Users can register and monitor AI agents via HTTP or bash
- [x] **Phase 5: Tasks & Conversations** - Users can assign work to agents with threaded discussion and audit trails
- [x] **Phase 6: Goals & Alignment** - Users can define company mission and trace all work back to objectives
- [x] **Phase 7: Heartbeats & Triggers** - Agents wake on schedule or in response to events
- [x] **Phase 8: Budget & Cost Control** - Users can enforce per-agent spending limits with atomic enforcement
- [x] **Phase 9: Governance & Audit** - Users can gate high-impact actions, control agents, and audit everything
- [x] **Phase 10: Dashboard & Real-time UI** - Users get a unified command center with live updates

### Phase 1: Authentication
**Goal**: Users can securely create and manage their accounts
**Why this matters**: Identity is the foundation -- users need accounts before they can own companies, manage agents, or control budgets. Without auth, nothing else can be scoped or secured.
**Depends on**: Nothing (first phase)
**Requirements**: AUTH-01, AUTH-02, AUTH-03, AUTH-04
**Success Criteria** (what must be TRUE):
  1. User can sign up with email and password and land on a logged-in page
  2. User can log out and log back in, with session persisting across browser refresh
  3. User can request a password reset email and use the link to set a new password
  4. User can change their email and password from an account settings page
**Plans**: 2/2 complete

Plans:
- [x] 01-01: Authentication foundation (PostgreSQL, auth generator, registration, home page)
- [x] 01-02: Account settings and controller tests

### Phase 2: Accounts & Multi-tenancy
**Goal**: Users can create and manage isolated companies, each functioning as an independent tenant
**Why this matters**: The multi-company model is core to Director -- solo builders run multiple AI companies, and teams need isolation between projects. Every feature after this is scoped to a company.
**Depends on**: Phase 1
**Requirements**: ACCT-01, ACCT-02, ACCT-03
**Success Criteria** (what must be TRUE):
  1. User can create a new company and see it listed in their account
  2. User can invite a team member by email, and that person can accept and access the company
  3. Company data is fully isolated -- members of one company cannot see another company's data
  4. Owner, admin, and member roles exist with appropriate access boundaries (e.g., only owner can delete company)
**Plans**: 2/2 complete

Plans:
- [x] 02-01: Multi-tenancy foundation (Company/Membership models, tenant switching, company switcher UI)
- [x] 02-02: Invitation system (token-based invitations, role authorization, acceptance flow)

### Phase 3: Org Chart & Roles
**Goal**: Users can define their AI company's organizational structure with roles, hierarchy, and visual representation
**Why this matters**: The org chart is what makes Director more than a task list -- it models a real company structure where agents have positions, reporting lines, and job specs that determine what work they handle.
**Depends on**: Phase 2
**Requirements**: ORG-01, ORG-02, ORG-03, ORG-04
**Success Criteria** (what must be TRUE):
  1. User can create roles with title, description, and job spec within a company
  2. User can arrange roles in a hierarchy with parent/child reporting lines
  3. User can assign an agent to a role (placeholder -- agents connected in Phase 4)
  4. Company org chart renders as a visual tree showing roles, hierarchy, and assignments
**Plans**: 2/2 complete

Plans:
- [x] 03-01: Role model with hierarchy, CRUD controller, views, and tests
- [x] 03-02: Visual SVG org chart with Stimulus tree layout and controller tests

### Phase 4: Agent Connection
**Goal**: Users can connect external AI agents to Director and monitor their status
**Why this matters**: BYOA (Bring Your Own Agent) is the integration model -- users are already running agents across Claude Code, Codex, Cursor, and others. This phase makes Director the single pane of glass for all of them.
**Depends on**: Phase 2 (agents belong to companies), Phase 3 (agents assigned to roles)
**Requirements**: AGNT-01, AGNT-02, AGNT-03, AGNT-04
**Success Criteria** (what must be TRUE):
  1. User can register an agent via HTTP API endpoint configuration and see it appear in the company
  2. User can register an agent via bash command configuration for local agents
  3. System displays agent status (online/offline/error) and updates it based on health checks
  4. Agents can declare capabilities/skills on registration, visible in the agent profile
**Plans**: 3/3 complete

Plans:
- [x] 04-01: Agent model, adapters (HTTP + Bash), API token, status enum, capabilities jsonb
- [x] 04-02: AgentsController CRUD, adapter config UI, Stimulus adapter toggle
- [x] 04-03: Health check service, agent skills API, role agent_name population

### Phase 5: Tasks & Conversations
**Goal**: Users can create, assign, and track units of work with full conversation history and audit trail
**Why this matters**: Tasks are the core work unit -- without them, agents have nothing to do. Threaded conversations let agents report progress and collaborate, while the audit trail ensures accountability for autonomous operations.
**Depends on**: Phase 3 (org chart for delegation), Phase 4 (agents to assign tasks to)
**Requirements**: TASK-01, TASK-02, TASK-03, TASK-04
**Success Criteria** (what must be TRUE):
  1. User can create a task, assign it to an agent, and see it in a task list
  2. Tasks have threaded conversation where agents and humans can post messages
  3. Agents can delegate tasks down the org chart to subordinates or escalate up to managers
  4. Every task action (creation, assignment, status change, delegation) is recorded in an immutable audit trail viewable by the user
**Plans**: 3/3 complete

Plans:
- [x] 05-01: Task, Message, AuditEvent models with Auditable concern and Agent api_token
- [x] 05-02: TasksController CRUD, MessagesController, conversation thread UI, audit trail display
- [x] 05-03: Delegation/escalation with dual auth (session + Bearer), org chart validation

### Phase 6: Goals & Alignment
**Goal**: Users can define a company mission and connect all work to it through a goal hierarchy
**Why this matters**: Goals prevent agent drift -- when agents operate autonomously, every task should trace back to a company objective. This is how users maintain strategic control even when they step away.
**Depends on**: Phase 2 (company-level mission), Phase 5 (tasks as leaf nodes)
**Requirements**: GOAL-01, GOAL-02, GOAL-03
**Success Criteria** (what must be TRUE):
  1. User can set a company mission (top-level goal) and see it displayed prominently
  2. User can create a hierarchy of objectives under the mission, and assign tasks under objectives
  3. Dashboard shows goal progress that rolls up from task completion -- user can see what percentage of an objective is done
**Plans**: 2/2 complete

Plans:
- [x] 06-01: Goal model with self-referential tree hierarchy, task goal_id FK, recursive progress roll-up
- [x] 06-02: GoalsController CRUD, goal tree views, home mission display, task form goal linking

### Phase 7: Heartbeats & Triggers
**Goal**: Agents wake on configurable schedules and respond to events like task assignments or mentions
**Why this matters**: This is what makes agents autonomous rather than manually triggered -- scheduled heartbeats let agents check for work periodically, and event triggers let them respond immediately to new assignments. Without this, users would have to manually poke every agent.
**Depends on**: Phase 4 (agents), Phase 5 (tasks for event triggers)
**Requirements**: BEAT-01, BEAT-02, BEAT-03, BEAT-04
**Success Criteria** (what must be TRUE):
  1. User can configure a heartbeat schedule for an agent (e.g., every 15 minutes) and see the agent wake on that schedule
  2. Agent wakes immediately when a task is assigned to it or it is @mentioned in a conversation
  3. Heartbeat history is logged and viewable -- user can see when each agent last woke and what actions it took
  4. Different agents can have different wake conditions configured independently
**Plans**: 3/3 complete

Plans:
- [x] 07-01: HeartbeatEvent model, Agent schedule columns, WakeAgentService, AgentHeartbeatJob, HeartbeatScheduleManager
- [x] 07-02: Triggerable concern (task assignment + @mention callbacks), Agent events polling API
- [x] 07-03: HeartbeatsController, heartbeat history view, agent form schedule fieldset, agent show heartbeat section

### Phase 8: Budget & Cost Control
**Goal**: Users can set and enforce per-agent spending limits with full cost visibility
**Why this matters**: Budget enforcement is the core safety feature -- users will not trust autonomous agents with real work until they know spending cannot run away. This is what lets users "walk away and check in periodically" with confidence.
**Depends on**: Phase 4 (per-agent budgets), Phase 5 (per-task cost tracking)
**Requirements**: BUDG-01, BUDG-02, BUDG-03, BUDG-04
**Success Criteria** (what must be TRUE):
  1. User can set a monthly budget for each agent and see current spend vs. limit
  2. When an agent's budget is exhausted, the system atomically stops the agent -- no further actions until budget is replenished or increased
  3. Costs are tracked and displayed per task and per session so the user can see what each piece of work cost
  4. User receives an alert (in-app notification) before an agent's budget limit is reached (e.g., at 80%)
**Plans**: 4/4 complete

Plans:
- [x] 08-01: Budget data layer (budget_cents on Agent, cost_cents on Task, Notification model, budget calculation methods)
- [x] 08-02: BudgetEnforcementService (atomic pause on exhaustion, 80% threshold alerts, cost reporting API)
- [x] 08-03: Budget UI (agent form budget fieldset, spend bar visualization, task cost display)
- [x] 08-04: Notification bell UI (header bell icon, dropdown, mark-read actions, Stimulus toggle)

### Phase 9: Governance & Audit
**Goal**: Users can control agent autonomy through approval gates, kill switches, and comprehensive audit logging
**Why this matters**: Governance is what separates "agents running wild" from "agents running a company." Approval gates let users keep humans in the loop for critical decisions, kill switches provide emergency control, and audit logs provide the accountability needed to trust autonomous operations.
**Depends on**: Phase 4 (agent control), Phase 5 (action logging infrastructure)
**Requirements**: GOVR-01, GOVR-02, GOVR-03, GOVR-04
**Success Criteria** (what must be TRUE):
  1. User can define approval gates that pause an agent before high-impact actions and require human approval to proceed
  2. User can pause, resume, or terminate any agent at any time from any page where the agent appears
  3. All actions across the system are recorded in an immutable audit log that the user can browse and filter
  4. Configuration changes (role edits, budget changes, gate modifications) are versioned and the user can roll back to a previous version
**Plans**: 4/4 complete

Plans:
- [x] 09-01: Governance data layer (ApprovalGate, ConfigVersion, AuditEvent company scope, EmergencyStopService)
- [x] 09-02: GateCheckService, approval flow, emergency stop, agent control actions
- [x] 09-03: Governance UI (emergency stop button, gate fieldset, notification helper, gate sync)
- [x] 09-04: Audit log page with filters and config version history with diff display and rollback

### Phase 10: Dashboard & Real-time UI
**Goal**: Users get a unified command center with live updates showing company health at a glance
**Why this matters**: The dashboard is the "check in periodically" experience from the product vision -- it is the primary interface for users who have set up their AI company and want to monitor operations without diving into individual agents or tasks.
**Depends on**: All previous phases (aggregates data from every domain)
**Requirements**: DASH-01, DASH-02, DASH-03, DASH-04
**Success Criteria** (what must be TRUE):
  1. Company overview dashboard shows agents, active tasks, and budget status in a single view
  2. Task board view (kanban or list) lets the user manage all work in one place with drag-and-drop or status toggles
  3. Agent activity feed shows conversation threads and recent actions per agent
  4. Dashboard updates in real time via Turbo Streams -- agent status changes, new tasks, and budget alerts appear without page refresh
**Plans**: 4/4 complete

Plans:
- [x] 10-01: Dashboard controller, tabbed layout, Overview tab with company stats and budget cards
- [x] 10-02: Kanban task board with drag-and-drop between 5 status columns
- [x] 10-03: Activity timeline with agent filter and audit event display
- [x] 10-04: Real-time Turbo Stream broadcasts for live dashboard updates

</details>

<details>
<summary>v1.1 SQLite Migration & Cleanup (Phases 11-12) - SHIPPED 2026-03-28</summary>

- [x] **Phase 11: SQLite Migration** - Primary database switches from PostgreSQL to SQLite
- [x] **Phase 12: Cleanup & Verification** - Docs, dead code, and test suite aligned with the new stack

Full details: [v1.1-ROADMAP.md](milestones/v1.1-ROADMAP.md)

</details>

### v1.2 Agent Skills (In Progress)

**Milestone Goal:** Add a company-level skill library with rich markdown instruction packages, role-based auto-assignment, and full CRUD -- replacing the existing agent_capabilities system.

- [x] **Phase 13: Skill Data Model** - Skills and agent_skills tables replace agent_capabilities with tenant-scoped validations
- [x] **Phase 14: Skill Catalog & Seeding** - 50 builtin skill YAML files with company seeding on creation and backfill rake task
- [ ] **Phase 15: Role Auto-Assignment** - First agent assignment to a role automatically attaches role-appropriate skills
- [ ] **Phase 16: Skills CRUD** - Company skill library management with category filtering and builtin protection
- [ ] **Phase 17: Agent Skill Management** - Per-agent skill assignment UI replacing capabilities throughout the application

#### Phase 13: Skill Data Model
**Goal**: Create the skills and agent_skills tables, models with validations, and replace agent_capabilities associations on Agent
**Why this matters**: Skills are how agents know what they can do -- rich instruction packages instead of bare labels. This foundation replaces the placeholder capability system with a real skill library that agents can draw from when performing work.
**Depends on**: Phase 4 (Agent model), Phase 2 (Company/tenancy)
**Requirements**: DATA-01, DATA-02, DATA-03, DATA-04, DATA-05, DATA-06
**Success Criteria** (what must be TRUE):
  1. Skill records can be created for a company with key, name, description, markdown content, category, and builtin flag
  2. Agent can be linked to skills through agent_skills join records, and the association is queryable (agent.skills returns Skill records)
  3. Key uniqueness is enforced per company -- two companies can have the same skill key, but one company cannot have duplicates
  4. Agent skill assignments are validated to prevent cross-company links (agent and skill must belong to the same company)
  5. The agent_capabilities table and AgentCapability model no longer exist
**Plans**: 2/2 complete

Plans:
- [x] 13-01: Skills and AgentSkills tables, models, validations, scopes, fixtures, tests
- [x] 13-02: Drop agent_capabilities, wire skill associations, update views/routes/tests

#### Phase 14: Skill Catalog & Seeding
**Goal**: Create 44 builtin skill YAML files with meaningful markdown instruction content, a role-to-skills mapping config, and seeding logic for new and existing companies
**Why this matters**: A pre-built catalog of 44 curated skills is what makes Director immediately useful -- new companies start with a full skill library instead of building from scratch, and existing companies can backfill with a single command.
**Depends on**: Phase 13 (Skill model and table)
**Requirements**: SEED-01, SEED-02, SEED-03, SEED-04
**Success Criteria** (what must be TRUE):
  1. 44 individual YAML files exist in db/seeds/skills/, each containing key, name, description, category, and multi-paragraph markdown instructions
  2. config/default_skills.yml maps 11 role titles to arrays of skill keys, covering all 44 skills
  3. When a new company is created, all 44 builtin skills are automatically seeded into that company's skill library
  4. Running `bin/rails skills:reseed` creates all missing builtin skills for every existing company without duplicating or overwriting already-present skills
**Plans**: 2/2 complete

Plans:
- [x] 14-01: Skill YAML catalog (50 files in db/seeds/skills/) and config/default_skills.yml role mapping
- [x] 14-02: Company#seed_default_skills! method, after_create callback, skills:reseed rake task, tests

#### Phase 15: Role Auto-Assignment
**Goal**: When an agent is first assigned to a role, the system automatically attaches that role's default skills to the agent
**Why this matters**: Auto-assignment removes a tedious manual step -- when a user assigns an agent to a CTO role, the agent immediately gains code review, architecture planning, and technical strategy skills without the user having to configure each one.
**Depends on**: Phase 13 (AgentSkill model), Phase 14 (seeded skills and default_skills.yml mapping)
**Requirements**: AUTO-01, AUTO-02, AUTO-03
**Success Criteria** (what must be TRUE):
  1. Assigning an agent to a role for the first time (role had no agent before) automatically creates agent_skill records for that role's default skills
  2. Reassigning a role from one agent to another does not trigger auto-assignment on the new agent
  3. If a role title is not in the defaults mapping, or a mapped skill key does not exist in the company, the system proceeds silently without errors
**Plans**: TBD

Plans:
- [ ] 15-01: TBD

#### Phase 16: Skills CRUD
**Goal**: Full controller and views for managing the company's skill library with category filtering and builtin protection
**Why this matters**: Companies need to browse, customize, and extend their skill catalog -- editing builtin skill instructions to match their specific workflows, and creating entirely new custom skills for capabilities unique to their operation.
**Depends on**: Phase 13 (Skill model)
**Requirements**: CRUD-01, CRUD-02, CRUD-03, CRUD-04, ROUT-01
**Success Criteria** (what must be TRUE):
  1. User can browse all skills in the company library, with the list filterable by category (leadership, technical, creative, operations, research)
  2. User can view a skill's full markdown content and see which agents have that skill assigned
  3. User can edit any skill (including builtin skills) to customize the instruction content for their company
  4. User can create new custom skills (marked builtin: false) and destroy custom skills, but cannot destroy builtin skills
  5. Skill routes are active and capability routes are removed from the application
**Plans**: TBD

Plans:
- [ ] 16-01: TBD

#### Phase 17: Agent Skill Management
**Goal**: Per-agent skill assignment and removal UI, with agent views updated to show skills instead of capabilities
**Why this matters**: This is the hands-on interface where users fine-tune which skills each agent has -- adding specialized skills beyond the auto-assigned defaults, or removing skills that do not apply to a particular agent's work.
**Depends on**: Phase 13 (AgentSkill model), Phase 16 (skill routes and views)
**Requirements**: ASKL-01, ASKL-02, ASKL-03, ROUT-02
**Success Criteria** (what must be TRUE):
  1. User can assign a skill from the company library to an agent, and remove a skill from an agent, via the agent's page
  2. Agent show page displays the agent's assigned skills (with names and categories) instead of the old capabilities list
  3. Agent card/partial throughout the application shows skills instead of capabilities
  4. Nested agent skill routes (create/destroy) are active and RESTful
**Plans**: TBD

Plans:
- [ ] 17-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9 -> 10 -> 11 -> 12 -> 13 -> 14 -> 15 -> 16 -> 17

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Authentication | v1.0 | 2/2 | Complete | 2026-03-26 |
| 2. Accounts & Multi-tenancy | v1.0 | 2/2 | Complete | 2026-03-26 |
| 3. Org Chart & Roles | v1.0 | 2/2 | Complete | 2026-03-27 |
| 4. Agent Connection | v1.0 | 3/3 | Complete | 2026-03-27 |
| 5. Tasks & Conversations | v1.0 | 3/3 | Complete | 2026-03-27 |
| 6. Goals & Alignment | v1.0 | 2/2 | Complete | 2026-03-27 |
| 7. Heartbeats & Triggers | v1.0 | 3/3 | Complete | 2026-03-27 |
| 8. Budget & Cost Control | v1.0 | 4/4 | Complete | 2026-03-27 |
| 9. Governance & Audit | v1.0 | 4/4 | Complete | 2026-03-27 |
| 10. Dashboard & Real-time UI | v1.0 | 4/4 | Complete | 2026-03-28 |
| 11. SQLite Migration | v1.1 | 2/2 | Complete | 2026-03-28 |
| 12. Cleanup & Verification | v1.1 | 1/1 | Complete | 2026-03-28 |
| 13. Skill Data Model | v1.2 | 2/2 | Complete | 2026-03-28 |
| 14. Skill Catalog & Seeding | v1.2 | 2/2 | Complete | 2026-03-28 |
| 15. Role Auto-Assignment | v1.2 | 0/TBD | Not started | - |
| 16. Skills CRUD | v1.2 | 0/TBD | Not started | - |
| 17. Agent Skill Management | v1.2 | 0/TBD | Not started | - |
