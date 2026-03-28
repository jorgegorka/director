---
phase: 23-http-adapter-real-execution
plan: 01
subsystem: api
tags: [rails, net-http, adapter, http, webmock, minitest, retry, backoff]

# Dependency graph
requires:
  - phase: 22-agentrun-data-model-and-job-dispatch
    provides: ExecuteAgentJob dispatch chain, AgentRun model, BaseAdapter.execute contract

provides:
  - HttpAdapter.execute with real Net::HTTP POST delivery
  - PermanentError (4xx) and TransientError (5xx/timeout) error classification
  - Exponential backoff retry (MAX_RETRIES=3: 1s, 2s, 4s)
  - Configurable timeouts (5s open, 30s read) with per-agent override
  - 16-test unit suite for HttpAdapter covering all HTTP-01 through HTTP-04 requirements
  - 2 end-to-end ExecuteAgentJob integration tests for HTTP adapter dispatch

affects:
  - phase-24-claude-local-adapter  # adapter architecture is now proven end-to-end
  - phase-25-streaming-ui          # HTTP agent runs now produce real completed AgentRun records

# Tech tracking
tech-stack:
  added: []  # No new gems -- WebMock already in Gemfile, Net::HTTP is stdlib
  patterns:
    - backoff_sleep hook pattern for zero-sleep testing without structural change
    - define_singleton_method override for test isolation of class method behavior

key-files:
  created:
    - app/adapters/http_adapter.rb  # Full implementation (replaces stub)
    - test/adapters/http_adapter_test.rb
  modified:
    - test/jobs/execute_agent_job_test.rb  # +2 HTTP end-to-end tests

key-decisions:
  - "Minitest 6.0.2 has no minitest/mock -- used define_singleton_method for backoff_sleep override instead of stub"
  - "backoff_sleep extracted as public class method on HttpAdapter for testability without modifying retry logic"
  - "WebMock (already in Gemfile) used for HTTP stubbing -- consistent with execute_hook_service_test.rb pattern"
  - "Net::HTTP::Post headers set via request[key]=value iteration (not merge!) -- GenericRequest has no merge! method"

patterns-established:
  - "backoff_sleep hook: extracting sleep into an overridable class method for zero-wait test execution"
  - "WebMock with sequential .then.to_return for retry success path testing"
  - "define_singleton_method in setup/teardown for test-scoped class method overrides"

requirements_covered:
  - id: "HTTP-01"
    description: "POST request to agent URL with JSON context payload"
    evidence: "app/adapters/http_adapter.rb#execute + build_payload"
  - id: "HTTP-02"
    description: "4xx responses raise PermanentError immediately, no retry"
    evidence: "app/adapters/http_adapter.rb#deliver_with_retries Net::HTTPClientError branch"
  - id: "HTTP-03"
    description: "5xx and connection errors retry up to MAX_RETRIES with exponential backoff"
    evidence: "app/adapters/http_adapter.rb#deliver_with_retries + backoff_sleep"
  - id: "HTTP-04"
    description: "Explicit timeouts: 5s open, 30s read, per-agent override capped at 120s"
    evidence: "app/adapters/http_adapter.rb OPEN_TIMEOUT=5, READ_TIMEOUT=30"

# Metrics
duration: 6min
completed: 2026-03-28
---

# Phase 23 Plan 01: HTTP Adapter Real Execution Summary

**Net::HTTP POST delivery in HttpAdapter with 4xx/5xx error classification, 3-attempt exponential backoff, and 16-test unit coverage validating the Phase 22 dispatch chain end-to-end**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-03-28T18:43:34Z
- **Completed:** 2026-03-28T18:49:30Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- HttpAdapter.execute sends real Net::HTTP POST with JSON payload containing agent_id, agent_name, run_id, trigger_type, task context, and delivered_at timestamp
- 4xx responses raise PermanentError immediately (no retry), 5xx and network errors retry 3x with 1s/2s backoff before raising TransientError
- 16-test HttpAdapter unit suite covers all HTTP-01 through HTTP-04 requirements including auth_token, custom headers, connection errors, and timeout configuration
- 2 ExecuteAgentJob integration tests prove the full dispatch chain: HTTP agent run succeeds (completed + exit_code=0) and 4xx run fails (error_message includes status code)
- Full test suite passes: 970 tests, 0 failures

## Requirements Covered

| REQ-ID | Requirement | Evidence |
|--------|-------------|----------|
| HTTP-01 | POST request to agent URL with JSON context payload | `HttpAdapter#execute` + `build_payload` |
| HTTP-02 | 4xx raises PermanentError immediately, no retry | `deliver_with_retries` Net::HTTPClientError branch |
| HTTP-03 | 5xx retries 3x with exponential backoff (1s, 2s) | `deliver_with_retries` loop + `backoff_sleep` |
| HTTP-04 | 5s open timeout, 30s read timeout, per-agent override | `OPEN_TIMEOUT=5`, `READ_TIMEOUT=30`, config override |

## Task Commits

1. **Task 1: Implement HttpAdapter.execute with Net::HTTP delivery, error classification, and retry** - `7118884` (feat)
2. **Task 2: Tests for HttpAdapter and ExecuteAgentJob HTTP integration** - `8c0b7c0` (test)

## Files Created/Modified

- `/app/adapters/http_adapter.rb` - Full implementation: execute, build_payload, deliver_with_retries, backoff_sleep hook, PermanentError/TransientError classes, 4 constants
- `/test/adapters/http_adapter_test.rb` - 16 tests: HTTP-01 through HTTP-04 coverage, regression, auth, headers
- `/test/jobs/execute_agent_job_test.rb` - Added 2 HTTP end-to-end integration tests + WebMock require

## Decisions Made

- **Minitest 6.0.2 has no minitest/mock**: Used `define_singleton_method` for test-scoped class method override instead of `.stub`. The `backoff_sleep` hook was extracted as a public class method on HttpAdapter to support zero-sleep testing.
- **WebMock over manual Net::HTTP stubbing**: WebMock was already in the Gemfile (used by execute_hook_service_test.rb). Used consistent `stub_request` pattern.
- **Net::HTTP::Post header setting**: `request[key] = value` iteration used instead of `request.merge!` -- GenericRequest doesn't implement `merge!`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Minitest 6.0.2 has no stub/mock support**
- **Found during:** Task 2 (test implementation)
- **Issue:** Plan specified `Net::HTTP.any_instance.stub(:request, ...)` and `HttpAdapter.stub(:sleep, nil)` -- but Minitest 6.0.2 removed `minitest/mock` entirely. `Object#stub` is not available.
- **Fix:** (a) Switched HTTP stubbing to WebMock (already in Gemfile, consistent with project pattern). (b) Extracted `backoff_sleep` as an overridable public class method on HttpAdapter. (c) Used `define_singleton_method` in test setup/teardown for zero-sleep override.
- **Files modified:** `app/adapters/http_adapter.rb` (added `backoff_sleep`), `test/adapters/http_adapter_test.rb` (WebMock + define_singleton_method)
- **Verification:** 16 adapter tests pass, 970 total tests pass
- **Committed in:** 8c0b7c0 (Task 2 commit)

**2. [Rule 3 - Blocking] Net::HTTP::Post has no merge! method**
- **Found during:** Task 2 (test execution revealed NoMethodError in adapter)
- **Issue:** `request.merge!(config["headers"])` raises NoMethodError -- Net::HTTP::GenericRequest doesn't implement `merge!`
- **Fix:** Changed to `config["headers"]&.each { |k, v| request[k] = v }` iteration
- **Files modified:** `app/adapters/http_adapter.rb`
- **Verification:** custom_headers test passes with `X-Custom: value` header correctly set
- **Committed in:** 8c0b7c0 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Both fixes necessary for functionality. No scope creep. `backoff_sleep` hook is a minimal addition that improves testability.

## Issues Encountered

None beyond the deviations documented above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- HttpAdapter validates the full Phase 22 dispatch chain end-to-end -- ExecuteAgentJob correctly routes to adapters, handles results, and handles errors
- Phase 24 (Claude Local Adapter) can proceed: the adapter architecture is proven, error class pattern is established (PermanentError/TransientError), and the job-to-adapter contract is validated
- No blockers

---
*Phase: 23-http-adapter-real-execution*
*Completed: 2026-03-28*
