---
phase: 20-validation-feedback-loop
verified: 2026-03-28T16:45:00Z
status: passed
score: "7/7 truths verified | security: 0 critical, 0 high | performance: 0 high"
performance_findings:
  - {check: "N+1 query in build_feedback_body", severity: low, file: "app/services/process_validation_result_service.rb", line: 60, detail: "msg.author accessed inside loop without .includes(:author) on line 55. Low severity because this runs in a background job and validation subtasks typically have few messages."}
---

# Phase 20: Validation Feedback Loop -- Verification Report

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | When a validation subtask with parent_task completes, ProcessValidationResultJob is automatically enqueued via after_commit callback | PASS | `app/models/concerns/hookable.rb:32-38` -- `enqueue_validation_feedback` checks `saved_change_to_status?`, `completed?`, `parent_task_id.present?` then calls `ProcessValidationResultJob.perform_later(id)`. Callback registered in `app/models/task.rb:34` as `after_commit :enqueue_validation_feedback, on: [:create, :update]`. Test at `hookable_test.rb:145-153` confirms enqueue. |
| 2 | ProcessValidationResultService collects messages from validation subtask and posts feedback message on parent task | PASS | `app/services/process_validation_result_service.rb:33-38` creates `Message.create!` on `parent_task` with body from `build_feedback_body`. Test at `process_validation_result_service_test.rb:37-44` confirms message creation on parent task. |
| 3 | Feedback message body contains validation subtask title, status, and all message bodies | PASS | `build_feedback_body` (lines 48-68) includes `validation_task.title`, `validation_task.status`, and iterates all `validation_task.messages`. Tests at lines 52-69 verify title, message content, author name, and no-messages case. |
| 4 | Original agent woken with review_validation trigger_type after feedback is posted | PASS | `wake_original_agent` (lines 73-89) calls `WakeAgentService.call` with `trigger_type: :review_validation`. `HeartbeatEvent` enum includes `review_validation: 4` (heartbeat_event.rb:6). Test at lines 81-89 confirms HeartbeatEvent is `review_validation?` with correct agent and trigger_source. |
| 5 | Audit event with action validation_feedback_received is recorded on parent task | PASS | `record_audit_event` (lines 93-107) calls `parent_task.record_audit_event!` with `action: "validation_feedback_received"`. Tests at lines 124-135 and 137-142 verify audit event action, metadata, actor, and message count. |
| 6 | Subtasks without parent_task do NOT enqueue ProcessValidationResultJob | PASS | Guard clause at `hookable.rb:35`: `return unless parent_task_id.present?`. Tests at hookable_test.rb:155-159 (root task) and 162-167 (task without parent) confirm no enqueue. |
| 7 | validation_feedback_received is included in AuditEvent::GOVERNANCE_ACTIONS | PASS | `audit_event.rb:29` lists `validation_feedback_received` in the GOVERNANCE_ACTIONS array. Test at line 144-145 asserts inclusion. |

## Artifact Status

| Artifact | Exists | Substantive | Notes |
|----------|--------|-------------|-------|
| `app/models/concerns/hookable.rb` | YES | YES | Extended with `enqueue_validation_feedback` (7 lines, proper guard clauses) |
| `app/jobs/process_validation_result_job.rb` | YES | YES | 15 lines, retry_on (3 attempts), guard clauses, delegates to service |
| `app/services/process_validation_result_service.rb` | YES | YES | 108 lines, three-phase flow: post_feedback_message, wake_original_agent, record_audit_event |
| `app/models/audit_event.rb` | YES | YES | GOVERNANCE_ACTIONS includes validation_feedback_received |
| `app/models/heartbeat_event.rb` | YES | YES | Enum includes review_validation: 4 |
| `app/models/task.rb` | YES | YES | after_commit :enqueue_validation_feedback registered on line 34 |
| `test/models/concerns/hookable_test.rb` | YES | YES | 4 new validation feedback tests (lines 145-178) |
| `test/jobs/process_validation_result_job_test.rb` | YES | YES | 6 tests: guard clauses, service delegation, queue name |
| `test/services/process_validation_result_service_test.rb` | YES | YES | 15 tests: feedback message, agent wake, audit event, edge cases, full flow |

No stubs, no TODOs, no debug statements in any phase 20 artifact.

## Key Links (Wiring)

| From | To | Via | Status |
|------|----|-----|--------|
| `hookable.rb:enqueue_validation_feedback` | `ProcessValidationResultJob.perform_later` | after_commit on Task completion when parent_task_id present | CONNECTED |
| `ProcessValidationResultJob#perform` | `ProcessValidationResultService.call` | Service delegation (find task, guard clauses, call service) | CONNECTED |
| `ProcessValidationResultService#post_feedback_message` | `Message.create!` on parent_task | ActiveRecord create with author=validation agent | CONNECTED |
| `ProcessValidationResultService#wake_original_agent` | `WakeAgentService.call` | Service-to-service with review_validation trigger_type | CONNECTED |
| `ProcessValidationResultService#record_audit_event` | `Task#record_audit_event!` via Auditable | Auditable concern on parent_task | CONNECTED |

## Cross-Phase Integration

### Phase 19 -> Phase 20 (Hook-to-Feedback Loop)

The complete E2E flow is wired:

1. **Phase 19**: `ExecuteHookService#dispatch_trigger_agent` (line 43-51) creates a validation subtask with `parent_task: task` -- this sets the `parent_task_id` that Phase 20 detects.
2. **Phase 20**: When that validation subtask is later completed, `Hookable#enqueue_validation_feedback` detects `parent_task_id.present?` and enqueues `ProcessValidationResultJob`.
3. **Phase 20**: `ProcessValidationResultService` collects messages from the validation subtask, posts feedback on the parent task, wakes the original agent with `review_validation`, and records the audit event.

Both `hook_executed` (Phase 19) and `validation_feedback_received` (Phase 20) are in `AuditEvent::GOVERNANCE_ACTIONS`, providing a complete audit trail.

### Phase 7 -> Phase 20 (WakeAgentService)

`WakeAgentService` is called with `trigger_type: :review_validation` (value 4 in HeartbeatEvent enum). The service correctly handles terminated agents (early return in `wake_original_agent`), matching WakeAgentService's own terminated check.

### Callback Ordering

`enqueue_hooks_for_transition` fires before `enqueue_validation_feedback` (task.rb lines 33-34), so hooks that create MORE subtasks fire first, then validation feedback fires if this task itself is a completed subtask. This ordering is correct and intentional.

## Test Results

- **Phase 20 tests**: 37 runs, 104 assertions, 0 failures, 0 errors, 0 skips
- **Full test suite**: 852 runs, 2106 assertions, 0 failures, 0 errors, 0 skips
- **Rubocop**: 3 files inspected, 0 offenses
- **Brakeman**: 0 security warnings

## Commits

| Commit | Message | Verified |
|--------|---------|----------|
| `774dd56` | feat(20-01): add validation feedback detection and ProcessValidationResultJob | YES |
| `dfd84c3` | feat(20-01): create ProcessValidationResultService and add review_validation trigger_type | YES |
| `b163de1` | test(20-01): add comprehensive tests for validation feedback loop | YES |

## Performance Findings

| Severity | File | Line | Detail |
|----------|------|------|--------|
| Low | `app/services/process_validation_result_service.rb` | 55/60 | N+1 on `msg.author` inside loop in `build_feedback_body`. Could add `.includes(:author)` to the messages query. Low severity: runs in background job, validation subtasks typically have few messages. |

## Security Findings

None. Brakeman reports 0 warnings. The service has no user-facing input -- it is only called from a background job with an integer task_id. No SQL interpolation, no mass assignment from params, no unescaped output.

## Duplication Findings

None. The audit recording pattern follows the established Auditable concern. The service structure (initialize + call + self.call) matches the project convention used by ExecuteHookService, WakeAgentService, etc.

## Gaps

None.
