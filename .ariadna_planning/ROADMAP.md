# Roadmap: Director

## Overview

Director transforms the chaos of managing multiple AI agents into a structured business with org charts, accountability, and cost control. This roadmap builds that capability layer by layer -- starting with identity and tenancy, then organizational structure, then agent connectivity, then the operational machinery (tasks, goals, schedules, budgets, governance), and finally a unified dashboard that ties it all together with real-time updates.

**Product vision:** Users can set up an AI company, assign agents to roles, define goals, set budgets, and walk away -- checking in periodically to approve decisions, review work, and adjust course.
**Building for:** Solo AI builders running multiple agents across providers, small teams prototyping zero-human workflows, and developers who need self-hostable orchestration infrastructure.

## Milestones

- v1.0 Core Platform - Phases 1-10 (shipped 2026-03-28)
- v1.1 SQLite Migration & Cleanup - Phases 11-12 (shipped 2026-03-28)
- v1.2 Agent Skills - Phases 13-17 (shipped 2026-03-28)
- v1.3 Agent Hooks - Phases 18-21 (shipped 2026-03-28)
- v1.4 Agent Execution - Phases 22-25 (shipped 2026-03-28)
- v1.5 Role Templates - Phases 26-28 (shipped 2026-03-30)
- **v1.6 Service Refactor & Cleanup - Phases 29-33 (in progress)**

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

<details>
<summary>v1.3 Agent Hooks (Phases 18-21) - SHIPPED 2026-03-28</summary>

- [x] **Phase 18: Hook Data Foundation** - AgentHook and HookExecution models with lifecycle event configuration and execution tracking
- [x] **Phase 19: Hook Triggering Engine** - Hookable concern detects task transitions and dispatches hooks as background jobs
- [x] **Phase 20: Validation Feedback Loop** - Completed validation subtasks feed results back to the original agent for iterative improvement
- [x] **Phase 21: Hook Management UI** - CRUD controller for creating and managing hooks nested under agents

Full details: [v1.3-ROADMAP.md](milestones/v1.3-ROADMAP.md)

</details>

<details>
<summary>v1.4 Agent Execution (Phases 22-25) - SHIPPED 2026-03-28</summary>

- [x] **Phase 22: AgentRun Data Model and Job Dispatch** - Persistent execution records and real job dispatch
- [x] **Phase 23: HTTP Adapter Real Execution** - Real POST delivery with error classification and retry
- [x] **Phase 24: Claude Local Adapter with Tmux** - Claude CLI via tmux with stream-JSON and session resumption
- [x] **Phase 25: Live Streaming UI and Result Callbacks** - Live output streaming, status broadcasts, cancel, API callbacks

Full details: [v1.4-ROADMAP.md](milestones/v1.4-ROADMAP.md)

</details>

<details>
<summary>v1.5 Role Templates (Phases 26-28) - SHIPPED 2026-03-30</summary>

- [x] **Phase 26: Template Data and Registry** - YAML department definitions and the registry that loads them
- [x] **Phase 27: Template Application Service** - Business logic to create role hierarchies with skill pre-assignment
- [x] **Phase 28: Templates Browse and Apply UI** - User-facing pages to discover, preview, and apply templates

Full details: [v1.5-ROADMAP.md](milestones/v1.5-ROADMAP.md)

</details>

### v1.6 Service Refactor & Cleanup (Phases 29-33) - IN PROGRESS

- [ ] **Phase 29: Roles Domain** - WakeRoleService, GateCheckService, EmergencyStopService relocate to `app/models/roles/`
- [ ] **Phase 30: Hooks & Budgets** - ExecuteHookService, ProcessValidationResultService, BudgetEnforcementService relocate to domain namespaces
- [ ] **Phase 31: Agents, Goals, Heartbeats & Documents** - AiClient, GoalEvaluationService, HeartbeatScheduleManager, CreateDocumentService relocate to domain namespaces
- [ ] **Phase 32: Role Templates** - RoleTemplateRegistry, ApplyRoleTemplateService, ApplyAllRoleTemplatesService relocate to `app/models/role_templates/`
- [ ] **Phase 33: Final Cleanup** - Verify all references updated, all tests pass, delete `app/services/`, address code quality

Full details: [v1.6-ROADMAP.md](milestones/v1.6-ROADMAP.md)

### Phase 29: Roles Domain
**Goal**: Relocate the three role-related services (WakeRoleService, GateCheckService, EmergencyStopService) to `app/models/roles/`
**Why this matters**: WakeRoleService is the most widely depended-on service in the codebase -- it is called by hooks, goals, the triggerable concern, and controllers. Moving it first establishes the foundation that all subsequent phases build on. GateCheckService and EmergencyStopService share the roles domain and have no outward dependencies.
**Depends on**: Nothing (first phase of milestone)
**Requirements**: ROLE-01, ROLE-02, ROLE-03
**Success Criteria** (what must be TRUE):
  1. `Roles::Waking.call(role:, trigger_type:)` works identically to the old `WakeRoleService.call` -- agents still wake on schedule and in response to events
  2. `Roles::GateCheck.check!(role:, action_type:)` correctly pauses actions requiring approval -- governance gates still block unauthorized agent actions
  3. `Roles::EmergencyStop.call!(company:, user:)` pauses all active roles in a company -- the emergency stop button on the company page still works
  4. All callers of the old service names (jobs, controllers, concerns, other services) reference the new namespaced classes
  5. All existing tests pass with the relocated classes
**Plans**: 2/2 complete

Plans:
- [x] 29-01: Relocate WakeRoleService to Roles::Waking and update all 6 callers
- [x] 29-02: Relocate GateCheckService to Roles::GateCheck and EmergencyStopService to Roles::EmergencyStop

### Phase 30: Hooks & Budgets
**Goal**: Relocate ExecuteHookService, ProcessValidationResultService, and BudgetEnforcementService to their respective domain namespaces
**Why this matters**: Hooks are a critical execution path -- they fire on task lifecycle events and trigger agent-to-agent validation. Budget enforcement is the safety gate that prevents runaway spending. Both must work flawlessly after relocation.
**Depends on**: Phase 29 (ExecuteHookService and ProcessValidationResultService both call Roles::Waking)
**Requirements**: HOOK-01, HOOK-02, BUDG-01
**Success Criteria** (what must be TRUE):
  1. `Hooks::Executor.call(execution)` dispatches trigger_agent and webhook hooks identically to the old service -- hook executions still fire on task state changes
  2. `Hooks::ValidationProcessor.call(task)` feeds validation results back to the parent task and wakes the original agent -- the validation feedback loop still works end-to-end
  3. `Budgets::Enforcement.check!(role)` atomically pauses agents that exceed their budget and sends threshold alerts -- budget safety still prevents overspending
  4. All existing tests pass with the relocated classes

### Phase 31: Agents, Goals, Heartbeats & Documents
**Goal**: Relocate AiClient, GoalEvaluationService, HeartbeatScheduleManager, and CreateDocumentService to their domain namespaces
**Why this matters**: These four services span the remaining domains. GoalEvaluationService depends on AiClient (co-moved here) and Roles::Waking (moved in Phase 29), making this the right time to relocate both together. HeartbeatScheduleManager and CreateDocumentService are standalone leaf services with no cross-dependencies.
**Depends on**: Phase 29 (GoalEvaluationService calls Roles::Waking)
**Requirements**: AGNT-01, GOAL-01, BEAT-01, DOCS-01
**Success Criteria** (what must be TRUE):
  1. `Agents::AiClient.chat(system:, prompt:)` communicates with the Anthropic API identically -- goal evaluation still gets AI-generated assessments
  2. `Goals::Evaluation.call(task)` evaluates completed tasks against company goals, records results, and wakes relevant agents -- goal alignment still works after task completion
  3. `Heartbeats::ScheduleManager.sync(role)` creates and removes recurring Solid Queue jobs -- heartbeat schedules still sync when role settings change
  4. `Documents::Creator.call(company:, title:, content:)` creates documents scoped to the company -- document creation still works from all entry points
  5. All existing tests pass with the relocated classes

### Phase 32: Role Templates
**Goal**: Relocate RoleTemplateRegistry, ApplyRoleTemplateService, and ApplyAllRoleTemplatesService to `app/models/role_templates/`
**Why this matters**: The three template services form a tightly coupled chain -- the registry loads templates, the applicator creates individual departments, and the bulk applicator orchestrates full company setup. They must move together to maintain internal coherence.
**Depends on**: Phase 29 (roles/hiring.rb already references RoleTemplateRegistry, but that is in app/models/ already)
**Requirements**: TMPL-01, TMPL-02, TMPL-03
**Success Criteria** (what must be TRUE):
  1. `RoleTemplates::Registry.all` and `RoleTemplates::Registry.find(key)` load and cache YAML templates identically -- the templates browse page still displays all 5 departments
  2. `RoleTemplates::Applicator.call(company:, template_key:)` creates role hierarchies with skill pre-assignment and skip-duplicate logic -- applying a template still creates the correct roles
  3. `RoleTemplates::BulkApplicator.call(company:)` creates all departments under a shared CEO -- the "Apply All" button still sets up a complete company
  4. All callers (role_templates_controller, roles/hiring.rb) reference the new namespaced classes

### Phase 33: Final Cleanup
**Goal**: Verify all references are updated, all tests pass, delete `app/services/`, and address code quality issues discovered during migration
**Why this matters**: The milestone is not complete until the old directory is gone and the codebase is cleaner than we found it. This phase catches any stale references, confirms the full test suite passes, and addresses incidental quality issues.
**Depends on**: Phases 29-32 (all services must be relocated before cleanup)
**Requirements**: CLEN-01, CLEN-02, CLEN-03, CLEN-04
**Success Criteria** (what must be TRUE):
  1. No file in the codebase references any of the 13 old service class names -- grep confirms zero hits
  2. The full test suite passes (`bin/rails test`) with zero failures and zero errors
  3. The `app/services/` directory no longer exists
  4. At least one code quality improvement is made (dead code removal, naming fix, or unused import cleanup discovered during migration)

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9 -> 10 -> 11 -> 12 -> 13 -> 14 -> 15 -> 16 -> 17 -> 18 -> 19 -> 20 -> 21 -> 22 -> 23 -> 24 -> 25 -> 26 -> 27 -> 28 -> 29 -> 30 -> 31 -> 32 -> 33

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
| 21. Hook Management UI | v1.3 | 1/1 | Complete | 2026-03-28 |
| 22. AgentRun Data Model and Job Dispatch | v1.4 | 1/1 | Complete | 2026-03-28 |
| 23. HTTP Adapter Real Execution | v1.4 | 1/1 | Complete | 2026-03-28 |
| 24. Claude Local Adapter with Tmux | v1.4 | 1/1 | Complete | 2026-03-28 |
| 25. Live Streaming UI and Result Callbacks | v1.4 | 3/3 | Complete | 2026-03-28 |
| 26. Template Data and Registry | v1.5 | 2/2 | Complete | 2026-03-29 |
| 27. Template Application Service | v1.5 | 2/2 | Complete | 2026-03-29 |
| 28. Templates Browse and Apply UI | v1.5 | 2/2 | Complete | 2026-03-30 |
| 29. Roles Domain | v1.6 | 2/2 | Complete | 2026-03-30 |
| 30. Hooks & Budgets | v1.6 | 0/0 | Not started | — |
| 31. Agents, Goals, Heartbeats & Documents | v1.6 | 0/0 | Not started | — |
| 32. Role Templates | v1.6 | 0/0 | Not started | — |
| 33. Final Cleanup | v1.6 | 0/0 | Not started | — |
