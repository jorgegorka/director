# Phase 5: Tasks & Conversations — Context

## Decisions (LOCKED)

### 1. Conversation Model: Nested Replies
Messages can reply to specific parent messages, forming sub-threads within a task. Each message has an optional `parent_id` for threading. UI renders indented reply chains.

### 2. Delegation: Both Human and Agent
- Users delegate/escalate via UI buttons on the task page
- Agents delegate/escalate via API endpoints (POST /tasks/:id/delegate, POST /tasks/:id/escalate)
- Delegation goes down the org chart (to subordinates), escalation goes up (to manager)
- Both actions recorded in audit trail

### 3. Audit Trail: Separate AuditEvent Model
Polymorphic `AuditEvent` model reusable across phases:
- `auditable`: polymorphic (Task, Agent, etc.)
- `actor`: polymorphic (User, Agent)
- `action`: string enum (created, assigned, delegated, escalated, status_changed, etc.)
- `metadata`: jsonb (before/after state, reason, etc.)
- `created_at`: immutable timestamp

This model will extend to Phase 9 (Governance & Audit) without refactoring.

## Claude's Discretion

- Task status workflow (which statuses, allowed transitions)
- Task priority levels (if any)
- Message content format (plain text vs. markdown)
- UI layout for task list and detail views
- How to display nested conversation threads in the UI

## Deferred Ideas

- None identified
