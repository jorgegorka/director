---
phase: 22-agentrun-data-model-and-job-dispatch
verified: 2026-03-28T19:20:00Z
status: passed
score: "8/8 truths verified | security: 0 critical, 0 high | performance: 0 high"
security_findings:
  - {check: "rescue-scope", severity: medium, file: "app/jobs/execute_agent_job.rb", line: 25, detail: "rescue Exception catches SignalException/Interrupt, suppressing graceful shutdown signals from Solid Queue. Required because NotImplementedError inherits from ScriptError not StandardError. Mitigation: re-raise if e.is_a?(SignalException) before processing. Pre-existing brakeman warning (agent_hooks_controller.rb:66) is unrelated to this phase."}
---

# Phase 22 Verification: AgentRun Data Model and Job Dispatch

## Goal

Persistent execution records exist for every agent run, and WakeAgentService dispatches real execution jobs instead of stubs.

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| T1 | When a task is assigned to an agent, an AgentRun record is created with status queued and the agent status changes from idle to running | VERIFIED | `Task` includes `Triggerable` concern which calls `WakeAgentService.call` via `trigger_assignment_wake` after_commit hook. `WakeAgentService#dispatch_execution` creates `AgentRun` with `status: :queued`. `ExecuteAgentJob#perform` sets `agent.update!(status: :running)`. WakeAgentService test confirms `AgentRun.count` increments by 1 on wake (13 tests, 40 assertions, all pass). |
| T2 | AgentRun stores log_output text, exit_code integer, cost_cents integer, started_at, completed_at, and claude_session_id | VERIFIED | Schema confirmed in `db/schema.rb`: all columns present with correct types. `mark_completed!` accepts `exit_code`, `cost_cents`, `claude_session_id`. `mark_running!` sets `started_at`. `mark_completed!/mark_failed!/mark_cancelled!` set `completed_at`. |
| T3 | AgentRun stores claude_session_id for session resumption across runs | VERIFIED | `claude_session_id` string column exists in schema with index. `mark_completed!` accepts and preserves existing session ID. `Agent#latest_session_id` picks most recent non-null session ID. `build_context` in `ExecuteAgentJob` includes `resume_session_id` when prior session exists. |
| T4 | AgentRun has a state machine with valid transitions: queued->running->completed/failed/cancelled, and queued->cancelled | VERIFIED | `mark_running!` raises unless `queued?`. `mark_cancelled!` raises if `completed?` or `failed?`. `terminal?` predicate covers all terminal states. 57 model tests pass including all transition guards. |
| T5 | ExecuteAgentJob runs on the dedicated execution queue and dispatches to the correct adapter execute method based on agent.adapter_type | VERIFIED | `queue_as :execution` confirmed in job file. Dispatches via `agent.adapter_class.execute(agent, build_context(agent_run))`. `agent.adapter_class` calls `AdapterRegistry.for(adapter_type)` which returns the correct adapter class. Job test confirms `queue_name == "execution"`. |
| T6 | If ExecuteAgentJob fails mid-run, the agent status returns to idle and the AgentRun is marked failed — agent does not get stuck | VERIFIED | `rescue Exception => e` block calls `agent_run.mark_failed!` and `agent.update!(status: :idle) if agent.running?`. Job tests confirm agent returns to idle after failure (`rescue Exception` is required because `NotImplementedError` inherits from `ScriptError`, not `StandardError`). 11 job tests pass. |
| T7 | The execution queue is configured as a separate worker pool in config/queue.yml so long-running execution jobs do not block default queue jobs | VERIFIED | `config/queue.yml` has two distinct worker entries: `queues: "default"` (threads: 3, polling: 0.1s) and `queues: "execution"` (threads: 2, polling: 0.5s). Default worker no longer uses wildcard `*` — it will not pick up execution jobs. |
| T8 | All model tests, job tests, and service tests pass | VERIFIED | `bin/rails test` — 952 tests, 2315 assertions, 0 failures, 0 errors, 0 skips. Individual suites: agent_run_test (57/95), execute_agent_job_test (11/19), wake_agent_service_test (13/40), agent_test (59/99 — no regression). |

## Artifact Status

| Artifact | Path | Exists | Substantive | Notes |
|----------|------|--------|-------------|-------|
| Migration | `db/migrate/20260328181016_create_agent_runs.rb` | Yes | Yes | All required columns: agent_id (FK, not null), task_id (FK, nullable), company_id (FK, not null), status (integer enum, default 0), log_output (text), exit_code (integer), cost_cents (integer), claude_session_id (string), trigger_type (string), error_message (text), started_at, completed_at, timestamps. 4 composite indexes. Schema confirms migration applied. |
| AgentRun model | `app/models/agent_run.rb` | Yes | Yes | Tenantable + Chronological concerns included. Status enum (queued/running/completed/failed/cancelled). All 4 mark_* methods. `append_log!`, `duration_seconds`, `terminal?`. Scopes: for_agent, active, terminal, recent. |
| AgentRun tests | `test/models/agent_run_test.rb` | Yes | Yes | 57 tests covering validations, associations, enum predicates, all scopes, all mark_* transitions and guards, append_log!, duration_seconds, terminal?, agent association and latest_session_id. |
| Fixtures | `test/fixtures/agent_runs.yml` | Yes | Yes | 4 fixtures: queued_run, running_run, completed_run (with session_id + cost), failed_run. All statuses represented. |
| Agent model (modified) | `app/models/agent.rb` | Yes | Yes | `has_many :agent_runs, dependent: :destroy` at line 14. `latest_session_id` method at line 140 uses `.where.not(claude_session_id: nil).order(created_at: :desc).pick(:claude_session_id)`. |
| Task model (added) | `app/models/task.rb` | Yes | Yes | `has_many :agent_runs, dependent: :nullify` at line 15. Required to prevent FK constraint failure when tasks are destroyed. Correct nullify (not destroy) since task_id is nullable. |
| ExecuteAgentJob | `app/jobs/execute_agent_job.rb` | Yes | Yes | `queue_as :execution`. `discard_on DeserializationError`. Terminal guard. Full transition sequence. `rescue Exception` (documented). `build_context` includes task details and resume_session_id. |
| Job tests | `test/jobs/execute_agent_job_test.rb` | Yes | Yes | 11 tests covering queue name, skip-if-not-found, terminal guard, transition sequence, failure recovery, agent idle reset, error recording, build_context with/without task and session. |
| Queue config | `config/queue.yml` | Yes | Yes | Two distinct worker entries. No wildcard queue on default worker. Separate `EXECUTION_CONCURRENCY` env var. |
| WakeAgentService (modified) | `app/services/wake_agent_service.rb` | Yes | Yes | `deliver` calls `dispatch_execution(event)` after HTTP delivery. `dispatch_execution` creates AgentRun and enqueues `ExecuteAgentJob.perform_later(agent_run.id)`. `find_task_from_context` handles symbol and string keys, nil-safe. |
| Service tests (modified) | `test/services/wake_agent_service_test.rb` | Yes | Yes | 7 original tests preserved. 6 new tests: AgentRun creation, nil task, job enqueue with queue assertion, both records created together, terminated agent guard, string task_id key. `include ActiveJob::TestHelper` present. |

## Key Links

| Link | Status | Evidence |
|------|--------|----------|
| `AgentRun -> Agent` (belongs_to) | VERIFIED | `belongs_to :agent` in agent_run.rb |
| `AgentRun -> Task` (belongs_to, optional) | VERIFIED | `belongs_to :task, optional: true` in agent_run.rb |
| `Agent -> AgentRun` (has_many, dependent: destroy) | VERIFIED | `has_many :agent_runs, dependent: :destroy` in agent.rb:14 |
| `Task -> AgentRun` (has_many, dependent: nullify) | VERIFIED | `has_many :agent_runs, dependent: :nullify` in task.rb:15 |
| `ExecuteAgentJob -> AgentRun#mark_running!/mark_completed!/mark_failed!` | VERIFIED | Lines 14, 18, 27 of execute_agent_job.rb |
| `ExecuteAgentJob -> BaseAdapter.execute(agent, context)` | VERIFIED | `agent.adapter_class.execute(agent, build_context(agent_run))` at line 17 |
| `WakeAgentService -> AgentRun` (creates in deliver) | VERIFIED | `dispatch_execution` at lines 58-68 of wake_agent_service.rb |
| `WakeAgentService -> ExecuteAgentJob` (perform_later) | VERIFIED | `ExecuteAgentJob.perform_later(agent_run.id)` at line 66 of wake_agent_service.rb |
| `config/queue.yml -> ExecuteAgentJob` (execution queue) | VERIFIED | `queues: "execution"` worker entry in queue.yml |
| `Task#trigger_assignment_wake -> WakeAgentService` | VERIFIED | `Triggerable` concern wraps `WakeAgentService.call`; Task includes Triggerable and calls `trigger_agent_wake` in `trigger_assignment_wake` after_commit hook |

## Cross-Phase Integration

**Upstream (consumed from prior phases):**
- `HeartbeatEvent#mark_delivered!` / `mark_failed!` — used by WakeAgentService; confirmed present in heartbeat_event.rb
- `Agent#adapter_class` -> `AdapterRegistry.for(adapter_type)` — confirmed at agent.rb:46
- `Triggerable` concern — confirmed at app/models/concerns/triggerable.rb, wraps WakeAgentService.call
- `BaseAdapter.execute` raises `NotImplementedError` — confirmed in base_adapter.rb; job correctly catches it via `rescue Exception`

**Downstream (what phases 23+ will consume from this phase):**
- Phase 23 (HTTP adapter): Will implement `HttpAdapter.execute(agent, context)` which the job already dispatches to via `agent.adapter_class.execute`. The AgentRun model's `mark_completed!`/`mark_failed!` interface is ready.
- Phase 24 (Claude adapter): Will use `build_context[:resume_session_id]` for conversation resumption and call `agent_run.mark_completed!(claude_session_id: ...)` to persist the session ID.
- Future: `AgentRunsController` (referenced in ARCHITECTURE.md) will query `AgentRun` records — the `for_agent`, `active`, `terminal`, `recent`, `for_current_company` scopes are all ready.

**No orphaned modules.** All new code is reachable from the task assignment flow.

## Security Findings

| Check | Severity | File | Line | Detail |
|-------|----------|------|------|--------|
| rescue-scope | Medium | `app/jobs/execute_agent_job.rb` | 25 | `rescue Exception` catches `SignalException` and `Interrupt`, which are used by Solid Queue for graceful shutdown. If a worker receives SIGTERM during ExecuteAgentJob execution, the rescue block will catch it, mark the run as failed with "Interrupt" error message, and return normally — preventing the signal from propagating. Recommendation: add `raise if e.is_a?(SignalException)` before the error handling block. The pre-existing brakeman warning (mass assignment in agent_hooks_controller.rb:66) is unrelated to this phase. |

## Performance Findings

No high-severity performance findings. `append_log!` performs a full column read + concatenation + write for each log line — this will become a bottleneck with high-frequency logging in Phase 24 (Claude streaming). The architecture document already notes this; streaming phases will need to address it (e.g., Turbo Stream broadcast from within the adapter, not repeated DB writes).

## Rubocop

No offenses on `app/models/agent_run.rb`, `app/models/agent.rb`, `app/jobs/execute_agent_job.rb`, `app/services/wake_agent_service.rb`. The `rescue Exception` on line 25 of execute_agent_job.rb has a `# rubocop:disable Lint/RescueException` inline comment.

## Summary

Phase 22 achieves its goal. Persistent execution records exist for every agent run (AgentRun table with full state machine, 57 model tests), and WakeAgentService now dispatches real execution jobs via ExecuteAgentJob on a dedicated queue instead of returning stubs (13 service tests). The full test suite passes with 952 tests and 0 failures. The cross-phase wiring is correct: the Task->Triggerable->WakeAgentService->AgentRun+ExecuteAgentJob->BaseAdapter chain is complete. One medium security finding exists (`rescue Exception` suppressing shutdown signals) which should be addressed before production load under SIGTERM conditions, but does not block the phase goal.
