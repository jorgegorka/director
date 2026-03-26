# Roadmap: Director

## Overview

Director transforms the chaos of managing multiple AI agents into a structured business with org charts, accountability, and cost control. This roadmap builds that capability layer by layer -- starting with identity and tenancy, then organizational structure, then agent connectivity, then the operational machinery (tasks, goals, schedules, budgets, governance), and finally a unified dashboard that ties it all together with real-time updates.

**Product vision:** Users can set up an AI company, assign agents to roles, define goals, set budgets, and walk away -- checking in periodically to approve decisions, review work, and adjust course.
**Building for:** Solo AI builders running multiple agents across providers, small teams prototyping zero-human workflows, and developers who need self-hostable orchestration infrastructure.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Authentication** - Users can create accounts, log in, and manage credentials
- [x] **Phase 2: Accounts & Multi-tenancy** - Users can create isolated companies with team access
- [ ] **Phase 3: Org Chart & Roles** - Users can define company structure with hierarchical roles
- [ ] **Phase 4: Agent Connection** - Users can register and monitor AI agents via HTTP or bash
- [ ] **Phase 5: Tasks & Conversations** - Users can assign work to agents with threaded discussion and audit trails
- [ ] **Phase 6: Goals & Alignment** - Users can define company mission and trace all work back to objectives
- [ ] **Phase 7: Heartbeats & Triggers** - Agents wake on schedule or in response to events
- [ ] **Phase 8: Budget & Cost Control** - Users can enforce per-agent spending limits with atomic enforcement
- [ ] **Phase 9: Governance & Audit** - Users can gate high-impact actions, control agents, and audit everything
- [ ] **Phase 10: Dashboard & Real-time UI** - Users get a unified command center with live updates

## Phase Details

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
**Plans**: TBD

Plans:
- [ ] 03-01: TBD
- [ ] 03-02: TBD

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
**Plans**: TBD

Plans:
- [ ] 04-01: TBD
- [ ] 04-02: TBD
- [ ] 04-03: TBD

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
**Plans**: TBD

Plans:
- [ ] 05-01: TBD
- [ ] 05-02: TBD
- [ ] 05-03: TBD

### Phase 6: Goals & Alignment
**Goal**: Users can define a company mission and connect all work to it through a goal hierarchy
**Why this matters**: Goals prevent agent drift -- when agents operate autonomously, every task should trace back to a company objective. This is how users maintain strategic control even when they step away.
**Depends on**: Phase 2 (company-level mission), Phase 5 (tasks as leaf nodes)
**Requirements**: GOAL-01, GOAL-02, GOAL-03
**Success Criteria** (what must be TRUE):
  1. User can set a company mission (top-level goal) and see it displayed prominently
  2. User can create a hierarchy of objectives under the mission, and assign tasks under objectives
  3. Dashboard shows goal progress that rolls up from task completion -- user can see what percentage of an objective is done
**Plans**: TBD

Plans:
- [ ] 06-01: TBD
- [ ] 06-02: TBD

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
**Plans**: TBD

Plans:
- [ ] 07-01: TBD
- [ ] 07-02: TBD
- [ ] 07-03: TBD

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
**Plans**: TBD

Plans:
- [ ] 08-01: TBD
- [ ] 08-02: TBD

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
**Plans**: TBD

Plans:
- [ ] 09-01: TBD
- [ ] 09-02: TBD
- [ ] 09-03: TBD

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
**Plans**: TBD

Plans:
- [ ] 10-01: TBD
- [ ] 10-02: TBD
- [ ] 10-03: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9 -> 10

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Authentication | 2/2 | Complete | 2026-03-26 |
| 2. Accounts & Multi-tenancy | 2/2 | Complete | 2026-03-26 |
| 3. Org Chart & Roles | 0/TBD | Not started | - |
| 4. Agent Connection | 0/TBD | Not started | - |
| 5. Tasks & Conversations | 0/TBD | Not started | - |
| 6. Goals & Alignment | 0/TBD | Not started | - |
| 7. Heartbeats & Triggers | 0/TBD | Not started | - |
| 8. Budget & Cost Control | 0/TBD | Not started | - |
| 9. Governance & Audit | 0/TBD | Not started | - |
| 10. Dashboard & Real-time UI | 0/TBD | Not started | - |
