---
phase: 31-agents-goals-heartbeats-documents
verified: 2026-03-30T14:15:41Z
status: passed
score: "8/8 truths verified (plan 01) + 7/7 truths verified (plan 02) = 15/15 | security: 0 critical, 0 high | performance: 0 high"
---

# Phase 31 Verification: Agents, Goals, Heartbeats, Documents Domain Relocation

## Phase Goal

Relocate AiClient, GoalEvaluationService, HeartbeatScheduleManager, and CreateDocumentService to their domain namespaces.

## Observable Truths

### Plan 31-01: Agents::AiClient and Goals::Evaluation

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Agents::AiClient.chat(system:, prompt:) communicates with the Anthropic API identically | PASS | Full implementation at app/models/agents/ai_client.rb:23-47 with Net::HTTP, JSON parsing, usage return. 4 tests pass. |
| 2 | Agents::AiClient.estimate_cost_cents(usage) calculates cost from token usage identically | PASS | Implementation at line 17-21 with INPUT/OUTPUT_COST_PER_MILLION constants. Test at ai_client_test.rb:51-56 passes. |
| 3 | Goals::Evaluation.call(task) evaluates completed tasks against goals, records results, wakes agents | PASS | Full 188-line implementation with pass/fail/block flows. 13 tests covering all flows pass. |
| 4 | EvaluateGoalAlignmentJob calls Goals::Evaluation instead of GoalEvaluationService | PASS | evaluate_goal_alignment_job.rb:13 reads `Goals::Evaluation.call(task)`. Job test line 39 description updated. |
| 5 | Goals::Evaluation internally calls Agents::AiClient instead of bare AiClient | PASS | evaluation.rb:55 calls `Agents::AiClient.chat(...)`, line 95 calls `Agents::AiClient.estimate_cost_cents(...)`. |
| 6 | All existing AiClient tests pass under Agents::AiClient namespace | PASS | `bin/rails test test/models/agents/ai_client_test.rb` -- 4 runs, 0 failures. |
| 7 | All existing GoalEvaluationService tests pass under Goals::Evaluation namespace | PASS | `bin/rails test test/models/goals/evaluation_test.rb` -- 13 runs, 0 failures. |
| 8 | No file outside .ariadna_planning/ references bare AiClient or GoalEvaluationService | PASS | grep for `\bAiClient\b` returns only `Agents::AiClient` references. grep for `GoalEvaluationService` returns zero matches in app/ and test/. |

### Plan 31-02: Heartbeats::ScheduleManager and Documents::Creator

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Heartbeats::ScheduleManager.sync(role) creates/removes recurring Solid Queue jobs | PASS | Full 77-line implementation with upsert_recurring_task/remove logic. 7 tests pass. |
| 2 | Heartbeats::ScheduleManager.remove(role) destroys the recurring task | PASS | Implementation at lines 16-19 with find_recurring_task/destroy. Test at line 102-109 passes. |
| 3 | Documents::Creator.call(author:, company:, title:, body:, tag_names:) creates documents with tag linking | PASS | Complete 18-line implementation. 6 tests covering role/user authors, tags, existing tags, validation, no auto-link all pass. |
| 4 | Role#sync_heartbeat_schedule calls Heartbeats::ScheduleManager instead of HeartbeatScheduleManager | PASS | role.rb:216 reads `Heartbeats::ScheduleManager.sync(self)`, triggered by after_commit at line 40. |
| 5 | All existing HeartbeatScheduleManager tests pass under Heartbeats::ScheduleManager namespace | PASS | `bin/rails test test/models/heartbeats/schedule_manager_test.rb` -- 7 runs, 0 failures. |
| 6 | All existing CreateDocumentService tests pass under Documents::Creator namespace | PASS | `bin/rails test test/models/documents/creator_test.rb` -- 6 runs, 0 failures. |
| 7 | No file outside .ariadna_planning/ references bare HeartbeatScheduleManager or CreateDocumentService | PASS | grep for both returns zero matches in app/ and test/. |

## Artifact Status

| Artifact | Status | Details |
|----------|--------|---------|
| app/models/agents/ai_client.rb | EXISTS, substantive | 79 lines, Agents::AiClient with full API wrapper |
| app/models/goals/evaluation.rb | EXISTS, substantive | 189 lines, Goals::Evaluation with complete evaluation logic |
| app/models/heartbeats/schedule_manager.rb | EXISTS, substantive | 77 lines, Heartbeats::ScheduleManager with SolidQueue integration |
| app/models/documents/creator.rb | EXISTS, substantive | 19 lines, Documents::Creator with tag linking |
| test/models/agents/ai_client_test.rb | EXISTS, substantive | 4 tests, all pass |
| test/models/goals/evaluation_test.rb | EXISTS, substantive | 13 tests, all pass |
| test/models/heartbeats/schedule_manager_test.rb | EXISTS, substantive | 7 tests with FakeTask/FakeTaskStore, all pass |
| test/models/documents/creator_test.rb | EXISTS, substantive | 6 tests, all pass |
| app/services/ai_client.rb | DELETED | Confirmed absent |
| app/services/goal_evaluation_service.rb | DELETED | Confirmed absent |
| app/services/heartbeat_schedule_manager.rb | DELETED | Confirmed absent |
| app/services/create_document_service.rb | DELETED | Confirmed absent |
| test/services/ai_client_test.rb | DELETED | Confirmed absent |
| test/services/goal_evaluation_service_test.rb | DELETED | Confirmed absent |
| test/services/heartbeat_schedule_manager_test.rb | DELETED | Confirmed absent |
| test/services/create_document_service_test.rb | DELETED | Confirmed absent |

## Key Links (Wiring)

| From | To | Via | Status |
|------|----|-----|--------|
| EvaluateGoalAlignmentJob (line 13) | Goals::Evaluation.call | Direct method call | VERIFIED |
| Goals::Evaluation#evaluate (line 55) | Agents::AiClient.chat | Direct method call | VERIFIED |
| Goals::Evaluation#record_evaluation (line 95) | Agents::AiClient.estimate_cost_cents | Direct method call | VERIFIED |
| Goals::Evaluation#wake_role (line 159) | Roles::Waking.call | Direct method call | VERIFIED (Roles::Waking exists at app/models/roles/waking.rb, accepts **args) |
| Role#sync_heartbeat_schedule (line 216) | Heartbeats::ScheduleManager.sync | after_commit callback | VERIFIED |

## Cross-Phase Integration

- **Phase 29 (Roles domain)**: Goals::Evaluation calls Roles::Waking.call (phase 29 artifact) -- verified wiring intact.
- **Phase 30 (Hooks/Budgets)**: No direct dependency. app/services/ now only contains 3 remaining services (apply_all_role_templates_service.rb, apply_role_template_service.rb, role_template_registry.rb) -- no orphaned references.
- **No orphaned modules**: All four relocated classes have at least one caller or test exercising them.
- **E2E flow**: Task completion -> EvaluateGoalAlignmentJob -> Goals::Evaluation.call -> Agents::AiClient.chat -> evaluation recorded -> Roles::Waking on failure. Full chain uses new namespaces.

## Test Results

- Phase-specific tests: 35 runs, 90 assertions, 0 failures, 0 errors
- Full suite: 1243 runs, 3412 assertions, 0 failures, 0 errors, 0 skips
- Rubocop: 6 files inspected, 0 offenses

## Commits

| Hash | Message | Status |
|------|---------|--------|
| 292bfdb | refactor(31-01): relocate AiClient to Agents::AiClient | VERIFIED |
| 269f4e4 | refactor(31-01): relocate GoalEvaluationService to Goals::Evaluation | VERIFIED |
| 89d527d | refactor(31-02): relocate HeartbeatScheduleManager to Heartbeats::ScheduleManager | VERIFIED |
| 75b9712 | refactor(31-02): relocate CreateDocumentService to Documents::Creator | VERIFIED |

## Security Findings

None. API key access uses Rails credentials with ENV fallback -- no hardcoded secrets, no logging of sensitive data.

## Performance Findings

None.

## Duplication Findings

None. Each class exists exactly once in the codebase.

## Anti-Patterns

None detected. No TODOs, FIXMEs, stubs, debug statements, or placeholder implementations.
