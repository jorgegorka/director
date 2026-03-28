# Requirements: Director

**Defined:** 2026-03-28
**Core Value:** Users can organize AI agents into a functioning company structure and confidently let them work autonomously — knowing budgets are enforced, tasks are tracked, and humans retain control through governance.

## v1.3 Requirements

Requirements for Agent Hooks milestone. Each maps to roadmap phases.

### Data Model

- [ ] **DATA-01**: AgentHook belongs to agent with lifecycle_event, action_type (trigger_agent/webhook), action_config, enabled flag, and position ordering — *configures when and how hooks fire*
- [ ] **DATA-02**: HookExecution tracks each hook firing with status (queued/running/completed/failed), input/output payloads, timing, and error messages — *provides observability into hook behavior*
- [ ] **DATA-03**: Agent has_many agent_hooks with dependent destroy — *hooks are agent-scoped and clean up on deletion*

### Hook Triggering

- [ ] **TRIG-01**: Hookable concern detects task status transitions and enqueues matching hooks as background jobs — *hooks fire automatically without blocking task saves*
- [ ] **TRIG-02**: Only enabled hooks for the task's assignee fire, ordered by position — *gives users control over which hooks run and in what order*
- [ ] **TRIG-03**: Completed subtasks with a parent_task enqueue ProcessValidationResultJob — *closes the feedback loop automatically*

### Hook Actions

- [ ] **ACT-01**: trigger_agent action creates a validation subtask assigned to target agent and wakes it via WakeAgentService — *enables agent-to-agent validation workflows*
- [ ] **ACT-02**: webhook action POSTs JSON payload to configured URL with custom headers and timeouts — *enables external system integration*
- [ ] **ACT-03**: ExecuteHookJob retries on failure with polynomial backoff (3 attempts) — *handles transient failures gracefully*

### Feedback Loop

- [ ] **FEED-01**: ProcessValidationResultService collects validation subtask messages and posts feedback on the parent task — *original agent sees validation results*
- [ ] **FEED-02**: Original agent is woken with review_validation context after feedback is posted — *enables iterative improvement based on validation*
- [ ] **FEED-03**: Audit events recorded for hook_executed and validation_feedback_received — *governance trail for all hook activity*

### Management UI

- [ ] **UI-01**: AgentHooksController provides CRUD for hooks nested under agents — *users can create and manage hooks through the web interface*
- [ ] **UI-02**: Company scoping ensures hooks are only accessible within the owning company — *multi-tenant isolation maintained*
- [ ] **UI-03**: HeartbeatEvent trigger_type extended with hook_triggered — *distinguishes hook-originated wake calls from other triggers*

## Future Requirements

None deferred — this is a focused milestone.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Conditional hook filtering (task tags, priority) | conditions column exists but v1.3 fires all enabled hooks — filtering deferred |
| Hook execution dashboard/analytics | Execution records exist for debugging; dedicated UI deferred |
| Synchronous before_* blocking hooks | All hooks are async background jobs in v1.3 for SQLite write performance |
| Chain hooks (hook triggers hook) | Complexity risk; v1.3 supports one level of agent-to-agent only |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| DATA-01 | — | Pending |
| DATA-02 | — | Pending |
| DATA-03 | — | Pending |
| TRIG-01 | — | Pending |
| TRIG-02 | — | Pending |
| TRIG-03 | — | Pending |
| ACT-01 | — | Pending |
| ACT-02 | — | Pending |
| ACT-03 | — | Pending |
| FEED-01 | — | Pending |
| FEED-02 | — | Pending |
| FEED-03 | — | Pending |
| UI-01 | — | Pending |
| UI-02 | — | Pending |
| UI-03 | — | Pending |

**Coverage:**
- v1.3 requirements: 15 total
- Mapped to phases: 0
- Unmapped: 15

---
*Requirements defined: 2026-03-28*
*Last updated: 2026-03-28 after initial definition*
