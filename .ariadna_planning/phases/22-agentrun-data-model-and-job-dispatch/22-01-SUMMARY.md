---
phase: 22-agentrun-data-model-and-job-dispatch
plan: 01
status: complete
started_at: 2026-03-28T18:10:12Z
completed_at: 2026-03-28T18:14:36Z
duration_minutes: 4
tasks_completed: 3
files_created: 6
files_modified: 4
commits: 3
---

# Plan 22-01 Summary: AgentRun Data Model and Job Dispatch

## Objective

Created the AgentRun data model, ExecuteAgentJob with dedicated queue, and wired WakeAgentService to dispatch real execution jobs. This is the persistence and dispatch foundation for all agent execution in v1.4.

Implements: EXEC-01 (state machine), EXEC-02 (log/exit/cost/timing), EXEC-03 (session ID), EXEC-04 (job dispatch), EXEC-05 (agent status transitions), EXEC-06 (dedicated queue).

## Tasks Completed

### Task 1: AgentRun migration, model, fixtures, tests (commit 83c17c3)

**Migration** (`db/migrate/20260328181016_create_agent_runs.rb`):
- Created `agent_runs` table with: agent_id (FK, not null), task_id (FK, nullable for heartbeat-triggered runs), company_id (FK, not null), status (integer enum, default 0), log_output (text), exit_code (integer), cost_cents (integer), claude_session_id (string), trigger_type (string), error_message (text), started_at, completed_at, timestamps
- Composite indexes on [agent_id, status], [agent_id, created_at], [company_id, created_at]
- Index on claude_session_id for session resumption lookups
- Note: removed explicit task_id index since `t.references` already creates it (deviation caught during migration run)

**Model** (`app/models/agent_run.rb`):
- Includes Tenantable (company scoping, for_current_company scope) and Chronological (chronological/reverse_chronological scopes)
- Status enum: queued(0) / running(1) / completed(2) / failed(3) / cancelled(4)
- State machine: mark_running! (raises unless queued), mark_completed! (accepts exit_code/cost_cents/claude_session_id, preserves existing session_id), mark_failed! (requires error_message, optional exit_code), mark_cancelled! (raises from completed/failed)
- append_log!: incremental log accumulation, nil-safe, ignores blank
- duration_seconds: nil-safe, returns float
- terminal?: convenience predicate (completed? || failed? || cancelled?)
- Scopes: for_agent, active (queued+running), terminal (completed+failed+cancelled), recent (24h)

**Agent model** (`app/models/agent.rb`):
- Added `has_many :agent_runs, dependent: :destroy`
- Added `latest_session_id`: picks most recent non-null claude_session_id for Claude conversation resumption (EXEC-03)

**Results**: 57 model tests pass, 59 existing agent tests pass (no regression)

### Task 2: ExecuteAgentJob and queue configuration (commit 168ee78)

**Job** (`app/jobs/execute_agent_job.rb`):
- `queue_as :execution` (dedicated queue, not default)
- `discard_on ActiveJob::DeserializationError` for clean handling of deleted AgentRuns
- No retry_on: execution failures need human review, not automatic retry
- Transition sequence: AgentRun queued->running, Agent idle->running, call adapter_class.execute, AgentRun running->completed, Agent running->idle
- Rescue `Exception` (not just StandardError): catches NotImplementedError from BaseAdapter since it inherits from ScriptError, not StandardError. Ensures agent never gets stuck in running state (EXEC-05)
- build_context: assembles {run_id, trigger_type, task_id/title/description (if task present), resume_session_id (if prior session)}

**Queue config** (`config/queue.yml`):
- Default worker: `queues: "default"`, threads: 3, polling: 0.1s (fast short jobs)
- Execution worker: `queues: "execution"`, threads: 2, polling: 0.5s (long-running jobs)
- Separate EXECUTION_CONCURRENCY env var for independent production scaling
- Changed from `queues: "*"` wildcard to `queues: "default"` -- default worker no longer picks up execution jobs (EXEC-06)

**Results**: 11 job tests pass including adapter dispatch, failure recovery, context building, session resumption

### Task 3: WakeAgentService wiring (commit 95c6be5)

**Service** (`app/services/wake_agent_service.rb`):
- Updated deliver to call dispatch_execution after HeartbeatEvent delivery
- Added dispatch_execution: creates AgentRun (status: queued, trigger_type from service), enqueues ExecuteAgentJob.perform_later(agent_run.id)
- Added find_task_from_context: resolves Task from context[:task_id] or context["task_id"] (symbol or string key), nil-safe -- returns nil for heartbeat/scheduled triggers with no task
- Terminated agent guard already in call method -- neither HeartbeatEvent nor AgentRun created

**Task model fix** (`app/models/task.rb`):
- Added `has_many :agent_runs, dependent: :nullify` -- required to prevent FK constraint failure when tasks are destroyed (task_id is nullable on agent_runs, preserving run history)
- Rule 3 auto-fix: discovered during full test suite run (3 TaskTest failures)

**Results**: 13 service tests pass (7 existing preserved + 6 new). Full suite: 952 tests, 2315 assertions, 0 failures

## Deviations

**[Rule 3 - Blocking] Duplicate task_id index in migration**: `t.references :task` already creates an index on task_id; the explicit `add_index :agent_runs, [:task_id]` caused `SQLite3::SQLException: index already exists`. Removed the duplicate index. Migration ran cleanly.

**[Rule 3 - Blocking] BaseAdapter.execute raises NotImplementedError, not StandardError**: `NotImplementedError` inherits from `ScriptError`, not `StandardError`. The plan's `rescue => e` clause would not catch it, leaving agent stuck in running state and violating EXEC-05. Changed to `rescue Exception => e` with rubocop disable comment. All 11 job tests verify failure recovery path works correctly.

**[Rule 3 - Blocking] Task FK constraint on agent_runs.task_id**: Deleting a Task with associated AgentRuns caused `SQLite3::ConstraintException: FOREIGN KEY constraint failed`. Since task_id is nullable, added `has_many :agent_runs, dependent: :nullify` to Task model to preserve run history while satisfying FK constraint.

## Artifacts

| File | Type | Description |
|------|------|-------------|
| `db/migrate/20260328181016_create_agent_runs.rb` | Migration | Creates agent_runs table with all columns and indexes |
| `app/models/agent_run.rb` | Model | AgentRun with state machine, Tenantable/Chronological concerns |
| `app/models/agent.rb` | Modified | Added has_many :agent_runs, latest_session_id |
| `app/models/task.rb` | Modified | Added has_many :agent_runs, dependent: :nullify |
| `app/jobs/execute_agent_job.rb` | Job | Dispatches to adapter, manages agent/run status, handles failure |
| `config/queue.yml` | Config | Separate execution queue worker pool |
| `app/services/wake_agent_service.rb` | Modified | Creates AgentRun and enqueues ExecuteAgentJob on wake |
| `test/fixtures/agent_runs.yml` | Fixtures | queued, running, completed, failed agent runs |
| `test/models/agent_run_test.rb` | Tests | 57 tests covering all model behavior |
| `test/jobs/execute_agent_job_test.rb` | Tests | 11 tests covering dispatch, recovery, context |
| `test/services/wake_agent_service_test.rb` | Modified | 6 new tests for AgentRun creation and job enqueue |

## Key Links Created

- AgentRun -> Agent (belongs_to)
- AgentRun -> Task (belongs_to, optional)
- Agent -> AgentRun (has_many, dependent: destroy)
- Task -> AgentRun (has_many, dependent: nullify)
- ExecuteAgentJob -> AgentRun#mark_running!/mark_completed!/mark_failed!
- ExecuteAgentJob -> BaseAdapter.execute(agent, context)
- WakeAgentService -> AgentRun (creates on deliver)
- WakeAgentService -> ExecuteAgentJob (enqueues via perform_later)
- config/queue.yml -> ExecuteAgentJob (execution queue with dedicated threads)

## Verification

- `bin/rails db:migrate` -- passed
- `bin/rails test test/models/agent_run_test.rb` -- 57 tests, 95 assertions, 0 failures
- `bin/rails test test/models/agent_test.rb` -- 59 tests, 99 assertions, 0 failures
- `bin/rails test test/jobs/execute_agent_job_test.rb` -- 11 tests, 19 assertions, 0 failures
- `bin/rails test test/services/wake_agent_service_test.rb` -- 13 tests, 40 assertions, 0 failures
- `bin/rails test` -- 952 tests, 2315 assertions, 0 failures, 0 errors
- `bin/rubocop` -- no offenses on new/modified Ruby files
- `bin/brakeman --quiet --no-pager` -- no new security warnings (1 pre-existing in agent_hooks_controller.rb)

## Self-Check: PASSED
