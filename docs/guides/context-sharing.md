# Agent Context Sharing

How context is assembled when an agent is woken up by a heartbeat, @mention, question answer, task assignment, or hook.

## The Flow

### 1. Trigger fires

A heartbeat, @mention, question answer, task assignment, or hook calls `Roles::Waking.call()` with a `trigger_type` and trigger-specific `context` hash (e.g., `task_id`, `message_id`, `answered_by`).

### 2. `Roles::Waking` creates a `RoleRun`

(`app/models/roles/waking.rb:61-66`) — it copies the `task_id` and `trigger_type` from the trigger context, then enqueues `ExecuteRoleJob`.

### 3. `ExecuteRoleJob#build_context` assembles the full context

(`app/jobs/execute_role_job.rb:36-57`):

| Context piece | Source |
|---|---|
| `run_id`, `trigger_type` | From the `RoleRun` record |
| `task_id`, `task_title`, `task_description` | Loaded from `role_run.task` (if task-triggered) |
| `resume_session_id` | `role.latest_session_id` — the `claude_session_id` from the most recent completed `RoleRun` |
| `skills` | `role.skills` serialized with key, name, description, markdown |
| `documents` | Three groups: skill docs, role docs, task docs |

### 4. Adapter composes the actual prompt

(`app/adapters/claude_local_adapter.rb:96-142`):

- **System prompt** = `role.job_spec` + skills catalog (names/descriptions) + skill instructions (full markdown in `<skill>` XML tags)
- **User prompt** = `task_description` or `task_title`
- **Session resumption** = `--resume {session_id}` flag if a previous session exists

## Context by Trigger Type

### Heartbeats

The context is minimal — just `trigger_type: :scheduled`. There is typically no task, so the agent wakes with only its job spec, skills, documents, and any prior session to resume. The user prompt falls back to `"Execute assigned task"`.

### Question Answered

The waking context includes `answer_message_id`, `question_message_id`, `task_id`, and `answered_by`. The task gets loaded and its description becomes the user prompt. The agent can resume its previous Claude session via `--resume`, which restores its full conversation history from the prior run.

### Task Assignment

Context includes `task_id`, `task_title`, and `task_description`. The task description becomes the user prompt directly.

### @Mention

Context includes `message_id`, `task_id`, and `mentioned_by` (either `"user"` or `"role"`). The associated task provides the user prompt.

### Hook Triggered

Context includes `hook_id`, `hook_name`, `validation_task_id`, and `original_task_id`/`original_task_title`. A new "Validate: {task_title}" task is created and assigned to the target agent.

## Session Resumption

Session resumption is the primary memory mechanism. There is no explicit conversation history re-transmission. Claude CLI's `--resume` flag handles restoring the agent's prior context internally. The `claude_session_id` is persisted on `RoleRun` after each completed execution and retrieved via `role.latest_session_id`.

## Key Files

- `app/models/roles/waking.rb` — Wake-up orchestrator
- `app/jobs/execute_role_job.rb` — Context assembly
- `app/adapters/claude_local_adapter.rb` — Prompt composition (local CLI)
- `app/adapters/http_adapter.rb` — Payload composition (cloud agents)
- `app/models/concerns/triggerable.rb` — Wake trigger helpers
- `app/models/heartbeat_event.rb` — Wake-up audit log
- `app/models/role_run.rb` — Execution state tracking
