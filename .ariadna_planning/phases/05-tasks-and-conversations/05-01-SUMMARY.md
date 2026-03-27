---
phase: 05-tasks-and-conversations
plan: "01"
status: complete
completed_at: 2026-03-27T10:38:00Z
duration: ~9 minutes
tasks_completed: 2
files_changed: 24
---

# Plan 05-01 Summary: Data Layer - Task, Message, AuditEvent Models

## Objective

Establish the core data layer for Phase 5: Task (work unit), Message (threaded conversation), and AuditEvent (immutable audit trail) models with migrations, concerns, fixtures, and comprehensive tests. Also added `api_token` column to Agent for Plan 03's agent-initiated API authentication.

## What Was Built

### Migrations (5 total)

- `20260327102951_create_tasks.rb` - Tasks table with status/priority integer enums, company/creator/assignee/parent_task references, due_at/completed_at timestamps, composite indexes on (company_id, status) and (assignee_id, status)
- `20260327103010_create_messages.rb` - Messages table with polymorphic author, parent threading (self-referential FK), and (task_id, created_at) composite index
- `20260327103011_create_audit_events.rb` - AuditEvents table with polymorphic auditable/actor, action string, metadata jsonb, immutable (only created_at, no updated_at), composite index on (auditable_type, auditable_id, created_at)
- `20260327103012_add_api_token_to_agents.rb` - api_token column on agents with unique index
- `20260327103456_make_task_creator_nullable.rb` - Makes creator_id nullable to support `dependent: :nullify` on User.created_tasks

### New Models

**`app/models/task.rb`**
- Includes `Tenantable` (belongs_to :company, for_current_company scope) and `Auditable` (has_many :audit_events, record_audit_event!)
- Status enum: open(0), in_progress(1), blocked(2), completed(3), cancelled(4)
- Priority enum: low(0), medium(1), high(2), urgent(3)
- Cross-company validation for assignee and parent_task
- `before_save :set_completed_at` callback - sets/clears completed_at on status change
- Scopes: `active`, `by_priority`, `roots`

**`app/models/message.rb`**
- Polymorphic `author` (User or Agent)
- Self-referential `parent` / `replies` for nested threading
- Same-task validation on parent
- Scopes: `roots`, `chronological`

**`app/models/audit_event.rb`**
- Polymorphic `auditable` and `actor`
- `readonly?` returns true for persisted records (immutability)
- metadata stored as jsonb
- Scopes: `chronological`, `reverse_chronological`, `for_action`

### New Concern

**`app/models/concerns/auditable.rb`**
- `has_many :audit_events, as: :auditable, dependent: :delete_all`
- `record_audit_event!(actor:, action:, metadata: {})` helper
- Uses `delete_all` (not `destroy`) to bypass readonly? when cascade-deleting audit trail

### Updated Models

- **Company**: added `has_many :tasks, dependent: :destroy`
- **Agent**: added `has_many :assigned_tasks`, `before_create :generate_api_token`, `regenerate_api_token!`, `self.generate_unique_api_token` (loop with uniqueness check)
- **User**: added `has_many :created_tasks, dependent: :nullify`

### Fixtures

- `tasks.yml` - 6 tasks: design_homepage (in_progress/high), fix_login_bug (open/urgent), write_tests (open/medium/unassigned), completed_task (completed/medium), subtask_one (subtask of design_homepage), widgets_task (cross-company isolation)
- `messages.yml` - 5 messages: first_update (User), agent_reply (Agent), threaded_reply (reply to agent_reply), bug_report_msg (different task), widgets_msg (cross-company)
- `audit_events.yml` - 3 events: task_created, task_assigned, task_status_changed (with metadata)
- `agents.yml` - Updated all 4 agents with deterministic api_token values

### Tests

- `test/models/task_test.rb` - 37 tests: validations, all enum values, associations, scoping (for_current_company, active, by_priority, roots), callbacks, audit integration, deletion cascading
- `test/models/message_test.rb` - 18 tests: validations, polymorphic author (User+Agent), parent threading, scopes, nested reply chains
- `test/models/audit_event_test.rb` - 14 tests: validations, polymorphic associations, readonly? immutability, scopes, metadata handling
- `test/models/agent_test.rb` - Added 3 tests: api_token generated on create, uniqueness, regenerate_api_token!

## Deviations from Plan

### Rule 1: Auto-fix - duplicate index in CreateTasks migration
`t.references :parent_task` auto-creates an index on `parent_task_id`. Explicit `add_index :tasks, :parent_task_id` caused a duplicate. Removed the redundant explicit index.

### Rule 1: Auto-fix - duplicate index in CreateAuditEvents migration
`t.references :actor, polymorphic: true` auto-creates `index_audit_events_on_actor_type_and_actor_id`. The plan's explicit `add_index [:actor_type, :actor_id], name: "index_audit_events_on_actor"` collided. Removed the explicit actor index (the auto-created one serves the same purpose).

### Rule 1: Auto-fix - Auditable concern uses delete_all not destroy
`dependent: :destroy` on `has_many :audit_events` caused `ActiveRecord::ReadOnlyRecord` when deleting tasks/companies. Since AuditEvents are immutable, `dependent: :delete_all` bypasses ActiveRecord callbacks and directly issues a SQL DELETE. This is the correct approach for immutable records in cascade scenarios.

### Rule 1: Auto-fix - creator_id must be nullable for dependent: nullify
The plan specified both `null: false` on `creator_id` in the migration AND `dependent: :nullify` on `User.has_many :created_tasks`. These are contradictory. Added a separate `MakeTaskCreatorNullable` migration and made `belongs_to :creator` optional to support user deletion without cascading task deletion. This matches the intent ("destroying user nullifies creator_id" in the plan's done criteria).

## Verification Results

```
bin/rails db:migrate:status   -- all 13 migrations up
Task columns:                 -- assignee_id, company_id, completed_at, creator_id, description, due_at, parent_task_id, priority, status, title (confirmed)
Message columns:              -- author_id, author_type, body, parent_id, task_id (confirmed)
AuditEvent columns:           -- action, actor_id, actor_type, auditable_id, auditable_type, created_at, metadata (no updated_at, confirmed)
Agent api_token:              -- column exists (true)
Task audit_events association: -- has_many (confirmed)
Test suite:                   -- 265 tests, 642 assertions, 0 failures, 0 errors, 0 skips
Rubocop:                      -- 105 files inspected, no offenses detected
```

## Commits

- `fdfaa2a` - feat(05-01): Create Task, Message, AuditEvent models and add api_token to Agent
- `8dc6942` - test(05-01): Add fixtures and model tests for Task, Message, AuditEvent, and Agent api_token

## Self-Check: PASSED
