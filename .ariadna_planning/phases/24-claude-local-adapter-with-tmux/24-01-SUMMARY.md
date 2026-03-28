---
phase: 24-claude-local-adapter-with-tmux
plan: 01
status: complete
completed_at: 2026-03-28T19:26:23Z
duration: ~11 minutes
tasks_completed: 2
files_changed: 3
---

# Plan 24-01: ClaudeLocalAdapter with tmux execution

## Objective

Implement `ClaudeLocalAdapter.execute` so that Claude Local agents spawn a real `claude` CLI process via tmux, stream JSON output into the AgentRun log, and return session ID and cost data.

## Tasks Completed

### Task 1: Implement ClaudeLocalAdapter.execute (commit f71649d)

Replaced the `BaseAdapter` stub with a full tmux-based implementation:

**Error classes:**
- `ClaudeLocalAdapter::BudgetExhausted < StandardError` — raised before tmux spawn when `agent.budget_exhausted?`
- `ClaudeLocalAdapter::ExecutionError < StandardError` — raised on tmux failure or timeout

**Constants:** `POLL_INTERVAL = 0.5`, `SESSION_PREFIX = "director_run"`, `MAX_POLL_WAIT = 300`

**Key design decisions:**

1. Shell-out methods (`spawn_session`, `session_exists?`, `capture_pane`, `kill_session`) are **public** class methods (not `private_class_method`). This is required for `define_singleton_method` to shadow them in tests without permanently destroying the original — Ruby's `define_singleton_method` over a `private_class_method` def collapses both into one slot, so `remove_method` permanently removes the method. Making them public ensures test overrides shadow rather than replace.

2. `env_prefix` is also public for the same reason.

3. Budget gate (CLAUDE-06) runs BEFORE `AgentRun.find` — no DB or tmux side effects on budget exhaustion.

4. `--bare` always present (CLAUDE-07) — prevents reading/writing `~/.claude/claude.json` under concurrency.

5. `ANTHROPIC_API_KEY` passed via `-e` env flag in tmux command, not inherited from Rails process (CLAUDE-07).

6. Polling loop uses `session_exists?` to detect process completion, then does a final `capture_pane` after loop to collect trailing output.

7. Ensure block always calls `cleanup_session` → `kill_session` to prevent orphan tmux sessions.

8. `build_claude_command` shellescape-s individual arguments but NOT the whole command string; the spawn command wraps the claude command in double-quotes for the tmux last-arg position.

### Task 2: Tests (commit 7e94623)

**`test/adapters/claude_local_adapter_test.rb` (19 tests):**

Test isolation pattern: setup defines ALL shell-out stubs globally using `define_singleton_method` with local variable closures (not `@instance_vars`, since `define_singleton_method` blocks run with `self = ClaudeLocalAdapter`, not the test instance). Teardown removes singleton overrides. Individual tests re-override specific methods as needed.

Coverage:
- CLAUDE-01: `--bare`, `--output-format stream-json`, `--model`, session name, tmux failure
- CLAUDE-02: stream-JSON line-by-line accumulation in `AgentRun#log_output`
- CLAUDE-03: `session_id` extraction from result event
- CLAUDE-04: `--resume` present/absent based on `context[:resume_session_id]`
- CLAUDE-05: `total_cost_usd` → `cost_cents` conversion (0.0234→2, 1.5678→157)
- CLAUDE-06: budget gate blocks execution without spawning tmux
- CLAUDE-07: `ANTHROPIC_API_KEY` in env, missing key raises `ExecutionError`
- Cleanup: ensure block calls `kill_session` even on mid-poll errors
- Regression: `display_name`, `description`, `config_schema` unchanged

**`test/jobs/execute_agent_job_test.rb` (2 new tests, 1 updated):**

- Updated "transitions agent_run from queued to running" — comment updated to reflect `ExecutionError` (not `NotImplementedError`) as the expected failure
- New: "executes Claude Local agent run successfully through adapter" — stubs all shell methods, asserts `run.completed?`, `run.claude_session_id`, `run.cost_cents`, `agent.idle?`
- New: "Claude Local adapter budget exhausted marks run as failed" — creates a real task with `cost_cents >= budget_cents` to exhaust the budget via actual DB state

## Deviations

**[Rule 1 - Bug Fix]** Public class methods for testable hooks: The plan specified `private_class_method` for shell-out methods. Changed to public because `define_singleton_method` on a `private_class_method def self.method` permanently removes the method when `remove_method` is called (Ruby merges both definitions into one singleton class slot). Making them public allows proper shadow/restore in tests. The `env_prefix` method was also changed to public for the same reason. The "missing API key" test uses `ENV.delete("ANTHROPIC_API_KEY")` + real credentials returning nil, rather than `define_singleton_method` on `env_prefix`.

**[Rule 1 - Bug Fix]** Test closure variable capture: `define_singleton_method` blocks run with `self = ClaudeLocalAdapter`, so `@spawn_calls` inside a block refers to the class's instance variable (nil), not the test's. Fixed by capturing shared arrays as local variables before the block, then assigning them to `@instance_vars` as well (`spawn_calls = @spawn_calls = []`). The block closes over the local variable while the test assertions use the instance variable — both point to the same array object.

**[Rule 1 - Bug Fix]** Budget exhausted job test: `@agent.define_singleton_method(:budget_exhausted?) { true }` doesn't work for the job test because `ExecuteAgentJob#perform` loads a fresh AR object via `agent_run.agent`. Fixed by creating a real `Task` with `cost_cents >= budget_cents` to trigger the budget check through actual DB state.

## Files Changed

| File | Change |
|------|--------|
| `app/adapters/claude_local_adapter.rb` | Full implementation (165 lines → was 13 line stub) |
| `test/adapters/claude_local_adapter_test.rb` | New: 19 tests |
| `test/jobs/execute_agent_job_test.rb` | 2 new tests, 1 test comment updated |

## Verification

- `bin/rubocop app/adapters/claude_local_adapter.rb test/adapters/claude_local_adapter_test.rb test/jobs/execute_agent_job_test.rb` — no offenses
- `bin/rails test test/adapters/claude_local_adapter_test.rb` — 19/19 passing
- `bin/rails test test/jobs/execute_agent_job_test.rb` — 15/15 passing
- `bin/rails test` — 991/991 passing, 0 failures, 0 errors

## Self-Check: PASSED

All created files found. All commits verified (f71649d, 7e94623).

## Key Links Established

- `ClaudeLocalAdapter.execute` → `ExecuteAgentJob#perform` via `agent.adapter_class.execute(agent, context)`
- `ClaudeLocalAdapter.execute` → `AgentRun#mark_completed!` / `AgentRun#mark_failed!` via result hash / exception propagation
- `ClaudeLocalAdapter.poll_session` → `AgentRun#append_log!` per parsed stream-JSON line
- `ClaudeLocalAdapter.execute` → `Agent#budget_exhausted?` budget gate
