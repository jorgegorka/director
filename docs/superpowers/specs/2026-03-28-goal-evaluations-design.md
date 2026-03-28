# Goal Evaluations: Goals as Agent Evals

## Context

Goals in Director are currently passive containers — they group tasks and show progress %. Agents have no awareness of goals, and task completion triggers no quality assessment. This means an agent can mark tasks "done" without actually advancing the company's objectives.

This design turns goals into an active evaluation layer. When an agent completes a task, an AI evaluator judges whether the work meaningfully advances the agent's assigned goal. Failed evaluations reopen the task with feedback, creating an automatic improvement loop.

## Data Model

### Agent goal assignment

Add `goal_id` (FK, optional) to the `agents` table.

- `Agent belongs_to :goal, optional: true`
- `Goal has_many :agents`
- One agent, one goal. A goal can have multiple agents working toward it.
- Validation: goal must belong to the same company (Tenantable).

### GoalEvaluation model (new)

| Column | Type | Notes |
|--------|------|-------|
| `id` | bigint | PK |
| `company_id` | bigint, FK, NOT NULL | Tenantable |
| `task_id` | bigint, FK, NOT NULL | The completed task being evaluated |
| `goal_id` | bigint, FK, NOT NULL | The goal evaluated against |
| `agent_id` | bigint, FK, NOT NULL | The agent whose work is evaluated |
| `result` | integer (enum) | `pass: 0, fail: 1` |
| `feedback` | text, NOT NULL | AI-generated explanation |
| `attempt_number` | integer, NOT NULL | 1, 2, or 3 |
| `cost_cents` | integer | Token cost of the evaluation call |
| `created_at` | datetime | |
| `updated_at` | datetime | |

Indexes: `[task_id, attempt_number]` (unique), `[goal_id]`, `[agent_id]`.

Associations:
- `belongs_to :company` (Tenantable)
- `belongs_to :task`
- `belongs_to :goal`
- `belongs_to :agent`

Constants:
- `MAX_ATTEMPTS = 3`

Scopes:
- `passed` / `failed` — filter by result
- `for_task(task)` — evaluations for a specific task
- `latest` — most recent first

## Evaluation Flow

### Trigger

In `Task` model, a new `after_commit` callback:

```
after_commit :enqueue_goal_evaluation, on: [:update]
```

Fires when: `status_previously_changed? && completed? && assignee&.goal.present?`

Enqueues `EvaluateGoalAlignmentJob.perform_later(task.id)`.

### Job: EvaluateGoalAlignmentJob

1. Load task, agent, goal
2. Delegate to `GoalEvaluationService.call(task)`

### Service: GoalEvaluationService

**Input:** a completed Task whose assignee has a goal.

**Steps:**

1. **Check attempt count.** Count existing GoalEvaluations for this task. If `>= MAX_ATTEMPTS`, mark task as `blocked`, create audit event, return early.

2. **Build evaluation context:**
   - Goal hierarchy via `goal.ancestry_chain` (mission -> objective -> sub-objective)
   - Task title + description
   - Task messages (work output from the agent)

3. **Call AI evaluator.** A lightweight, single-turn LLM call (not a full agent run). Send structured prompt, parse structured response: `{ result: "pass"|"fail", feedback: "..." }`.

4. **Record GoalEvaluation.** Create record with result, feedback, attempt_number, cost_cents.

5. **Charge cost to agent budget.** Add the evaluation's `cost_cents` to the task's `cost_cents` field (the existing budget system sums task costs per agent per month).

6. **If fail:**
   - Post feedback as a Message on the task (sender: system or evaluator)
   - Update task status to `in_progress` (reopens it)
   - Wake agent via `WakeAgentService` with `trigger_type: :goal_evaluation_failed` and context including the feedback

7. **If pass:**
   - Task stays completed. Normal flow continues.
   - GoalEvaluation recorded for audit.

### New HeartbeatEvent trigger type

Add `:goal_evaluation_failed` to the trigger_type enum on HeartbeatEvent. This distinguishes evaluation-driven wakes from other triggers, allowing the agent execution context to include the evaluation feedback.

## AI Evaluator

### Approach

A direct, single-turn API call to Claude — not a full agent execution. The evaluation is a focused judgment, not open-ended work.

### Prompt structure

```
You are evaluating whether a completed task advances a company goal.

## Goal Hierarchy
Mission: {mission title} - {mission description}
  Objective: {objective title} - {objective description}
    Sub-objective: {sub-objective title} - {sub-objective description}

## Completed Task
Title: {task title}
Description: {task description}

## Work Output
{task messages / agent output}

## Instructions
Evaluate whether this task's output meaningfully advances the stated goal.
Respond in JSON:
{
  "result": "pass" or "fail",
  "feedback": "2-3 sentence explanation. If fail, include specific guidance."
}
```

### Implementation

New `AiClient` service (or similar thin wrapper) that:
- Accepts a prompt and expected response format
- Calls the Claude API
- Parses the JSON response
- Returns structured result
- Tracks token usage for cost calculation

This client is intentionally minimal — it's not the agent execution pipeline. It's a utility for single-turn AI calls that other services can reuse.

## UI Changes

### Task show page

Below task details, add an "Evaluations" section:
- List of evaluation attempts (attempt #, pass/fail badge, feedback, timestamp)
- Current evaluation status: "Passed", "Failed - retrying (attempt 2/3)", "Blocked - evaluation exhausted"
- Only visible when task has evaluations

### Agent show page

New "Goal" section:
- Assigned goal (linked to goal show page)
- Evaluation summary: total evaluations, pass rate %
- Recent evaluations (last 5)

### Goal show page

Add evaluation stats alongside existing progress %:
- Tasks evaluated count
- Pass/fail ratio
- This distinguishes "progress" (tasks completed) from "quality" (tasks that actually advance the goal)

### Dashboard

Existing mission display can show evaluation health alongside progress %.

## Files to Create

- `db/migrate/TIMESTAMP_add_goal_id_to_agents.rb`
- `db/migrate/TIMESTAMP_create_goal_evaluations.rb`
- `app/models/goal_evaluation.rb`
- `app/jobs/evaluate_goal_alignment_job.rb`
- `app/services/goal_evaluation_service.rb`
- `app/services/ai_client.rb`

## Files to Modify

- `app/models/agent.rb` — add `belongs_to :goal`, validation, goal-related methods
- `app/models/goal.rb` — add `has_many :agents`, `has_many :goal_evaluations`
- `app/models/task.rb` — add `after_commit :enqueue_goal_evaluation`, add `has_many :goal_evaluations`
- `app/models/heartbeat_event.rb` — add `:goal_evaluation_failed` trigger type
- `app/controllers/agents_controller.rb` — permit `goal_id` param, load goal for form
- `app/views/agents/_form.html.erb` — add goal select dropdown
- `app/views/agents/show.html.erb` — add Goal section with eval stats
- `app/views/tasks/show.html.erb` — add Evaluations section
- `app/views/goals/show.html.erb` — add evaluation stats
- `test/fixtures/goal_evaluations.yml` — test fixtures
- `test/models/goal_evaluation_test.rb` — model tests
- `test/services/goal_evaluation_service_test.rb` — service tests
- `test/jobs/evaluate_goal_alignment_job_test.rb` — job tests

## Verification

1. **Unit tests:** GoalEvaluation model validations, scopes, associations
2. **Service tests:** GoalEvaluationService with mocked AI client — test pass flow, fail flow, retry exhaustion, budget charging
3. **Job tests:** EvaluateGoalAlignmentJob dispatches service correctly
4. **Model tests:** Agent goal association, Task evaluation trigger callback
5. **Controller tests:** Agent form accepts goal_id, show page renders eval stats
6. **Manual test:** Assign a goal to an agent, create a task for that agent, mark it complete, verify evaluation fires and result is recorded
7. **Rubocop + Brakeman:** Ensure no style or security issues
