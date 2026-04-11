# Goals and Tasks

How Director organizes work for your AI company — one unified model for both the day-to-day work and the missions it serves.

## One Model: Tasks

Director has a single work-unit model: the **task**. Every piece of work — from a multi-month company mission down to a one-off fix — lives in the `tasks` table.

What makes the model feel like "goals and tasks" is the task hierarchy:

- A **root task** (a task with no parent) is a **mission**. It's the top-level description of what a part of the company is trying to achieve.
- The subtasks underneath it are the concrete work that advances that mission.

The Goals page at `/goals` is just a filtered view of your root tasks. Creating a "goal" there creates a task with no parent. Agents break it down into subtasks from there.

## Tasks

Every task has a title, an optional description, a status, a priority, and a completion percentage. Most tasks are created by an agent (or a human) under an existing root task.

### Status

Tasks move through a lifecycle:

- **Open** — created but work hasn't started
- **In progress** — an agent is actively working on it
- **Pending review** — work is finished and waiting for approval
- **Completed** — the work is done
- **Blocked** — something is preventing progress
- **Cancelled** — the work is no longer needed

When a task is marked completed, Director automatically records the completion timestamp.

### Priority

Each task has a priority level that signals how urgent it is:

- **Low** — handle when you get to it
- **Medium** — normal priority (the default)
- **High** — should be addressed soon
- **Urgent** — needs immediate attention

The dashboard sorts tasks by priority, so agents and users see the most urgent work first.

### Assigning a Task to an Agent

When you assign a task to an agent, that agent automatically wakes up and starts working. The task's title and description become the agent's instructions — the description is literally what the agent reads as its prompt. This means **how you write the task description directly shapes what the agent does**. Be clear and specific.

### Subtasks

Tasks can have child tasks (subtasks) for breaking large work into smaller pieces. This is how a root task (the mission) gets divided into the actual work an agent can execute in a single run. Subtasks can themselves have subtasks, so the hierarchy can go as deep as the work needs.

### Due Dates and Cost

Tasks support optional due dates for deadline tracking and a cost field (in dollars) for budget visibility. These are informational — they help you monitor timelines and spending but don't enforce hard limits on their own.

### Documents

You can attach documents to a task to give the agent reference material. When the agent wakes up to work on the task, it receives the content of all attached documents as part of its context. Use this for specifications, data files, guidelines, or anything the agent needs to read before doing the work.

### Conversation

Each task has a message thread where you and agents can communicate. You can leave instructions, ask questions, or provide feedback. Agents can also post messages — including questions back to you.

If you @mention an agent's name in a message, that agent wakes up and sees the message in the context of the task. This is useful for pulling in a second agent's expertise or redirecting work.

### Audit Trail

Every significant action on a task is logged automatically:

- When it was created and by whom
- Assignment changes (who was assigned, who reassigned)
- Status changes (from what to what)
- Delegations and escalations (see below)

The audit trail gives you a full history of what happened and when, without any manual record-keeping.

## Missions (Root Tasks)

A root task — a task with no parent — is a mission. Use missions to express the broadest things you want your company to accomplish. Because they're just tasks, they have the same fields as any other task: title, description, priority, assignee.

A few things are specific to root tasks:

- **They're shown at `/goals`.** The Goals page is a facade over `Current.project.tasks.roots`. It's where you go to create a new mission or see how the existing ones are tracking.
- **Creator defaults.** When you create a root task from the Goals page, Director assigns its `creator_id` to the project's first root role automatically. If your project has no root role yet, you'll see a clean error asking you to hire one first.
- **Summary.** When every subtask under a root task is completed, Director auto-completes the root and then runs a summarization sub-agent that writes a short achievement summary onto it. The summary is what you read to understand what was accomplished without walking the whole subtask tree.
- **They don't sit in the human review queue.** The `pending_human_review` scope excludes root tasks — missions flow straight to `completed` once their subtasks finish.

### When to Create a Mission

Create a root task when you want to:

- Express a high-level objective your company is working toward
- Give agents a shared framing for a body of related work
- Hold an agent accountable to an outcome instead of individual tasks
- Get automatic quality evaluation on the work that advances it (see below)

## Auto-Completion

Root tasks auto-complete. You don't mark a mission as "done" manually — instead, Director watches the subtasks underneath it, and when every descendant reaches `completed`, `Tasks::CompletionTracking#auto_transition_on_subtasks_completed!` flips the root to `completed` too. That also kicks off the summarization step.

This is why you don't need a separate progress-tracking mechanism. The progress bar on a root task is computed from its subtasks, and the final transition falls out of the same rules.

Subtasks have a different auto-completion path: when every one of their own subtasks is completed, a non-root task transitions to `pending_review` instead, because its creator (a human or an orchestrator) is expected to approve the work before it's really done.

## Task Evaluations

When a non-root task with a human creator is approved, Director runs a **task evaluation**. An AI evaluator reviews the approved work against the root ancestor's description and returns one of:

- **Pass** — the work meaningfully advances the mission
- **Fail** — the work doesn't align with or advance the mission

Each evaluation carries written feedback explaining the reasoning. If an evaluation fails, the agent can retry — up to 3 attempts per task. After 3 failures the task escalates into the human review queue with the full history so a person can unstick it.

Under the hood, `EvaluateTaskAlignmentJob` runs `Tasks::Evaluation` with the task and its root ancestor; results are stored in `task_evaluations`. Evaluations show up on the task detail page and contribute to the root task's pass rate.

## Delegation and Escalation

When a task is assigned to an agent, two workflow actions become available:

- **Delegate** — reassign the task to one of the agent's subordinates. Use this when the assigned agent is too senior for the work, or when a more specialized agent under them would be a better fit.
- **Escalate** — reassign the task to the agent's manager. Use this when the agent is stuck, the task is beyond its capabilities, or the work needs someone with broader authority.

Both actions follow the organizational hierarchy you've set up in your company's org chart. Both are logged in the task's audit trail with the reason for the action.

## Practical Tips

- **Write task descriptions like instructions.** The description is what the agent reads, so write it the way you'd brief a colleague: clear objective, key constraints, expected output.
- **Attach documents for context the agent can't infer.** If the work depends on a specification, dataset, or style guide, attach it to the task rather than pasting it into the description.
- **Use missions to organize, not micromanage.** Root tasks work best as meaningful outcomes ("Launch the API documentation site") rather than process steps ("Write page 1 of docs"). Let agents create the subtasks.
- **Use subtasks for complex work.** If a task needs multiple steps or agents, break it into subtasks rather than writing a single sprawling description.
- **Check the progress bar on the mission, not just individual tasks.** Root tasks roll up their subtask status, so the mission's progress is the quickest way to see if a whole area of work is on track.
- **Let the audit trail be your record.** You don't need to manually log what happened. Every assignment, status change, and delegation is tracked automatically.
