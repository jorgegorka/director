# Director

AI agent orchestration platform for building and managing anything from simple projects to AI companies.

**Run your AI agents like a real company.**

Managing multiple AI agents gets messy fast. They run in different tabs, lose context between sessions, burn through money with no oversight, and nobody knows what any of them are actually doing. Director fixes this by letting you organize your AI agents into a structured company — with an org chart, task assignments, budgets, and human oversight — so you can let them work autonomously while staying in control.

<img width="1218" height="905" alt="AI Company orchestrator" src="https://github.com/user-attachments/assets/de87fb27-990b-4ba2-a9bc-6848e5a9005b" />

## How it works

### Companies and teams

Everything starts with a company. You create one, give it a name, and you become its owner. From there you can invite other people to join as members or admins. Each person can belong to multiple companies, and each company is completely isolated — its agents, tasks, budgets, and data are separate from the rest.

If something goes wrong across the board, an admin can hit the **emergency stop** to freeze every agent in the company at once.

### Roles and org chart

Inside each company you define roles — CEO, lead engineer, content writer, support agent, whatever fits your operation. Roles are arranged in a hierarchy, just like a real org chart, with parent-child relationships that determine who reports to whom. Each role has a job specification describing what it's responsible for.

When you assign an agent to a role, it automatically receives a default set of skills relevant to that position.

### Agents

Agents are the AI workers in your company. Each agent is connected to an external AI service through one of three adapters:

- **HTTP** — sends tasks to any AI service via web requests. Director posts a JSON payload to a URL you configure and handles the response, including automatic retries with increasing wait times if something fails.
- **Process** — runs a command-line program on the server. Useful for local scripts or CLI-based AI tools.
- **Claude Local** — launches a Claude session in a dedicated terminal window, streams the output in real time, and enforces budget limits before each run starts.

Agents have a lifecycle you control directly. You can **pause** an agent (with a reason), **resume** it, or **terminate** it permanently. If an agent tries to do something that requires approval, it enters a **pending approval** state until a human approves or rejects the action.

Each agent has its own profile showing its assigned skills, linked documents, recent heartbeat activity, and a full history of its runs.

### Tasks

Tasks are the units of work in Director. You create a task with a title, description, and priority level (low, medium, high, or urgent), then assign it to an agent. Tasks live on a **Kanban board** where you can see them organized by status: open, in progress, blocked, completed, or cancelled.

Tasks support **delegation** — an agent can hand off a task to another agent — and **escalation**, where a task gets bumped up to the agent's manager in the org chart. Both of these can be subject to approval gates if you want human oversight on those decisions.

You can attach **documents** to tasks for reference material, and people or agents can post **messages** on tasks to discuss the work, with full threading support. Tasks can also have **subtasks** through parent-child relationships, so complex work can be broken into smaller pieces.

Every task tracks its cost, so you always know how much a piece of work actually cost to complete.

### Goals

Goals give your company direction. You create a hierarchy of goals — from high-level missions down to specific objectives and key results — and link tasks to them. This way every piece of work traces back to a company-level objective.

Progress rolls up automatically: as tasks linked to a goal are completed, the goal's progress updates to reflect it.

### Skills

Skills define what an agent is capable of. Director comes with **50 built-in skills** organized across 5 categories, and you can create your own custom skills on top of that.

Each skill has a name, description, category, and detailed documentation written in markdown. You can attach reference documents to skills for additional context. Skills are managed at the company level and then assigned to individual agents — you pick which skills each agent should have through a simple checkbox interface.

When a new company is created, it's automatically seeded with the full set of built-in skills. Built-in skills are protected and can't be deleted.

### Documents

Documents are Director's knowledge base. You create documents with a title and markdown content, organize them with **tags**, and link them to agents, tasks, or skills. This way your AI agents have access to the reference material they need.

Documents track who created them and who last edited them, so there's always accountability for the information in your knowledge base.

### Agent hooks

Hooks let you automate workflows between agents. You attach hooks to an agent and configure them to fire on lifecycle events — for example, **after a task starts** or **after a task completes**.

When a hook fires, it can do one of two things:

- **Trigger another agent** — creates a subtask and wakes up a different agent to handle it. When that agent finishes, the result is posted back to the original task, and the first agent is woken up to review it. This creates a **validation feedback loop** where agents check each other's work.
- **Call a webhook** — sends a JSON payload to an external URL with custom headers and timeout settings. This lets you integrate Director with other systems — notifications, logging, external workflows, anything that accepts HTTP requests.

Each hook execution is tracked with its status, timing, and payload data, and hooks support automatic retries if something fails.

### Budgets

Every agent has a budget. Before an agent starts a run, Director checks whether the agent can afford it — if the budget is exhausted, the run is blocked before it even begins.

Agents report their costs back to Director as they work, and you can see per-agent spending on the dashboard. The budget tracking is atomic, meaning costs are enforced precisely without race conditions even when multiple agents run simultaneously.

### Approval gates

Approval gates are how you keep humans in the loop. You configure them per agent, choosing which actions require human approval before they can proceed:

- **Task creation** — agent wants to create a new task
- **Task delegation** — agent wants to hand off work to another agent
- **Budget spend** — agent wants to spend beyond a threshold
- **Status change** — agent wants to change its own status
- **Escalation** — agent wants to escalate an issue to its manager

When an agent triggers a gate, it pauses and waits. An admin reviews the request and either **approves** or **rejects** it with a reason.

### Agent runs

Every time an agent executes a piece of work, Director creates a **run record** that tracks the full lifecycle: queued, running, completed, failed, or cancelled. Each run captures the trigger that started it (heartbeat, task assignment, mention, etc.), the cost incurred, the exit code, and the complete log output.

For Claude Local agents, you can **watch the output live** as it streams in real time — you see exactly what the agent is thinking and doing. If a run is taking too long or going in the wrong direction, you can **cancel it** directly from the interface, which kills the underlying process immediately.

Runs are processed through a dedicated job queue, and agents can resume sessions across multiple runs for continuity.

### Dashboard

The dashboard is your command center. At a glance you can see:

- How many agents are active and online
- Active and completed task counts
- Budget utilization across all agents with per-agent spending breakdowns
- A Kanban view of all tasks grouped by status
- A real-time activity timeline showing what's happening across the company
- Goal progress across all objectives

The dashboard updates in real time — when an agent completes a task, starts a run, or triggers a hook, you see it immediately without refreshing the page.

### Audit trail

Every significant action in Director is recorded in an **immutable audit log** — it can't be edited or deleted. You can filter the log by who performed the action (user or agent), what type of action it was, and when it happened.

On top of that, every change to an agent's or role's configuration is captured as a **config version**. You can view the full history of changes, compare any two versions to see exactly what changed, and **roll back** to a previous configuration if needed.

### Notifications

Director notifies you when things need your attention — when you're mentioned in a task message, when a task is assigned to you, or when an agent action requires your approval. Notifications are scoped to the company you're working in and can be marked as read.

## Who is Director for?

- **Solo AI builders** juggling multiple agents across different tools. You want one place to manage them all without tab chaos and runaway costs.
- **Small teams** experimenting with AI-powered workflows. You need guardrails and visibility before trusting agents with real work.
- **Developers** who need self-hostable orchestration infrastructure they can customize, instead of building it from scratch.

## Tech stack

- Ruby on Rails 8.1
- SQLite for everything (one file, no database server to install)
- Hotwire for real-time updates without JavaScript frameworks
- Custom CSS (no Tailwind, no Bootstrap)
- Docker-ready for deployment

## Getting started

**You need:** Ruby 3.4. No Node.js or external database required.

```bash
git clone https://github.com/jorgegorka/director.git
cd director
bin/setup
bin/dev
```

Then visit [http://localhost:3000](http://localhost:3000).

# Contributors

- [Mario Alvarez](https://github.com/marioalna)
- [Jorge Alvarez](https://github.com/jorgegorka)

## License

Released under the [MIT License](LICENSE).
