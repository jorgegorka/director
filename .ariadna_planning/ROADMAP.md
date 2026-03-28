# Roadmap: Director

## Overview

Director transforms the chaos of managing multiple AI agents into a structured business with org charts, accountability, and cost control. This roadmap builds that capability layer by layer -- starting with identity and tenancy, then organizational structure, then agent connectivity, then the operational machinery (tasks, goals, schedules, budgets, governance), and finally a unified dashboard that ties it all together with real-time updates.

**Product vision:** Users can set up an AI company, assign agents to roles, define goals, set budgets, and walk away -- checking in periodically to approve decisions, review work, and adjust course.
**Building for:** Solo AI builders running multiple agents across providers, small teams prototyping zero-human workflows, and developers who need self-hostable orchestration infrastructure.

## Milestones

- v1.0 Core Platform - Phases 1-10 (shipped 2026-03-28)
- v1.1 SQLite Migration & Cleanup - Phases 11-12 (shipped 2026-03-28)
- v1.2 Agent Skills - Phases 13-17 (shipped 2026-03-28)
- v1.3 Agent Hooks - Phases 18-21 (in progress)

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

<details>
<summary>v1.2 Agent Skills (Phases 13-17) - SHIPPED 2026-03-28</summary>

- [x] **Phase 13: Skill Data Model** - Skills and agent_skills tables replace agent_capabilities with tenant-scoped validations
- [x] **Phase 14: Skill Catalog & Seeding** - 50 builtin skill YAML files with company seeding on creation and backfill rake task
- [x] **Phase 15: Role Auto-Assignment** - First agent assignment to a role automatically attaches role-appropriate skills
- [x] **Phase 16: Skills CRUD** - Company skill library management with category filtering and builtin protection
- [x] **Phase 17: Agent Skill Management** - Per-agent skill assignment UI replacing capabilities throughout the application

Full details: [v1.2-ROADMAP.md](milestones/v1.2-ROADMAP.md)

</details>

### v1.3 Agent Hooks (In Progress)

**Milestone Goal:** Configurable agent hook system that fires at task lifecycle events, enabling agent-to-agent validation loops and webhook integrations -- so agents can check each other's work automatically.

- [ ] **Phase 18: Hook Data Foundation** - AgentHook and HookExecution models with lifecycle event configuration and execution tracking
- [ ] **Phase 19: Hook Triggering Engine** - Hookable concern detects task transitions and dispatches hooks as background jobs
- [ ] **Phase 20: Validation Feedback Loop** - Completed validation subtasks feed results back to the original agent for iterative improvement
- [ ] **Phase 21: Hook Management UI** - CRUD controller for creating and managing hooks nested under agents

### Phase 18: Hook Data Foundation
**Goal**: Establish the data layer for agent hooks -- the AgentHook configuration model, the HookExecution tracking model, and updates to existing models that integrate with the hook system
**Why this matters**: Users need to configure per-agent hooks that fire at specific task lifecycle moments. Without the data foundation, there is nothing to trigger, nothing to track, and no way to distinguish hook-originated agent wake calls from other triggers.
**Depends on**: Phase 17 (agents, tasks, heartbeat events all exist)
**Requirements**: DATA-01, DATA-02, DATA-03, UI-03
**Success Criteria** (what must be TRUE):
  1. User can create an AgentHook record for an agent specifying a lifecycle event (e.g., after_task_complete), action type (trigger_agent or webhook), and action configuration -- and it persists correctly
  2. HookExecution records can be created with status tracking (queued/running/completed/failed), input/output payloads, timing fields, and error messages
  3. Deleting an agent cascades to destroy all its hooks and their execution records
  4. HeartbeatEvent trigger_type enum includes hook_triggered, distinguishing hook-originated wake calls from scheduled, task_assigned, and mention triggers
**Plans**: 1/1 complete

Plans:
- [x] 18-01: Migrations, AgentHook model, HookExecution model, existing model updates, fixtures, and tests

### Phase 19: Hook Triggering Engine
**Goal**: Hooks fire automatically when tasks change status -- the Hookable concern detects transitions, finds matching enabled hooks, and dispatches them as background jobs with retry logic
**Why this matters**: This is the automation core. Users configure hooks so that agents validate each other's work or notify external systems automatically. Without the triggering engine, hooks are inert configuration that never fires.
**Depends on**: Phase 18 (hook and execution models exist)
**Requirements**: TRIG-01, TRIG-02, ACT-01, ACT-02, ACT-03
**Success Criteria** (what must be TRUE):
  1. When a task transitions to in_progress or completed, the system automatically enqueues ExecuteHookJob for each matching enabled hook on the assignee agent, ordered by position
  2. trigger_agent hooks create a validation subtask assigned to the target agent and wake that agent via WakeAgentService with hook_triggered context
  3. webhook hooks POST a JSON payload to the configured URL with custom headers and respect configured timeouts
  4. Disabled hooks are skipped, and failed hook executions retry up to 3 times with polynomial backoff before recording a failure
  5. Each hook execution is recorded as a HookExecution with status, payloads, timing, and an audit event for governance
**Plans**: 2/2 complete

Plans:
- [x] 19-01: Hookable concern with task status transition detection and hook enqueueing
- [x] 19-02: ExecuteHookService and ExecuteHookJob with trigger_agent and webhook dispatch

### Phase 20: Validation Feedback Loop
**Goal**: When a validation subtask completes, its results are automatically fed back to the original agent -- closing the loop so Agent A's work gets validated by Agent B and Agent A can iterate
**Why this matters**: The feedback loop is what makes agent-to-agent validation useful rather than fire-and-forget. Without it, Agent B validates but Agent A never sees the results. This is the "iterative improvement" capability that lets users trust agent quality.
**Depends on**: Phase 19 (validation subtasks are created by trigger_agent hooks)
**Requirements**: TRIG-03, FEED-01, FEED-02, FEED-03
**Success Criteria** (what must be TRUE):
  1. When a validation subtask with a parent task completes, ProcessValidationResultJob is automatically enqueued
  2. The service collects messages from the validation subtask and posts a feedback message on the parent task, so the original agent's conversation thread contains the validation results
  3. The original agent is woken with review_validation context after feedback is posted, enabling it to read and act on the validation
  4. Audit events are recorded for both hook_executed (from Phase 19) and validation_feedback_received, providing a complete governance trail for the entire hook-validate-feedback cycle
**Plans**: 1/1 complete

Plans:
- [x] 20-01: ProcessValidationResultService, ProcessValidationResultJob, feedback message posting, agent wake, and audit events

### Phase 21: Hook Management UI
**Goal**: Users can create, edit, and delete agent hooks through the web interface with proper company scoping
**Why this matters**: Without a management UI, users would need console access to configure hooks. The CRUD controller lets any user set up validation workflows and webhook integrations from the agent page -- making hooks accessible to non-technical users.
**Depends on**: Phase 18 (models), Phase 19 (hooks actually fire when configured)
**Requirements**: UI-01, UI-02
**Success Criteria** (what must be TRUE):
  1. User can navigate to an agent's hooks page, create a new hook with lifecycle event and action configuration, and see it listed
  2. User can edit an existing hook (change event, action type, enable/disable) and delete hooks they no longer need
  3. Hooks are scoped to the owning company -- users cannot see or modify hooks belonging to agents in other companies
**Plans**: TBD

Plans:
- [ ] 21-01: Routes, AgentHooksController CRUD, views, company scoping, and controller tests

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9 -> 10 -> 11 -> 12 -> 13 -> 14 -> 15 -> 16 -> 17 -> 18 -> 19 -> 20 -> 21

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
| 15. Role Auto-Assignment | v1.2 | 1/1 | Complete | 2026-03-28 |
| 16. Skills CRUD | v1.2 | 2/2 | Complete | 2026-03-28 |
| 17. Agent Skill Management | v1.2 | 2/2 | Complete | 2026-03-28 |
| 18. Hook Data Foundation | v1.3 | 1/1 | Complete | 2026-03-28 |
| 19. Hook Triggering Engine | v1.3 | 2/2 | Complete | 2026-03-28 |
| 20. Validation Feedback Loop | v1.3 | 1/1 | Complete | 2026-03-28 |
| 21. Hook Management UI | v1.3 | 0/1 | Not started | - |
