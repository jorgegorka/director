# Director

## What This Is

Director is an open-source orchestration platform for AI agent companies — a Rails-based clone of Paperclip AI. Users create virtual companies staffed by AI agents organized in hierarchies, assign goals and tasks, enforce budgets, and govern operations through approval gates. It turns the chaos of managing multiple AI agents into a structured business with org charts, accountability, and cost control.

## Core Value

Users can organize AI agents into a functioning company structure and confidently let them work autonomously — knowing budgets are enforced, tasks are tracked, and humans retain control through governance.

## Who This Serves

- **Solo AI builders** — Running multiple agents across different providers (Claude Code, OpenClaw, Codex, Cursor). Frustrated by tab chaos, context loss, and runaway costs. Wants one dashboard to manage it all.
- **Small teams experimenting with AI operations** — Want to prototype "zero-human" workflows for specific business functions (content, support, development). Need guardrails before trusting agents with real work.
- **Developers building agent-powered products** — Need orchestration infrastructure they can self-host and customize rather than building from scratch.

## Product Vision

- **Success means:** Users can set up an AI company, assign agents to roles, define goals, set budgets, and walk away — checking in periodically from a dashboard to approve decisions, review work, and adjust course. The agents handle the rest.
- **Bigger picture:** Open-source alternative to Paperclip AI. A product others self-host and deploy. Potential for a managed/hosted version later.
- **Not optimizing for:** Mobile-first design, embedded AI model hosting (agents are external), enterprise SSO/compliance features in v1.

## Requirements

### Validated

- Multi-tenant account system with isolated companies — v1.0
- Org chart management with roles, hierarchy, and agent assignment — v1.0
- BYOA (Bring Your Own Agent) — connect any agent via HTTP or bash — v1.0
- Task/ticket system with conversation threads and delegation — v1.0
- Heartbeat system (scheduled + event-driven agent triggers) — v1.0
- Atomic per-agent budget enforcement with cost tracking — v1.0
- Human governance — approval gates, override controls, audit logs — v1.0
- Dashboard UI with org chart visualization, task boards, conversations — v1.0
- Goal alignment — tasks trace back to company mission — v1.0
- SQLite as sole database engine (primary + queue + cache + cable) — v1.1
- Clean codebase: dead scaffolding removed, docs reflect SQLite stack — v1.1
- Company-level skill library with 50 builtin skills across 5 categories — v1.2
- Agent skill assignments replacing agent_capabilities — v1.2
- Role-based auto-assignment on first agent assignment — v1.2
- Skills CRUD with category filtering and builtin protection — v1.2
- Per-agent skill management UI with checkbox assignment — v1.2
- Company seeding on creation + rake task for existing companies — v1.2
- Agent hooks with lifecycle event triggers (after_task_start, after_task_complete) — v1.3
- Hook execution tracking with status, payloads, timing, and retry logic — v1.3
- Agent-to-agent validation: trigger_agent hooks create subtasks, wake target agents — v1.3
- Webhook hooks POST JSON payloads to external URLs with headers and timeouts — v1.3
- Validation feedback loop: subtask results posted back to parent task, original agent woken — v1.3
- Hook management CRUD UI nested under agents with company scoping — v1.3
- AgentRun persistence with state machine, session resumption, dedicated execution queue — v1.4
- HTTP adapter with real POST delivery, error classification, exponential backoff retry — v1.4
- Claude Local adapter with tmux session lifecycle, stream-JSON parsing, budget gate — v1.4
- Live streaming UI with turbo_stream_from, tool-use indicators, broadcast batching — v1.4
- Cancel button kills tmux sessions and marks runs cancelled — v1.4
- API result/progress callbacks close autonomous execution loop with task status updates — v1.4

### Active

<!-- Current scope: v1.5 Role Templates -->

- [ ] Builtin YAML role templates shipped with the app (3-5 core departments)
- [ ] Each template defines a full department hierarchy with titles, descriptions, job specs, and skill assignments
- [ ] Templates are stackable — multiple departments can be applied to the same company
- [ ] Apply-then-edit workflow — one click creates the whole department
- [ ] Skip-duplicate logic — existing roles by title are not recreated
- [ ] Dedicated templates browse page with preview and apply
- [ ] Templates attach under CEO (root role)

### Out of Scope

- Mobile app — web-first, responsive later
- Hosting AI models — agents are always external (BYOA)
- Enterprise SSO/SAML — standard auth sufficient for v1
- Company templates marketplace ("Clipmart") — defer to v2
- Plugin system — defer to v2, focus on core features first

## Context

- Clone of [Paperclip AI](https://github.com/paperclipai/paperclip) — an open-source Node.js/React platform for "zero-human companies" with 33k+ GitHub stars
- Paperclip's core concepts: org charts, BYOA, heartbeats, budgets, governance, multi-company, audit trails
- Building on a fresh Rails 8 app skeleton already in place
- Deliberately choosing Rails defaults over Paperclip's Node.js stack — leveraging Hotwire, Solid Queue, Action Cable
- Modern CSS (custom properties, container queries, CSS nesting) instead of Tailwind
- Integer IDs throughout (no UUIDs)

## Constraints

- **Tech stack**: Rails 8, SQLite (primary + solid gems), Hotwire (Turbo + Stimulus), modern CSS, Solid Queue, Solid Cache, Solid Cable — no Tailwind, no React, no UUIDs
- **Auth**: Rails 8 built-in authentication (`has_secure_password` + auth generator) — no Devise
- **Multi-tenancy**: `Current.account` scoping pattern — no acts_as_tenant gem
- **Testing**: Minitest + fixtures — no RSpec, no FactoryBot. No system/integration tests. Focus on unit tests.
- **IDs**: Standard integer auto-increment primary keys
- **Frontend**: Hotwire + modern CSS only — no JavaScript frameworks, no Tailwind CSS
- **Deployment**: Standard Rails deployment via Kamal (SQLite, Puma, Solid Queue)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Rails 8 over Node.js | Leverage Rails conventions, Hotwire for real-time, Solid Queue for jobs — more productive for a single developer | — Pending |
| Modern CSS over Tailwind | User preference for semantic CSS with custom properties, container queries, and nesting | — Pending |
| Integer IDs over UUIDs | Rails default, simpler, user preference — no need for distributed ID generation | — Pending |
| Multi-tenant from day one | Core to the Paperclip model (multi-company support) — easier to build in from start than retrofit | — Pending |
| Hotwire over React | Rails-native real-time UI — matches Turbo Streams for live updates (agent status, task changes, conversations) | ✓ Good — turbo_stream_from + broadcast_append_to powers live streaming with zero custom JS |
| Budget enforcement in v1 | Core safety feature — users won't trust autonomous agents without cost controls | ✓ Good — budget gate blocks execution before tmux spawn |
| Both heartbeat + event triggers | Matches Paperclip behavior — agents need both scheduled work and reactive responses | ✓ Good |
| SQLite for all databases | Simplifies deployment (no external DB server), aligns all databases on one engine, Rails 8.1 has excellent SQLite support | ✓ Good — broadcast batching (100ms) protects SQLite from write pressure |
| tmux for Claude subprocess management | Real TTY (solves stdout buffering), session persistence, zombie-free lifecycle, no new gems | ✓ Good — clean process isolation, session naming by run ID |
| No new gems for v1.4 | Net::HTTP (stdlib), tmux (system dep), Turbo::StreamsChannel (already in Gemfile) | ✓ Good — zero dependency growth |

## Current Milestone: v1.5 Role Templates

**Goal:** Add builtin role templates — predefined department structures (Engineering, Marketing, Operations, Finance, HR) that users can apply to their companies with one click, creating full hierarchies with job specs and skill assignments.

**Target features:**
- Builtin YAML template definitions (3-5 departments)
- Template browse page with department preview
- One-click apply with skip-duplicate logic
- Pre-assigned skills and full job specs on template roles
- Stackable — multiple departments under the same CEO

## Current State

**Shipped:** v1.0 (Core Platform) + v1.1 (SQLite Migration) + v1.2 (Agent Skills) + v1.3 (Agent Hooks) + v1.4 (Agent Execution)
**Codebase:** ~17,700 LOC Ruby, 1124 tests, 25 phases, 47 plans
**Stack:** Rails 8, SQLite (all databases), Hotwire, modern CSS, Solid Queue/Cache/Cable
**Status:** Fully functional orchestration platform with real agent execution. Auth, multi-tenancy, org charts, agents with skill management, tasks, goals, heartbeats, budgets, governance, dashboard with real-time updates. HTTP and Claude Local adapters execute real work. Live streaming UI shows agent output in real time. API callbacks close the autonomous execution loop.

**Known tech debt:**
- permit! on action_config params in AgentHooksController (mitigated by model validation)
- N+1 COUNT query on hooks index page (negligible at expected cardinality)
- tmux availability not verified in Docker image (deployment dependency)

---
*Last updated: 2026-03-29 after v1.5 milestone start*
