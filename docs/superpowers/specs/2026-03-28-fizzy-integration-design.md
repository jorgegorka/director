# Fizzy Integration Design

Two-way sync between Director (AI agent orchestration) and Fizzy (Kanban board by 37signals). Fizzy is the human-facing project board; Director is the AI execution engine.

## Approach

Hybrid of existing Director patterns:

- **Inbound (Fizzy -> Director):** Webhook endpoint receives Fizzy events, creates/updates tasks, wakes agents via `WakeAgentService`
- **Outbound (Director -> Fizzy):** `after_commit` callbacks on Task trigger `FizzyOutboundSyncJob`, which calls Fizzy's REST API via `FizzyClient`

No new namespace or parallel infrastructure. Sync rides on existing patterns (wake service, background jobs, audit events).

## Conceptual Mapping

| Fizzy | Director |
|-------|----------|
| Board | Goal |
| Card | Task |
| Card assignee (by name) | Agent |
| Card comment | Message |
| Card step | Subtask / step |
| Column | Task status (via configurable mapping) |

## Ownership Split

Each field is writable from one side only. No conflict resolution needed.

**Fizzy owns (humans decide):**

- Card creation (new work)
- Column/triage placement (priority, workflow stage)
- Assignments (which agent works on it)
- Tags
- Closing/reopening cards (human accepts work as done)

**Director owns (agents report):**

- Task status updates (in_progress, blocked)
- Progress comments (agent reporting what it did)
- Cost/budget consumption
- Steps completion
- Subtask creation (agent-spawned work appears as new cards in Fizzy)

## Data Model

### FizzyConnection

Stores the link between a Director company and a Fizzy account.

| Column | Type | Purpose |
|--------|------|---------|
| `company_id` | integer, FK | Owner company |
| `fizzy_url` | string | Base URL of the Fizzy instance |
| `fizzy_account_slug` | string | Account slug for API paths |
| `api_token` | string, encrypted | Personal access token (Read+Write) |
| `webhook_secret` | string | Secret for verifying inbound webhook signatures |
| `active` | boolean | Toggle sync on/off |
| `status_column_map` | json | Maps Director task statuses to Fizzy column IDs |
| `timestamps` | | |

Belongs to `Company` via `Tenantable`. Encrypted `api_token` via Rails encrypted attributes.

`status_column_map` example:

```json
{
  "in_progress": "03f5v9zkft4hj...",
  "blocked": "03f8abc123..."
}
```

### FizzySyncMapping

Tracks which Fizzy resource maps to which Director resource.

| Column | Type | Purpose |
|--------|------|---------|
| `fizzy_connection_id` | integer, FK | Parent connection |
| `syncable_type` | string | Polymorphic: `Goal` or `Task` |
| `syncable_id` | integer | Director record ID |
| `fizzy_resource_type` | string | `board` or `card` |
| `fizzy_resource_id` | string | Fizzy's ID (string format like `03f5v9zkft...`) |
| `last_synced_at` | datetime | Echo loop prevention |
| `timestamps` | | |

Belongs to `FizzyConnection`. Polymorphic to `Goal` or `Task`. Unique index on `[fizzy_connection_id, fizzy_resource_type, fizzy_resource_id]`.

No columns added to existing models.

## Inbound Flow (Fizzy -> Director)

### Webhook Endpoint

`FizzyWebhooksController` at `POST /webhooks/fizzy` (unauthenticated -- outside session scope, called by Fizzy's server):

1. Identifies the connection by matching the board ID from the payload to a FizzySyncMapping
2. Verifies `X-Webhook-Signature` HMAC-SHA256 against that connection's `webhook_secret`
2. Returns `200 OK` immediately (Fizzy times out after 7 seconds)
3. Enqueues `FizzyInboundSyncJob` with raw payload

### Event Processing

`FizzyInboundSyncJob` handles each event type:

| Fizzy Event | Director Action |
|-------------|-----------------|
| `card_published` | Create Task under mapped Goal, create FizzySyncMapping |
| `card_assigned` | Find Director agent by name (case-insensitive), assign to task, wake via `WakeAgentService` |
| `card_unassigned` | Unassign agent from task |
| `card_triaged` | Update task metadata (column context) |
| `card_closed` | Mark task as `completed` |
| `card_reopened` | Mark task as `open` |
| `comment_created` | Create Message on the task |

### Echo Prevention

After processing, the job updates `last_synced_at` on the mapping. Outbound callbacks check this timestamp -- if synced within the last 5 seconds, skip outbound push.

### Agent Name Matching

On `card_assigned`, the job looks up the Fizzy user name from the payload and finds a Director agent with matching `name` (case-insensitive). If no match found, task stays unassigned and an `AuditEvent` is logged.

## Outbound Flow (Director -> Fizzy)

### Trigger

`after_commit` callbacks on `Task` detect changes to agent-owned fields. Two conditions before firing:

1. A `FizzySyncMapping` exists for this task
2. `last_synced_at` is older than 5 seconds (echo prevention)

If both pass, enqueue `FizzyOutboundSyncJob`.

### API Calls

`FizzyOutboundSyncJob` calls Fizzy via `FizzyClient`:

| Director Event | Fizzy API Call |
|----------------|----------------|
| Task status -> `in_progress` | `POST /cards/:number/triage` (move to configured column) |
| Task status -> `completed` | `POST /cards/:number/closure` |
| Task status -> `blocked` | `POST /cards/:number/comments` (comment noting blocker) |
| Task status -> `open` (reopened) | `DELETE /cards/:number/closure` |
| Message created by agent | `POST /cards/:number/comments` |
| Agent creates subtask | `POST /boards/:board_id/cards` + new FizzySyncMapping |
| Step completed | `PUT /cards/:number/steps/:id` |

### FizzyClient

Plain Ruby service wrapping `Net::HTTP`. Handles:

- Bearer token auth via `Authorization` header
- JSON serialization/deserialization
- ETag caching support
- Error classification (auth failure vs transient vs validation)

No gem dependencies.

## Configuration & Setup

### Admin Setup Flow

1. Admin navigates to Company Settings -> Integrations -> Fizzy
2. Enters Fizzy instance URL and API token
3. Director calls `GET /my/identity` to verify credentials and fetch account slug
4. Fetches boards via `GET /:slug/boards` and columns via `GET /:slug/boards/:id/columns`
5. Admin maps each board to a Director goal (dropdown)
6. Admin maps Director task statuses to Fizzy columns
7. Director registers webhooks on each mapped board via `POST /:slug/boards/:board_id/webhooks`, subscribing to: `card_published`, `card_assigned`, `card_unassigned`, `card_triaged`, `card_closed`, `card_reopened`, `comment_created`
8. Stores returned `signing_secret` as `webhook_secret`

### Initial Sync

After setup, Director imports existing cards on mapped boards:

- For each card, create a Task and FizzySyncMapping
- Attempt agent name matching for assigned cards
- Wake matched agents via `WakeAgentService`

### UI

Standard Turbo form submissions. Progressive disclosure: connection form first, then board/column mapping after verification succeeds. No new Stimulus controllers needed.

## Error Handling & Resilience

### Inbound Failures

- Invalid signature: return `401`, log `AuditEvent`, don't process
- Processing failure (mapping not found, agent name mismatch): log `AuditEvent` with details, don't raise -- webhook was legitimate
- Extended downtime: Fizzy auto-deactivates webhooks via its `DelinquencyTracker`. Admin must reactivate in Fizzy after recovery.

### Outbound Failures

- `FizzyOutboundSyncJob` retries 3 times with exponential backoff (standard Active Job)
- After final failure: log `AuditEvent`. Director state is correct; Fizzy is stale.
- Auth failure (401 response): mark `FizzyConnection` as `active: false`, create Notification for admin

### Connection Health

No active polling or health checks. Failures are diagnosed via `AuditEvent` trail and Fizzy's own webhook delivery logs.

## Testing Strategy

### Unit Tests

- `FizzyConnection` -- validations (URL format, token presence), encryption, active scope, Tenantable
- `FizzySyncMapping` -- polymorphic association, uniqueness constraints, echo check logic
- `FizzyClient` -- stubbed HTTP responses for each API method, auth header, error handling (401, 422, timeout)

### Controller Tests

- `FizzyWebhooksController` -- valid signature accepted, invalid rejected (401), payload enqueues job, returns 200 before processing
- Admin setup controller -- CRUD for connections, board fetching, mapping persistence

### Job Tests

- `FizzyInboundSyncJob` -- each event type creates/updates correct Director record, echo prevention, agent name matching (hit/miss), audit events on failure
- `FizzyOutboundSyncJob` -- each status change calls correct API endpoint, echo prevention, retry on failure, connection deactivation on 401

### Fixtures

- `fizzy_connections.yml` -- one active, one inactive
- `fizzy_sync_mappings.yml` -- board-to-goal and card-to-task mappings

All Minitest + fixtures. No system tests.

## Fizzy API Reference (Key Endpoints Used)

**Auth:** Bearer token via `Authorization: Bearer <token>` header.

**Inbound webhooks from Fizzy:**
- JSON payload with `X-Webhook-Signature` (HMAC-SHA256) and `X-Webhook-Timestamp` headers
- Actions: `card_published`, `card_assigned`, `card_unassigned`, `card_triaged`, `card_closed`, `card_reopened`, `comment_created`

**Outbound API calls from Director:**
- `GET /my/identity` -- verify credentials
- `GET /:slug/boards` -- list boards
- `GET /:slug/boards/:id/columns` -- list columns
- `POST /:slug/boards/:board_id/cards` -- create card
- `PUT /:slug/cards/:number` -- update card
- `POST /:slug/cards/:number/closure` -- close card
- `DELETE /:slug/cards/:number/closure` -- reopen card
- `POST /:slug/cards/:number/triage` -- move to column
- `POST /:slug/cards/:number/comments` -- add comment
- `PUT /:slug/cards/:number/steps/:id` -- update step
- `POST /:slug/cards/:number/assignments` -- toggle assignment
- `POST /:slug/boards/:board_id/webhooks` -- register webhook
