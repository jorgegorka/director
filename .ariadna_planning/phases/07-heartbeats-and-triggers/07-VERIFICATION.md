---
phase: 07-heartbeats-and-triggers
verified: 2026-03-27T15:10:00Z
status: gaps_found
score: "11/12 truths verified | security: 0 critical, 0 high | performance: 1 medium"
gaps:
  - truth: "All model and service tests pass"
    status: partial
    reason: "test 'agent.last_heartbeat_event returns most recent' in test/models/heartbeat_event_test.rb fails when run in isolation (single-file or standalone execution) due to fixture created_at ordering assumption. Passes in full parallel suite by accident."
    artifacts:
      - path: test/models/heartbeat_event_test.rb
        issue: "Line 142-149: test asserts heartbeat_events(:mention_event).id == last.id, relying on mention_event having a later created_at than scheduled_heartbeat. Fixtures use auto-assigned created_at (insertion order), not the fixture delivered_at values (15 min ago vs 1 hour ago). Fails deterministically when run alone (bin/rails test test/models/heartbeat_event_test.rb exits 1)."
    missing:
      - "Fix the test to create its own fixture data with explicit created_at values, or set created_at on fixtures in YAML using ERB (e.g. created_at: <%= 10.minutes.ago.to_fs(:db) %>)"
performance_findings:
  - check: "mention-detect-n+1"
    severity: medium
    file: app/models/concerns/triggerable.rb
    line: 27
    detail: "detect_mentions loads ALL active agents into Ruby memory via company.agents.active.select { ... }. For companies with many agents this is an O(N) Ruby-side scan. A SQL LIKE query or a regex match on the database side would be more efficient. Low risk at current scale but will degrade as agent count grows."

# Phase 07 Verification Report: Heartbeats and Triggers

**Phase goal:** Agents wake on configurable schedules and respond to events like task assignments or mentions

## Observable Truths Table

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | HeartbeatEvent model exists with agent_id, trigger_type (scheduled/task_assigned/mention), trigger_source, status (queued/delivered/failed), delivered_at, response_payload, metadata jsonb | PASS | `app/models/heartbeat_event.rb` — enums, associations, scopes all present; schema.rb confirms all columns with correct types and indexes |
| 2 | Agent model has heartbeat_interval (integer, nullable) and heartbeat_enabled (boolean, default false) per-agent schedule columns | PASS | `db/schema.rb` lines 34-35 confirm both columns; migration `20260327135006` creates them correctly |
| 3 | WakeAgentService dispatches adapter-aware wake calls: HTTP = immediate delivery, process/claude_local = queued | PASS | `app/services/wake_agent_service.rb` — `initial_status` returns `:delivered` for `agent.http?`, `:queued` otherwise; 7 tests verify both paths |
| 4 | AgentHeartbeatJob is an ActiveJob that calls WakeAgentService for a given agent_id | PASS | `app/jobs/agent_heartbeat_job.rb` — extends ApplicationJob, queue_as :default, delegates to `WakeAgentService.call` with guards |
| 5 | HeartbeatScheduleManager creates/updates/removes SolidQueue::RecurringTask when agent schedule changes | PASS | `app/services/heartbeat_schedule_manager.rb` — `class_attribute :task_store` pattern with FakeTaskStore injection; 7 tests cover all CRUD paths |
| 6 | HeartbeatEvent scoped to company via agent association with chronological/by_trigger scopes | PASS | `HeartbeatEvent` belongs_to agent; agent belongs_to company; `HeartbeatsController#set_agent` scopes via `Current.company.agents.find`; `Api::AgentEventsController` scopes via `@current_agent.heartbeat_events` |
| 7 | Agent has after_commit callback to sync schedule via HeartbeatScheduleManager | PASS | `app/models/agent.rb` line 22: `after_commit :sync_heartbeat_schedule, if: :heartbeat_config_changed?` using `saved_change_to_heartbeat_interval?` / `saved_change_to_heartbeat_enabled?` |
| 8 | When a task is assigned to an agent, a HeartbeatEvent with trigger_type: task_assigned is created | PASS | `app/models/task.rb` — `include Triggerable`, `after_commit :trigger_assignment_wake, on: [:create, :update], if: :agent_just_assigned?`; 8 TriggerableTaskTest tests pass |
| 9 | When a message @mentions an agent in the same company, a HeartbeatEvent with trigger_type: mention is created | PASS | `app/models/message.rb` — `include Triggerable`, `after_commit :trigger_mention_wake, on: :create`; case-insensitive; 8 TriggerableMentionTest tests pass |
| 10 | Process/claude_local agents can poll queued HeartbeatEvents via Bearer-authenticated JSON API | PASS | `GET /api/agent/events` and `POST /api/agent/events/:id/acknowledge` routes exist; `Api::AgentEventsController` uses `AgentApiAuthenticatable`; 10 controller tests pass |
| 11 | User can configure heartbeat schedule in agent form; show page displays history | PASS | `app/views/agents/_form.html.erb` — heartbeat fieldset with checkbox and 9-option interval select; `app/views/agents/show.html.erb` — real heartbeat section with schedule status, last activity, 5 recent events table, link to full history; `AgentsController` permits `:heartbeat_enabled, :heartbeat_interval` |
| 12 | All model and service tests pass | PARTIAL | Full parallel suite passes (455 tests, 0 failures). Single-file run of `test/models/heartbeat_event_test.rb` fails 1/21: `test "agent.last_heartbeat_event returns most recent"` due to fixture `created_at` ordering assumption (see gaps) |

**Score: 11/12 truths verified (1 partial)**

## Artifact Status

| Artifact | Exists | Substantive | Notes |
|----------|--------|-------------|-------|
| `app/models/heartbeat_event.rb` | YES | YES | Full model: enums, scopes, mark_delivered!/mark_failed! |
| `app/services/wake_agent_service.rb` | YES | YES | Adapter-aware dispatch, event creation, last_heartbeat_at update |
| `app/jobs/agent_heartbeat_job.rb` | YES | YES | ApplicationJob with 3 guard checks before delegating to service |
| `app/services/heartbeat_schedule_manager.rb` | YES | YES | CRUD for SolidQueue::RecurringTask with injectable task_store |
| `app/models/concerns/triggerable.rb` | YES | YES | trigger_agent_wake + detect_mentions helpers |
| `app/controllers/api/agent_events_controller.rb` | YES | YES | index + acknowledge actions with AgentApiAuthenticatable |
| `app/controllers/heartbeats_controller.rb` | YES | YES | Offset-based pagination, company-scoped set_agent |
| `app/views/heartbeats/index.html.erb` | YES | YES | Table, pagination nav, empty state |
| `app/views/agents/_form.html.erb` | YES | YES | Heartbeat fieldset with checkbox and select |
| `app/views/agents/show.html.erb` | YES | YES | Real heartbeat section replaces placeholder |
| `app/helpers/heartbeats_helper.rb` | YES | YES | heartbeat_trigger_badge, heartbeat_status_indicator, heartbeat_schedule_label |
| `db/migrate/20260327134948_create_heartbeat_events.rb` | YES | YES | Full table with 3 indexes and foreign key |
| `db/migrate/20260327135006_add_heartbeat_schedule_to_agents.rb` | YES | YES | Adds heartbeat_interval + heartbeat_enabled with correct defaults |
| `test/fixtures/heartbeat_events.yml` | YES | YES | 5 fixtures covering all trigger types and statuses across 3 agents |
| `test/models/heartbeat_event_test.rb` | YES | YES (with gap) | 21 tests; 1 test fragile due to fixture created_at ordering |
| `test/services/wake_agent_service_test.rb` | YES | YES | 7 tests covering all adapter paths |
| `test/jobs/agent_heartbeat_job_test.rb` | YES | YES | 4 tests covering all guard conditions |
| `test/services/heartbeat_schedule_manager_test.rb` | YES | YES | 7 tests with FakeTaskStore injection |
| `test/models/concerns/triggerable_test.rb` | YES | YES | 16 tests in 2 classes |
| `test/controllers/api/agent_events_controller_test.rb` | YES | YES | 10 tests covering auth + polling + acknowledge |
| `test/controllers/heartbeats_controller_test.rb` | YES | YES | 11 tests covering CRUD, security, pagination |

## Key Links (Wiring)

| From | To | Via | Status |
|------|----|-----|--------|
| `app/models/heartbeat_event.rb` | `app/models/agent.rb` | `belongs_to :agent` | WIRED |
| `app/models/agent.rb` | `app/models/heartbeat_event.rb` | `has_many :heartbeat_events, dependent: :destroy` | WIRED |
| `app/services/wake_agent_service.rb` | `app/models/heartbeat_event.rb` | `agent.heartbeat_events.create!` | WIRED |
| `app/jobs/agent_heartbeat_job.rb` | `app/services/wake_agent_service.rb` | `WakeAgentService.call(agent:, trigger_type: :scheduled)` | WIRED |
| `app/services/heartbeat_schedule_manager.rb` | `app/jobs/agent_heartbeat_job.rb` | `class_name: "AgentHeartbeatJob"` in recurring task | WIRED |
| `app/models/agent.rb` | `app/services/heartbeat_schedule_manager.rb` | `after_commit :sync_heartbeat_schedule` → `HeartbeatScheduleManager.sync(self)` | WIRED |
| `app/models/concerns/triggerable.rb` | `app/services/wake_agent_service.rb` | `WakeAgentService.call(agent:, trigger_type:, ...)` | WIRED |
| `app/models/task.rb` | `app/models/concerns/triggerable.rb` | `include Triggerable` + `after_commit :trigger_assignment_wake` | WIRED |
| `app/models/message.rb` | `app/models/concerns/triggerable.rb` | `include Triggerable` + `after_commit :trigger_mention_wake, on: :create` | WIRED |
| `app/controllers/api/agent_events_controller.rb` | `app/models/heartbeat_event.rb` | `@current_agent.heartbeat_events.queued.chronological` | WIRED |
| `app/controllers/api/agent_events_controller.rb` | `app/controllers/concerns/agent_api_authenticatable.rb` | `include AgentApiAuthenticatable` | WIRED |
| `app/controllers/heartbeats_controller.rb` | `app/models/heartbeat_event.rb` | `@agent.heartbeat_events.reverse_chronological.offset.limit` | WIRED |
| `app/views/agents/show.html.erb` | `app/controllers/heartbeats_controller.rb` | `link_to "View all heartbeat history", agent_heartbeats_path(@agent)` | WIRED |
| `config/routes.rb` | `app/controllers/heartbeats_controller.rb` | `resources :heartbeats, only: [:index]` nested under `:agents` | WIRED |
| `config/routes.rb` | `app/controllers/api/agent_events_controller.rb` | `namespace :api, scope :agent, resources :events` | WIRED |

## Cross-Phase Integration

**Phase 4 (Agents):** `AgentApiAuthenticatable` concern from Phase 4 is correctly reused by `Api::AgentEventsController`. Agent's `adapter_type` enum (http/process/claude_local) is consumed by `WakeAgentService#initial_status` to decide delivery mechanism. `agent.terminated?` guards work because `status` enum was established in Phase 4.

**Phase 5 (Tasks + Messages):** Task and Message models were already established in Phase 5. Phase 7 adds `include Triggerable` to both without breaking existing behavior. `after_commit` pattern matches Auditable concern established in Phase 5. The `task.company` accessor used in `trigger_mention_wake` is reliable via the existing `belongs_to :company` chain.

**E2E User Flow (Success Criterion 1 — schedule):**
- User opens agent edit form → `_form.html.erb` shows heartbeat fieldset (checkbox + interval select)
- User enables schedule + selects interval → form submits to `AgentsController#update`
- `agent_params` permits `:heartbeat_enabled, :heartbeat_interval` — wired
- Agent saves → `after_commit :sync_heartbeat_schedule` fires → `HeartbeatScheduleManager.sync` → creates SolidQueue recurring task
- Solid Queue fires `AgentHeartbeatJob` → `WakeAgentService.call(trigger_type: :scheduled)` → creates HeartbeatEvent
- User visits agent page → `@recent_heartbeats` from `show` action → heartbeat table renders
- User clicks "View all heartbeat history" → `agent_heartbeats_path(@agent)` → `HeartbeatsController#index` → paginated view

**E2E User Flow (Success Criterion 2 — event triggers):**
- Task assigned to agent → `after_commit :trigger_assignment_wake` → `WakeAgentService` → HeartbeatEvent with trigger_type: task_assigned
- Message with @agent_name → `after_commit :trigger_mention_wake` → `detect_mentions` → `WakeAgentService` → HeartbeatEvent with trigger_type: mention
- Both flows verified by 16 tests in `triggerable_test.rb`

**E2E User Flow (Success Criterion 3 — history viewable):**
- Agent show page shows 5 most recent heartbeat events inline + link to full history
- `GET /agents/:id/heartbeats` shows paginated full history
- Both wired and controller-tested

**E2E User Flow (Success Criterion 4 — per-agent independent config):**
- `heartbeat_interval` and `heartbeat_enabled` are per-agent columns
- Different agents get distinct Solid Queue tasks keyed `"agent_heartbeat_{id}"`
- Form allows independent config per agent
- Tested in agents_controller_test.rb

## Security Findings

No Brakeman warnings. No CSRF or auth bypasses detected.

- `Api::AgentEventsController#acknowledge`: uses scoped `@current_agent.heartbeat_events.queued.find_by(id:)` — correctly prevents cross-agent event access and re-acknowledgment. Verified by 2 tests.
- `HeartbeatsController#set_agent`: scopes to `Current.company.agents.find(params[:agent_id])` — correctly prevents cross-company access. Verified by test "should not show heartbeats for agent from another company".
- No mass assignment risk: `agent_params` explicitly permits only `:heartbeat_enabled, :heartbeat_interval`.

## Performance Findings

| Severity | File | Line | Detail |
|----------|------|------|--------|
| medium | `app/models/concerns/triggerable.rb` | 27 | `detect_mentions` loads all active agents into Ruby memory via `company.agents.active.select { ... }`. This is an O(N) in-process scan. For companies with large agent counts (100+), every message creation will load all agents. A SQL approach using `WHERE LOWER(name) = ANY(?)` or a stored full-text search would scale better. |

## Gaps Narrative

### Gap 1: Test fragility in `test/models/heartbeat_event_test.rb:142` (PARTIAL failure)

**Truth:** "All model and service tests pass"
**What fails:** `bin/rails test test/models/heartbeat_event_test.rb` exits with 1 failure. The test `"agent.last_heartbeat_event returns most recent"` asserts that `claude_agent`'s `last_heartbeat_event` is `mention_event` (created 15 minutes ago) rather than `scheduled_heartbeat` (created 1 hour ago). These timestamps are the fixture `delivered_at` values, but `reverse_chronological` orders by `created_at`, not `delivered_at`. Fixtures auto-assign `created_at` based on insertion order, which isn't deterministic relative to the `delivered_at` values specified in the YAML.

**Why it passes in full suite:** The full parallel suite runs with multiple worker processes. Each process loads fixtures in a different context that happens to assign `mention_event` a later `created_at`. This is coincidental, not guaranteed.

**Fix required:** Either add `created_at` ERB timestamps to the two fixtures in `heartbeat_events.yml`, or rewrite the test to create its own events with explicit ordering.

This is a real gap — the summary's self-check claim "All files confirmed present" did not catch that a specific test fails when run standalone.
