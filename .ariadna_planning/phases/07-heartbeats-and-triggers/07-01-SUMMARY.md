---
phase: 07-heartbeats-and-triggers
plan: "01"
status: complete
started_at: 2026-03-27T13:49:39Z
completed_at: 2026-03-27T13:55:09Z
duration_seconds: 330
tasks_completed: 2
tasks_total: 2
files_created: 10
files_modified: 2
commits:
  - hash: ebf279d
    message: "feat(07-01): HeartbeatEvent model and Agent heartbeat schedule columns"
  - hash: f432419
    message: "feat(07-01): WakeAgentService, AgentHeartbeatJob, HeartbeatScheduleManager"
tests_before: 373
tests_after: 412
tests_added: 39
---

# Plan 07-01 Summary: Heartbeat Data Layer and Job Infrastructure

## Objective

Established the foundation for Phase 7 heartbeats and triggers: the HeartbeatEvent model for logging all agent wake events, per-agent heartbeat schedule configuration on the Agent model, the WakeAgentService for adapter-aware dispatch, AgentHeartbeatJob for Solid Queue execution, and HeartbeatScheduleManager for dynamic recurring task management.

## Tasks Completed

### Task 1: HeartbeatEvent model, migrations, and Agent updates

**Migrations created:**
- `20260327134948_create_heartbeat_events.rb` — creates heartbeat_events table with agent_id (FK), trigger_type (integer enum), trigger_source (string), status (integer enum), delivered_at, request_payload (jsonb), response_payload (jsonb), metadata (jsonb), timestamps. Adds three indexes: [agent_id, created_at], [agent_id, trigger_type], and status.
- `20260327135006_add_heartbeat_schedule_to_agents.rb` — adds heartbeat_interval (integer, nullable) and heartbeat_enabled (boolean, default false) to agents.

**Model created:** `app/models/heartbeat_event.rb`
- `belongs_to :agent`
- Enums: `trigger_type` (scheduled: 0, task_assigned: 1, mention: 2), `status` (queued: 0, delivered: 1, failed: 2)
- Scopes: `chronological`, `reverse_chronological`, `by_trigger`, `recent`, `for_agent`
- Methods: `mark_delivered!(response:)`, `mark_failed!(error_message:)`

**Agent model updated** (`app/models/agent.rb`):
- `has_many :heartbeat_events, dependent: :destroy`
- `validates :heartbeat_interval, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true`
- `after_commit :sync_heartbeat_schedule, if: :heartbeat_config_changed?`
- Public methods: `heartbeat_scheduled?`, `last_heartbeat_event`
- Private methods: `heartbeat_config_changed?`, `sync_heartbeat_schedule`

**Test coverage:** 5 fixtures (covering all trigger types and statuses), 21 tests in `test/models/heartbeat_event_test.rb`

### Task 2: WakeAgentService, AgentHeartbeatJob, HeartbeatScheduleManager

**WakeAgentService** (`app/services/wake_agent_service.rb`):
- Adapter-aware dispatch: HTTP agents get immediate delivery (creates event with `status: delivered`, calls `mark_delivered!`), process/claude_local agents get queued events (`status: queued`)
- Creates HeartbeatEvent record with `request_payload` containing trigger context, agent_id, company_id, triggered_at, and any custom context hash
- Updates `agent.last_heartbeat_at` via `update_column` after each wake
- Returns `nil` immediately for terminated agents
- Class method `self.call(**args)` delegates to instance

**AgentHeartbeatJob** (`app/jobs/agent_heartbeat_job.rb`):
- Extends `ApplicationJob`, queued in `:default`
- Guards: `find_by` (not `find`) for non-existent agents, `heartbeat_scheduled?` check, `terminated?` check
- Delegates entirely to `WakeAgentService.call`

**HeartbeatScheduleManager** (`app/services/heartbeat_schedule_manager.rb`):
- Uses `class_attribute :task_store` for injectable task store (production uses `SolidQueue::RecurringTask`, tests inject `FakeTaskStore`)
- `solid_queue_available?` guard checks both `defined?(SolidQueue::RecurringTask)` and table existence; returns `true` when `task_store` is set
- Task key format: `"agent_heartbeat_{agent_id}"`
- Schedule expression: `"every {interval} minutes"`
- `upsert_recurring_task`: finds or builds task, assigns attributes with `static: false`, saves
- `sync`: calls `upsert_recurring_task` if `heartbeat_scheduled?`, else `remove`
- `remove`: destroys existing task if present (safe-delete pattern)

**Test coverage:** 7 WakeAgentService tests, 4 AgentHeartbeatJob tests, 7 HeartbeatScheduleManager tests (18 total)

## Deviations

### [Rule 2 - Architecture] HeartbeatScheduleManager task_store injection pattern

**Issue:** `SolidQueue::RecurringTask` uses a separate SQLite database in production, but in dev/test it falls back to the primary PostgreSQL DB which doesn't have the `solid_queue_recurring_tasks` table. The plan acknowledged this and suggested a guard or mocking approach.

**Solution:** Added `class_attribute :task_store` to `HeartbeatScheduleManager`. When `task_store` is set, the manager uses it instead of `SolidQueue::RecurringTask` and skips the `solid_queue_available?` guard. Tests inject a `FakeTaskStore` (in-memory hash-backed store) that implements the same interface (`new(key:)`, `find_by(key:)`, `save!`, `destroy`, `assign_attributes`).

**Why:** This is cleaner than Mocha mocking (not in the project), avoids adding SolidQueue schema to the primary DB (which would be architecturally wrong), and gives a natural extension point for future testing.

**Impact:** No production behavior change. The `task_store = nil` default means production always uses `SolidQueue::RecurringTask` with the full `solid_queue_available?` guard.

## Key Patterns Used

- **Enum integers in migrations** — matches existing project pattern (adapter_type, status enums use integer columns)
- **`update_column` for timestamp** — bypasses callbacks/validations for performance-sensitive last_heartbeat_at update
- **`find_by` not `find`** — AgentHeartbeatJob uses `find_by` to return nil instead of raising for missing agents
- **`after_commit` for external sync** — same pattern as Auditable concern; ensures schedule sync only fires after successful DB commit
- **`saved_change_to_*?`** — uses Rails 5.1+ saved change tracking (not `*_changed?` which is pre-save)
- **class_attribute for testability** — standard Rails pattern for injectable dependencies

## Test Counts

| File | Tests |
|------|-------|
| test/models/heartbeat_event_test.rb | 21 |
| test/services/wake_agent_service_test.rb | 7 |
| test/jobs/agent_heartbeat_job_test.rb | 4 |
| test/services/heartbeat_schedule_manager_test.rb | 7 |
| **Total added** | **39** |

Full suite: 412 tests, 1052 assertions, 0 failures, 0 errors, 0 skips.

## Files Created

- `app/models/heartbeat_event.rb`
- `app/services/wake_agent_service.rb`
- `app/services/heartbeat_schedule_manager.rb`
- `app/jobs/agent_heartbeat_job.rb`
- `db/migrate/20260327134948_create_heartbeat_events.rb`
- `db/migrate/20260327135006_add_heartbeat_schedule_to_agents.rb`
- `test/fixtures/heartbeat_events.yml`
- `test/models/heartbeat_event_test.rb`
- `test/services/wake_agent_service_test.rb`
- `test/services/heartbeat_schedule_manager_test.rb`
- `test/jobs/agent_heartbeat_job_test.rb`

## Files Modified

- `app/models/agent.rb` — added heartbeat_events association, heartbeat_interval validation, after_commit callback, heartbeat_scheduled?, last_heartbeat_event
- `db/schema.rb` — auto-updated by migrations

## Self-Check: PASSED

All files confirmed present. Both commits confirmed in git log (ebf279d, f432419). Full test suite: 412 tests, 0 failures, 0 errors.
