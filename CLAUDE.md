# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Director is a Rails 8 clone of [Paperclip AI](https://github.com/paperclipai/paperclip) — an orchestration platform for AI agent companies. Users create virtual companies staffed by AI agents, organize them in hierarchies, assign goals/tasks, enforce budgets, and govern operations through approval gates.

## Hard Constraints

- **Auth**: Rails 8 built-in authentication (`has_secure_password` + `bin/rails generate authentication`) — NO Devise
- **Frontend**: Hotwire (Turbo + Stimulus) + modern CSS — NO Tailwind, NO React
- **CSS**: Pure custom CSS with OKLCH colors, CSS layers, logical properties — see `docs/style-guide.md`
- **IDs**: Standard integer auto-increment — NO UUIDs
- **Testing**: Minitest + fixtures — NO RSpec, NO FactoryBot, NO system/integration tests
- **Multi-tenancy**: `Current.account` scoping — NO acts_as_tenant gem
- **Database**: SQLite for everything (primary + Solid Queue/Cache/Cable)
- **Deployment**: Kamal + Docker

## Commands

```bash
bin/setup              # Install deps, prepare DB, start server
bin/dev                # Start dev server
bin/ci                 # Full CI suite (rubocop → security → tests)

# Testing (unit + controller tests only — no system/integration tests)
bin/rails test                              # All tests
bin/rails test test/models/user_test.rb     # Single file
bin/rails test test/models/user_test.rb:25  # Single test by line

# Linting
bin/rubocop            # Style check (rubocop-rails-omakase)
bin/rubocop -a         # Auto-fix

# Security
bin/brakeman --quiet --no-pager
bin/bundler-audit
bin/importmap audit
```

## Architecture

Fresh Rails 8.1 app. Planning docs live in `.ariadna_planning/` (PROJECT.md, REQUIREMENTS.md, ROADMAP.md, STATE.md, phases/).

## Conventions

- **Code style**: rubocop-rails-omakase (Basecamp's opinionated Rails style)
- **CSS architecture**: See `docs/style-guide.md` — CSS layers, OKLCH color system, semantic variables, logical properties, dark mode support, icon system via CSS masks
- **Rails patterns**: See `docs/patterns-and-best-practices.md` — concern architecture (shared + model-specific), intention-revealing APIs, thin controllers, `_now`/`_later` job pattern
- **Paperclip reference**: See `docs/paperclip-clone.md` — schema design, feature mapping from the Node.js original
