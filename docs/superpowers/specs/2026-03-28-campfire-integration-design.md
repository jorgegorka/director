# Campfire Integration Design

Two-way communication channel between Director (AI agent orchestration) and Campfire (real-time chat by 37signals). Campfire is the human-facing chat room; Director broadcasts agent activity and receives natural language instructions.

## Approach

Optional external integration — Director works standalone, users who run Campfire get a real-time communication channel. Follows the Fizzy integration pattern: background jobs for outbound, webhook controller for inbound, rides on existing infrastructure (audit events, wake service, Solid Queue).

Key difference from Fizzy: Fizzy syncs *data* (tasks/cards), Campfire syncs *messages* (activity broadcasts + human commands). No resource-to-resource mapping needed.

## Conceptual Mapping

| Campfire | Director |
|----------|----------|
| Room | Company (1:1) |
| Bot | Director instance |
| Bot message (outbound) | Activity event broadcast |
| @mention message (inbound) | Natural language instruction |
| Webhook | Inbound message trigger |

## Data Model

### CampfireConnection

Stores the link between a Director company and a Campfire room.

| Column | Type | Purpose |
|--------|------|---------|
| `company_id` | integer, FK | Owner company |
| `campfire_url` | string | Base URL of the Campfire instance |
| `bot_key` | string, encrypted | Bot key from Campfire (`{user_id}-{token}`) |
| `room_id` | string | Campfire room ID to post in |
| `webhook_secret` | string | Secret for verifying inbound webhooks |
| `active` | boolean | Toggle on/off |
| `event_filters` | json | Which event types to broadcast |
| `timestamps` | | |

Belongs to `Company` via `Tenantable`. Encrypted `bot_key` via Rails encrypted attributes. Auto-generated `webhook_secret` via `SecureRandom.hex(32)`. Unique constraint: one connection per company.

`event_filters` example (defaults to all `true`):

```json
{
  "agent_status": true,
  "task_lifecycle": true,
  "agent_output": true,
  "governance": true
}
```

No sync mapping table needed — unlike Fizzy, there's no resource-to-resource mapping, just message flow. No columns added to existing models.

## Outbound Flow (Director → Campfire)

### Trigger

Hooks into the existing `AuditEvent` system. Every significant action already creates an audit event — no need to touch individual models.

1. `AuditEvent` is created (already happens today)
2. `after_commit` on `AuditEvent` checks: does this company have an active `CampfireConnection`?
3. If yes, check `event_filters` — does this event type pass the filter?
4. If yes, enqueue `CampfireBroadcastJob`

### Event Type Mapping

| AuditEvent action | Event filter key | Example Campfire message |
|---|---|---|
| `agent.started`, `agent.paused`, `agent.terminated` | `agent_status` | "**Researcher** started running" |
| `task.assigned`, `task.completed`, `task.created` | `task_lifecycle` | "Task **Analyze Q1 data** assigned to **Analyst**" |
| `message.created` (by agent) | `agent_output` | "**Researcher** posted on **Analyze Q1 data**: _Found 3 anomalies in..._" |
| `approval_gate.triggered`, `budget.alert` | `governance` | "**Approval needed:** Agent **Deployer** wants to execute deploy script" |

### CampfireBroadcastJob

1. Builds an HTML message from the audit event via `CampfireMessageFormatter`
2. POSTs to `{campfire_url}/rooms/{room_id}/{bot_key}/messages` with the HTML body
3. Retries 3 times with exponential backoff on failure

### Digest Batching

When a burst of audit events fire (e.g., emergency stop terminates 10 agents), batch them into a single summary message instead of 10 individual posts. Mechanism: `CampfireBroadcastJob` writes audit event IDs to a `campfire_digest:{company_id}` cache key (a list) with a 2-second TTL. When the job executes, it reads the list — if multiple IDs are present, it formats them as a single digest message. If only one ID, it formats normally. This means the first event in a burst waits up to 2 seconds before posting, allowing subsequent events to join the digest.

### CampfireClient

Plain Ruby `Net::HTTP` wrapper, same pattern as `FizzyClient`. Two methods:

- `post_message(body)` — sends text/HTML to the configured room
- `post_attachment(file)` — sends a file (future use)

No gem dependencies.

## Inbound Flow (Campfire → Director)

### Webhook Endpoint

`CampfireWebhooksController` at `POST /webhooks/campfire`

Campfire fires a webhook when someone @mentions the Director bot in a room.

### Payload Format

```json
{
  "user":    { "id": 1, "name": "Jorge" },
  "room":    { "id": 5, "name": "General", "path": "/rooms/5/42-abc123/messages" },
  "message": { "id": 99, "body": { "html": "<p>have the researcher look into Q1 trends</p>", "plain": "have the researcher look into Q1 trends" }, "path": "/rooms/5/@99" }
}
```

### Authentication

Campfire's webhook doesn't include a signature header. Director generates a `webhook_secret` during setup and appends it as a query param to the webhook URL registered in Campfire: `{director_url}/webhooks/campfire?token={secret}`. Controller verifies the token against stored `webhook_secret`. Acceptable because this is server-to-server over HTTPS.

### Flow

1. Controller receives webhook POST
2. Verifies token query param against stored `webhook_secret`
3. Identifies the `CampfireConnection` by matching `room_id` from the payload
4. Returns a synchronous acknowledgment as the HTTP response body (text/plain), e.g., "Got it — routing to Researcher"
5. Enqueues `CampfireInboundJob` with the payload

### CampfireInboundJob Processing

1. Parse the natural language message via `CampfireIntentParser`
2. Based on intent, take action:

| Parsed Intent | Director Action |
|---|---|
| Route message to agent | Create `Message` on the agent's active task (or latest task), wake agent via `WakeAgentService` |
| Create new task | Create `Task`, assign to identified agent, wake agent |
| Status query | Enqueue `CampfireBroadcastJob` with a status summary reply |
| Pause/resume agent | Call existing agent control actions, audit event triggers broadcast |
| Unrecognized | Post a reply: "I didn't understand that. Try: 'have Researcher look into X' or 'pause Analyst'" |

3. Log an `AuditEvent` for the inbound action

## Natural Language Intent Parsing

### Approach

Pattern matching first, no LLM dependency. A `CampfireIntentParser` service uses regex patterns to extract structured intents. Covers the 80% case without external dependencies. The parser interface supports adding LLM-based parsing for the `:unknown` fallback in a future phase.

### Pattern Grammar

| Pattern | Intent | Example |
|---|---|---|
| `{agent_name} + action phrase` | `:route_to_agent` | "have **Researcher** look into Q1 trends" |
| `assign {description} to {agent_name}` | `:create_task` | "assign 'Q1 analysis' to **Analyst**" |
| `pause {agent_name}` | `:pause` | "pause **Deployer**" |
| `resume {agent_name}` | `:resume` | "resume **Deployer**" |
| `status` / `status {agent_name}` | `:status` | "status" or "status **Researcher**" |
| No recognized pattern | `:unknown` | Post help message with examples |

### Agent Name Matching

1. Fetch all agent names for the company
2. Case-insensitive substring match against the message (same approach as Director's existing `Triggerable` concern)
3. If multiple agents match, pick the longest name match (avoids "Art" matching inside "Arthur")
4. If no agent matches but intent is clear, reply listing available agents

### Return Value

```ruby
CampfireIntent = Data.define(:action, :agent_name, :body, :confidence)
# action: :route_to_agent, :create_task, :pause, :resume, :status, :unknown
```

## Configuration & Setup

### Admin Setup Flow

**Step 1 — Campfire side (manual, guided by Director UI):**

1. Admin goes to their Campfire instance → `/account/bots`
2. Creates a bot named "Director" (with avatar)
3. Sets the webhook URL to `{director_url}/webhooks/campfire?token={generated_secret}` (Director generates and displays this URL)
4. Copies the bot key

**Step 2 — Director side:**

1. Admin navigates to Company Settings → Integrations → Campfire
2. Enters Campfire instance URL, bot key, and room ID
3. Director verifies the connection by posting a test message: "Director connected successfully"
4. Admin configures event filters (checkboxes, all enabled by default)
5. Connection saved and active

### Controller

`CampfireConnectionsController` nested under company settings. Standard CRUD — `new`, `create`, `edit`, `update`, `destroy`. Plus a `test` action that posts a test message.

### UI

Standard Turbo form submissions with progressive disclosure. Connection form first, then event filter checkboxes after verification succeeds. A help panel with step-by-step Campfire bot setup instructions. No new Stimulus controllers needed.

### Validation

- `campfire_url` — valid URL format, HTTPS
- `bot_key` — present, matches format `{integer}-{token}`
- `room_id` — present
- `webhook_secret` — auto-generated on create
- Unique constraint: one connection per company

## Error Handling & Resilience

### Outbound Failures (Director → Campfire)

- `CampfireBroadcastJob` retries 3 times with exponential backoff (standard Active Job)
- After final failure: log `AuditEvent`. Director state is correct; Campfire missed a message.
- 401/403 response (bad bot key): mark `CampfireConnection` as `active: false`, create `Notification` for admin
- Connection errors (DNS, timeout, refused): same retry/log pattern

### Inbound Failures (Campfire → Director)

- Invalid webhook token: return `401`, log `AuditEvent`
- Unknown room (no matching connection): return `404`
- Intent parsing failure: synchronous reply "I didn't understand that" with examples, log `AuditEvent`
- Agent not found: synchronous reply listing available agents, log `AuditEvent`
- Processing failure in `CampfireInboundJob`: log `AuditEvent`, post follow-up error message to Campfire

### Connection Health

No active polling or health checks. Failures diagnosed via `AuditEvent` trail. Admin can hit the `test` action anytime to verify.

### Rate Limiting

Campfire has no built-in rate limiting. Director throttles outbound via digest batching — burst events within 2 seconds are merged into a single summary message per company.

## Testing Strategy

### Unit Tests

- `CampfireConnection` — validations (URL format, bot key format, presence), encryption of bot_key, active scope, Tenantable, event_filters defaults, webhook_secret auto-generation
- `CampfireClient` — stubbed HTTP responses for `post_message` and `post_attachment`, error classification (401, timeout, connection refused)
- `CampfireIntentParser` — each pattern returns correct intent struct, agent name matching (exact, substring, case-insensitive, no match, multiple match picks longest), unknown input returns `:unknown`
- `CampfireMessageFormatter` — each audit event type produces correct HTML output, digest batching for burst events

### Controller Tests

- `CampfireWebhooksController` — valid token accepted, invalid token rejected (401), unknown room (404), payload enqueues job, synchronous acknowledgment returned in response body
- `CampfireConnectionsController` — CRUD, test action posts message, validation errors rendered, only admins can access

### Job Tests

- `CampfireBroadcastJob` — posts formatted message, retries on failure, deactivates connection on 401, digest merging on burst, skips when connection inactive
- `CampfireInboundJob` — each intent type triggers correct Director action (route to agent, create task, pause, resume, status query), unknown intent posts help reply, agent not found posts available agents, audit events logged

### Fixtures

- `campfire_connections.yml` — one active, one inactive

All Minitest + fixtures. No system tests.

## Campfire Bot API Reference

**Bot creation:** Admin UI at `/account/bots`. Each bot gets a key in format `{user_id}-{bot_token}`.

**Sending messages (Director → Campfire):**
```
POST /rooms/{room_id}/{bot_key}/messages
Content-Type: text/html

<p><strong>Researcher</strong> started running</p>
```
Returns `201 Created` with `Location` header.

**Receiving webhooks (Campfire → Director):**

Campfire POSTs JSON to the bot's configured webhook URL when the bot is @mentioned:

```json
{
  "user":    { "id": 1, "name": "Jorge" },
  "room":    { "id": 5, "name": "General", "path": "/rooms/5/42-abc123/messages" },
  "message": { "id": 99, "body": { "html": "...", "plain": "..." }, "path": "/rooms/5/@99" }
}
```

- In direct messages: bot receives all messages
- In group rooms: bot receives only messages where it is @mentioned
- `message.body.plain` strips the bot @mention (clean input)
- `room.path` is the bot's reply URL

**Synchronous reply:** Return HTTP 200 with `Content-Type: text/html` or `text/plain` body — Campfire posts it as a reply automatically. 7-second timeout.

**File attachments:** Send as multipart form data via `params[:attachment]`. Webhook responses with non-text content types are posted as file attachments.
