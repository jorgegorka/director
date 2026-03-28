# Phase 8: Budget & Cost Control — Context

## Decisions (LOCKED)

### Cost Tracking: Task-Based Only
Drop the "session" concept from BUDG-03. Track cost per task only — no session boundaries to define. Each task records its cost. Agent-level spend is the sum of task costs within the budget period.

### Budget Exhaustion: Pause Agent Immediately
When an agent's monthly spend hits the budget limit, the system atomically pauses the agent (status → paused). In-flight tasks remain assigned but the agent cannot act on them until the budget is replenished or increased. This is the hard stop — no grace period, no "finish current task."

### Alerts: Notification Model
Create a new Notification model to store budget alerts in the database. Display as a bell icon with badge count + dropdown in the app header. This model will be reusable in Phase 9 for governance alerts. Threshold alert fires at 80% of budget consumed.

## Claude's Discretion

- Schema design for budget columns (on Agent? separate BudgetPeriod model?)
- Cost recording mechanism (how agents report costs via API)
- Notification UI placement and styling details
- Whether budget period is strictly calendar month or rolling 30 days

## Deferred Ideas

- Session-based cost tracking (explicitly dropped)
- Email notifications for budget alerts (in-app only for now)
