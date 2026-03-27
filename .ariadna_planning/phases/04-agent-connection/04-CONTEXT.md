# Phase 4: Agent Connection — Context

## Decisions

### Integration Model: Paperclip "Director Controls Agents"
User creates agents in the UI, configures adapter type and settings. Director calls out to agents (not self-registration). Matches proven Paperclip design.

### All Three Adapter Types
- **HTTP adapter** — POST to configured URL via Faraday (cloud-hosted agents)
- **Process adapter** — Spawns shell commands via Open3 (local scripts, CLI tools)
- **Claude Local adapter** — Spawns `claude` CLI with stream-json output and session resumption

Each adapter type has its own configuration fields. Adapter system uses a registry pattern mapping `adapter_type` enum to adapter classes.

### Capabilities as Separate Model
AgentCapability model (normalized) rather than text/jsonb field on Agent. Allows structured querying and future task-matching.

### Scope: Agent CRUD + Adapter Config Only
- Agent model with adapter_type enum and adapter config
- Agent CRUD controller and views (nested under companies)
- Adapter configuration UI (dynamic fields per adapter type via Stimulus)
- Agent status display (idle/running/paused/error/terminated/pending_approval)
- Agent assignment to roles (populate the existing `roles.agent_id` FK from Phase 3)
- NO heartbeat execution in this phase — comes in Phase 7

## Claude's Discretion

- Adapter config storage approach (separate config models vs jsonb vs normalized columns)
- Agent status tracking mechanism (enum on model, updated during future heartbeat runs)
- UI layout for agent detail page and adapter config forms
- How `last_heartbeat_at` is displayed before heartbeat execution exists

## Deferred Ideas

- Heartbeat execution engine (Phase 7)
- Agent self-registration API
- Company skills / skill marketplace
- Cost tracking per agent
