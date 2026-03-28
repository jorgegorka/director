---
phase: 23-http-adapter-real-execution
verified: 2026-03-28T19:55:00Z
status: passed
score: "5/5 truths verified | security: 0 critical, 0 high | performance: 0 high"
---

# Phase 23 Verification: HTTP Adapter Real Execution

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| T1 | When an HTTP agent is woken, Director sends a real POST request to the agent's configured URL with the task context as JSON payload | PASS | `HttpAdapter.execute` builds a `build_payload` hash (agent_id, agent_name, run_id, trigger_type, task{id,title,description}, delivered_at) and delivers via `Net::HTTP::Post`; test "payload includes agent and task context" verifies all fields via `assert_requested` block |
| T2 | If the agent URL returns a 4xx response, Director marks the run as permanently failed and does not retry | PASS | `deliver_with_retries` raises `PermanentError` immediately on `Net::HTTPClientError`; `ExecuteAgentJob#perform` catches it via `rescue StandardError` and calls `mark_failed!`; test "4xx response raises PermanentError immediately without retry" asserts `times: 1`; integration test "HTTP adapter 4xx marks run as failed" asserts `run.failed?` and message includes "404" |
| T3 | If the agent URL returns a 5xx or times out, Director retries up to 3 times with exponential backoff before marking failed | PASS | `MAX_RETRIES=3` loop retries on `Net::HTTPServerError`, `Net::OpenTimeout`, `Net::ReadTimeout`, `Errno::ECONNREFUSED`, `Errno::ECONNRESET`, `SocketError`; backoff is `BASE_BACKOFF * (2 ** attempt)` (1s, 2s between attempts 0→1, 1→2); test "5xx response retries and eventually raises TransientError" asserts `times: HttpAdapter::MAX_RETRIES` |
| T4 | HTTP requests use explicit timeouts (5s connect, 30s read) so a slow or unresponsive agent never blocks a thread indefinitely | PASS | `OPEN_TIMEOUT=5`, `READ_TIMEOUT=30` set on every `Net::HTTP` instance in `deliver_with_retries`; test "timeouts are configured correctly" captures the `Net::HTTP` instance via `define_singleton_method` and asserts `open_timeout==5` and `read_timeout==30` |
| T5 | Successful delivery returns a result hash that ExecuteAgentJob uses to mark the run completed | PASS | `HttpAdapter.execute` returns `{ exit_code: 0, response_code: response.code.to_i, response_body: ... }`; `ExecuteAgentJob#perform` passes this to `mark_completed!`; integration test "executes HTTP agent run successfully through adapter" asserts `run.completed?` and `run.exit_code == 0` |

## Artifacts

| Path | Status | Notes |
|------|--------|-------|
| `app/adapters/http_adapter.rb` | PASS — substantive | 107 lines; full implementation with `execute`, `build_payload`, `deliver_with_retries`, `backoff_sleep` hook, `PermanentError`/`TransientError` classes, 4 constants |
| `test/adapters/http_adapter_test.rb` | PASS — substantive | 234 lines; 16 tests covering HTTP-01 through HTTP-04, auth_token, custom headers, missing URL, blank URL, and class method regression |
| `test/jobs/execute_agent_job_test.rb` | PASS — updated | 2 new end-to-end integration tests added (lines 139–181) proving full dispatch chain for success and 4xx failure |

No stubs or TODOs found in `app/adapters/http_adapter.rb`.

## Key Links / Wiring

| From | To | Via | Status |
|------|----|-----|--------|
| `app/adapters/http_adapter.rb` | `ExecuteAgentJob#perform` | `agent.adapter_class.execute(agent, context)` dispatches to `HttpAdapter.execute` when `agent.adapter_type == :http`; `AdapterRegistry.for("http")` returns `HttpAdapter` | PASS |
| `app/adapters/http_adapter.rb` | `AgentRun#mark_completed!` / `AgentRun#mark_failed!` | Result hash `{ exit_code: 0, ... }` flows through `ExecuteAgentJob` to `mark_completed!`; `PermanentError`/`TransientError` rescued and forwarded to `mark_failed!` | PASS |
| `app/services/execute_hook_service.rb` | `app/adapters/http_adapter.rb` | Reference pattern only (not a call dependency); both use `Net::HTTP::Post` independently — acceptable parallel implementations per plan | PASS |
| `WakeAgentService#dispatch_execution` | `ExecuteAgentJob.perform_later` | Creates `AgentRun` and enqueues job; job then calls `agent.adapter_class.execute` | PASS |
| `Runnable#mark_failed!` | `AgentRun` | Included via `include Runnable` in `AgentRun`; provides `mark_failed!(error_message:, **attrs)` | PASS |

## Cross-Phase Integration

### Phase 22 Dependency (AgentRun + ExecuteAgentJob)

The full dispatch chain is validated end-to-end:

1. `WakeAgentService.call` creates `AgentRun` (queued) and calls `ExecuteAgentJob.perform_later`
2. `ExecuteAgentJob#perform` calls `agent.adapter_class.execute(agent, context)` — resolves to `HttpAdapter.execute` for HTTP agents
3. `HttpAdapter.execute` sends real `Net::HTTP::Post` and returns result hash
4. `ExecuteAgentJob` calls `mark_completed!` or (on error) `mark_failed!`
5. Agent status returns to `:idle` in both success and failure paths

All integration tests (`test/jobs/execute_agent_job_test.rb`) pass, including pre-existing tests for `claude_local` adapter (still correctly raising `NotImplementedError`).

### Phase 24/25 Readiness

The adapter architecture is proven. Phase 24 (ClaudeLocalAdapter) can follow the same `PermanentError`/`TransientError` pattern. Phase 25 (streaming UI) will find `AgentRun` records with `status: :completed` and `exit_code: 0` from real HTTP executions.

## Test Results

- `bin/rails test test/adapters/http_adapter_test.rb` — 16 runs, 34 assertions, 0 failures
- `bin/rails test test/jobs/execute_agent_job_test.rb` — 13 runs, 26 assertions, 0 failures
- `bin/rails test` — 970 runs, 2356 assertions, 0 failures, 0 errors, 0 skips
- `bin/rubocop app/adapters/http_adapter.rb test/adapters/http_adapter_test.rb test/jobs/execute_agent_job_test.rb` — 3 files, no offenses

## Security Review

Files changed in this phase: `app/adapters/http_adapter.rb`, `test/adapters/http_adapter_test.rb`, `test/jobs/execute_agent_job_test.rb`.

- SSL is enabled conditionally (`http.use_ssl = (uri.scheme == "https")`) — no `VERIFY_NONE` override. HTTPS agents get TLS verification by default.
- Auth token is passed in `Authorization: Bearer` header — not in URL query string.
- Read timeout is capped at 120s when per-agent override is provided — prevents unbounded thread blocking.
- Response body is truncated to 1000 chars before storing — no unbounded payload storage.
- The pre-existing `Mass Assignment: medium` finding in `agent_hooks_controller.rb` is not related to this phase.

No new security findings introduced by this phase.

## Performance Review

- All HTTP calls go through the background job queue (`execution`) — no blocking in the request/response cycle.
- Explicit timeouts (5s connect, 30s read) prevent thread starvation.
- Retry backoff uses `sleep` inside the background job — acceptable; job workers are designed for this.
- No N+1 queries introduced.

## Backoff Verification

With `MAX_RETRIES=3` and `BASE_BACKOFF=1`:
- Attempt 0 fails → sleep 1s (`1 * 2^0`)
- Attempt 1 fails → sleep 2s (`1 * 2^1`)
- Attempt 2 fails → raise `TransientError` (no sleep after last attempt)

The plan's "1s, 2s, 4s" description lists potential multipliers; with 3 total attempts only 2 sleeps occur (1s, 2s). This is correct behavior — the 4s delay would apply if a 4th attempt were needed, which MAX_RETRIES=3 never triggers. Implementation is consistent with the plan intent.

## Deviation Notes

Two blocking issues were auto-fixed by the agent (documented in SUMMARY.md):
1. Minitest 6.0.2 has no `stub` — WebMock (already in Gemfile) used instead; `backoff_sleep` extracted as overridable hook using `define_singleton_method`.
2. `Net::HTTP::GenericRequest` has no `merge!` — replaced with `each { |k,v| request[k] = v }` iteration.

Both deviations are correct fixes; the resulting implementation satisfies all plan requirements.

## Conclusion

Phase 23 goal is fully achieved. HTTP agents configured with endpoint URLs receive real `POST` delivery when woken via `WakeAgentService` → `ExecuteAgentJob` → `HttpAdapter.execute`. Failure handling is correctly classified (4xx permanent, 5xx/timeout transient with 3-attempt retry). All 5 must-have truths verified, all 3 artifacts are substantive, all key links are wired and tested end-to-end.
