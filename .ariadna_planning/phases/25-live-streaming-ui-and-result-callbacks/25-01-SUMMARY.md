---
phase: 25-live-streaming-ui-and-result-callbacks
plan: 01
status: complete
completed_at: 2026-03-28
duration: ~18 minutes
tasks_completed: 2
tasks_total: 2
files_changed: 9
commits:
  - hash: 728c6c7
    message: "feat(25-01): add AgentRun#broadcast_line! and ClaudeLocalAdapter integration"
  - hash: ed8ebe6
    message: "feat(25-01): add AgentRunsController, views, routes, and agent show page integration"
---

# Plan 25-01 Summary: Live Streaming UI and Result Callbacks

## Objective

Create the AgentRuns controller, views, and live streaming infrastructure so users can view agent run history and watch live output stream in the browser. Implements STREAM-01 (live output streaming via turbo_stream_from).

## What Was Built

### Task 1: AgentRun#broadcast_line! and ClaudeLocalAdapter integration

**`app/models/agent_run.rb`** — Added `broadcast_line!` method:
- Calls existing `append_log!` for SQL persistence (COALESCE concatenation, race-free)
- Broadcasts via `Turbo::StreamsChannel.broadcast_append_to` to `"agent_run_#{id}"` stream
- Target is `"agent-run-output"` DOM element
- Renders `agent_runs/log_line` partial with the text
- Guards against blank/nil text (inherited from `append_log!` guard + explicit return)

**`app/views/agent_runs/_log_line.html.erb`** — Simple partial:
- Single `div.agent-run-output__line` wrapping raw text content
- No markdown parsing per project design decisions

**`app/adapters/claude_local_adapter.rb`** — Updated `poll_session`:
- Both `append_log!` call sites replaced with `broadcast_line!`
- Log persistence unchanged — `broadcast_line!` calls `append_log!` internally
- Live broadcasts now flow to subscribed browsers during execution

**`test/models/agent_run_test.rb`** — Added 3 tests:
- Persistence via `append_log!` is verified by reloading from DB
- Blank/nil guard tested with `update_columns` + reload assertions
- No error raised on broadcast (Turbo Streams are fire-and-forget in test env)

### Task 2: AgentRunsController with index/show views, routes, and agent show page integration

**`config/routes.rb`** — Added nested resource:
- `resources :agent_runs, only: [:index, :show]` inside `resources :agents`
- Generates: `GET /agents/:agent_id/agent_runs` and `GET /agents/:agent_id/agent_runs/:id`

**`app/controllers/agent_runs_controller.rb`** — Thin controller:
- `before_action :require_company!` for auth gate
- `set_agent` scopes via `Current.company.agents.find(params[:agent_id])` — cross-company access blocked
- `set_agent_run` scopes via `@agent.agent_runs.find(params[:id])` — cross-agent access blocked
- Index loads 50 most recent runs, ordered by `created_at: :desc`

**`app/helpers/agent_runs_helper.rb`** — Two helpers:
- `agent_run_status_badge` — renders `span.status-badge.status-badge--{status}` (reuses existing badge CSS)
- `agent_run_duration` — formats `duration_seconds` as "Xs" or "Xm Ys", returns "---" for nil

**`app/views/agent_runs/index.html.erb`** — Run list table:
- Shows Run ID (linked to show), Status badge, Trigger, Duration, Cost, Started
- Empty state via `.agent-runs__empty`

**`app/views/agent_runs/show.html.erb`** — Live streaming view:
- `turbo_stream_from "agent_run_#{@agent_run.id}"` establishes Action Cable subscription
- Existing `log_output` rendered on page load (split by `\n`, each line as `_log_line` partial)
- `id="agent-run-output"` is the Turbo Stream append target for `broadcast_line!`
- Live indicator pulse animation shown for `running?` or `queued?` runs
- Error message section shown for failed runs with `kv-row--error` CSS class

**`app/controllers/agents_controller.rb`** — Added `@recent_runs`:
- `@agent.agent_runs.order(created_at: :desc).limit(5)` in `show` action

**`app/views/agents/show.html.erb`** — Recent Runs card:
- Added after Heartbeat card, before Skills card
- Shows last 5 runs with Run ID (linked), Status, Duration, Started
- "View all runs" link to `agent_agent_runs_path(@agent)`
- Empty state message when no runs yet

**`app/assets/stylesheets/application.css`** — New `@layer components` block:
- `.agent-runs__header` — flex row with space-between for title + back button
- `.agent-run-detail` — max-width container with auto margins
- `.agent-run-detail__kv` — responsive grid for metadata key-value pairs
- `.agent-run-output` — monospace output container with inset background
- `.agent-run-output__stream` — max 70vh scrollable, pre-wrap, word-break
- `.agent-run-output__live-indicator` — flex row with pulsing dot
- `@keyframes pulse` — 1.5s opacity animation
- Status badge variants: `queued`, `completed`, `failed`, `cancelled`

**`test/controllers/agent_runs_controller_test.rb`** — 9 controller tests:
- Auth guard: unauthenticated redirect to session_url
- Company scoping: `widgets_agent` returns 404 (not_found)
- Agent scoping: `running_run` (belongs to http_agent) returns 404 on claude_agent show
- Empty state, log output display, error message display

## Patterns Used

- **Thin controller**: AgentRunsController delegates all scoping to model associations
- **Company scoping**: `Current.company.agents.find(...)` — established pattern matching AgentsController
- **Turbo Streams**: `turbo_stream_from` in view + `Turbo::StreamsChannel.broadcast_append_to` in model — same pattern as dashboard real-time UI (Phase 10)
- **CSS layers**: New styles added in separate `@layer components { }` block — existing project convention
- **Status badges**: Reused existing `.status-badge` base class, added AgentRun-specific variants
- **Design tokens**: Used actual CSS variable names from file (`--space-1` through `--space-12`, `--border`, `--text-muted`, `--font-mono`, `--radius-md`, `--color-error-fg`, `--color-success-fg`)

## Deviations

**Rule 2: Auto-fix — Test assertion pattern alignment**
The plan specified `assert_raises(ActiveRecord::RecordNotFound)` for cross-company scoping tests. The established project pattern (verified in `agents_controller_test.rb` line 42-45) uses `assert_response :not_found` instead. Rails integration test runner catches `RecordNotFound` and converts it to a 404 response — `assert_raises` never fires because no exception propagates to the test. Fixed both tests to use `assert_response :not_found`.

## Verification

- `bin/rails test test/models/agent_run_test.rb` — 60 tests, 0 failures
- `bin/rails test test/controllers/agent_runs_controller_test.rb` — 9 tests, 0 failures
- `bin/rails test test/controllers/agents_controller_test.rb` — 58 tests, 0 failures
- `bin/rails test` — 1094 tests, 0 failures, 0 errors, 0 skips
- `bin/rubocop app/models/agent_run.rb app/adapters/claude_local_adapter.rb app/controllers/agent_runs_controller.rb app/helpers/agent_runs_helper.rb` — 0 offenses

## Success Criteria Verification

1. Users can navigate to `/agents/:agent_id/agent_runs` — index view with 50-run limit, status badges, timing
2. Users can view run detail at `/agents/:agent_id/agent_runs/:id` — existing log rendered on load + `turbo_stream_from` for live
3. `AgentRun#broadcast_line!` — persists via `append_log!` AND broadcasts to `"agent_run_#{id}"` stream
4. `ClaudeLocalAdapter.poll_session` — uses `broadcast_line!` at both call sites
5. Agent show page — Recent Runs card with last 5 runs and link to full list
6. All routes, controllers, views, tests pass — 1094 tests passing
7. `bin/rubocop` — 0 new offenses

## Self-Check: PASSED

All created files confirmed to exist on disk. Both task commits verified in git log.
