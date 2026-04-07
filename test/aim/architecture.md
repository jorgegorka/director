# Director AI Architecture — AIM Reference

This document maps the Director prompt composition pipeline. Read it when you need to understand or modify agent behavior.

---

## How an agent runs

```
Goal/Task assigned or heartbeat fires
  → ExecuteRoleJob enqueued
    → Builds context hash (task, goal, skills)
    → ClaudeLocalAdapter.execute(role, context)
      → compose_system_prompt(role, context)
        → build_identity_prompt (who you are, org chart, tool catalog)
        → role.job_spec (role-specific override, if any)
        → role.role_category.job_spec (category behavioral instructions)
        → build_goal_prompt (if working on a goal)
        → build_skills_prompt (if role has skills)
      → build_user_prompt(context)
        → Task assigned: task title + description + documents
        → Goal assigned: goal title + description + active tasks
        → Task pending review: task id + assignee + hand-off instruction
      → Spawns `claude -p` in tmux with stream-json output
      → MCP config points at bin/director-mcp with role's API token
```

---

## System prompt composition

**File:** `app/adapters/claude_local_adapter.rb`

The system prompt is composed from 5 parts in this order:

| Part | Method | Lines | Content |
|------|--------|-------|---------|
| Identity | `build_identity_prompt` | 190-238 | Role title, project name, org chart (manager + reports), specialist tool catalog, efficiency rules |
| Role job_spec | `role.job_spec` | — | Optional role-level override (most roles don't have one) |
| Category job_spec | `role.role_category.job_spec` | — | The main behavioral instructions — Orchestrator, Planner, or Worker |
| Goal context | `build_goal_prompt` | 241-254 | Current goal title + description + focus rules |
| Skills | `build_skills_prompt` | 256-278 | Skill catalog + full markdown instructions |

---

## User prompt (trigger context)

**File:** `app/adapters/claude_local_adapter.rb:280-316`

The user prompt varies by trigger type:

| Trigger | What the agent sees |
|---------|--------------------|
| `task_pending_review` | "Task #N is pending your review: {title}. {assignee} has submitted this task for review. Hand this off to the review_task specialist." |
| `task_assigned` | "You have been assigned Task #N: {title}. {description}. Reference documents (if any). The task is already in_progress. Start working immediately." |
| `goal_assigned` | "You have been assigned Goal: {title}. {description}. Active tasks list (if any). Focus instructions." |
| `heartbeat` | "Check your assigned goals and tasks, then execute the highest-priority work." |

---

## Files to modify during optimization

### High impact (affects all roles in a category)

| File | What it controls |
|------|-----------------|
| `db/seeds/role_categories.yml` | The 3 category job specs. Primary optimization target. After editing, run `bin/rails db:seed` to reload into the database. |

### Medium impact (affects all roles)

| File | What it controls |
|------|-----------------|
| `app/adapters/claude_local_adapter.rb:190-238` | Identity prompt — shared "How to Work" section, specialist tool descriptions, efficiency rules. |
| `app/adapters/claude_local_adapter.rb:280-316` | User prompt — how tasks/goals are presented. Controls context quality. |

### Medium impact (affects specific sub-agents)

| File | What it controls |
|------|-----------------|
| `app/mcp/sub_agents/create_task.rb:45-64` | create_task specialist system prompt |
| `app/mcp/sub_agents/review_task.rb:39-58` | review_task specialist system prompt |
| `app/mcp/sub_agents/hire_role.rb:39-55` | hire_role specialist system prompt |
| `app/mcp/sub_agents/summarize_goal.rb:37-53` | summarize_goal specialist system prompt |

### Low impact (affects tool descriptions)

| File | What it controls |
|------|-----------------|
| `app/mcp/tools/*.rb` | Individual tool definitions — tool name, description, input schema |
| `app/mcp/director_server.rb:9-48` | Tool scopes — which tools each category/sub-agent can see |

---

## Tool scopes

### Orchestrator scope (15 tools)

**Specialist wrappers** (spawn sub-agents):
- `create_task` — delegate task creation
- `review_task` — delegate review decisions
- `hire_role` — delegate hiring
- `summarize_goal` — delegate goal summary writing

**Mechanical tools** (direct use):
- `update_task_status`, `list_my_tasks`, `list_my_goals`
- `list_available_roles`, `list_hirable_roles`
- `add_message`, `get_task_details`, `get_goal_details`
- `update_goal`, `search_documents`, `get_document`

### Sub-agent scopes

| Sub-agent | Tools |
|-----------|-------|
| create_task | `get_goal_details`, `list_available_roles`, `create_task` (direct) |
| review_task | `get_task_details`, `submit_review_decision` |
| hire_role | `list_hirable_roles`, `hire_role` (direct) |
| summarize_goal | `get_goal_details`, `update_goal_summary` |

**Note:** Workers see the same mechanical tools as orchestrators but WITHOUT the 4 specialist wrappers. However, the current implementation gives all categories the orchestrator scope. This is a known gap — the tool_scope for workers/planners is not yet differentiated at the DirectorServer level. Behavioral discipline comes entirely from the job_spec prompt instructions.

---

## Configuration

| Setting | Value | Where |
|---------|-------|-------|
| Default model | claude-sonnet-4-20250514 | `db/seeds.rb` line 25 |
| Max turns (sub-agents) | 6-8 | `app/mcp/sub_agents/base.rb` line 7 |
| Max turns (AIM scenarios) | 10 | `test/aim/lib/runner.rb` |
| MCP transport | stdin/stdout JSON-RPC | `app/mcp/director_server.rb` |

---

## Context building (for AIM scenarios)

The AIM runner must replicate the context hash that `ExecuteRoleJob.build_context` produces. Key fields:

```ruby
{
  run_id: nil,                          # Not needed for AIM
  trigger_type: "task_assigned",        # From scenario
  task_id: task.id,                     # Resolved from seed data
  task_title: task.title,
  task_description: task.description,
  assignee_role_title: task.assignee.title,
  goal_id: goal.id,
  goal_title: goal.title,
  goal_description: goal.description,
  goal_active_tasks: [...],             # Array of {id, title, status, assignee_id}
  skills: [...]                         # Serialized skills array
}
```
