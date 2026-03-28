---
phase: 19-hook-triggering-engine
plan: 02
subsystem: api
tags: [rails, activerecord, net-http, webmock, services, jobs, hooks, audit]

# Dependency graph
requires:
  - phase: 19-hook-triggering-engine/19-01
    provides: Hookable concern, ExecuteHookJob, HookExecution fixtures, agent_hooks fixtures
  - phase: 18-hook-data-foundation/18-01
    provides: AgentHook model with target_agent/trigger_agent?/webhook? methods, HookExecution with mark_running!/mark_completed!/mark_failed!
provides:
  - ExecuteHookService.call dispatches trigger_agent hooks (creates validation subtask + wakes target agent)
  - ExecuteHookService.call dispatches webhook hooks (POSTs JSON via Net::HTTP with custom headers + configurable timeout)
  - Full HookExecution lifecycle management (queued -> running -> completed/failed) via existing mark_* methods
  - Audit event recording on each successful execution via AgentHook#record_audit_event!
  - Re-raise on failure for ExecuteHookJob retry_on mechanism
  - hook_executed added to AuditEvent::GOVERNANCE_ACTIONS
affects: [20-feedback-loop, 21-hooks-management-ui]

# Tech tracking
tech-stack:
  added: [webmock 3.26.2 (HTTP stubbing in tests)]
  patterns: [service-to-service delegation (ExecuteHookJob -> ExecuteHookService), Net::HTTP webhook dispatch with configurable timeout, audit event on service completion]

key-files:
  created:
    - app/services/execute_hook_service.rb
    - test/services/execute_hook_service_test.rb
  modified:
    - test/jobs/execute_hook_job_test.rb
    - app/models/audit_event.rb
    - test/models/audit_event_test.rb
    - Gemfile + Gemfile.lock

key-decisions:
  - "ExecuteHookService re-raises StandardError after mark_failed! — required for ExecuteHookJob retry_on mechanism to work (exception must propagate)"
  - "unless execution.failed? guard on mark_failed! prevents double-marking on job retry (execution already marked failed from previous attempt)"
  - "Net::HTTP stdlib used for webhook dispatch (no extra gem needed); timeout configured from action_config with 30s default"
  - "hook_executed added to GOVERNANCE_ACTIONS because hook execution affects agent behavior and control flow — fits governance visibility pattern"
  - "HeartbeatEvent count in WakeAgentService test is 2 not 1: subtask creation triggers Triggerable#trigger_assignment_wake (task_assigned event) plus explicit hook_triggered from dispatch_trigger_agent"

patterns-established:
  - "ExecuteHookService pattern: initialize(execution) + call + self.call — matches all existing services (WakeAgentService, GateCheckService)"
  - "Service records audit event directly via auditable.record_audit_event! — delegates to Auditable concern on the owning model"
  - "Output payload captures dispatch-specific result metadata (validation_task_id for trigger_agent, response_code/body for webhook)"

requirements_covered:
  - id: "TRIG-02"
    description: "Hook execution dispatches trigger_agent (creates validation subtask, wakes target agent) and webhook (POST JSON to URL)"
    evidence: "app/services/execute_hook_service.rb#dispatch_trigger_agent, #dispatch_webhook"
  - id: "ACT-01"
    description: "trigger_agent hook creates a validation subtask assigned to target agent with parent_task set to triggering task"
    evidence: "app/services/execute_hook_service.rb#dispatch_trigger_agent, Task.create! with parent_task: task"
  - id: "ACT-02"
    description: "webhook hook POSTs JSON payload to configured URL with custom headers and respects configurable timeout"
    evidence: "app/services/execute_hook_service.rb#dispatch_webhook, #build_webhook_headers"
  - id: "ACT-03"
    description: "Each successful hook execution records hook_executed audit event on AgentHook for governance visibility"
    evidence: "app/services/execute_hook_service.rb#record_audit_event, AuditEvent::GOVERNANCE_ACTIONS includes hook_executed"

# Metrics
duration: ~3min
completed: 2026-03-28
---

# Plan 19-02 Summary: ExecuteHookService Dispatch Logic

**ExecuteHookService with trigger_agent dispatch (creates validation subtask + wakes target agent via WakeAgentService) and webhook dispatch (Net::HTTP POST with custom headers/timeout), full HookExecution lifecycle, and audit event recording**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-03-28T15:11:23Z
- **Completed:** 2026-03-28T15:14:43Z
- **Tasks:** 3
- **Files modified:** 6

## Accomplishments
- ExecuteHookService dispatches both hook types: trigger_agent (creates validation subtask with parent_task + calls WakeAgentService with hook_triggered) and webhook (Net::HTTP POST with configurable timeout and custom headers from action_config)
- Full HookExecution lifecycle via existing mark_* methods: queued -> mark_running! -> mark_completed! on success, mark_failed! on error with re-raise for job retry
- Audit event recorded on each successful execution via AgentHook#record_audit_event! with action "hook_executed"
- 15 service tests + 2 new job integration tests, all passing; WebMock added for HTTP stubbing
- hook_executed added to AuditEvent::GOVERNANCE_ACTIONS for governance visibility

## Task Commits

1. **Task 1: Create ExecuteHookService** - `4628e05` (feat)
2. **Task 2: Create comprehensive tests for ExecuteHookService** - `11642d8` (test)
3. **Task 3: Extend ExecuteHookJob tests and run full suite verification** - `77c8a99` (test)

## Files Created/Modified
- `app/services/execute_hook_service.rb` - Service with trigger_agent and webhook dispatch, lifecycle management, audit recording
- `test/services/execute_hook_service_test.rb` - 15 tests covering all dispatch paths, lifecycle transitions, audit events
- `test/jobs/execute_hook_job_test.rb` - Extended with 2 integration tests (queued execution, running/retry execution)
- `app/models/audit_event.rb` - Added hook_executed to GOVERNANCE_ACTIONS
- `test/models/audit_event_test.rb` - Updated GOVERNANCE_ACTIONS test to include hook_executed
- `Gemfile` + `Gemfile.lock` - Added webmock gem for HTTP stubbing

## Decisions Made

- **Re-raise after mark_failed!**: The service must re-raise so `ExecuteHookJob`'s `retry_on StandardError` mechanism fires. If the service swallowed the exception, retries would never happen.
- **`unless execution.failed?` guard**: On job retry, the execution is already `failed` from the previous attempt. Without the guard, `mark_failed!` would raise because the record is already in that state (update! on failed record with `completed_at` already set could cause issues).
- **Net::HTTP stdlib**: No external HTTP gem needed. The webhook timeout is read from `action_config["timeout"]` with a 30-second default, matching the plan's specification.
- **hook_executed in GOVERNANCE_ACTIONS**: Hook execution is a governance-relevant event because it modifies agent behavior (creates tasks, wakes agents). It fits the existing pattern of actions that affect agent control.
- **HeartbeatEvent count of 2 in WakeAgentService test**: When `dispatch_trigger_agent` creates a subtask with an assignee, `Triggerable#trigger_assignment_wake` fires (task_assigned event). Then `dispatch_trigger_agent` explicitly calls `WakeAgentService` with hook_triggered. Both are correct — the test was updated to reflect this.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] HeartbeatEvent count assertion corrected from 1 to 2**
- **Found during:** Task 2 (creating tests)
- **Issue:** Test expected `assert_difference "HeartbeatEvent.count", 1` but count changed by 2. Creating a validation subtask with an assignee triggers `Triggerable#trigger_assignment_wake` (1 task_assigned event) in addition to the explicit `WakeAgentService.call` with `hook_triggered` (1 more event).
- **Fix:** Updated assertion to `assert_difference "HeartbeatEvent.count", 2` and added a comment explaining both events. Also updated the assertion to use `HeartbeatEvent.where(trigger_type: :hook_triggered).last` to target the specific event under test.
- **Files modified:** `test/services/execute_hook_service_test.rb`
- **Verification:** All 15 service tests pass
- **Committed in:** `11642d8` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - behavior correct, test expectation wrong)
**Impact on plan:** No scope change. The code behaves correctly — the test expectation misunderstood the interaction between Triggerable and Hookable.

## Issues Encountered
- WebMock not in Gemfile. Added to :development/:test group and ran `bundle install`. Plan explicitly anticipated this scenario.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 19 is now complete: Hookable concern detects task status transitions, ExecuteHookJob enqueues, ExecuteHookService dispatches
- End-to-end flow works: task status change -> Hookable detects -> ExecuteHookJob queued -> ExecuteHookService dispatches -> HookExecution completed + audit event recorded
- Phase 20 (feedback loop) can now process validation subtasks created by trigger_agent hooks — the parent_task FK is set correctly
- Phase 21 (management UI) can build CRUD on top of the working hook triggering engine

## Self-Check: PASSED

All created files exist at expected paths. All three task commits verified in git history.

---
*Phase: 19-hook-triggering-engine*
*Completed: 2026-03-28*
