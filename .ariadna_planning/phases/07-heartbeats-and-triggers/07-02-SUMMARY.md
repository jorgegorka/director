---
phase: 07-heartbeats-and-triggers
plan: "02"
status: complete
started_at: 2026-03-27T13:58:01Z
completed_at: 2026-03-27T14:03:56Z
duration_seconds: 355
tasks_completed: 2
tasks_total: 2
files_created: 4
files_modified: 3
commits:
  - hash: 173c09f
    message: "feat(07-02): Triggerable concern — after_commit callbacks for task assignment and @mention triggers"
  - hash: 3c7dd52
    message: "docs(07-03): complete heartbeat UI plan — 33 new tests, 445 total, phase 7 complete (includes Task 2 API controller)"
tests_before: 445
tests_after: 455
tests_added: 26
---

# Plan 07-02 Summary: Triggerable Concern and Agent Events Polling API

## Objective

Implemented event-driven trigger callbacks on Task and Message models (BEAT-02) and the agent events polling API for process/bash agents. After_commit callbacks detect task assignment and @mention conditions and wake the relevant agent via WakeAgentService. Process/bash agents poll queued events via a Bearer-authenticated JSON API endpoint.

## Tasks Completed

### Task 1: Triggerable concern with after_commit callbacks

**Triggerable concern** (`app/models/concerns/triggerable.rb`):
- `trigger_agent_wake(agent:, trigger_type:, trigger_source:, context: {})` — central dispatch helper that guards against terminated agents before calling WakeAgentService
- `detect_mentions(text, company)` — case-insensitive @mention detection scoped to agents in the same company using direct string matching (handles multi-word agent names like "API Bot")

**Task model updated** (`app/models/task.rb`):
- `include Triggerable` added
- `after_commit :trigger_assignment_wake, on: [:create, :update], if: :agent_just_assigned?`
- `agent_just_assigned?` uses `previously_new_record?` for create vs `saved_change_to_assignee_id?` for updates
- Only fires when `assignee_id.present?` — unassignment does not trigger

**Message model updated** (`app/models/message.rb`):
- `include Triggerable` added
- `after_commit :trigger_mention_wake, on: :create`
- `trigger_mention_wake` detects @mentions in body, wakes each mentioned agent with message context (message_id, task_id, mentioned_by)

**Deviation (Rule 3 — auto-fix blocking issue):** The pre-existing commit `c92453d` (07-03 partial work) updated `agents/show.html.erb` to reference `agent_heartbeats_path(@agent)` but the route wasn't yet added. This caused 2 test failures. Added `resources :heartbeats, only: [:index]` nested under agents and the `agents_controller_test` heartbeat schedule tests to unblock the suite.

**Test coverage:** 16 tests in `test/models/concerns/triggerable_test.rb`:
- 8 TriggerableTaskTest: create with/without assignee, update to assign, reassign, no-op update, unassign, terminated agent skip, context payload
- 8 TriggerableMentionTest: mention triggers wake, no mention, multi-mention, case-insensitive, non-existent agent, cross-company isolation, terminated agent skip, context payload

### Task 2: Agent events polling API

**AgentEventsController** (`app/controllers/api/agent_events_controller.rb`):
- Extends `ApplicationController`, includes `AgentApiAuthenticatable` (reuses Bearer token auth pattern)
- `GET /api/agent/events` — returns all queued events for authenticated agent in chronological order with serialized payload (id, trigger_type, trigger_source, request_payload, created_at ISO8601)
- `POST /api/agent/events/:id/acknowledge` — marks event as delivered; uses `find_by` scoped to the authenticated agent's queued events (prevents cross-agent access and re-acknowledgment)

**Routes** (`config/routes.rb`):
```
GET  /api/agent/events                  -> Api::AgentEventsController#index
POST /api/agent/events/:id/acknowledge  -> Api::AgentEventsController#acknowledge
```

**Test coverage:** 10 tests in `test/controllers/api/agent_events_controller_test.rb`:
- 2 auth tests: unauthorized without token, unauthorized with invalid token
- 4 index tests: queued events returned, delivered events excluded, chronological order, payload structure
- 4 acknowledge tests: success marks delivered, cross-agent blocked (404), delivered event blocked (404), non-existent event (404)

Note: Task 2 files were committed as part of the concurrent 07-03 docs commit (3c7dd52) since 07-03 executed in parallel and picked up the same work.

## Key Patterns Used

- **after_commit callbacks (not after_save)** — avoids firing on transaction rollback; same pattern as Auditable concern
- **`previously_new_record?`** — distinguishes create vs update in a single `after_commit :method, on: [:create, :update]` callback
- **`saved_change_to_assignee_id?`** — Rails 5.1+ saved change tracking (not pre-save `*_changed?`)
- **Direct string matching for @mentions** — `downcased.include?("@#{agent.name.downcase}")` handles multi-word names like "API Bot" cleanly
- **Bearer token auth via AgentApiAuthenticatable** — reuses existing concern pattern from MessagesController/TaskDelegationsController
- **Scoped find_by for acknowledge** — `@current_agent.heartbeat_events.queued.find_by(id:)` prevents cross-agent access without explicit error, just 404

## Test Counts

| File | Tests |
|------|-------|
| test/models/concerns/triggerable_test.rb | 16 |
| test/controllers/api/agent_events_controller_test.rb | 10 |
| **Total added** | **26** |

Full suite: 455 tests, 1167 assertions, 0 failures, 0 errors, 0 skips.

## Files Created

- `app/models/concerns/triggerable.rb`
- `test/models/concerns/triggerable_test.rb`
- `app/controllers/api/agent_events_controller.rb`
- `test/controllers/api/agent_events_controller_test.rb`

## Files Modified

- `app/models/task.rb` — include Triggerable, after_commit callback, agent_just_assigned?, trigger_assignment_wake
- `app/models/message.rb` — include Triggerable, after_commit callback, trigger_mention_wake
- `config/routes.rb` — added agent heartbeats nested route (unblocking fix) + API namespace routes

## Self-Check: PASSED
