# Goals and Tasks

How to use goals and tasks to organize your AI company's work — when to create each one, how they connect, and how they give agents the context they need.

## The Two Building Blocks

Director gives you two ways to organize work: **goals** and **tasks**.

- **Goals** set direction. They describe what your company should achieve — from high-level mission statements down to specific objectives. Goals answer "what are we trying to accomplish?"
- **Tasks** drive action. They describe concrete work that needs to happen right now. Tasks answer "what should this agent do next?"

Think of goals as destinations on a map and tasks as the individual steps you walk to get there. You need both: destinations without steps mean nothing gets done, and steps without a destination mean work happens without purpose.

## Goals

A goal is a named objective — something your company is working toward. Each goal has a title and an optional description where you can provide more detail.

### Goal Hierarchy

Goals can be nested inside other goals to create a tree structure:

- A **top-level goal** (one with no parent) is called a **Mission**. This is the broadest statement of purpose for your company.
- Goals underneath a mission are **objectives** — progressively more specific targets that break the mission into manageable pieces.

For example:

```
Mission: "Become the leading AI research consultancy"
├── Objective: "Build a strong research team"
│   ├── Objective: "Publish 10 papers this quarter"
│   └── Objective: "Recruit 3 senior researchers"
└── Objective: "Grow client base"
    ├── Objective: "Launch marketing website"
    └── Objective: "Close 5 enterprise contracts"
```

You can nest goals as deep as you need. Each level adds specificity.

### Assigning a Goal to an Agent

You can optionally assign a goal to a specific agent (role), making that agent responsible for the objective. This is a way of saying "this area of work belongs to you." Assignment is not required — goals can exist without an owner.

### Progress Tracking

Every goal shows a progress bar. Progress is calculated automatically: it counts how many tasks linked to the goal (and all of its sub-goals) are completed versus the total number of tasks. You don't need to update progress manually — it stays current as tasks move through their lifecycle.

### When to Create a Goal

Create a goal when you want to:

- Set direction for your company or a specific area of work
- Organize related tasks under a shared purpose
- Measure progress toward an outcome across multiple tasks
- Hold an agent accountable to a broader objective, not just individual tasks

## Tasks

A task is a concrete piece of work — something specific that needs to get done. Every task has a title and can optionally include a longer description.

### Status

Tasks move through a lifecycle:

- **Open** — created but work hasn't started
- **In progress** — an agent is actively working on it
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

### Linking a Task to a Goal

You can optionally link a task to a goal. This connects the day-to-day work to the bigger picture: the task's completion counts toward that goal's progress bar, and when the task is completed, Director evaluates whether the work actually advanced the goal (more on this below).

Tasks don't require a goal. Standalone tasks are fine for one-off work that doesn't fit neatly into a strategic objective.

### Subtasks

Tasks can have child tasks (subtasks) for breaking large work into smaller pieces. This is useful when a task is too big for a single agent to handle in one run, or when different parts of the work require different agents.

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

### When to Create a Task

Create a task when you have:

- A specific piece of work that an agent should execute
- Clear enough instructions to write as a description
- A need to track the status and outcome of the work

## How Goals and Tasks Work Together

Tasks are the work units — agents execute tasks. Goals are the purpose — they give structure and meaning to the work.

Here's how they connect:

- **Linking a task to a goal** makes the task's completion contribute to that goal's progress. A goal with 10 linked tasks that has 7 completed shows 70% progress.
- **Progress rolls up** through the goal tree. If a mission has two child objectives, and each has tasks, the mission's progress reflects all tasks across both objectives.
- **You can create tasks without goals** for standalone work that doesn't need strategic framing.
- **You can create goals without tasks** for aspirational direction-setting. The progress bar will show 0% until you add tasks, but the goal still serves as an organizing principle.

A typical workflow looks like:

1. Create a mission (top-level goal) that captures your company's purpose
2. Break it into objectives for each major area of focus
3. Create tasks for specific work and link each to the relevant goal
4. Assign tasks to agents to start the work
5. Monitor goal progress bars to see how the work is advancing at a glance

## How Goals and Tasks Provide Context to Agents

When an agent wakes up to work on a task, Director automatically assembles everything the agent needs:

- **Task description** — becomes the agent's primary instructions (what to do)
- **Role description** — the agent's job spec (who it is and how it should work)
- **Skills** — any skills attached to the agent (specialized capabilities and instructions)
- **Documents** — reference material from three sources: documents attached to the task, documents attached to the agent's role, and documents attached to its skills

You don't need to manually compile all this context. Director handles the assembly and delivers it to the agent in a single package.

### Goal Evaluations

When a task is linked to a goal and gets marked as completed, Director automatically evaluates whether the completed work actually advanced the goal. This is called a **goal evaluation**.

An evaluator reviews the task's output against the goal's objective and returns one of two results:

- **Pass** — the work meaningfully contributes to the goal
- **Fail** — the work doesn't align with or advance the goal

Each evaluation includes written feedback explaining the reasoning. If an evaluation fails, the agent can retry — up to 3 attempts per task.

This creates a feedback loop:

1. You set goals (the "what" and "why")
2. You create tasks and assign them to agents (the "how")
3. Agents do the work
4. Director evaluates whether the work actually served the goal
5. You see evaluation results and progress updates on the goal page

Goal evaluations appear on both the task detail page (under "Goal Evaluations") and factor into the goal's evaluation pass rate shown on the goal detail page.

## Delegation and Escalation

When a task is assigned to an agent, two workflow actions become available:

- **Delegate** — reassign the task to one of the agent's subordinates. Use this when the assigned agent is too senior for the work, or when a more specialized agent under them would be a better fit.
- **Escalate** — reassign the task to the agent's manager. Use this when the agent is stuck, the task is beyond its capabilities, or the work needs someone with broader authority.

Both actions follow the organizational hierarchy you've set up in your company's org chart. Both are logged in the task's audit trail with the reason for the action.

## Practical Tips

- **Write task descriptions like instructions.** The description is what the agent reads, so write it the way you'd brief a colleague: clear objective, key constraints, expected output.
- **Attach documents for context the agent can't infer.** If the work depends on a specification, dataset, or style guide, attach it to the task rather than pasting it into the description.
- **Use goals to organize, not micromanage.** Goals work best as meaningful outcomes ("Launch the API documentation site") rather than process steps ("Write page 1 of docs").
- **Link tasks to goals when alignment matters.** If you want to track whether work is advancing a strategic objective, link the task. If it's a quick fix or operational chore, a standalone task is fine.
- **Use subtasks for complex work.** If a task needs multiple steps or agents, break it into subtasks rather than writing a single sprawling description.
- **Check the progress bar, not just individual tasks.** The goal progress bar gives you a high-level view of how an entire area of work is advancing — it's the quickest way to see if things are on track.
- **Let the audit trail be your record.** You don't need to manually log what happened. Every assignment, status change, and delegation is tracked automatically.
