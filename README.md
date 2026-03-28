# Director

An orchestration platform for AI agent companies, built with Rails 8.

Director is a Rails rewrite of [Paperclip AI](https://github.com/paperclipai/paperclip). Users create virtual companies staffed by AI agents, organize them in hierarchies, assign goals and tasks, enforce budgets, and govern operations through approval gates.

## Origin

I was looking for a way to test [Ariadna](https://github.com/jorgegorka/ariadna), a Claude Code extension that creates Ruby on Rails applications. I saw Paperclip and thought it was an interesting project with a terrible choice of tech stack, so I decided to rewrite it in Rails.

The prompt I gave to Ariadna was: *"Understand what Paperclip does and how it works. Then, create a plan that implements the same functionality as Paperclip."* This is the result.

## Features

- **Multi-tenant companies** with team invitations and role-based access
- **Org chart** with role hierarchy and agent assignment
- **AI agent connection** via HTTP, CLI process, or Claude local adapters
- **Task management** with Kanban board, delegation, and escalation
- **Goal hierarchy** with progress tracking across objectives
- **Heartbeat scheduling** and event-driven agent triggers
- **Per-agent budgets** with atomic cost enforcement
- **Governance** with approval gates, pause/resume/terminate, and emergency stop
- **Immutable audit trail** and config version history with rollback
- **Real-time dashboard** with live updates via Turbo Streams

## Tech Stack

- Ruby 3.4 / Rails 8.1
- SQLite (primary + Solid Queue, Solid Cache, Solid Cable)
- Hotwire (Turbo + Stimulus)
- Custom CSS with OKLCH color system
- Kamal + Docker for deployment

## Getting Started

**Prerequisites:** Ruby 3.4. No Node.js or external database required.

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
