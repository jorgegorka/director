---
phase: 04-agent-connection
plan: "02"
status: complete
completed_at: 2026-03-27T09:11:28Z
duration_seconds: 332
tasks_completed: 3
tasks_total: 3
files_created: 12
files_modified: 3
commits: 3
---

# Plan 04-02 Summary: Agent CRUD Interface

## Objective

Built the full Agent CRUD interface: controller, views, routes, dynamic adapter configuration form with Stimulus, and comprehensive controller tests. Users can now create, view, edit, and delete agents within their company, with adapter-specific configuration fields that change dynamically based on the selected adapter type.

## Tasks Completed

### Task 1: Routes, controller, helper, and Stimulus adapter config controller (commit: cf2f922)

**Routes updated:**
- `config/routes.rb` — Added `resources :agents` after org_chart route

**Controller created:**
- `app/controllers/agents_controller.rb` — Full CRUD controller scoped to `Current.company`, `require_company!` before action, `set_agent` scoped finder. `agent_params` permits standard fields plus builds `adapter_config` hash from nested params (handles ActionController::Parameters jsonb hash).

**Helper created:**
- `app/helpers/agents_helper.rb` — `agent_status_badge(agent)` renders status pill with BEM CSS class, `adapter_type_label(agent)` returns display name from Adapters::Registry, `adapter_type_options` maps all registry adapter types to `[display_name, type]` pairs for select options.

**Stimulus controller created:**
- `app/javascript/controllers/adapter_config_controller.js` — `configGroup` targets, `connect()` calls `toggle()`, `toggle()` queries `[data-adapter-config-select]` value and shows/hides/enables/disables matching fieldset groups. Auto-registered via `eagerLoadControllersFrom`.

### Task 2: Agent views with dynamic adapter config form (commit: cef80b1)

**Views created:**
- `app/views/agents/index.html.erb` — Page header with "New Agent" button, grid of agent cards, empty state
- `app/views/agents/_agent.html.erb` — Agent card with name link, status badge, adapter type label, description truncated to 120 chars, capabilities count, roles count
- `app/views/agents/show.html.erb` — Full detail page: status badge + adapter type in header, adapter config as definition list (auth_token masked showing last 4 chars), heartbeat display with "Never" fallback and future-update note, capabilities as badge list, assigned roles as links
- `app/views/agents/new.html.erb` — Minimal new form wrapper
- `app/views/agents/edit.html.erb` — Minimal edit form wrapper
- `app/views/agents/_form.html.erb` — Form with Stimulus `adapter-config` controller: name, description, adapter_type select, three conditional fieldsets (HTTP: url/method/auth_token; Process: command/working_directory; Claude Local: model/max_turns/system_prompt)

**CSS added to `app/assets/stylesheets/application.css`:**
- `.agents-page`, `.agents-page__header`, `.agents-page__empty` — page layout matching roles-page pattern
- `.agents-list` — CSS grid `auto-fill minmax(20rem, 1fr)`
- `.agent-card` — card with flex column layout, header/meta/footer structure
- `.agent-card__name` — link with brand-500 hover
- `.status-badge` — pill with 6 status variants: `--idle` (success green), `--running` (accent teal), `--paused` (warning amber), `--error` (error red), `--terminated` (neutral gray), `--pending_approval` (brand blue)
- `.agent-detail` — detail page layout with config dl, heartbeat, capabilities, roles
- `.agent-detail__config-row` — definition list grid (10rem label / 1fr value)
- `.agent-detail__masked` — monospace display for masked auth_token values
- `.capability-badge` — accent-tinted pill for capability names
- `.agent-form-page` — constrained form layout
- `.form__fieldset` — styled fieldset with legend for adapter config groups, inputs inherit form styling

All styles use OKLCH colors from tokens, CSS layers, logical properties, CSS nesting.

### Task 3: Comprehensive controller tests (commit: fa7ca48)

**Test file created:**
- `test/controllers/agents_controller_test.rb` — 20 tests covering all CRUD actions

**Test coverage:**
- Index: renders success, only shows acme agents (not widgets_agent)
- Show: renders agent detail, shows adapter type label, returns 404 for other company's agent
- New/Create: form renders, creates http/process/claude_local agents, rejects blank name, rejects duplicate name, rejects http without url (config validation)
- Edit/Update: form renders, updates name/description, updates adapter_config jsonb, rejects blank name
- Destroy: decrements Agent.count, nullifies roles.agent_id (CTO role had claude_agent assigned)
- Auth/Scoping: unauthenticated redirects to session, no-company user redirects to new_company

**Results:** 185 tests, 468 assertions, 0 failures, 0 errors, 0 skips

## Key Decisions

- **Fixture jsonb format:** Changed `test/fixtures/agents.yml` from JSON string literals (`'{"key": "val"}'`) to YAML hash syntax (`key: val`). JSON string literals caused Rails to store the raw string in PostgreSQL without proper deserialization — the column returned a String instead of a Hash, breaking all controller tests. YAML hash syntax lets Rails' ActiveRecord type system properly serialize/deserialize the jsonb column (Rule 1 auto-fix).
- **adapter_params pattern:** `agent_params` explicitly rebuilds `adapter_config` from `params[:agent][:adapter_config]` using `permit!.to_h` to avoid strong params blocking nested jsonb hash keys. This is the correct pattern for unrestricted jsonb field updates.
- **Stimulus toggle design:** Disabled state on hidden inputs (not just `display: none`) prevents form submission of non-active adapter config fields, ensuring clean jsonb storage with only the relevant adapter's keys.
- **Auth token masking:** Show page displays only last 4 chars of auth_token values (if present) to avoid leaking credentials in the UI.

## Deviations

- **[Rule 1 - Bug] Fixture jsonb format:** Discovered during controller test execution that JSON string literals in YAML fixtures (`'{"key": "val"}'`) cause Rails to store the jsonb column value as a literal string rather than a properly typed Hash. Auto-fixed by converting all `adapter_config` fixture values to YAML hash syntax. This affected only test fixtures — production behavior is unaffected since real code always passes Ruby Hash values.

## Artifacts Produced

| File | Purpose |
|------|---------|
| `app/controllers/agents_controller.rb` | Full CRUD controller scoped to Current.company |
| `app/helpers/agents_helper.rb` | Status badge, adapter type label, adapter type options helpers |
| `app/javascript/controllers/adapter_config_controller.js` | Stimulus controller toggling adapter-specific fieldsets |
| `app/views/agents/index.html.erb` | Agent list page |
| `app/views/agents/_agent.html.erb` | Agent card partial |
| `app/views/agents/show.html.erb` | Agent detail page |
| `app/views/agents/new.html.erb` | New agent form page |
| `app/views/agents/edit.html.erb` | Edit agent form page |
| `app/views/agents/_form.html.erb` | Dynamic adapter config form partial |
| `app/assets/stylesheets/application.css` | Agent CSS: cards, status badges, detail, form fieldsets |
| `test/controllers/agents_controller_test.rb` | 20 comprehensive controller tests |
| `test/fixtures/agents.yml` | Fixed: YAML hash syntax for jsonb adapter_config |

## Self-Check: PASSED

All files verified present:
- app/controllers/agents_controller.rb — FOUND
- app/helpers/agents_helper.rb — FOUND
- app/javascript/controllers/adapter_config_controller.js — FOUND
- app/views/agents/index.html.erb — FOUND
- app/views/agents/_agent.html.erb — FOUND
- app/views/agents/show.html.erb — FOUND
- app/views/agents/new.html.erb — FOUND
- app/views/agents/edit.html.erb — FOUND
- app/views/agents/_form.html.erb — FOUND
- test/controllers/agents_controller_test.rb — FOUND
- test/fixtures/agents.yml — FOUND (modified)

All commits verified:
- cf2f922: feat(04-02): routes, AgentsController, AgentsHelper, and Stimulus adapter config controller
- cef80b1: feat(04-02): agent views with dynamic adapter config form and CSS styles
- fa7ca48: test(04-02): comprehensive AgentsController tests and fixture fix
