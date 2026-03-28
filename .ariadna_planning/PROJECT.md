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

<!-- Shipped in v1.0 and confirmed valuable. -->

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

### Active

(None — define requirements for next milestone with `/ariadna:new-milestone`)

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
| Hotwire over React | Rails-native real-time UI — matches Turbo Streams for live updates (agent status, task changes, conversations) | — Pending |
| Budget enforcement in v1 | Core safety feature — users won't trust autonomous agents without cost controls | — Pending |
| Both heartbeat + event triggers | Matches Paperclip behavior — agents need both scheduled work and reactive responses | — Pending |
| SQLite for all databases | Simplifies deployment (no external DB server), aligns all databases on one engine, Rails 8.1 has excellent SQLite support | ✓ Good |

## Current State

**Shipped:** v1.0 (Core Platform) + v1.1 (SQLite Migration & Cleanup)
**Codebase:** ~10,193 LOC Ruby, 668 tests, 12 phases, 32 plans
**Stack:** Rails 8, SQLite (all databases), Hotwire, modern CSS, Solid Queue/Cache/Cable
**Status:** Fully functional platform — auth, multi-tenancy, org charts, agents, tasks, goals, heartbeats, budgets, governance, dashboard with real-time updates. Zero external database dependencies.

**Known tech debt:** None significant — v1.1 cleanup addressed scaffolding leftovers and stale docs.

---
*Last updated: 2026-03-28 after v1.1 milestone completion*
