# Director: Paperclip AI Agent Orchestration in Rails 8

## Context

[Paperclip](https://github.com/paperclipai/paperclip) is an open-source Node.js/React platform that orchestrates multiple AI agents as a virtual company. Users define company missions, hire agent "employees," allocate budgets, and monitor performance. Its tagline: *"If OpenClaw is an employee, Paperclip is the company."*

**Director** replicates Paperclip's full feature set as a Ruby on Rails 8 app with Hotwire (Turbo + Stimulus), PostgreSQL, and Solid Queue. The goal is a single Rails monolith that consolidates Paperclip's Node.js server, React SPA, and Drizzle ORM layer (~30 schema tables, ~60 services, ~290 UI files).

---

## Phase 1: Foundation — Rails App, Companies, Agents, Org Chart

### 1.1 Bootstrap

```bash
rails new director --database=postgresql --css=tailwind --skip-jbuilder --asset-pipeline=propshaft
```

**Key gems:**
| Gem | Purpose |
|-----|---------|
| `pg` | PostgreSQL |
| `solid_queue` | Background jobs (Rails 8 default) |
| `solid_cache` | Caching (Rails 8 default) |
| `solid_cable` | ActionCable (Rails 8 default) |
| `turbo-rails` / `stimulus-rails` | Hotwire |
| plain modern css | Styling |
| `geared_pagination` | Pagination |
| `faraday` | HTTP adapter client |
| `fugit` | Cron expression parsing |
| `commonmarker` | Markdown rendering |

Run `rails generate authentication` for built-in User/Session/Password models.

### 1.2 Migrations

**companies** — `id`, `name`, `description`, `status` (active/paused/archived), `pause_reason`, `paused_at`, `issue_prefix` (unique), `issue_counter`, `budget_monthly_cents`, `spent_monthly_cents`, `require_board_approval_for_new_agents:bool`, `brand_color`, timestamps

**agents** — `id`, `company_id`, `name`, `role` (general), `title`, `icon`, `status` (idle/running/paused/error/terminated/pending_approval), `reports_to:` (self-ref FK for org chart), `capabilities:text`, `adapter_type` (claude_local/process/http), `adapter_config:jsonb`, `runtime_config:jsonb`, `budget_monthly_cents`, `spent_monthly_cents`, `pause_reason`, `paused_at`, `permissions:jsonb`, `last_heartbeat_at`, `metadata:jsonb`, timestamps

**company_memberships** — `company_id`, `user_id`, `role` (member/admin/owner), unique index on `[company_id, user_id]`

### 1.3 Models

- **Company** — `has_many :agents`, `has_many :company_memberships`, `has_many :users, through: :company_memberships`. Method `next_issue_identifier!` atomically increments counter via `UPDATE...RETURNING`.
- **Agent** — `belongs_to :company`, `belongs_to :manager, class_name: "Agent", foreign_key: :reports_to, optional: true`, `has_many :direct_reports, class_name: "Agent", foreign_key: :reports_to`. State machine concern for status transitions. Enum for `adapter_type`.
- **CompanyMembership** — join model with role enum.

### 1.4 Controllers & Views

- `CompaniesController` — standard CRUD
- `AgentsController` — nested under companies. New agent form with dynamic adapter config fields (Stimulus controller)
- `OrgChartController` — renders org chart via recursive partial + recursive CTE query for `reports_to` chains
- **Layout**: App shell with persistent sidebar (company nav), Turbo Frames for panel navigation

### 1.5 Services

- `Companies::CreateService` — prefix generation, default goal creation
- `Agents::CreateService` — validates adapter config, optionally creates approval if board approval required
- `Agents::StateTransitionService` — enforces valid status transitions, logs activity

---

## Phase 2: Projects, Goals, Issues (Task Management)

### 2.1 Migrations

**goals** — `id`, `company_id`, `title`, `description`, `level` (mission/strategy/task), `status` (planned/active/achieved), `parent_id` (self-ref tree), `owner_agent_id`, timestamps

**projects** — `id`, `company_id`, `goal_id`, `name`, `description`, `status` (backlog/active/paused/completed/archived), `lead_agent_id`, `target_date`, `color`, `pause_reason`, `paused_at`, `execution_workspace_policy:jsonb`, `archived_at`, timestamps

**issues** — `id`, `company_id`, `project_id`, `goal_id`, `parent_id` (sub-issues), `title`, `description`, `status` (backlog/todo/in_progress/in_review/blocked/done/cancelled), `priority` (low/medium/high/urgent), `assignee_agent_id`, `assignee_user_id`, `checkout_run_id`, `execution_run_id`, `issue_number:int`, `identifier` (unique, e.g. "PAP-42"), `origin_kind` (manual/heartbeat/routine), `billing_code`, `started_at`, `completed_at`, `cancelled_at`, timestamps

**issue_comments** — `id`, `company_id`, `issue_id`, `agent_id` (optional), `user_id` (optional), `content:text`, timestamps

**issue_attachments** — `id`, `company_id`, `issue_id`, `issue_comment_id` (optional), `filename`, `content_type`, `byte_size`, `checksum`, timestamps. Uses ActiveStorage for file storage.

### 2.2 Models

- **Goal** — self-referential tree via `parent_id`. `has_many :children`. Scope `roots`. Method `ancestors` via recursive CTE.
- **Project** — `belongs_to :company`, `belongs_to :goal, optional: true`, `belongs_to :lead_agent, optional: true`, `has_many :issues`
- **Issue** — Most complex model. `before_create :assign_identifier` calls `company.next_issue_identifier!`. Concerns: `Issues::StatusLifecycle` (sets `started_at`/`completed_at`/`cancelled_at` on transitions), `Issues::Checkout` (atomic checkout for heartbeat runs). Self-referential for sub-issues.
- **IssueComment** — polymorphic author (agent or user)

### 2.3 Controllers & Views

- `GoalsController` — tree visualization with collapsible nodes (Stimulus)
- `ProjectsController` — list + detail with issues list
- `IssuesController` — index with filter bar (status, assignee, project, priority, search), detail with properties sidebar + comments thread. Optional kanban board view.

### 2.4 Services

- `Issues::CreateService` — validates assignee, sets identifier, resolves goal from project fallback
- `Issues::SearchService` — PostgreSQL full-text search via `tsvector` or `pg_trgm`
- `Goals::TreeService` — builds nested goal tree, computes ancestors/descendants

---

## Phase 3: Heartbeat Engine, Adapters, Execution

The core of Director — agents pick up issues, adapters execute work, results are captured.

### 3.1 Migrations

**heartbeat_runs** — `id`, `company_id`, `agent_id`, `invocation_source` (on_demand/scheduled/wakeup), `trigger_detail`, `status` (queued/running/completed/failed), `started_at`, `finished_at`, `exit_code`, `signal`, `error`, `error_code`, `usage_json:jsonb`, `result_json:jsonb`, `context_snapshot:jsonb`, `process_pid`, `session_id_before`, `session_id_after`, `log_store`, `log_ref`, `log_bytes:bigint`, `stdout_excerpt`, `stderr_excerpt`, `external_run_id`, `retry_of_run_id`, `process_loss_retry_count`, timestamps

**agent_runtime_states** — one row per agent. `agent_id` (PK), `company_id`, `adapter_type`, `current_session_id`, `state_json:jsonb`, token/cost accumulators, `last_run_id`, `last_run_status`, `last_error`, timestamps

**agent_task_sessions** — `agent_id`, `adapter_type`, `task_key`, `session_display_id`, `session_params_json:jsonb`, unique on `[company_id, agent_id, adapter_type, task_key]`

**agent_wakeup_requests** — `agent_id`, `source`, `reason`, `payload:jsonb`, `status` (queued/claimed/finished), `idempotency_key`, timestamps

### 3.2 Adapter System

```
app/adapters/
  base_adapter.rb        # Interface: execute(context), test_environment
  process_adapter.rb     # Spawns shell commands via Open3, captures stdout/stderr/exit_code
  http_adapter.rb        # POST to configured URL via Faraday, parses JSON response
  claude_local_adapter.rb # Spawns `claude` CLI, --output-format stream-json, session resumption
  registry.rb            # Maps adapter_type strings to adapter classes
```

Each adapter returns an `AdapterResult` struct with: `exit_code`, `stdout`, `stderr`, `usage` (tokens), `session_id`, `result_json`.

### 3.3 Heartbeat Execution Service

`app/services/heartbeat/execution_service.rb` — The heart of Director:

1. Claim queued run atomically (`UPDATE ... WHERE status = 'queued'`)
2. Check budget blocks via `Budgets::InvocationBlockService`
3. Build context snapshot (agent info, company goals, assigned issues, skills)
4. Instantiate adapter via `Adapters.for(agent)`
5. Call `adapter.execute(context)` — long-running
6. Parse results: exit code, usage, cost data, session state
7. Update `HeartbeatRun` with results
8. Create `CostEvent` records
9. Update `AgentRuntimeState`
10. Update issue status if applicable
11. Log activity, broadcast Turbo Stream update

### 3.4 Background Jobs

- `HeartbeatRunJob` — ActiveJob/Solid Queue. Receives `heartbeat_run_id`, calls `ExecutionService`
- `OrphanRecoveryJob` — Recurring (every 5 min), finds stuck "running" runs and marks failed
- `Heartbeat::EnqueueService` — Creates `HeartbeatRun` record + enqueues job. Called from UI, wakeup requests, routine triggers

### 3.5 Real-Time Updates

Replace Paperclip's SSE `live-events` with ActionCable + Turbo Streams:

```ruby
# app/channels/company_channel.rb — subscribes to company-specific stream
# On agent status change, heartbeat status change, issue update:
Turbo::StreamsChannel.broadcast_replace_to(company, :agents, ...)
```

### 3.6 Controllers

- `HeartbeatRunsController` — nested under agents. Run history, log viewer, "Trigger Heartbeat" button
- Agent detail page gets live status indicator + trigger button

---

## Phase 4: Cost Tracking, Budget Enforcement, Approvals

### 4.1 Migrations

**cost_events** — `id`, `company_id`, `agent_id`, `issue_id`, `project_id`, `goal_id`, `heartbeat_run_id`, `billing_code`, `provider`, `biller`, `billing_type`, `model`, `input_tokens`, `cached_input_tokens`, `output_tokens`, `cost_cents`, `occurred_at`, timestamps

**budget_policies** — `company_id`, `scope_type` (company/agent/project), `scope_id`, `metric`, `window_kind` (calendar_month_utc), `amount_cents`, `warn_percent` (80), `hard_stop:bool`, `notify:bool`, `active:bool`, timestamps

**budget_incidents** — `company_id`, `budget_policy_id`, `scope_type`, `scope_id`, `threshold_type` (warn/hard_stop), `amount_limit`, `amount_observed`, `status` (open/resolved), `approval_id`, `resolved_at`, timestamps

**approvals** — `company_id`, `approval_type` (hire_agent/budget_override/strategy_change), `requested_by_agent_id`, `requested_by_user_id`, `status` (pending/approved/rejected), `payload:jsonb`, `decision_note`, `decided_by_user_id`, `decided_at`, timestamps

**approval_comments** — `approval_id`, `company_id`, `content`, `author_type`, `author_id`, timestamps

### 4.2 Services

- `Costs::RecordService` — Creates `CostEvent`, atomically updates `agent.spent_monthly_cents` + `company.spent_monthly_cents` via `UPDATE SET col = col + N`, triggers budget evaluation
- `Costs::ReportingService` — Aggregation queries: summary, by_agent, by_provider, by_model, timeline
- `Budgets::EvaluationService` — Finds matching policies, computes window spend, creates warn/hard_stop incidents, pauses scope on hard stop. Uses `SELECT...FOR UPDATE` locking.
- `Budgets::InvocationBlockService` — Hierarchical check (company -> agent -> project) for budget blocks before heartbeat execution
- `Approvals::DecisionService` — approve/reject lifecycle. On hire approval: activates agent. On budget override: resolves incident, resumes scope.

### 4.3 Controllers & Views

- `CostsController` — Dashboard with summary cards, by-agent/provider breakdowns, date range filtering (Stimulus)
- `ApprovalsController` — Pending/resolved tabs, detail with comment thread, approve/reject buttons
- `BudgetPoliciesController` — CRUD under company settings

---

## Phase 5: Routines, Scheduling, Activity Log, Skills, Workspaces

### 5.1 Migrations

**routines** — `company_id`, `project_id`, `goal_id`, `title`, `description`, `assignee_agent_id`, `priority`, `status` (active/paused/archived), `concurrency_policy` (always_enqueue/skip_if_active/coalesce_if_active), `catch_up_policy`, timestamps

**routine_triggers** — `routine_id`, `kind` (cron/webhook), `cron_expression`, `timezone`, `next_run_at`, `enabled:bool`, `public_id` (unique, for webhook URL), `signing_mode`, timestamps

**routine_runs** — `routine_id`, `trigger_id`, `source`, `status`, `triggered_at`, `linked_issue_id`, `coalesced_into_run_id`, `failure_reason`, `completed_at`, timestamps

**activity_logs** — `company_id`, `actor_type` (user/agent/system), `actor_id`, `action`, `entity_type`, `entity_id`, `agent_id`, `heartbeat_run_id`, `details:jsonb`, `created_at`

**company_skills** — `company_id`, `key` (unique per company), `slug`, `name`, `description`, `markdown:text`, `source_type`, `source_locator`, `trust_level`, `compatibility`, `file_inventory:jsonb`, `metadata:jsonb`, timestamps

**documents** / **document_revisions** — versioned documents with revision history

**execution_workspaces** — `company_id`, `project_id`, `mode`, `strategy_type`, `name`, `status`, `cwd`, `repo_url`, `branch_name`, `provider_type`, `opened_at`, `closed_at`, `metadata:jsonb`, timestamps

### 5.2 Services

- `Routines::ExecutionService` — On trigger fire: check concurrency policy, create linked issue, enqueue heartbeat, create routine_run
- `RoutineTickerJob` — Recurring (every minute via Solid Queue): queries triggers where `next_run_at <= now`, fires them, updates `next_run_at` using `fugit` gem for cron parsing
- `Routines::WebhookService` — Validates HMAC-SHA256 signatures, creates routine run from payload
- `ActivityLog::RecordService` — Central logging called by all services. Creates entry + broadcasts Turbo Stream.
- `Documents::RevisionService` — Creates new revision on update, manages version numbering
- `CompanySkills::ManagementService` — CRUD, import from local path, materialize to filesystem for adapter consumption

### 5.3 Controllers & Views

- `RoutinesController` — List, detail (triggers + recent runs), CRUD
- `RoutineWebhooksController` — Public `POST /webhooks/routines/:public_id`
- `ActivityController` — Paginated feed with Turbo Stream live updates, filters
- `CompanySkillsController` — List, import, detail with markdown preview
- `CompanySettingsController` — Tabs: General, Budget Policies, Skills, Governance

---

## Phase 6: Dashboard, Polish, Production

### 6.1 Dashboard

`DashboardController` — `/companies/:company_id/dashboard`:
- Agent status breakdown (active/running/paused/error counts)
- Task status counts (open/in_progress/blocked/done)
- Cost utilization bar (current month spend vs budget)
- Pending approvals count + budget incidents
- Recent activity feed (live-updating via Turbo)
- Active heartbeat runs widget

Each widget is a Turbo Frame that loads independently and auto-refreshes.

### 6.2 UI Polish

- **Command palette** (Cmd+K) — Stimulus controller searching across all entities
- **Sidebar** — Company switcher, main nav, agent quick-list with live status indicators
- **Mobile bottom nav** — Responsive layout
- **Toast notifications** — Stimulus controller for flash + real-time event alerts

### 6.3 Production Config

**Solid Queue** (`config/recurring.yml`):
```yaml
routine_ticker:
  class: RoutineTickerJob
  schedule: every minute
orphan_recovery:
  class: OrphanRecoveryJob
  schedule: every 5 minutes
monthly_spend_reset:
  class: MonthlySpendResetJob
  schedule: "0 5 1 * *"
```

**Health check**: `GET /health` — DB connectivity, Solid Queue status, adapter availability

**Docker**: `Dockerfile` + `docker-compose.yml` with PostgreSQL

---

## Cross-Cutting Concerns

- **Authorization**: Company membership required. Role-based (owner/admin/member) for destructive ops.
- **Concern `CompanyScoped`**: All models scoped via `belongs_to :company`, controllers use `@company.agents` etc.
- **Concern `Trackable`**: After create/update callbacks for activity logging
- **UUID PKs everywhere**:  Nope, use rails ids.
- **JSONB columns**: `adapter_config`, `runtime_config`, `permissions`, `metadata`, `payload` — Let's use standard rails models not jsonb for these.
- **Database-level locking**: Budget spend uses `UPDATE SET col = col + N`, budget evaluation uses `SELECT...FOR UPDATE`

---

## Verification

After each phase:
1. Run `rails test` / `rspec` — all tests pass
2. Run `rails db:migrate:status` — all migrations up
3. Manual smoke test: create company, hire agent, create project/goals/issues, trigger heartbeat, verify cost tracking, approve actions, set up routine
4. Check real-time: open two browser tabs, verify Turbo Stream updates propagate
5. Check mobile: verify responsive layout works

Full end-to-end test after Phase 6:
1. Create a company with a mission goal
2. Hire a Claude Code agent and a Process agent
3. Create a project with issues assigned to agents
4. Trigger heartbeats and verify execution + cost tracking
5. Set budget policies and verify enforcement (warn + hard stop)
6. Create a routine with cron trigger and verify scheduled execution
7. Review activity log for complete audit trail
8. Dashboard shows accurate real-time data
