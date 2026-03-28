---
phase: 18-hook-data-foundation
plan: 01
subsystem: database
tags: [rails, activerecord, sqlite, migrations, models, enums, concerns, fixtures]

# Dependency graph
requires:
  - phase: 17-agent-skill-management
    provides: AgentSkill pattern for join model tests; established Agent model patterns
  - phase: 09-governance-audit
    provides: ConfigVersioned concern for versioning AgentHook changes
  - phase: 07-heartbeats-and-triggers
    provides: HeartbeatEvent model that gained hook_triggered enum value
provides:
  - agent_hooks table and AgentHook model (DATA-01)
  - hook_executions table and HookExecution model (DATA-02)
  - Agent has_many :agent_hooks, dependent: :destroy (DATA-03)
  - HeartbeatEvent trigger_type extended with hook_triggered: 3 (UI-03)
affects: [19-triggering-engine, 20-feedback-loop, 21-management-ui]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - LIFECYCLE_EVENTS constant pattern (string enum validated against constant, same as GATABLE_ACTIONS)
    - action_config schema validation (per-action_type JSON config validation via validate method)
    - target_agent convenience method (looks up agent from JSON config without belongs_to)
    - mark_running!/mark_completed!/mark_failed! state transition pattern (mirrors HeartbeatEvent.mark_delivered!)
    - duration_seconds computed from started_at/completed_at timing fields

key-files:
  created:
    - db/migrate/20260328143524_create_agent_hooks.rb
    - db/migrate/20260328143529_create_hook_executions.rb
    - app/models/agent_hook.rb
    - app/models/hook_execution.rb
    - test/fixtures/agent_hooks.yml
    - test/fixtures/hook_executions.yml
    - test/models/agent_hook_test.rb
    - test/models/hook_execution_test.rb
  modified:
    - app/models/agent.rb
    - app/models/heartbeat_event.rb
    - app/models/task.rb
    - test/models/agent_test.rb
    - test/models/heartbeat_event_test.rb

key-decisions:
  - "index: false on t.references when providing explicit add_index with composite indexes -- avoids SQLite duplicate index error (same pattern as 08-01)"
  - "HookExecution does NOT include Tenantable -- has direct belongs_to :company; Tenantable would add duplicate belongs_to"
  - "Task model gains has_many :hook_executions, dependent: :destroy -- FK constraint blocks task destroy tests without it"
  - "target_agent_id in fixtures uses placeholder value 1 -- target_agent method safely returns nil for non-matching IDs"

patterns-established:
  - "LIFECYCLE_EVENTS constant: string values validated via inclusion validation, not integer enum -- allows future extension without migration"
  - "validate_action_config_schema: per-action_type JSON key presence check, returns early if config blank"
  - "governance_attributes override in AgentHook: returns specific attribute names tracked by ConfigVersioned"

requirements_covered:
  - id: "DATA-01"
    description: "AgentHook model with lifecycle_event, action_type enum, action_config JSON, enabled flag, position ordering, agent_id + company_id FKs"
    evidence: "app/models/agent_hook.rb, db/migrate/20260328143524_create_agent_hooks.rb"
  - id: "DATA-02"
    description: "HookExecution model with status tracking (queued/running/completed/failed), input/output payloads, timing fields, mark_* transition methods"
    evidence: "app/models/hook_execution.rb, db/migrate/20260328143529_create_hook_executions.rb"
  - id: "DATA-03"
    description: "Agent has_many :agent_hooks, dependent: :destroy -- deleting agent cascades to hooks and their executions"
    evidence: "app/models/agent.rb line 13"
  - id: "UI-03"
    description: "HeartbeatEvent trigger_type enum extended with hook_triggered: 3"
    evidence: "app/models/heartbeat_event.rb line 4"

# Metrics
duration: 4min
completed: 2026-03-28
---

# Phase 18-01: Hook Data Foundation Summary

**AgentHook and HookExecution models with migrations, concerns, state-transition methods, fixtures, and 48 new model tests establishing the data layer for the agent hooks system**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-28T14:35:20Z
- **Completed:** 2026-03-28T14:39:46Z
- **Tasks:** 3
- **Files modified:** 13

## Accomplishments
- Two new migrations creating `agent_hooks` and `hook_executions` tables with proper indexes and foreign keys
- AgentHook model with Tenantable/Auditable/ConfigVersioned concerns, LIFECYCLE_EVENTS constant, action_type enum, per-type action_config schema validation, and target_agent convenience method
- HookExecution model with 4-state status enum, mark_running!/mark_completed!/mark_failed! transitions, duration_seconds helper
- Agent and HeartbeatEvent models updated (has_many :agent_hooks, hook_triggered enum value)
- 48 new model tests covering validations, enums, associations, scopes, methods, cascade destroy, and defaults

## Requirements Covered
| REQ-ID | Requirement | Evidence |
|--------|-------------|----------|
| DATA-01 | AgentHook model with lifecycle event, action types, config validation | `app/models/agent_hook.rb` |
| DATA-02 | HookExecution with status tracking and mark_* transitions | `app/models/hook_execution.rb` |
| DATA-03 | Agent has_many :agent_hooks with cascade destroy | `app/models/agent.rb` |
| UI-03 | HeartbeatEvent hook_triggered enum value | `app/models/heartbeat_event.rb` |

## Task Commits

Each task was committed atomically:

1. **Task 1: Create migrations for agent_hooks and hook_executions tables** - `0db1e13` (feat)
2. **Task 2: Create AgentHook and HookExecution models with fixtures and existing model updates** - `4b7cf71` (feat)
3. **Task 3: Create comprehensive model tests for AgentHook and HookExecution** - `dec0257` (test)

## Files Created/Modified
- `db/migrate/20260328143524_create_agent_hooks.rb` - agent_hooks table migration
- `db/migrate/20260328143529_create_hook_executions.rb` - hook_executions table migration
- `app/models/agent_hook.rb` - AgentHook model with concerns, validations, scopes, target_agent
- `app/models/hook_execution.rb` - HookExecution model with status enum and mark_* methods
- `app/models/agent.rb` - Added has_many :agent_hooks, dependent: :destroy
- `app/models/heartbeat_event.rb` - Extended trigger_type enum with hook_triggered: 3
- `app/models/task.rb` - Added has_many :hook_executions, dependent: :destroy (auto-fix)
- `test/fixtures/agent_hooks.yml` - 3 fixtures: claude_validation_hook, claude_webhook_hook, disabled_hook
- `test/fixtures/hook_executions.yml` - 2 fixtures: completed_execution, failed_execution
- `test/models/agent_hook_test.rb` - 30 AgentHook tests
- `test/models/hook_execution_test.rb` - 18 HookExecution tests
- `test/models/agent_test.rb` - Added has_many :agent_hooks and cascade destroy tests
- `test/models/heartbeat_event_test.rb` - Added hook_triggered? enum test

## Decisions Made
- Used `index: false` on `t.references` calls when providing explicit `add_index` -- matches 08-01 pattern to avoid SQLite duplicate index error
- HookExecution does NOT include Tenantable because it already has `belongs_to :company` directly; Tenantable would create a duplicate declaration
- `lifecycle_event` uses string + LIFECYCLE_EVENTS constant (not integer enum) to allow future extension without migration -- same pattern as ApprovalGate.GATABLE_ACTIONS

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added has_many :hook_executions to Task model**
- **Found during:** Task 2 (after running full test suite)
- **Issue:** hook_executions table has FK to tasks; existing task destroy tests (destroying task destroys messages/subtasks/audit_events) failed with SQLite FK constraint error because no dependent: :destroy on Task side
- **Fix:** Added `has_many :hook_executions, dependent: :destroy` to app/models/task.rb
- **Files modified:** `app/models/task.rb`
- **Verification:** Full suite went from 3 errors to 0 errors, 793 tests passing
- **Committed in:** `4b7cf71` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 2 - missing critical)
**Impact on plan:** Essential for test suite correctness. The plan specified the AgentHook → Task relationship but did not add the reciprocal association needed for cascade behavior.

## Issues Encountered
- Migration failed on first run: `add_index :agent_hooks, [:company_id]` conflicted with auto-created index from `t.references :company`. Fixed by adding `index: false` to all `t.references` calls where explicit indexes are provided.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 19 (triggering engine) can now add the Hookable concern that detects task state transitions and fires AgentHook records
- Phase 21 (management UI) can now scaffold CRUD for AgentHook records
- All 4 requirements (DATA-01, DATA-02, DATA-03, UI-03) are complete and tested

---
*Phase: 18-hook-data-foundation*
*Completed: 2026-03-28*

## Self-Check: PASSED

- app/models/agent_hook.rb -- FOUND
- app/models/hook_execution.rb -- FOUND
- test/fixtures/agent_hooks.yml -- FOUND
- test/fixtures/hook_executions.yml -- FOUND
- test/models/agent_hook_test.rb -- FOUND
- test/models/hook_execution_test.rb -- FOUND
- db/migrate/20260328143524_create_agent_hooks.rb -- FOUND
- db/migrate/20260328143529_create_hook_executions.rb -- FOUND
- Commit 0db1e13 -- FOUND
- Commit 4b7cf71 -- FOUND
- Commit dec0257 -- FOUND
- Test suite: 793 runs, 0 failures, 0 errors
