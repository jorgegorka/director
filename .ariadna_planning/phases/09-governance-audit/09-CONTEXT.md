# Phase 9: Governance & Audit — Context

## Decisions

### Approval Gates (GOVR-01)
**Decision:** Action-type gates — system defines gatable action types (e.g., task creation, budget spend, delegation, status changes), user toggles which ones apply per agent.
- Agent hits a gated action → pauses with `pending_approval` status → user approves/rejects → agent continues or stays paused
- Gate configuration is per-agent (which action types require approval)
- Action types are predefined by the system, not custom user strings

### Kill Switches (GOVR-02)
**Decision:** Emergency stop only — add a company-level "emergency stop all agents" button. Individual pause/resume/terminate stays on the agent show page (already built in Phase 4).
- No need to duplicate agent controls on task views or org chart
- Emergency stop = bulk pause all active agents in the company

### Audit Log (GOVR-03)
**Decision:** Expand AuditEvent + build UI — extend existing AuditEvent model to cover governance actions (gate approvals/rejections, emergency stops, config changes) and build a company-wide audit log page with filters by actor, action type, and date range.
- Builds on Phase 5's Auditable concern and AuditEvent model
- New event types for governance actions, not a separate logging system

### Configuration Versioning (GOVR-04)
**Decision:** Lightweight custom versioning — ConfigVersion model tracking JSON snapshots of key configuration changes (role edits, budget changes, gate modifications). No external gem.
- Simple rollback: restore previous snapshot
- Scoped to governance-relevant configs, not all model changes

## Claude's Discretion

- Database schema design for ApprovalGate and ConfigVersion models
- Which specific action types to predefine as gatable
- UI layout for audit log page and filters
- How rollback confirmation works (preview diff, one-click restore)

## Deferred Ideas

- Per-action custom gate rules (e.g., "approve if cost > $50") — too complex for v1
- Agent controls on every page — emergency stop covers the safety need
- Paper Trail gem — lightweight custom versioning is sufficient
- Full expansion audit (login, page views, API calls) — governance actions only
