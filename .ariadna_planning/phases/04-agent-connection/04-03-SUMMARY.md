# Plan 04-03 Summary: UI Wire-Up — Capabilities, Role Assignment, Navigation

**Phase:** 04-agent-connection
**Plan:** 03
**Status:** COMPLETE
**Duration:** ~5m 23s
**Tasks:** 3/3 complete
**Tests:** 197 passing (0 failures, 0 errors)

---

## Objective

Complete the Phase 4 feature set by wiring capabilities management into the agent profile, connecting agents to roles in the UI (replacing Phase 3 placeholders), and adding navigation.

---

## Tasks Completed

### Task 1: Capabilities management on agent profile
**Commit:** dbc5576

- Created `AgentCapabilitiesController` with `create`/`destroy` actions, scoped to `Current.company` via `set_agent`
- Nested routes: `POST /agents/:agent_id/capabilities` and `DELETE /agents/:agent_id/capabilities/:id`
- Agent show page updated: removable capability badges (with turbo confirm) + inline add form using `form_with(url: agent_capabilities_path(@agent))`
- CSS added: `.capability-badge__remove` (inline × button), `.form--inline` and `.form__field--inline` (horizontal flex layout)
- 8 controller tests: add capability, add without description, remove, duplicate prevention, blank prevention, cross-company scoping (POST + DELETE)
- **Deviation note:** `form_with(model: [@agent, AgentCapability.new])` generated incorrect `agent_agent_capabilities_path` helper. Fixed by using explicit `url: agent_capabilities_path(@agent)` (Rule 3 auto-fix)

### Task 2: Agent assignment to roles and placeholder replacement
**Commit:** 8ef74cf

- `RolesController#index`: added `:agent` to includes chain (prevents N+1)
- `RolesController#role_params`: added `:agent_id` to permitted params
- `RolesHelper#options_for_agent_select`: returns active company agents ordered by name
- `roles/_form.html.erb`: agent assignment dropdown with "None (unassigned)" blank option
- `roles/_role.html.erb`: conditional agent display with status-colored dot and link (replaces hardcoded "Unassigned")
- `roles/show.html.erb`: assigned agent with name, link, and status badge; removes Phase 3 placeholder text "Agents can be assigned in Phase 4"
- CSS: agent-dot status colors for all 6 statuses (idle=green, running=teal, paused=amber, error=red, terminated=gray, pending_approval=blue)
- 4 new roles controller tests: assign on create, assign on update, unassign (agent_id: ""), show agent name on detail

### Task 3: Navigation link, org chart agent names, full verification
**Commit:** 1d7c3a5

- Added "Agents" link to `app/views/layouts/application.html.erb` header nav (conditional on `Current.company`, active state via `controller_name == "agents"`)
- Added "Agents" link to `app/views/home/show.html.erb` company nav
- CSS: `.nav__link` and `.nav__link--active` styles
- `OrgChartsHelper#role_node_data`: replaced `agent_name: nil` with `agent_name: role.agent&.name`
- `OrgChartsController#show`: added `:agent` to includes chain to prevent N+1 on org chart render
- Removed Phase 3 home page placeholder "Agents, tasks, and goals coming soon."

---

## Files Modified

| File | Change |
|------|--------|
| `config/routes.rb` | Added nested capabilities resources under agents |
| `app/controllers/agent_capabilities_controller.rb` | New — create/destroy with company scoping |
| `app/controllers/roles_controller.rb` | Permit agent_id, eager-load :agent |
| `app/controllers/org_charts_controller.rb` | Eager-load :agent |
| `app/helpers/roles_helper.rb` | Added options_for_agent_select |
| `app/helpers/org_charts_helper.rb` | Use role.agent&.name instead of nil |
| `app/views/agents/show.html.erb` | Capabilities section with add/remove UI |
| `app/views/roles/_form.html.erb` | Agent assignment dropdown |
| `app/views/roles/_role.html.erb` | Conditional agent display with status dot |
| `app/views/roles/show.html.erb` | Assigned agent with status badge, no placeholder |
| `app/views/layouts/application.html.erb` | Agents nav link with active state |
| `app/views/home/show.html.erb` | Agents nav link, removed placeholder section |
| `app/assets/stylesheets/application.css` | nav__link, capability-badge__remove, form--inline, agent-dot status colors |
| `test/controllers/agent_capabilities_controller_test.rb` | New — 8 tests |
| `test/controllers/roles_controller_test.rb` | 4 new agent assignment tests |

---

## Patterns Used

- **Nested resources:** `resources :agents do resources :capabilities` — clean RESTful semantics for capability management
- **Current.company scoping:** Both `AgentCapabilitiesController` and `RolesController` scope through `Current.company.agents` to prevent cross-tenant access
- **Eager loading:** `:agent` added to includes in `RolesController#index` and `OrgChartsController#show` to prevent N+1 queries
- **Safe nullability:** `role.agent&.name` for optional association access throughout
- **Explicit URL in form_with:** When `model:` array generates incorrect helper names (due to custom controller naming), use `url:` explicitly

---

## Deviations

1. **[Rule 3 - Auto-fix] form_with model array generated wrong path helper**
   - `form_with(model: [@agent, AgentCapability.new])` generated `agent_agent_capabilities_path` (non-existent)
   - Fixed: `form_with(url: agent_capabilities_path(@agent))` with explicit field name `agent_capability[name]`
   - Root cause: Rails infers path from model class name, producing `agent_` prefix twice with custom controller naming

---

## Verification

- `bin/rails routes | grep capabilities` — POST and DELETE nested under agents: confirmed
- `bin/rails test` — 197 tests, 0 failures, 0 errors
- `bin/rubocop` — 94 files inspected, 0 offenses
- `bin/brakeman --quiet --no-pager` — 0 new warnings (1 pre-existing from 04-02: adapter_config.permit!)
- `grep -r "Phase 4\|Phase 3" app/views/roles/` — 0 results (all placeholders replaced)

---

## Phase 4 Success Criteria Coverage

1. User can register an agent via HTTP API endpoint configuration — DONE (04-02)
2. User can register an agent via bash command configuration — DONE (04-02, process adapter)
3. System displays agent status visually (badges + dots) — DONE (status badges + colored dots throughout)
4. Agents can declare capabilities, visible in agent profile — DONE (04-03, inline add/remove badges)
5. Agent assignment to roles — DONE (04-03, dropdown + role card/detail display)
6. Navigation includes "Agents" link — DONE (04-03)
7. Org chart nodes show real agent names — DONE (04-03)

**Phase 4 is complete.**

## Self-Check: PASSED

All created files confirmed present. All 3 task commits found.
