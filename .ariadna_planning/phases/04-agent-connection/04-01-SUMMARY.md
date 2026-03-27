---
phase: 04-agent-connection
plan: "01"
status: complete
completed_at: 2026-03-27T09:03:19Z
duration_seconds: 298
tasks_completed: 3
tasks_total: 3
files_created: 11
files_modified: 3
commits: 3
---

# Plan 04-01 Summary: Agent Model Foundation and Adapter Registry

## Objective

Created the Agent and AgentCapability models with migrations, the adapter registry system, and comprehensive model tests. Agents belong to companies via the Tenantable concern, have adapter configurations stored as jsonb, declare capabilities via a normalized model, and can be assigned to roles.

## Tasks Completed

### Task 1: Agent and AgentCapability migrations and models (commit: 641a0ad)

**Migrations created:**
- `20260327085826_create_agents.rb` — agents table with company_id FK, name, adapter_type (integer enum), status (integer enum), adapter_config (jsonb), description, last_heartbeat_at, pause_reason, paused_at; unique index on [company_id, name]; status index; FK from roles.agent_id to agents
- `20260327085837_create_agent_capabilities.rb` — agent_capabilities table with agent_id FK, name, description; unique index on [agent_id, name]

**Models created/updated:**
- `app/models/agent.rb` — Tenantable concern, adapter_type enum (http/process/claude_local), status enum (idle/running/paused/error/terminated/pending_approval), jsonb adapter_config with schema validation, active scope, online?/offline? helpers, adapter method delegating to Adapters::Registry
- `app/models/agent_capability.rb` — belongs_to agent, name uniqueness scoped to agent_id, by_name scope
- `app/models/company.rb` — added `has_many :agents, dependent: :destroy`
- `app/models/role.rb` — added `belongs_to :agent, optional: true` and `delegate :name, to: :agent, prefix: true, allow_nil: true`

### Task 2: Adapter registry and base classes (commit: 33c6502)

**Files created in `app/adapters/adapters/`:**
- `registry.rb` — `Adapters::Registry` with ADAPTERS map, CONFIG_SCHEMAS (required/optional keys), and class methods: `for`, `required_config_keys`, `optional_config_keys`, `all_config_keys`, `adapter_types`
- `base_adapter.rb` — `Adapters::BaseAdapter` abstract interface with `execute`, `test_connection`, `display_name`, `description`
- `http_adapter.rb` — HTTP API adapter with Phase 7 stubs
- `process_adapter.rb` — Shell Command adapter with Phase 7 stubs
- `claude_local_adapter.rb` — Claude Code (Local) adapter with Phase 7 stubs

**Deviation (Rule 3 - Blocking):** The plan specified files at `app/adapters/*.rb` (e.g., `app/adapters/registry.rb` defining `Adapters::Registry`). Rails 8 + Zeitwerk treats `app/adapters` as a root autoload directory, so files there must define top-level constants. To use `Adapters::*` namespace, files must be at `app/adapters/adapters/*.rb`. Added `app/adapters/adapters.rb` as the namespace anchor file. This is the correct Zeitwerk pattern and required no config changes.

### Task 3: Model tests and fixtures (commit: 8e843e8)

**Fixtures created:**
- `test/fixtures/agents.yml` — 4 agents: claude_agent (acme, claude_local, idle), http_agent (acme, http, idle), process_agent (acme, process, paused), widgets_agent (widgets, http, idle)
- `test/fixtures/agent_capabilities.yml` — 3 capabilities: claude_coding and claude_analysis for claude_agent; http_data_processing for http_agent

**Fixtures updated:**
- `test/fixtures/roles.yml` — CTO role now references `agent: claude_agent` to test agent-role assignment

**Tests created:**
- `test/models/agent_test.rb` — 28 tests covering: validations (name presence, uniqueness scoped to company, adapter_config schema validation per adapter type), enums (all 3 adapter_type values, all 6 status values), associations (company, agent_capabilities, roles), scoping (for_current_company, active excludes terminated), methods (online?/offline?, adapter returns correct class), deletion behavior (nullify roles.agent_id, destroy capabilities, company cascade)
- `test/models/agent_capability_test.rb` — 10 tests covering: validations (name presence, uniqueness scoped to agent_id, cross-agent name allowed), associations (belongs_to agent), scopes (by_name alphabetical ordering)

**Results:** 165 tests, 410 assertions, 0 failures, 0 errors, 0 skips

## Key Decisions

- **Zeitwerk namespace structure:** `app/adapters/adapters/` subdirectory pattern required for `Adapters::*` namespace with Rails 8 autoloading — no config changes needed, just correct file placement
- **adapter_config validation:** Schema validation runs via `validate_adapter_config_schema` checking required keys from Registry against jsonb keys; skips validation when config is blank (separate presence validation handles that)
- **Agent.active scope:** Excludes only `:terminated` status — allows paused, error, pending_approval agents to appear as "active" records (they're not done, just temporarily offline)
- **roles.agent_id FK:** Added via `add_foreign_key :roles, :agents` in the CreateAgents migration — the column already existed from Phase 3, only the FK was missing

## Artifacts Produced

| File | Purpose |
|------|---------|
| `app/models/agent.rb` | Agent model with Tenantable, enums, config validation |
| `app/models/agent_capability.rb` | Normalized capability model |
| `app/adapters/adapters/registry.rb` | Adapter type to class mapping with config schemas |
| `app/adapters/adapters/base_adapter.rb` | Abstract interface for all adapters |
| `db/migrate/20260327085826_create_agents.rb` | Agents table with all columns and indexes |
| `db/migrate/20260327085837_create_agent_capabilities.rb` | Agent capabilities table |
| `test/models/agent_test.rb` | 28 Agent model tests |
| `test/models/agent_capability_test.rb` | 10 AgentCapability model tests |

## Self-Check: PASSED

All files verified present:
- app/models/agent.rb — FOUND
- app/models/agent_capability.rb — FOUND
- app/adapters/adapters/registry.rb — FOUND
- app/adapters/adapters/base_adapter.rb — FOUND
- app/adapters/adapters/http_adapter.rb — FOUND
- app/adapters/adapters/process_adapter.rb — FOUND
- app/adapters/adapters/claude_local_adapter.rb — FOUND
- test/models/agent_test.rb — FOUND
- test/models/agent_capability_test.rb — FOUND
- test/fixtures/agents.yml — FOUND
- test/fixtures/agent_capabilities.yml — FOUND

All commits verified present:
- 641a0ad: feat(04-01): Agent and AgentCapability models with migrations
- 33c6502: feat(04-01): Adapter registry and base classes for all adapter types
- 8e843e8: test(04-01): Model tests and fixtures for Agent and AgentCapability
