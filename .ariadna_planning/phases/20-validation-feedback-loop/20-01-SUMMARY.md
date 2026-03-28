---
phase: 20-validation-feedback-loop
plan: 01
subsystem: api
tags: [rails, activejob, activerecord, concerns, services, hooks, heartbeat, audit]

# Dependency graph
requires:
  - phase: 19-hook-triggering-engine
    provides: Hookable concern, ExecuteHookJob, ExecuteHookService, HookExecution, AgentHook, trigger_agent hooks that create validation subtasks with parent_task_id
  - phase: 07-heartbeats-and-triggers
    provides: HeartbeatEvent enum, WakeAgentService, trigger_agent_wake pattern
  - phase: 09-governance-audit
    provides: Auditable concern, AuditEvent model with GOVERNANCE_ACTIONS
provides:
  - ProcessValidationResultJob -- enqueued when a completed subtask with parent_task_id is detected by Hookable
  - ProcessValidationResultService -- collects validation messages, posts feedback on parent task, wakes original agent, records audit event
  - Hookable#enqueue_validation_feedback -- after_commit detection for completed subtasks with parent_task_id
  - HeartbeatEvent review_validation trigger_type (value 4)
  - AuditEvent GOVERNANCE_ACTIONS includes validation_feedback_received
affects:
  - 21-hook-management-ui -- UI will expose hooks that trigger the validation feedback loop
  - future agent runtime -- agents reading review_validation heartbeat events will consume feedback messages

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Service delegation: ProcessValidationResultJob is a thin wrapper that delegates entirely to ProcessValidationResultService.call"
    - "Concern extension: Hookable private method enqueue_validation_feedback added alongside existing enqueue_hooks_for_transition"
    - "Defensive service: early returns guard against missing parent task, non-completed task, terminated agent"
    - "update_columns bypass: used in tests to set status without triggering after_commit callbacks"

key-files:
  created:
    - app/jobs/process_validation_result_job.rb
    - app/services/process_validation_result_service.rb
    - test/jobs/process_validation_result_job_test.rb
    - test/services/process_validation_result_service_test.rb
  modified:
    - app/models/concerns/hookable.rb
    - app/models/task.rb
    - app/models/audit_event.rb
    - app/models/heartbeat_event.rb
    - test/models/concerns/hookable_test.rb

key-decisions:
  - "enqueue_validation_feedback fires AFTER enqueue_hooks_for_transition -- hooks that create more subtasks fire first, then feedback loop fires if this task itself is a completed subtask"
  - "ProcessValidationResultJob receives task_id (integer) not ActiveRecord record -- avoids serialization issues, allows graceful missing record handling on retry"
  - "Feedback message posted on PARENT task (not validation subtask) so the original agent's conversation thread contains the validation results"
  - "Author of feedback message is the validation agent (subtask assignee), not Current.user -- clear attribution of who provided the validation"
  - "review_validation: 4 added to HeartbeatEvent enum -- new trigger_type that enables original agent to distinguish validation feedback wakes from other wake types"
  - "WakeAgentService called with review_validation trigger_type; if parent agent is terminated, skip wake but still post message and record audit event"

patterns-established:
  - "Validation feedback loop: Hookable after_commit detects -> ProcessValidationResultJob enqueues -> ProcessValidationResultService executes (message + wake + audit)"
  - "Guard clause pattern in jobs: find_by (not find), check completed?, check parent_task_id.present? -- each early return is idempotent for retries"
  - "Service method order: post_feedback_message -> wake_original_agent -> record_audit_event -- message first so feedback_message_id is available in wake context and audit metadata"

requirements_covered:
  - id: "FEED-01"
    description: "When validation subtask completes, automatically collect results and post feedback on parent task"
    evidence: "app/models/concerns/hookable.rb#enqueue_validation_feedback + app/services/process_validation_result_service.rb#post_feedback_message"
  - id: "FEED-02"
    description: "Original agent woken with review_validation trigger after feedback is posted"
    evidence: "app/services/process_validation_result_service.rb#wake_original_agent + app/models/heartbeat_event.rb enum review_validation: 4"
  - id: "FEED-03"
    description: "Audit event validation_feedback_received recorded on parent task for governance"
    evidence: "app/services/process_validation_result_service.rb#record_audit_event + app/models/audit_event.rb GOVERNANCE_ACTIONS"

# Metrics
duration: 3min
completed: 2026-03-28
---

# Phase 20-01: Validation Feedback Loop Summary

**Completed agent-to-agent validation cycle: Hookable detects completed subtasks and triggers ProcessValidationResultService to post validation feedback on the parent task, wake the original agent with review_validation, and record a governance audit event**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-03-28T15:38:13Z
- **Completed:** 2026-03-28T15:41:00Z
- **Tasks:** 3
- **Files modified:** 9 (5 created, 4 modified)

## Accomplishments
- ProcessValidationResultJob with retry_on (3 attempts, polynomially_longer) delegates to ProcessValidationResultService -- same pattern as ExecuteHookJob
- Hookable concern extended with enqueue_validation_feedback that detects completed subtasks (saved_change_to_status? + completed? + parent_task_id.present?) and enqueues the job
- ProcessValidationResultService closes the feedback loop: collects all validation subtask messages, posts formatted feedback on parent task, wakes original agent via WakeAgentService with review_validation trigger_type, records validation_feedback_received governance audit event
- HeartbeatEvent enum extended with review_validation: 4 and AuditEvent::GOVERNANCE_ACTIONS includes validation_feedback_received
- 26 new tests (4 in HookableTest, 6 in ProcessValidationResultJobTest, 15 in ProcessValidationResultServiceTest) -- full suite: 852 tests, 0 failures, 0 errors, 0 skips

## Task Commits

1. **Task 1: Extend Hookable, create ProcessValidationResultJob, add governance action** - `774dd56` (feat)
2. **Task 2: Create ProcessValidationResultService, add review_validation enum** - `dfd84c3` (feat)
3. **Task 3: Comprehensive tests for validation feedback loop** - `b163de1` (test)

## Files Created/Modified
- `app/jobs/process_validation_result_job.rb` - Thin job with guard clauses, delegates to ProcessValidationResultService
- `app/services/process_validation_result_service.rb` - Full feedback loop: message, wake, audit
- `app/models/concerns/hookable.rb` - Added enqueue_validation_feedback private method
- `app/models/task.rb` - Registered after_commit :enqueue_validation_feedback callback
- `app/models/audit_event.rb` - Added validation_feedback_received to GOVERNANCE_ACTIONS
- `app/models/heartbeat_event.rb` - Added review_validation: 4 to trigger_type enum
- `test/models/concerns/hookable_test.rb` - Extended with 4 validation feedback detection tests
- `test/jobs/process_validation_result_job_test.rb` - 6 tests for job guard clauses and service delegation
- `test/services/process_validation_result_service_test.rb` - 15 tests covering full feedback loop

## Decisions Made
- enqueue_validation_feedback fires after enqueue_hooks_for_transition so hooks that create more subtasks (trigger_agent) fire first, then the feedback loop activates if this task is itself a completed subtask
- ProcessValidationResultJob receives task_id integer (not record) to allow graceful retry handling when records are missing
- Feedback message authored by validation agent (subtask assignee) with fallback to parent agent -- clear conversation attribution
- wake_original_agent returns early if parent has no assignee or assignee is terminated, but message and audit still proceed -- defense in depth without blocking the feedback record

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 20 Plan 01 complete: validation feedback loop fully implemented and tested
- Phase 21 (hook management UI) can proceed -- AgentHook CRUD and HookExecution visibility will expose the full hook-to-validation-feedback cycle to users
- ProcessValidationResultService is ready for agent runtime integration -- agents reading review_validation heartbeat events will find feedback messages on their parent tasks

## Self-Check: PASSED

All files confirmed present:
- app/jobs/process_validation_result_job.rb: FOUND
- app/services/process_validation_result_service.rb: FOUND
- test/jobs/process_validation_result_job_test.rb: FOUND
- test/services/process_validation_result_service_test.rb: FOUND
- .ariadna_planning/phases/20-validation-feedback-loop/20-01-SUMMARY.md: FOUND

All commits confirmed present:
- 774dd56: FOUND (Task 1 - feat: add validation feedback detection)
- dfd84c3: FOUND (Task 2 - feat: create ProcessValidationResultService)
- b163de1: FOUND (Task 3 - test: comprehensive tests)

---
*Phase: 20-validation-feedback-loop*
*Completed: 2026-03-28*
