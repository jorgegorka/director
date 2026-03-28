---
phase: 24-claude-local-adapter-with-tmux
verified: 2026-03-28T20:33:00Z
status: passed
score: "6/6 truths verified | security: 0 critical, 0 high | performance: 0 high"
---

# Phase 24 Verification: Claude Local Adapter with Tmux

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | ClaudeLocalAdapter.execute spawns a tmux session running `claude -p --bare --output-format stream-json` and returns a result hash | PASS | `app/adapters/claude_local_adapter.rb:34-55` implements full execute method. `build_claude_command` (line 96-109) constructs the CLI invocation with `-p`, `--bare`, `--output-format stream-json`. Spawn via `tmux new-session -d -s ...` on line 45. Tests "tmux command includes --bare flag", "tmux command includes --output-format stream-json", "budget OK allows execution to proceed" all pass (19/19 in adapter test file). |
| 2 | Budget exhausted blocks execution before tmux spawn, raising BudgetExhausted | PASS | Line 35-37: `budget_exhausted?` check is the FIRST thing in `execute`, before `AgentRun.find` or any tmux interaction. Test "budget exhausted raises BudgetExhausted without spawning tmux" verifies no `spawn_session` call. Integration test "Claude Local adapter budget exhausted marks run as failed" verifies end-to-end via real DB state. |
| 3 | Stream-JSON output is parsed line-by-line and accumulated in AgentRun log via append_log! | PASS | `poll_session` (line 112-153) loops calling `capture_pane`, splits on newlines, calls `agent_run.append_log!(line + "\n")` for each new line. Test "stream-JSON lines accumulated in AgentRun log" verifies `log_output` contains both assistant and result events. |
| 4 | Session ID from result event extracted and returned as :session_id | PASS | `parse_result` (line 156-178) parses each line as JSON, checks `event["type"] == "result"`, extracts `event["session_id"]`. Test "session_id extracted from result event" asserts `result[:session_id] == "sess_new_xyz"`. Test "missing result event returns nil session_id and cost_cents" covers the nil case. |
| 5 | Cost from total_cost_usd converted to cents and returned as :cost_cents | PASS | Line 173: `(event["total_cost_usd"].to_f * 100).round`. Test "cost_cents converted from total_cost_usd" asserts 0.0234 -> 2. Test "cost_cents conversion handles larger amounts" asserts 1.5678 -> 157. |
| 6 | ANTHROPIC_API_KEY passed explicitly via tmux env, --bare always present | PASS | `env_prefix` (line 70-74) fetches key from ENV or credentials, returns `ANTHROPIC_API_KEY=<escaped>`. Spawn command uses `-e #{prefix}` (line 45). `--bare` is hardcoded in `build_claude_command` (line 103). Tests verify both: "tmux command includes ANTHROPIC_API_KEY in environment" and "tmux command includes --bare flag". Missing key raises ExecutionError (test "missing ANTHROPIC_API_KEY raises ExecutionError"). |

## Artifact Status

| Artifact | Exists | Substantive | Notes |
|----------|--------|-------------|-------|
| `app/adapters/claude_local_adapter.rb` | YES | YES (184 lines) | Full implementation: error classes, constants, execute, build_claude_command, env_prefix, poll_session, parse_result, cleanup_session, hookable shell-out methods |
| `test/adapters/claude_local_adapter_test.rb` | YES | YES (353 lines, 19 tests) | Covers all CLAUDE requirements, budget gate, command construction, stream parsing, error handling, cleanup, regression |
| `test/jobs/execute_agent_job_test.rb` | YES | YES (247 lines, 15 tests) | 2 new Claude Local tests (success end-to-end, budget exhausted), 1 updated test comment |

No stubs, no TODOs, no debug statements, no NotImplementedError remaining in any artifact.

## Key Links / Wiring

| From | To | Via | Verified |
|------|----|-----|----------|
| `ClaudeLocalAdapter.execute` | `ExecuteAgentJob#perform` | `agent.adapter_class.execute(agent, context)` line 17 of execute_agent_job.rb | YES -- `AdapterRegistry` maps `"claude_local"` to `ClaudeLocalAdapter` (adapter_registry.rb:5). Agent model has `enum :adapter_type, { ..., claude_local: 2 }` (agent.rb:16). |
| `ClaudeLocalAdapter.execute` | `AgentRun#mark_completed!` | Result hash with `:exit_code`, `:session_id`, `:cost_cents` flows through ExecuteAgentJob line 19-23 | YES -- `mark_completed!` accepts `exit_code:`, `cost_cents:`, `claude_session_id:` kwargs. Job maps `:session_id` to `claude_session_id:`. |
| `ClaudeLocalAdapter.execute` | `AgentRun#mark_failed!` | `BudgetExhausted` / `ExecutionError` caught by `rescue StandardError` in ExecuteAgentJob line 25 | YES -- Both error classes inherit from `StandardError`. |
| `ClaudeLocalAdapter.poll_session` | `AgentRun#append_log!` | `agent_run.append_log!(line + "\n")` for each parsed stream-JSON line | YES -- `append_log!` uses SQL COALESCE concatenation (agent_run.rb:34-38). |
| `ClaudeLocalAdapter.execute` | `Agent#budget_exhausted?` | Budget check at line 35 before any tmux spawn | YES -- `budget_exhausted?` defined in agent.rb:132-134. |
| `ExecuteAgentJob#build_context` | `Agent#latest_session_id` | Populates `resume_session_id` in context for `--resume` flag | YES -- `latest_session_id` queries completed AgentRuns for last `claude_session_id` (agent.rb:140-143). |

## Cross-Phase Integration

| Integration Point | Status | Evidence |
|-------------------|--------|----------|
| Phase 22 (AgentRun with session_id, cost_cents) | WIRED | `claude_session_id` and `cost_cents` columns exist on AgentRun. `mark_completed!` accepts both. `latest_session_id` queries prior runs for session resumption. |
| Phase 23 (ExecuteAgentJob dispatch chain) | WIRED | Same `adapter_class.execute(agent, context)` dispatch mechanism works for both HttpAdapter and ClaudeLocalAdapter. Both tested end-to-end in execute_agent_job_test.rb. |
| Downstream (Phase 25 streaming) | READY | `append_log!` accumulates output during execution. AgentRun status transitions through `mark_running!` / `mark_completed!` / `mark_failed!`. These are the hooks Phase 25 will use for live streaming. |
| AdapterRegistry | WIRED | `claude_local` maps to `ClaudeLocalAdapter` in adapter_registry.rb. Agent enum includes `claude_local: 2`. UI form has fieldset for claude_local config. |

## Security Analysis

| Check | Severity | Finding |
|-------|----------|---------|
| Command injection via shell-out | REVIEWED | All user-supplied values (`prompt`, `model`, `system_prompt`, `allowed_tools`, `resume_session_id`, `session_name`, `api_key`) are passed through `Shellwords.shellescape`. Session name is constructed from `SESSION_PREFIX` (constant) + `run_id` (integer). |
| API key exposure | REVIEWED | `ANTHROPIC_API_KEY` is passed via tmux `-e` flag (process environment), not command-line argument visible in `ps`. Key is fetched fresh per execution, not stored in adapter state. |
| Tmux session cleanup | REVIEWED | `ensure` block on line 53-54 calls `cleanup_session` on all code paths (success, error, timeout). Prevents orphan sessions. |
| Brakeman | CLEAR | No new warnings from this phase. Pre-existing `permit!` in agent_hooks_controller.rb is unrelated. |

No critical or high security findings.

## Performance Analysis

| Check | Severity | Finding |
|-------|----------|---------|
| Polling interval | OK | `POLL_INTERVAL = 0.5s` is reasonable. `MAX_POLL_WAIT = 300s` prevents indefinite blocking. |
| append_log! per-line SQL | LOW | Each stream-JSON line triggers an individual `UPDATE` via `append_log!`. For a typical Claude run producing ~50-200 lines, this is acceptable. Could batch in future if needed. |
| AgentRun.find in execute | OK | Single find by primary key, negligible cost. |

No high performance findings.

## Test Results

- `bin/rails test test/adapters/claude_local_adapter_test.rb` -- 19/19 passing
- `bin/rails test test/jobs/execute_agent_job_test.rb` -- 15/15 passing (2 new + 13 existing)
- `bin/rails test` -- 991/991 passing, 0 failures, 0 errors
- `bin/rubocop` on changed files -- 0 offenses
- `bin/brakeman` -- no new warnings

## Commits

| Hash | Message | Verified |
|------|---------|----------|
| `f71649d` | feat(24-01): implement ClaudeLocalAdapter.execute with tmux session lifecycle | YES (1 file changed: claude_local_adapter.rb) |
| `7e94623` | test(24-01): add ClaudeLocalAdapter tests and update ExecuteAgentJob integration tests | YES (3 files changed: adapter + 2 test files) |
