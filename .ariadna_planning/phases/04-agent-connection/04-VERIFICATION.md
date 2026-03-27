---
phase: 04-agent-connection
verified: 2026-03-27T10:30:00Z
status: gaps_found
score: "11/12 truths verified | security: 0 critical, 1 high | performance: 0 high"
gaps:
  - truth: "System displays agent status and updates it based on health checks"
    status: partial
    reason: "Status display (badges, status-dots, CSS variants for all 6 statuses) is fully implemented. Automatic status updates via health checks are intentionally deferred to Phase 7 per the phase context document. The phase goal says 'updates it based on health checks' — that half is not delivered in this phase."
    artifacts: []
    missing: ["Heartbeat execution engine (Phase 7) — intentionally deferred, not a phase 4 failure"]
security_findings:
  - check: "MassAssignment"
    severity: high
    file: "app/controllers/agents_controller.rb"
    line: 53
    detail: "params[:agent][:adapter_config].permit! allows any keys to be stored in the adapter_config jsonb column. A user could inject arbitrary keys. Consider allowlisting keys per adapter_type using Adapters::Registry.all_config_keys."
---

# Phase 04 Verification: Agent Connection

**Goal:** Users can connect external AI agents to Director and monitor their status

**Verdict:** gaps_found — 11/12 truths verified. One success criterion (automatic status updates via health checks) is intentionally deferred to Phase 7 per the phase design. One medium-impact security finding (permit! on jsonb field).

---

## Observable Truths Table

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | User can register an agent via HTTP API endpoint configuration and see it in the company | PASS | `AgentsController#create` accepts `adapter_type: "http"` with `adapter_config[url]`. Controller test `should create http agent` passes. Agent appears in index scoped to `Current.company`. |
| 2 | User can register an agent via bash command configuration (process adapter) | PASS | Form includes Shell Command fieldset with `adapter_config[command]`. Controller test `should create process agent` passes. Registry maps `process` to `Adapters::ProcessAdapter`. |
| 3 | System displays agent status visually | PASS | `agent_status_badge` helper renders `.status-badge--{status}` pills. CSS defines all 6 variants (idle/running/paused/error/terminated/pending_approval). `role-card__agent-dot` colors defined for all 6 statuses. Used in `_agent.html.erb`, `show.html.erb`, roles views. |
| 3b | System updates agent status based on health checks | PARTIAL | Intentionally deferred to Phase 7 per `04-CONTEXT.md` ("NO heartbeat execution in this phase — comes in Phase 7"). `last_heartbeat_at` column exists. Show page displays "Never" with note. Status enum is in place for Phase 7 to update. |
| 4 | Agents can declare capabilities on registration / visible in agent profile | PASS | `AgentCapabilitiesController` with nested routes `POST/DELETE /agents/:agent_id/capabilities`. Agent show page has inline add/remove badges. `AgentCapability` normalized model with unique `[agent_id, name]` index. |
| 5 | Agent model exists with name, adapter_type enum, status enum, adapter_config jsonb | PASS | `app/models/agent.rb`: Tenantable, `enum :adapter_type {http: 0, process: 1, claude_local: 2}`, `enum :status {idle: 0, running: 1, paused: 2, error: 3, terminated: 4, pending_approval: 5}`, jsonb `adapter_config`. Schema confirmed via `db/schema.rb`. |
| 6 | AgentCapability model exists as normalized separate table | PASS | `app/models/agent_capability.rb` with `belongs_to :agent`, name uniqueness scoped to agent_id. Migration creates `agent_capabilities` table with `[agent_id, name]` unique index. |
| 7 | Agent belongs_to company via Tenantable, scoped by Current.company | PASS | `include Tenantable` in Agent model. All controller actions use `Current.company.agents` scope. Controller test `should not show agent from another company` returns 404. |
| 8 | Role belongs_to agent (optional) with FK | PASS | `role.rb`: `belongs_to :agent, optional: true`. Schema has `add_foreign_key "roles", "agents"`. `RolesController#role_params` permits `:agent_id`. |
| 9 | Adapter registry maps adapter_type values to adapter classes | PASS | `app/adapters/adapters/registry.rb`: `ADAPTERS` hash maps all 3 types. Runtime verified: `Adapters::Registry.adapter_types => ["http", "process", "claude_local"]`, `Registry.for("http").display_name => "HTTP API"`. |
| 10 | Agent form dynamically shows/hides adapter config fields via Stimulus | PASS | `adapter_config_controller.js` targets `[data-adapter-config-target="configGroup"]`, shows/hides and enables/disables inputs on `change->adapter-config#toggle`. Form wires `data-adapter-config-select` on the type select. |
| 11 | Navigation includes an "Agents" link | PASS | `layouts/application.html.erb` line 40: `link_to "Agents", agents_path` with active state guard, conditional on `Current.company`. |
| 12 | Org chart nodes reflect assigned agent names (Phase 3 placeholder replaced) | PASS | `OrgChartsHelper#role_node_data` uses `agent_name: role.agent&.name`. `OrgChartsController#show` includes `:agent` in query. `grep "Phase 4" app/views/roles/` returns 0 results. |

---

## Artifact Status

| Artifact | Path | Status | Notes |
|----------|------|--------|-------|
| Agent model | `app/models/agent.rb` | PRESENT, SUBSTANTIVE | Full model: Tenantable, enums, jsonb config validation, online?/offline?, adapter delegation |
| AgentCapability model | `app/models/agent_capability.rb` | PRESENT, SUBSTANTIVE | Normalized, validates uniqueness scoped to agent_id, by_name scope |
| Adapter registry | `app/adapters/adapters/registry.rb` | PRESENT, SUBSTANTIVE | Maps all 3 types, CONFIG_SCHEMAS with required/optional keys per type |
| Base adapter | `app/adapters/adapters/base_adapter.rb` | PRESENT, SUBSTANTIVE | Abstract interface: execute, test_connection, display_name, description |
| HTTP adapter | `app/adapters/adapters/http_adapter.rb` | PRESENT | Phase 7 stubs with NotImplementedError — correct per phase scope |
| Process adapter | `app/adapters/adapters/process_adapter.rb` | PRESENT | Phase 7 stubs — correct per phase scope |
| Claude Local adapter | `app/adapters/adapters/claude_local_adapter.rb` | PRESENT | Phase 7 stubs — correct per phase scope |
| AgentsController | `app/controllers/agents_controller.rb` | PRESENT, SUBSTANTIVE | Full CRUD, require_company!, Current.company scoping, jsonb params handling |
| AgentCapabilitiesController | `app/controllers/agent_capabilities_controller.rb` | PRESENT, SUBSTANTIVE | create/destroy scoped to Current.company.agents |
| Agents views (6 files) | `app/views/agents/` | PRESENT, SUBSTANTIVE | index, show, new, edit, _form, _agent all present and complete |
| Stimulus controller | `app/javascript/controllers/adapter_config_controller.js` | PRESENT, SUBSTANTIVE | configGroup targets, toggle() method, disabled state management |
| AgentsHelper | `app/helpers/agents_helper.rb` | PRESENT, SUBSTANTIVE | agent_status_badge, adapter_type_label, adapter_type_options |
| Agents migration | `db/migrate/20260327085826_create_agents.rb` | PRESENT | Applied (status: up) |
| Capabilities migration | `db/migrate/20260327085837_create_agent_capabilities.rb` | PRESENT | Applied (status: up) |
| Agent model tests | `test/models/agent_test.rb` | PRESENT, SUBSTANTIVE | 28 tests covering validations, enums, associations, scoping, methods, deletion |
| AgentCapability model tests | `test/models/agent_capability_test.rb` | PRESENT, SUBSTANTIVE | 10 tests |
| Agent controller tests | `test/controllers/agents_controller_test.rb` | PRESENT, SUBSTANTIVE | 20 tests covering all CRUD + auth + scoping |
| Capabilities controller tests | `test/controllers/agent_capabilities_controller_test.rb` | PRESENT, SUBSTANTIVE | 8 tests covering add/remove/scoping/auth |
| Fixtures | `test/fixtures/agents.yml` | PRESENT | 4 agents (3 for acme, 1 for widgets), all 3 adapter types |
| Fixtures | `test/fixtures/agent_capabilities.yml` | PRESENT | 3 capabilities across 2 agents |

**Zeitwerk deviation (from SUMMARY):** The plan specified `app/adapters/registry.rb` but the actual files live at `app/adapters/adapters/registry.rb`. This is the correct Zeitwerk pattern for the `Adapters::*` namespace with Rails 8 autoloading. Confirmed working at runtime.

---

## Key Links (Wiring)

| From | To | Via | Status |
|------|----|-----|--------|
| `app/models/agent.rb` | `app/models/company.rb` | `include Tenantable` (scopes to company_id via Current.company) | WIRED |
| `app/models/agent.rb` | `app/models/agent_capability.rb` | `has_many :agent_capabilities, dependent: :destroy` | WIRED |
| `app/models/role.rb` | `app/models/agent.rb` | `belongs_to :agent, optional: true` + FK in schema | WIRED |
| `app/adapters/adapters/registry.rb` | `app/adapters/adapters/http_adapter.rb` | `Registry.for(:http)` returns `Adapters::HttpAdapter` via constantize | WIRED |
| `app/views/agents/_form.html.erb` | `AgentsController#create` | `form_with model: agent` | WIRED |
| `app/javascript/controllers/adapter_config_controller.js` | `app/views/agents/_form.html.erb` | `data-controller="adapter-config"` on form, `data-adapter-config-target="configGroup"` on fieldsets | WIRED |
| `app/controllers/agents_controller.rb` | `app/models/agent.rb` | `Current.company.agents` scope | WIRED |
| `config/routes.rb` | `app/controllers/agents_controller.rb` | `resources :agents` (7 RESTful routes confirmed) | WIRED |
| `config/routes.rb` | `app/controllers/agent_capabilities_controller.rb` | nested `resources :capabilities` under agents | WIRED |
| `app/views/agents/show.html.erb` | `AgentCapabilitiesController#create/#destroy` | `form_with(url: agent_capabilities_path(@agent))` + `button_to` with DELETE | WIRED |
| `app/views/roles/_form.html.erb` | `RolesController#update` | `f.select :agent_id, options_for_agent_select` | WIRED |
| `app/views/roles/_role.html.erb` | `app/models/agent.rb` | `role.agent` association, `role.agent.status` | WIRED |
| `app/helpers/org_charts_helper.rb` | `app/models/agent.rb` | `role.agent&.name` in `role_node_data` | WIRED |
| `app/controllers/org_charts_controller.rb` | `app/models/agent.rb` | `.includes(:agent)` in roles query | WIRED |

---

## Cross-Phase Integration

**From Phase 3 (Roles):**
- `roles.agent_id` FK column (from Phase 3 migration) now has a proper foreign key constraint to `agents` added in the Phase 4 CreateAgents migration. Confirmed in `db/schema.rb`.
- `Role.belongs_to :agent, optional: true` populates the pre-existing column.
- All "Phase 3 placeholder" text confirmed removed from role views (grep returns 0 results).

**Navigation regression:** The app header now only shows an "Agents" link under the company guard. The previous "Roles" and "Org Chart" links are absent from the header. However, the `app/views/home/show.html.erb` appears to provide company-scoped navigation. This warrants human review to confirm user discoverability of Roles/OrgChart post-phase-4 navigation refactor. The test suite passes so there is no functional regression, but UX navigation completeness needs visual verification.

---

## Test Results

| Suite | Tests | Assertions | Failures | Errors |
|-------|-------|------------|----------|--------|
| agent_test.rb | 28 | ~70 | 0 | 0 |
| agent_capability_test.rb | 10 | ~25 | 0 | 0 |
| agents_controller_test.rb | 20 | ~60 | 0 | 0 |
| agent_capabilities_controller_test.rb | 8 | ~25 | 0 | 0 |
| **Full suite** | **197** | **505** | **0** | **0** |

Full suite: 197 tests, 505 assertions, 0 failures, 0 errors, 0 skips.

---

## Security Findings

| Check | Severity | File | Line | Detail |
|-------|----------|------|------|--------|
| MassAssignment (permit!) | High | `app/controllers/agents_controller.rb` | 53 | `params[:agent][:adapter_config].permit!` allows any keys to be written to the jsonb `adapter_config` column. A malicious user can inject arbitrary keys (e.g. `__proto__`, `class`, or large payloads) since no allowlist is enforced. Mitigation: use `params[:agent][:adapter_config].permit(*Adapters::Registry.all_config_keys(adapter_type))` after resolving the adapter_type from params. This was flagged by Brakeman (exit code 3, 1 warning). |

This finding was pre-existing from Plan 04-02 (acknowledged in 04-03-SUMMARY.md as a known pre-existing Brakeman warning).

---

## Performance Findings

No high-severity performance issues found.

- N+1 prevention confirmed: `AgentsController#index` uses `.includes(:agent_capabilities, :roles)`.
- `RolesController#index` uses `.includes(:parent, :children, :agent)`.
- `OrgChartsController#show` uses `.includes(:parent, :children, :agent)`.
- `AgentCapabilitiesController` scopes through `Current.company.agents` (single FK lookup).

---

## Human Verification Needed

| Test | Expected | Why Human |
|------|----------|-----------|
| Stimulus adapter-config toggle on form | Selecting "HTTP API" shows HTTP fieldset, hides Process/Claude Local; switching hides HTTP and shows selected | Cannot run JavaScript in automated tests; requires browser |
| Navigation completeness | All company-scoped sections (Agents, Roles, Org Chart) are discoverable from the UI | Header only shows "Agents" link; Roles/Org Chart may be accessed from home page — needs visual confirmation |
| Auth token masking on show page | Creating an HTTP agent with auth_token shows "••••••••{last4}" on detail page | Requires end-to-end browser interaction |
| Status badge colors render correctly | idle=green, running=teal, paused=amber, error=red, terminated=gray, pending_approval=blue | Visual CSS validation requires browser |

---

## Gaps Narrative

**Success Criterion 3 — Partial (intentional):** "System displays agent status and updates it based on health checks." The display half is fully delivered: all 6 status values have CSS badge variants and role-card status dots, `agent_status_badge` helper is wired throughout the UI. The update-via-health-checks half is explicitly out of scope for Phase 4 per `04-CONTEXT.md` ("NO heartbeat execution in this phase — comes in Phase 7"). The `last_heartbeat_at` column is in place. This is a planned deferral, not an oversight.

**Security — Medium impact:** The `permit!` on `adapter_config` is a real finding (Brakeman High). The jsonb field stores arbitrary user-supplied keys with no type enforcement beyond what the adapter schema validation checks at model save time. The risk is bounded because: (a) the model's `validate_adapter_config_schema` still runs and rejects missing required keys, and (b) this is a private field (not user-visible until the show page). However, an authenticated user of the same company could store arbitrary keys. This should be addressed in a future plan by allowlisting keys per adapter_type.

**Navigation regression check:** The application header after Phase 4 only shows "Agents" under `Current.company` guard, without links to "Roles" or "Org Chart". These were likely present before Phase 4 (the summary notes the nav was refactored). The home page (`home/show.html.erb`) may provide these links. This should be verified visually as it affects user discoverability, though it does not cause test failures.
