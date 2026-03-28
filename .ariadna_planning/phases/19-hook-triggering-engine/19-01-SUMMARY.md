---
phase: 19-hook-triggering-engine
plan: 01
status: complete
started_at: 2026-03-28T15:05:21Z
completed_at: 2026-03-28T15:08:39Z
duration: ~3 minutes
tasks_completed: 3/3
files_changed: 4
---

# Plan 19-01 Summary: Hook Triggering Engine

## Objective

Create the Hookable concern that detects task status transitions and automatically enqueues hook execution jobs. When a task moves to `in_progress` or `completed`, the concern finds all matching enabled hooks on the assignee agent (ordered by position), creates a `HookExecution` record for each, and enqueues `ExecuteHookJob`.

## What Was Built

### Files Created

- **`app/models/concerns/hookable.rb`** — Concern with `HOOKABLE_TRANSITIONS` map, `enqueue_hooks_for_transition` private method (called via `after_commit`), and `build_hook_input_payload` helper
- **`app/jobs/execute_hook_job.rb`** — Job with `retry_on StandardError` (3 attempts, polynomially_longer), `discard_on ActiveJob::DeserializationError`, guard clauses for completed/failed/missing executions, delegation to `ExecuteHookService.call`
- **`test/models/concerns/hookable_test.rb`** — 11 tests covering all transition cases
- **`test/jobs/execute_hook_job_test.rb`** — 5 tests covering guard clauses and configuration

### Files Modified

- **`app/models/task.rb`** — Added `include Hookable` and `after_commit :enqueue_hooks_for_transition, on: [:create, :update]`
- **`test/fixtures/agent_hooks.yml`** — Added `claude_start_validation_hook` (position: 1) giving claude_agent 2 `after_task_start` hooks for ordering tests

## Key Design Decisions

- **`saved_change_to_status?` in after_commit context** — consistent with existing Task pattern (`saved_change_to_assignee_id?` in `trigger_assignment_wake`); works for both creates and updates
- **`HOOKABLE_TRANSITIONS` map** — maps only `in_progress` and `completed` to lifecycle event strings; all other transitions (open, blocked, cancelled) return nil and are ignored
- **Individual HookExecution per hook** — each hook gets its own execution record and job, enabling independent execution tracking and retry
- **Input payload captured at enqueue time** — task title, agent name, lifecycle event, hook metadata all stored in `input_payload` before the job runs, providing a snapshot of context at trigger time
- **Scope chain `enabled.for_event.ordered`** — uses the existing `Enableable#enabled`, `AgentHook#for_event`, and `AgentHook#ordered` scopes; no custom querying logic in the concern

## Deviations

### Rule 3 — ExecuteHookJob created in Task 1 (not Task 2)

**Trigger:** After creating `hookable.rb` and running the test suite, existing test `TaskTest#test_task_status_change_does_not_error` raised `NameError: uninitialized constant Hookable::ExecuteHookJob`. The `enqueue_hooks_for_transition` method references `ExecuteHookJob` at runtime, and Task 1's tests triggered that code path before Task 2 created the job.

**Fix:** Created `execute_hook_job.rb` as part of Task 1 execution to unblock the test suite. The job was staged in the Task 1 commit. Task 2 became a verification step (syntax check + review).

### Test fix — `assert_difference count` for direct in_progress creation

**Trigger:** The plan's test expected 1 HookExecution from creating a task directly in `in_progress` status, but `claude_agent` has 2 `after_task_start` hooks (`claude_webhook_hook` pos 0 + `claude_start_validation_hook` pos 1).

**Fix:** Changed `assert_difference ... 1` to `assert_difference ... 2` with an explanatory comment. This is correct behavior — the concern works as designed.

## Test Results

```
16 new tests (11 hookable, 5 job) — 0 failures, 0 errors
Full suite: 809 runs, 1976 assertions, 0 failures, 0 errors
```

## Commits

| Hash | Description |
|------|-------------|
| `3998dad` | feat(19-01): create Hookable concern with status transition detection and hook enqueueing |
| `6866273` | test(19-01): add comprehensive tests for Hookable concern and ExecuteHookJob |

## Self-Check: PASSED

All created files exist at expected paths. Both commits verified in git history.

## Next Plan

**19-02** — ExecuteHookService implementation (trigger_agent and webhook dispatch logic). The job and HookExecution records are in place; 19-02 implements `ExecuteHookService.call(execution)`.
