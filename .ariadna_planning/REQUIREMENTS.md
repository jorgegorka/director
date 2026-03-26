# Requirements: Director

**Defined:** 2026-03-26
**Core Value:** Users can organize AI agents into a functioning company structure and confidently let them work autonomously — knowing budgets are enforced, tasks are tracked, and humans retain control through governance.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Authentication

- [ ] **AUTH-01**: User can sign up with email and password — *enables account creation*
- [ ] **AUTH-02**: User can log in and session persists across browser refresh — *removes friction from daily use*
- [ ] **AUTH-03**: User can reset password via email link — *self-service recovery*
- [ ] **AUTH-04**: User can update email and password from account settings — *basic account management*

### Accounts & Multi-tenancy

- [ ] **ACCT-01**: User can create companies (each is an isolated tenant) — *core multi-company model*
- [ ] **ACCT-02**: User can invite team members to a company via email — *enables collaboration*
- [ ] **ACCT-03**: Company has role-based access: owner, admin, member — *governance over who can do what*

### Org Chart & Roles

- [ ] **ORG-01**: User can create and edit roles with title, description, and job spec — *defines positions in the AI company*
- [ ] **ORG-02**: User can assign agents to roles — *hiring agents into positions*
- [ ] **ORG-03**: Roles have hierarchical reporting lines (parent/child) — *delegation chains and escalation paths*
- [ ] **ORG-04**: Company org chart renders as a visual tree — *see the company structure at a glance*

### Agent Connection (BYOA)

- [ ] **AGNT-01**: User can register agents via HTTP API endpoints — *connect cloud-hosted agents*
- [ ] **AGNT-02**: User can register agents via bash command execution — *connect local agents*
- [ ] **AGNT-03**: System monitors agent status (online/offline/error) — *know which agents are alive*
- [ ] **AGNT-04**: Agents declare capabilities/skills on registration — *match agents to appropriate tasks*

### Task & Ticket System

- [ ] **TASK-01**: User can create tasks and assign them to agents — *the basic unit of work*
- [ ] **TASK-02**: Tasks have threaded conversation history — *agents discuss and report progress*
- [ ] **TASK-03**: Agents can delegate tasks down the org chart or escalate up — *work flows through hierarchy*
- [ ] **TASK-04**: All task actions logged with immutable audit trail — *full history of what happened and why*

### Goal Alignment

- [ ] **GOAL-01**: Company has a mission/top-level goal — *the north star all work traces to*
- [ ] **GOAL-02**: Goals form a hierarchy: mission > objectives > tasks — *every task carries full goal ancestry*
- [ ] **GOAL-03**: Dashboard shows goal progress rolling up from tasks — *see how work maps to objectives*

### Heartbeat & Triggers

- [ ] **BEAT-01**: Agents have configurable heartbeat schedule — *periodic wake to check for work*
- [ ] **BEAT-02**: Agents wake on events: task assigned, @mentioned — *immediate response to new work*
- [ ] **BEAT-03**: Heartbeat history logged with actions taken — *see when agents woke and what they did*
- [ ] **BEAT-04**: Per-agent configurable wake conditions — *different agents respond to different triggers*

### Budget & Cost Control

- [ ] **BUDG-01**: User can set monthly budget per agent — *spending limits for each agent*
- [ ] **BUDG-02**: Budget enforcement is atomic: agent stops when exhausted — *prevents runaway spend*
- [ ] **BUDG-03**: Cost tracked per task and per session — *see what each piece of work cost*
- [ ] **BUDG-04**: Budget alerts notify before limit is reached — *proactive cost management*

### Governance

- [ ] **GOVR-01**: Approval gates pause agent before high-impact actions — *humans control critical decisions*
- [ ] **GOVR-02**: User can pause, resume, or terminate any agent — *kill switch for agents*
- [ ] **GOVR-03**: All actions recorded in immutable audit log — *accountability for every decision*
- [ ] **GOVR-04**: Configuration changes are versioned with rollback — *undo bad changes*

### Dashboard & UI

- [ ] **DASH-01**: Company overview dashboard (agents, tasks, budgets at a glance) — *bird's-eye view*
- [ ] **DASH-02**: Task board view (kanban or list) — *manage all work in one place*
- [ ] **DASH-03**: Agent activity feed with conversation threads — *see what agents are saying and doing*
- [ ] **DASH-04**: Real-time updates via Turbo Streams — *live agent status and task changes*

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Multi-Company

- **MCMP-01**: User can switch between companies from a single account
- **MCMP-02**: Company-level billing and usage reports

### Plugins & Extensions

- **PLUG-01**: Plugin system for extending agent capabilities
- **PLUG-02**: Knowledge base plugins for agent context
- **PLUG-03**: Custom tracing and observability plugins

### Company Templates

- **TMPL-01**: Pre-built company templates with roles, goals, and agent configs
- **TMPL-02**: Template marketplace ("Clipmart")
- **TMPL-03**: Export company as template

### Advanced Agent Features

- **ADVG-01**: Agent skills learning at runtime
- **ADVG-02**: Cross-company agent sharing
- **ADVG-03**: Agent performance scoring and analytics

## Out of Scope

| Feature | Reason |
|---------|--------|
| Mobile app | Web-first, responsive later |
| Hosting AI models | Agents are always external (BYOA) |
| Enterprise SSO/SAML | Standard email/password auth sufficient for v1 |
| Real-time video/voice with agents | Text-based interaction only |
| Tailwind CSS | User preference for modern CSS |
| UUIDs | User preference for integer IDs, no distributed ID needs |
| React/SPA frontend | Hotwire provides sufficient interactivity |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| (Populated during roadmap creation) | | |

**Coverage:**
- v1 requirements: 39 total
- Mapped to phases: 0
- Unmapped: 39

---
*Requirements defined: 2026-03-26*
*Last updated: 2026-03-26 after initial definition*
