# Director

**Run your AI agents like a real company.**

Managing multiple AI agents gets messy fast. They run in different tabs, lose context between sessions, burn through money with no oversight, and nobody knows what any of them are actually doing. Director fixes this by letting you organize your AI agents into a structured company — with an org chart, task assignments, budgets, and human oversight — so you can let them work autonomously while staying in control.

<img width="1218" height="905" alt="AI Company orchestrator" src="https://github.com/user-attachments/assets/de87fb27-990b-4ba2-a9bc-6848e5a9005b" />


## What can you do with Director?

### Build your AI company

Create a company, define roles (CEO, engineer, researcher — whatever you need), arrange them in an org chart, and assign an AI agent to each position. Invite team members to collaborate. You can run multiple companies, each with its own agents and structure.

### Manage work

Create tasks with priorities, assign them to agents, and track everything on a Kanban board. Define company goals and link tasks to them so you always know how work connects to the bigger picture. Agents can delegate tasks to other agents or escalate issues up the chain.

### Stay in control

Set a budget for each agent so costs never spiral. Require human approval before agents take sensitive actions like creating tasks, spending money, or changing their own status. Pause, resume, or terminate any agent at any time. If something goes wrong, hit the emergency stop to freeze all agents in a company at once.

### See everything happening

A real-time dashboard shows what every agent is doing right now. Watch live output as agents work. Every action is recorded in an immutable audit trail — who did what, when, and why. Configuration changes are versioned so you can roll back to any previous setup.

### Connect any AI agent

Bring your own agents — Director works with any AI through HTTP webhooks, command-line processes, or a native Claude adapter. Agents report their costs and progress back automatically. Define skills and attach documents so agents have the knowledge they need.

## Who is Director for?

- **Solo AI builders** juggling multiple agents across different tools. You want one place to manage them all without tab chaos and runaway costs.
- **Small teams** experimenting with AI-powered workflows. You need guardrails and visibility before trusting agents with real work.
- **Developers** who need self-hostable orchestration infrastructure they can customize, instead of building it from scratch.

## Origin

I was looking for a way to test [Ariadna](https://github.com/jorgegorka/ariadna), a Claude Code extension that creates Ruby on Rails applications. I saw [Paperclip AI](https://github.com/paperclipai/paperclip) and thought it was an interesting project with a terrible choice of tech stack, so I decided to rewrite it in Rails.

The prompt I gave to Ariadna was: *"Understand what Paperclip does and how it works. Then, create a plan that implements the same functionality as Paperclip."* This is the result.

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

## Development

| Command | Description |
|---------|-------------|
| `bin/dev` | Start the development server |
| `bin/rails test` | Run all tests |
| `bin/rails test test/models/user_test.rb` | Run a single test file |
| `bin/rails test test/models/user_test.rb:25` | Run a single test by line |
| `bin/rubocop` | Lint check |
| `bin/rubocop -a` | Lint auto-fix |
| `bin/brakeman --quiet --no-pager` | Security scan |
| `bin/ci` | Full CI suite (lint + security + tests) |

## License

Released under the [MIT License](LICENSE).
