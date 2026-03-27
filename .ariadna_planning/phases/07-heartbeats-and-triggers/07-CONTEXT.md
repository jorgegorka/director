# Phase 7: Heartbeats & Triggers — Context

## Decisions

### Wake Mechanic: Adapter-aware delivery
HTTP agents receive a POST callback to their configured endpoint with trigger context (trigger type, task details, etc.). Bash agents get a queued event they poll for on next check-in. The adapter type determines the delivery mechanism.

### Scheduling: Solid Queue recurring jobs
Use Solid Queue's built-in recurring job support for heartbeat schedules. Store schedule configuration on the Agent model for per-agent flexibility, triggered via Solid Queue's recurring job infrastructure.

### Event Triggers: Model callbacks
Use after_commit callbacks on Task and Message models to detect trigger conditions (task assigned to agent, @mentioned in conversation) and enqueue wake jobs. Follows existing patterns like the Auditable concern.

## Claude's Discretion

- Heartbeat history model design (columns, retention)
- HeartbeatEvent/log structure
- @mention detection implementation in messages
- UI for configuring schedules and viewing heartbeat history
- How bash agents poll for queued events (API endpoint design)

## Deferred Ideas

None identified.
