# Agent Hooks System

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a configurable agent hook system that fires at task lifecycle events (before/after start, before/after complete). Hooks can trigger other agents, or call webhooks. The primary use case: when Agent A completes a task, Agent B validates the work and feeds results back so Agent A can iterate or finalize.

**Architecture:** Builds on existing patterns — `ApprovalGate` (per-agent config), `WakeAgentService` + `HeartbeatEvent` (agent triggering), `Auditable` (governance trail), `ConfigVersioned` (change tracking). New `Hookable` concern on Task detects status transitions and enqueues background jobs.

**Tech Stack:** Rails 8.1, SQLite, SolidQueue, Minitest + fixtures

```
Task status changes  ->  Hookable concern detects transition
                     ->  Finds matching AgentHooks for the assignee
                     ->  Enqueues ExecuteHookJob per hook
                     ->  ExecuteHookService dispatches by action_type:
                           - trigger_agent: creates validation subtask + wakes target agent
                           - webhook: POSTs payload to URL
                     ->  HookExecution records the result

Feedback loop (for trigger_agent):
  Validation subtask completes  ->  Hookable detects it has a parent_task
                                ->  Enqueues ProcessValidationResultJob
                                ->  Collects output, posts message on original task
                                ->  Wakes original agent with feedback context
```

---

### Task 1: Migrations

**Files:**
- Create: `db/migrate/YYYYMMDD01_create_agent_hooks.rb`
- Create: `db/migrate/YYYYMMDD02_create_hook_executions.rb`

- [ ] **Step 1: Create `agent_hooks` table**

  | Column | Type | Notes |
  |--------|------|-------|
  | `agent_id` | references | not null, FK |
  | `company_id` | references | not null, FK |
  | `lifecycle_event` | string | not null — validated against constant |
  | `action_type` | integer | not null, default 0 — enum (trigger_agent: 0, webhook: 1) |
  | `action_config` | json | not null, default {} — target_agent_id, url, prompt, headers |
  | `enabled` | boolean | not null, default true |
  | `position` | integer | not null, default 0 — execution ordering |
  | `name` | string | optional human label |
  | `conditions` | json | not null, default {} — future filtering |

  Indexes: `[agent_id, lifecycle_event]`, `[agent_id, enabled]`

- [ ] **Step 2: Create `hook_executions` table**

  | Column | Type | Notes |
  |--------|------|-------|
  | `agent_hook_id` | references | not null, FK |
  | `task_id` | references | not null, FK |
  | `company_id` | references | not null, FK |
  | `status` | integer | not null, default 0 — enum (queued: 0, running: 1, completed: 2, failed: 3) |
  | `input_payload` | json | not null, default {} |
  | `output_payload` | json | not null, default {} |
  | `error_message` | text | nullable |
  | `started_at` | datetime | nullable |
  | `completed_at` | datetime | nullable |

  Indexes: `[task_id, created_at]`, `[agent_hook_id, status]`

- [ ] **Step 3: Run migrations, verify schema**

---

### Task 2: AgentHook Model + Fixtures

**Files:**
- Create: `app/models/agent_hook.rb`
- Create: `test/fixtures/agent_hooks.yml`
- Create: `test/models/agent_hook_test.rb`

- [ ] **Step 1: Create AgentHook model**

  - `include Tenantable, Auditable, ConfigVersioned`
  - `belongs_to :agent`, `has_many :hook_executions, dependent: :destroy`
  - `enum :action_type, { trigger_agent: 0, webhook: 1 }`
  - `LIFECYCLE_EVENTS = %w[before_task_start after_task_start before_task_complete after_task_complete]`
  - Validates `lifecycle_event` inclusion in constant, `action_type` presence
  - Custom validation: `trigger_agent` requires `target_agent_id` in config, `webhook` requires `url`
  - Scopes: `enabled`, `for_event(event)`, `ordered` (by position, created_at)
  - `target_agent` convenience method
  - `governance_attributes` for ConfigVersioned
  - Pattern reference: follows `ApprovalGate` (`app/models/approval_gate.rb`) — string-validated type, belongs_to agent, enabled scope

- [ ] **Step 2: Create fixtures** (3 entries)

  - `claude_validation_hook`: agent=claude_agent, after_task_complete, trigger_agent targeting http_agent
  - `claude_webhook_hook`: agent=claude_agent, after_task_start, webhook with url
  - `disabled_hook`: agent=http_agent, after_task_complete, trigger_agent, enabled=false

- [ ] **Step 3: Write model tests**

  - Validations (lifecycle_event inclusion, action_config schema per action_type)
  - Enums (`trigger_agent?`, `webhook?`)
  - Associations (belongs_to agent, has_many hook_executions)
  - Scopes (enabled, for_event, ordered)
  - `target_agent` returns correct agent or nil
  - Destroying agent cascades to hooks

- [ ] **Step 4: Run tests, verify passing**

---

### Task 3: HookExecution Model + Fixtures

**Files:**
- Create: `app/models/hook_execution.rb`
- Create: `test/fixtures/hook_executions.yml`
- Create: `test/models/hook_execution_test.rb`

- [ ] **Step 1: Create HookExecution model**

  - `belongs_to :agent_hook`, `belongs_to :task`, `belongs_to :company`
  - `enum :status, { queued: 0, running: 1, completed: 2, failed: 3 }`
  - `mark_running!`, `mark_completed!(output:)`, `mark_failed!(error_message:)` — follows `HeartbeatEvent` pattern (`app/models/heartbeat_event.rb`)
  - `readonly?` returns true when completed or failed — follows `AuditEvent` pattern (`app/models/audit_event.rb`)
  - `duration_seconds` helper
  - Scopes: `chronological`, `recent`, `for_task`

- [ ] **Step 2: Create fixtures** (2 entries)

  - `completed_execution`: agent_hook=claude_validation_hook, task=completed_task, status=completed
  - `failed_execution`: agent_hook=claude_webhook_hook, task=design_homepage, status=failed, error_message set

- [ ] **Step 3: Write model tests**

  - Validations, enums, `mark_*` methods
  - `readonly?` for completed/failed records
  - `duration_seconds` calculation
  - Scopes

- [ ] **Step 4: Run tests, verify passing**

---

### Task 4: Update Existing Models

**Files:**
- Modify: `app/models/agent.rb` (line ~12, after approval_gates)
- Modify: `app/models/task.rb` (lines 1-4 for include, line ~12 for association)
- Modify: `app/models/heartbeat_event.rb` (line 4, extend enum)

- [ ] **Step 1: Add to Agent model**

  ```ruby
  has_many :agent_hooks, dependent: :destroy
  ```

- [ ] **Step 2: Add to Task model**

  ```ruby
  include Hookable
  has_many :hook_executions, dependent: :destroy
  ```

- [ ] **Step 3: Extend HeartbeatEvent trigger_type enum**

  ```ruby
  enum :trigger_type, { scheduled: 0, task_assigned: 1, mention: 2, hook_triggered: 3 }
  ```

  This gives hook-originated wake calls a distinct trigger type for filtering.

- [ ] **Step 4: Run full test suite to confirm no regressions**

---

### Task 5: Hookable Concern

**Files:**
- Create: `app/models/concerns/hookable.rb`
- Create: `test/models/concerns/hookable_test.rb`

- [ ] **Step 1: Create the Hookable concern**

  - `after_commit` on `[:create, :update]` — checks `saved_change_to_status?`
  - `in_progress` transition -> enqueues hooks for `after_task_start`
  - `completed` transition -> enqueues hooks for `after_task_complete`
  - If task has `parent_task` and just became completed -> enqueues `ProcessValidationResultJob` (closes feedback loop)
  - Finds hooks via `AgentHook.where(agent_id: assignee_id).for_event(event).enabled.ordered`
  - All hooks are async (background jobs via `ExecuteHookJob.perform_later`) — no blocking on Task save
  - Note: `before_*` and `after_*` are semantic labels for hook ordering (`position`), not synchronous vs async. Both run as background jobs to keep SQLite writes fast. Deliberate v1 simplification.
  - Reference: `app/models/concerns/triggerable.rb` for the existing concern pattern on Task

- [ ] **Step 2: Write concern tests**

  - Status -> in_progress enqueues after_task_start hooks
  - Status -> completed enqueues after_task_complete hooks
  - Disabled hooks not fired
  - Unassigned tasks don't fire hooks
  - Subtask completion with parent enqueues ProcessValidationResultJob
  - Non-status changes don't fire hooks

- [ ] **Step 3: Run tests, verify passing**

---

### Task 6: ExecuteHookService + Job

**Files:**
- Create: `app/services/execute_hook_service.rb`
- Create: `app/jobs/execute_hook_job.rb`
- Create: `test/services/execute_hook_service_test.rb`
- Create: `test/jobs/execute_hook_job_test.rb`

- [ ] **Step 1: Create ExecuteHookService**

  - `self.call(hook:, task:)` — follows `WakeAgentService` pattern (`app/services/wake_agent_service.rb`)
  - Creates `HookExecution` (queued -> running)
  - Dispatches by `action_type`:
    - **trigger_agent**: creates validation subtask (`Task.create!` with `parent_task: task`, `assignee: target_agent`), then calls `WakeAgentService.call(agent: target_agent, trigger_type: :hook_triggered, ...)` with context including `hook_id`, `original_task_id`, `action: "validate"`
    - **webhook**: POSTs JSON payload to configured URL via `Net::HTTP` (10s connect, 30s read timeout). Supports custom headers from `action_config["headers"]`.
  - Validation subtask uses `action_config["prompt"]` if present, otherwise default prompt referencing parent task title
  - Records result on `HookExecution` (`mark_completed!` or `mark_failed!`)
  - Creates audit event via `task.record_audit_event!(action: "hook_executed", ...)`
  - Top-level rescue marks execution as failed with error message

- [ ] **Step 2: Create ExecuteHookJob**

  - `queue_as :hooks`
  - `retry_on StandardError, wait: :polynomially_longer, attempts: 3`
  - `perform(agent_hook_id, task_id)` — finds records, calls `ExecuteHookService.call`
  - Guards: returns early if hook not found, disabled, or task not found

- [ ] **Step 3: Write service tests**

  - trigger_agent: creates subtask, wakes target, creates execution record
  - trigger_agent: handles missing/terminated target agent (marks failed)
  - webhook: creates execution with output (stub `Net::HTTP`)
  - Disabled hook returns nil
  - Cancelled task returns nil
  - Audit event created on execution

- [ ] **Step 4: Write job tests**

  - Calls `ExecuteHookService` with correct arguments
  - Guards (missing records, disabled hooks)

- [ ] **Step 5: Run tests, verify passing**

---

### Task 7: ProcessValidationResultService + Job

**Files:**
- Create: `app/services/process_validation_result_service.rb`
- Create: `app/jobs/process_validation_result_job.rb`
- Create: `test/services/process_validation_result_service_test.rb`
- Create: `test/jobs/process_validation_result_job_test.rb`

- [ ] **Step 1: Create ProcessValidationResultService**

  - `self.call(validation_task:)` — called when a subtask with a parent completes
  - Guards: only runs if task is completed, has `parent_task`, and parent has an assignee
  - Collects messages from validation subtask (`task.messages.chronological`)
  - Posts a feedback `Message` on the original (parent) task, attributed to the validator agent
  - Calls `WakeAgentService.call` on the original agent with context `{ action: "review_validation", validation_task_id:, validation_result: }`
  - Records audit event: `"validation_feedback_received"`
  - Reference: `Message` model (`app/models/message.rb`) — needs `task`, `author` (polymorphic), `body`

- [ ] **Step 2: Create ProcessValidationResultJob**

  - `queue_as :hooks`
  - `perform(validation_task_id)` — calls `ProcessValidationResultService.call`
  - Guards: returns early if task not found, not completed, or no parent_task

- [ ] **Step 3: Write service tests**

  - Posts feedback message on parent task
  - Wakes original agent
  - Collects messages from validation subtask
  - Creates audit event
  - No-ops for non-completed, no parent, no assignee

- [ ] **Step 4: Write job tests**

  - Calls service correctly
  - Guards (missing records, non-completed tasks)

- [ ] **Step 5: Run tests, verify passing**

---

### Task 8: Routes + Controller

**Files:**
- Modify: `config/routes.rb` (line ~34, inside agents resource block)
- Create: `app/controllers/agent_hooks_controller.rb`
- Create: `test/controllers/agent_hooks_controller_test.rb`

- [ ] **Step 1: Add routes** nested under agents:

  ```ruby
  resources :agents do
    resources :agent_hooks, only: [:index, :new, :create, :edit, :update, :destroy]
    # ... existing routes
  end
  ```

- [ ] **Step 2: Create AgentHooksController**

  Standard RESTful CRUD following existing controller patterns. Reference `app/controllers/agent_skills_controller.rb` for the nested-under-agent pattern. Require authentication, set company/agent via before_action, strong params for action_config/conditions as JSON.

- [ ] **Step 3: Write controller tests**

  - CRUD operations (index, create, update, destroy)
  - Company scoping (cannot access hooks from other companies)
  - Validation errors render form

- [ ] **Step 4: Run full test suite + rubocop + brakeman**

---

### Task 9: Verification

- [ ] **Step 1: Run `bin/rails db:migrate`** — migrations run clean
- [ ] **Step 2: Run `bin/rails test`** — all tests pass
- [ ] **Step 3: Run `bin/rubocop`** — no style violations
- [ ] **Step 4: Run `bin/brakeman --quiet --no-pager`** — no security warnings
- [ ] **Step 5: Manual console verification:**

  ```ruby
  agent_a = Agent.first
  agent_b = Agent.second
  hook = agent_a.agent_hooks.create!(
    company: agent_a.company,
    lifecycle_event: "after_task_complete",
    action_type: :trigger_agent,
    action_config: { "target_agent_id" => agent_b.id, "prompt" => "Review this work." }
  )
  task = agent_a.assigned_tasks.active.first
  task.update!(status: :completed)
  # Verify: ExecuteHookJob enqueued, HookExecution created, validation subtask created under task
  ```

---

## Key files to modify

- `app/models/agent.rb` — add `has_many :agent_hooks`
- `app/models/task.rb` — add `include Hookable`, `has_many :hook_executions`
- `app/models/heartbeat_event.rb` — extend `trigger_type` enum
- `config/routes.rb` — add `agent_hooks` nested routes

## Key files to create

- `db/migrate/..._create_agent_hooks.rb`
- `db/migrate/..._create_hook_executions.rb`
- `app/models/agent_hook.rb`
- `app/models/hook_execution.rb`
- `app/models/concerns/hookable.rb`
- `app/services/execute_hook_service.rb`
- `app/services/process_validation_result_service.rb`
- `app/jobs/execute_hook_job.rb`
- `app/jobs/process_validation_result_job.rb`
- `app/controllers/agent_hooks_controller.rb`
- All test + fixture files listed in tasks above
