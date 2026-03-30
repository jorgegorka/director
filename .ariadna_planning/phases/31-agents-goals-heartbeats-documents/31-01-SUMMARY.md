---
phase: 31-agents-goals-heartbeats-documents
plan: 01
status: complete
completed_at: 2026-03-30T14:11:00Z
duration: ~2 minutes
tasks_completed: 2
tasks_total: 2
commits:
  - 292bfdb
  - 269f4e4
---

# Plan 31-01 Summary: Agents::AiClient and Goals::Evaluation Relocation

## Objective

Relocate AiClient and GoalEvaluationService to their domain namespaces as Agents::AiClient and Goals::Evaluation respectively. These two classes moved together because GoalEvaluationService calls AiClient internally.

## Tasks Completed

### Task 1: Relocate AiClient to Agents::AiClient (292bfdb)

- Created `app/models/agents/ai_client.rb` — Agents::AiClient wrapping the exact logic from app/services/ai_client.rb
- Created `test/models/agents/ai_client_test.rb` — Agents::AiClientTest with updated class references (AiClient -> Agents::AiClient, AiClient::ApiError -> Agents::AiClient::ApiError, AiClient::ParseError -> Agents::AiClient::ParseError)
- Deleted `app/services/ai_client.rb`
- Deleted `test/services/ai_client_test.rb`
- All 4 AiClient tests pass under new namespace

### Task 2: Relocate GoalEvaluationService to Goals::Evaluation (269f4e4)

- Created `app/models/goals/evaluation.rb` — Goals::Evaluation wrapping the exact logic from app/services/goal_evaluation_service.rb, with internal references updated to Agents::AiClient
- Created `test/models/goals/evaluation_test.rb` — Goals::EvaluationTest with updated class references (GoalEvaluationService.call -> Goals::Evaluation.call)
- Updated `app/jobs/evaluate_goal_alignment_job.rb` line 13: GoalEvaluationService.call -> Goals::Evaluation.call
- Updated `test/jobs/evaluate_goal_alignment_job_test.rb` test description: "calls GoalEvaluationService for eligible task" -> "calls Goals::Evaluation for eligible task"
- Deleted `app/services/goal_evaluation_service.rb`
- Deleted `test/services/goal_evaluation_service_test.rb`
- All 18 goals/evaluation and job tests pass

## Artifacts Created

| Path | Provides |
|------|----------|
| app/models/agents/ai_client.rb | Agents::AiClient — Anthropic API wrapper |
| app/models/goals/evaluation.rb | Goals::Evaluation — goal alignment evaluation logic |
| test/models/agents/ai_client_test.rb | Agents::AiClientTest — 4 tests |
| test/models/goals/evaluation_test.rb | Goals::EvaluationTest — 13 tests |

## Key Links

- `EvaluateGoalAlignmentJob` -> `Goals::Evaluation.call` (direct method call)
- `Goals::Evaluation#evaluate` -> `Agents::AiClient.chat` (direct method call)
- `Goals::Evaluation#record_evaluation` -> `Agents::AiClient.estimate_cost_cents` (direct method call)
- `Goals::Evaluation#wake_role` -> `Roles::Waking.call` (unchanged)

## Verification

- `bin/rails test test/models/agents/ai_client_test.rb` — 4 runs, 0 failures
- `bin/rails test test/models/goals/evaluation_test.rb test/jobs/evaluate_goal_alignment_job_test.rb` — 18 runs, 0 failures
- `bin/rails test` — 1243 runs, 3412 assertions, 0 failures, 0 errors, 0 skips
- No bare AiClient or GoalEvaluationService references remain in app/ or test/
- app/models/agents/ and app/models/goals/ directories established

## Deviations

None. Execution was straightforward — direct copy with namespace wrapping and two internal reference updates.

## Self-Check: PASSED

Files exist:
- FOUND: app/models/agents/ai_client.rb
- FOUND: app/models/goals/evaluation.rb
- FOUND: test/models/agents/ai_client_test.rb
- FOUND: test/models/goals/evaluation_test.rb

Commits exist:
- FOUND: 292bfdb (refactor(31-01): relocate AiClient to Agents::AiClient)
- FOUND: 269f4e4 (refactor(31-01): relocate GoalEvaluationService to Goals::Evaluation)

Old files deleted:
- CONFIRMED: app/services/ai_client.rb deleted
- CONFIRMED: app/services/goal_evaluation_service.rb deleted
- CONFIRMED: test/services/ai_client_test.rb deleted
- CONFIRMED: test/services/goal_evaluation_service_test.rb deleted
