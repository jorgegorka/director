# Requirements: Director

**Defined:** 2026-03-28
**Core Value:** Users can organize AI agents into a functioning company structure and confidently let them work autonomously — knowing budgets are enforced, tasks are tracked, and humans retain control through governance.

## v1.4 Requirements

Requirements for agent execution milestone. Each maps to roadmap phases.

### Execution Data Model

- [ ] **EXEC-01**: AgentRun model with state machine (queued → running → completed/failed/cancelled) — *persistent execution record for all adapter types*
- [ ] **EXEC-02**: AgentRun stores accumulated log text, exit code, cost_cents, and timing (started_at, completed_at) — *durably captures execution results*
- [ ] **EXEC-03**: AgentRun stores claude_session_id for session resumption across runs — *enables conversation continuity*
- [ ] **EXEC-04**: ExecuteAgentJob dispatches to correct execution service based on adapter_type — *single entry point for all execution*
- [ ] **EXEC-05**: Agent status transitions (idle → running → idle/error) reflect real execution state — *dashboard shows accurate agent state*
- [ ] **EXEC-06**: Dedicated Solid Queue `execution` queue isolates long-running jobs from default queue — *prevents execution from blocking short jobs*

### HTTP Adapter

- [ ] **HTTP-01**: WakeAgentService delivers real HTTP POST to agent's configured URL with task context payload — *replaces TODO stub*
- [ ] **HTTP-02**: HTTP delivery classifies 4xx as permanent failure and 5xx/timeout as transient (retryable) — *prevents infinite retries on bad URLs*
- [ ] **HTTP-03**: HTTP delivery retries transient failures with exponential backoff — *resilient delivery without flooding*
- [ ] **HTTP-04**: HTTP delivery uses explicit timeouts (open: 5s, read: 30s) — *prevents thread-blocking on unresponsive agents*

### Claude Local Adapter

- [ ] **CLAUDE-01**: Tmux-based session management — spawns `claude -p --bare --output-format stream-json` in a named tmux session — *real TTY solves buffering, tmux manages process lifecycle*
- [ ] **CLAUDE-02**: Stream-json output parsed line-by-line, accumulated in AgentRun log — *captures full agent work history*
- [ ] **CLAUDE-03**: Session ID captured from result event and stored in AgentRun — *enables resumption*
- [ ] **CLAUDE-04**: Subsequent runs for same agent pass `--resume <session_id>` for conversation continuity — *agents maintain context across tasks*
- [ ] **CLAUDE-05**: `total_cost_usd` from result event written to AgentRun cost_cents and fed into budget tracking — *cost control on autonomous execution*
- [ ] **CLAUDE-06**: Execution blocked when agent.budget_exhausted? returns true — *prevents runaway spend*
- [ ] **CLAUDE-07**: `ANTHROPIC_API_KEY` passed explicitly via environment, `--bare` flag mandatory — *prevents session file corruption under concurrency*

### Live Streaming UI

- [ ] **STREAM-01**: AgentRun show view streams live output via turbo_stream_from while agent is active — *users watch agent work in real-time*
- [ ] **STREAM-02**: Agent status broadcast on agent-scoped stream (idle → running → idle) updates dashboard — *real-time agent state in UI*
- [ ] **STREAM-03**: Tool-use indicators parsed from stream-json content_block_start events and displayed — *users see what tools the agent is using*
- [ ] **STREAM-04**: Cancel button kills tmux session and marks AgentRun as cancelled — *human override on autonomous execution*
- [ ] **STREAM-05**: Broadcast batching (minimum 100ms interval) prevents Action Cable flooding — *protects SQLite from write pressure*

### Result Callbacks

- [ ] **CALLBACK-01**: `POST /api/agent_runs/:id/result` endpoint for agents to report task completion — *closes the autonomous execution loop*
- [ ] **CALLBACK-02**: `POST /api/agent_runs/:id/progress` endpoint for agents to report intermediate progress — *visibility into long-running work*
- [ ] **CALLBACK-03**: Result callback updates task status and posts completion message to task conversation — *results visible in task thread*
- [ ] **CALLBACK-04**: Cost reporting via result callback feeds into agent budget tracking — *budget enforcement on API-reported costs*

## Future Requirements

### Process Adapter

- **PROC-01**: ProcessAdapter executes shell commands via Open3 with output capture
- **PROC-02**: Process execution uses array form to prevent shell injection

### Hardening

- **HARD-01**: Orphan run recovery job cleans up stuck :running AgentRun records
- **HARD-02**: Webhook signature verification (HMAC) on outbound HTTP delivery
- **HARD-03**: Faraday-based retry with exponential backoff for HTTP adapter

## Out of Scope

| Feature | Reason |
|---------|--------|
| Process adapter execution | Simplify v1.4 scope — HTTP and Claude are the priority adapters |
| Redis for Action Cable | Solid Cable uses SQLite; adding Redis requires Kamal infra changes |
| Custom Action Cable channel | Turbo::StreamsChannel.broadcast_*_to is sufficient |
| SSE via ActionController::Live | Conflicts with Puma thread pool; incompatible with Turbo Streams |
| Interactive Claude sessions (stdin) | Non-interactive headless mode (-p flag) is correct for automation |
| Fork-based session management | State explosion risk; one session per agent is correct |
| Multi-agent concurrent execution tuning | Need single-agent stability first |
| AnyCable | Requires infra changes; overkill for current scale |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| EXEC-01 | Pending | Pending |
| EXEC-02 | Pending | Pending |
| EXEC-03 | Pending | Pending |
| EXEC-04 | Pending | Pending |
| EXEC-05 | Pending | Pending |
| EXEC-06 | Pending | Pending |
| HTTP-01 | Pending | Pending |
| HTTP-02 | Pending | Pending |
| HTTP-03 | Pending | Pending |
| HTTP-04 | Pending | Pending |
| CLAUDE-01 | Pending | Pending |
| CLAUDE-02 | Pending | Pending |
| CLAUDE-03 | Pending | Pending |
| CLAUDE-04 | Pending | Pending |
| CLAUDE-05 | Pending | Pending |
| CLAUDE-06 | Pending | Pending |
| CLAUDE-07 | Pending | Pending |
| STREAM-01 | Pending | Pending |
| STREAM-02 | Pending | Pending |
| STREAM-03 | Pending | Pending |
| STREAM-04 | Pending | Pending |
| STREAM-05 | Pending | Pending |
| CALLBACK-01 | Pending | Pending |
| CALLBACK-02 | Pending | Pending |
| CALLBACK-03 | Pending | Pending |
| CALLBACK-04 | Pending | Pending |

**Coverage:**
- v1.4 requirements: 26 total
- Mapped to phases: 0
- Unmapped: 26

---
*Requirements defined: 2026-03-28*
*Last updated: 2026-03-28 after initial definition*
