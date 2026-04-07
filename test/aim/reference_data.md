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

### Goal
- **Title:** AIM: Build MVP Feature
- **Assigned to:** AIM CEO
- **Description:** Build the minimum viable product feature set including auth, API, and tests.

### Tasks

| Title | Status | Creator | Assignee | Goal |
|-------|--------|---------|----------|------|
| AIM: Write authentication module | pending_review | VP Engineering | Senior Dev | Build MVP Feature |
| AIM: Write API documentation | open | VP Engineering | Senior Dev | Build MVP Feature |
| AIM: Analyze competitor pricing models | open | CEO | VP Strategy | Build MVP Feature |

The "Write authentication module" task has a message from Senior Dev: "Implemented authentication with bcrypt password hashing, session tokens, and login/logout endpoints. All unit tests pass."

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
- Flag oversized work via `add_message` (scope discipline)

**Must NOT do:**
- Call `create_task` (cannot delegate)
- Call `hire_role` (cannot hire)
- Mark own tasks `completed` (only reviewer can)

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
| orch_delegates_goal | create_task | update_task_status | Should delegate, not do work |
| orch_reviews_task | review_task | get_task_details, update_task_status | Should hand off to specialist, not self-review |
| worker_does_work | add_message, update_task_status | create_task, hire_role | Should produce work and submit |
| worker_scope_discipline | add_message | create_task, hire_role | Should flag as too large, not attempt delegation |
| planner_direct_work | add_message, update_task_status | — | Should do simple research directly |
| planner_delegates_research | create_task | — | May delegate parts; also acceptable to do directly |
