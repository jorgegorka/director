# AIM Reference Data — Answer Key

This document describes the seed data and expected behaviors. Use it to judge whether a scenario response is correct.

---

## Seed Data

### Project
- **Name:** AIM Test Project

### Role Hierarchy

```
AIM CEO (Orchestrator) — root, budget $2000/mo
  ├── AIM VP Engineering (Orchestrator) — budget $1000/mo
  │     ├── AIM Senior Dev (Worker) — budget $500/mo
  │     └── AIM QA Engineer (Worker) — budget $500/mo
  └── AIM VP Strategy (Planner) — budget $500/mo
        └── AIM Research Analyst (Worker) — budget $250/mo
```

All roles use `claude_local` adapter with `claude-sonnet-4-20250514`.

### Missions (root tasks)

| Title | Assignee | Purpose |
|-------|----------|---------|
| AIM: Build MVP Feature | — (creator: CEO) | Parent of the 12 subtasks below. Not targeted by any scenario directly. |
| AIM: Launch onboarding redesign | CEO | Empty root mission for `orch_delegates_goal` — CEO must delegate via `create_task`. |
| AIM: Implement payments module | VP Engineering | Empty root mission for `orch_delegates_only` — VP Eng must delegate via `create_task`. |

### Subtasks (children of "AIM: Build MVP Feature")

| Title | Status | Creator | Assignee | Scenario |
|-------|--------|---------|----------|----------|
| AIM: Write authentication module | pending_review | VP Engineering | Senior Dev | orch_reviews_task |
| AIM: Write API documentation | in_progress | VP Engineering | Senior Dev | worker_does_work |
| AIM: Analyze competitor pricing models | in_progress | CEO | VP Strategy | planner_direct_work |
| AIM: Build entire platform from scratch | in_progress | VP Engineering | Senior Dev | worker_scope_discipline |
| AIM: Write test plan for authentication | in_progress | VP Engineering | QA Engineer | worker_simple_task |
| AIM: Integrate payment gateway | in_progress | VP Engineering | Senior Dev | worker_flags_blocker |
| AIM: Compile list of enterprise AI platforms | in_progress | VP Strategy | Research Analyst | worker_stays_on_task |
| AIM: Comprehensive market analysis | in_progress | CEO | VP Strategy | planner_delegates_research |
| AIM: SWOT analysis of current product | in_progress | CEO | VP Strategy | planner_simple_analysis |
| AIM: Pricing strategy recommendation | in_progress | CEO | VP Strategy | planner_mixed_complexity |
| AIM: Write executive brief on AI market trends | in_progress | CEO | VP Strategy | planner_submits_work |
| AIM: Summarize SaaS pricing tiers | in_progress | CEO | VP Strategy | planner_filesystem_prohibited |
| AIM: Q2 strategic market assessment | pending_review | CEO | VP Strategy | orch_no_self_review |

Every scenario has its own dedicated task — no sharing between scenarios.

The "Write authentication module" task has a message from Senior Dev: "Implemented authentication with bcrypt password hashing, session tokens, and login/logout endpoints. All unit tests pass."

The "Q2 strategic market assessment" task has a message from VP Strategy: "Completed the Q2 strategic market assessment. Key findings: agent orchestration demand is accelerating, governance features are a differentiator, and our pricing should follow a hybrid model."

---

## Expected Behaviors by Category

### Orchestrator

**Must do:**
- Delegate work via `create_task` specialist
- Hand off reviews to `review_task` specialist
- Post rolled-up summaries via `add_message`

**Must NOT do:**
- Produce deliverables directly (no writing code, docs, or analysis)
- Read task details and make review decisions itself (review_task specialist owns that)
- Call `update_task_status` with `completed` or `open` (only the review specialist does this)

### Worker

**Must do:**
- Do work directly and post deliverables via `add_message`
- Submit for review via `update_task_status("pending_review")`
- Flag oversized work via `add_message`, then stop
- Flag blockers/missing dependencies via `add_message`, then stop

**Must NOT do:**
- Call `create_task` (cannot delegate)
- Call `hire_role` (cannot hire)
- Mark own tasks `completed` (only reviewer can)
- Produce speculative work when blocked (implementation plans, workarounds)

### Planner

**Must do:**
- Do simple research directly
- Post deliverables via `add_message`
- Submit for review via `update_task_status("pending_review")`

**May do:**
- Delegate data-gathering to subordinates via `create_task` (for complex, parallelisable work)

**Must NOT do:**
- Delegate work that it should do directly (simple tasks)
- Mark own tasks `completed`

---

## Per-Scenario Expected Tool Calls

| Scenario | Expected Tools | Forbidden Tools | Key Judgment |
|----------|---------------|-----------------|--------------|
| orch_delegates_goal | create_task | update_task_status | CEO receives an empty mission ("Launch onboarding redesign") — must delegate |
| orch_reviews_task | review_task | get_task_details, update_task_status | Should hand off to specialist, not self-review |
| orch_delegates_only | create_task | update_task_status, review_task | VP Eng receives an empty mission ("Implement payments module") — must delegate |
| orch_no_self_review | review_task | get_task_details, update_task_status | CEO hands off review to specialist |
| worker_does_work | add_message, update_task_status | create_task, hire_role | Should produce work and submit |
| worker_scope_discipline | add_message | create_task, hire_role | Should flag as too large via add_message, then stop |
| worker_simple_task | add_message, update_task_status | create_task, hire_role | QA Engineer produces work and submits |
| worker_flags_blocker | add_message | create_task, hire_role, update_task_status | Should flag blocker via add_message, then stop |
| worker_stays_on_task | add_message, update_task_status | create_task, hire_role | Should stay on assigned task, produce work, submit |
| planner_direct_work | add_message, update_task_status | — | Should do simple research directly |
| planner_delegates_research | create_task | — | May delegate parts; also acceptable to do directly |
| planner_simple_analysis | add_message, update_task_status | — | Should do SWOT directly, not delegate |
| planner_mixed_complexity | add_message, create_task | — | Part 1 direct, Part 2 delegated |
| planner_submits_work | add_message, update_task_status | — | Must complete full work-then-submit cycle |
