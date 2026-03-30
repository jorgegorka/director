---
phase: 29-roles-domain
plan: 02
status: complete
date: 2026-03-30
duration: ~10 minutes
tasks_completed: 2/2
commits:
  - 93e0d3a: refactor(29-02): relocate GateCheckService to Roles::GateCheck
  - 4511414: refactor(29-02): relocate EmergencyStopService to Roles::EmergencyStop
---

# Plan 29-02 Summary: Relocate GateCheckService and EmergencyStopService

## Objective

Relocate `GateCheckService` and `EmergencyStopService` to `Roles::GateCheck` and `Roles::EmergencyStop` in `app/models/roles/`. This completes Phase 29's goal of moving all three role-domain services to the Roles namespace.

## Tasks Completed

### Task 1: Relocate GateCheckService to Roles::GateCheck

**Created:** `app/models/roles/gate_check.rb`
- Wrapped existing `GateCheckService` logic in `module Roles`, renamed class to `GateCheck`
- Identical behavior: `check!` method, `pause_for_approval!`, `notify_gate_triggered!`, `record_audit_event!`
- No behavioral changes — pure namespace relocation

**Relocated test:** `test/models/roles/gate_check_test.rb`
- Class renamed: `GateCheckServiceTest` → `Roles::GateCheckTest`
- All `GateCheckService.check!(` references updated to `Roles::GateCheck.check!(`
- 8 tests pass

**Deleted:** `app/services/gate_check_service.rb`, `test/services/gate_check_service_test.rb`

### Task 2: Relocate EmergencyStopService to Roles::EmergencyStop

**Created:** `app/models/roles/emergency_stop.rb`
- Wrapped existing `EmergencyStopService` logic in `module Roles`, renamed class to `EmergencyStop`
- Identical behavior: `call!` method, `record_audit_event!`, `notify_emergency_stop!`
- `PAUSE_REASON` constant accessible as `Roles::EmergencyStop::PAUSE_REASON`

**Updated caller:** `app/controllers/companies_controller.rb`
- Line 31: `EmergencyStopService.call!(` → `Roles::EmergencyStop.call!(`

**Relocated test:** `test/models/roles/emergency_stop_test.rb`
- Class renamed: `EmergencyStopServiceTest` → `Roles::EmergencyStopTest`
- All `EmergencyStopService.call!(` references updated to `Roles::EmergencyStop.call!(`
- `EmergencyStopService::PAUSE_REASON` updated to `Roles::EmergencyStop::PAUSE_REASON`
- 7 tests pass (plus 6 CompaniesController tests = 13 total)

**Deleted:** `app/services/emergency_stop_service.rb`, `test/services/emergency_stop_service_test.rb`

## Rule 3 Deviation Applied

During Task 1 execution, it was discovered that `app/models/roles/waking.rb` and the deletion of `app/services/wake_role_service.rb` were pre-staged (from plan 01 work) and got bundled into the Task 1 commit. The callers still referenced `WakeRoleService` causing test failures.

Auto-fixed (Rule 3) by verifying all callers and test files properly reference `Roles::Waking` — the updates were already present in the working tree (committed in `663b227` alongside this plan's work).

## Verification

```
grep -r "GateCheckService|EmergencyStopService" app/ test/ --include="*.rb"
# Returns: Zero results
```

Full test suite: **1243 tests, 3412 assertions, 0 failures, 0 errors, 0 skips**

## Artifacts

| File | Status | Description |
|------|--------|-------------|
| `app/models/roles/gate_check.rb` | Created | Roles::GateCheck — governance gate checker |
| `app/models/roles/emergency_stop.rb` | Created | Roles::EmergencyStop — pause all active roles |
| `test/models/roles/gate_check_test.rb` | Created | Roles::GateCheckTest — 8 tests |
| `test/models/roles/emergency_stop_test.rb` | Created | Roles::EmergencyStopTest — 7 tests |
| `app/controllers/companies_controller.rb` | Updated | Uses Roles::EmergencyStop.call! |
| `app/services/gate_check_service.rb` | Deleted | Relocated to Roles namespace |
| `app/services/emergency_stop_service.rb` | Deleted | Relocated to Roles namespace |

## Phase 29 Completion Status

All three role-domain services have been relocated to `app/models/roles/`:
- `Roles::Hiring` (plan 01 — from HiringService)
- `Roles::Waking` (plan 01 — from WakeRoleService)
- `Roles::GateCheck` (plan 02 — from GateCheckService)
- `Roles::EmergencyStop` (plan 02 — from EmergencyStopService)

The `app/services/` directory is now clear of role-domain logic.

## Self-Check: PASSED

- `app/models/roles/gate_check.rb` — FOUND
- `app/models/roles/emergency_stop.rb` — FOUND
- `test/models/roles/gate_check_test.rb` — FOUND
- `test/models/roles/emergency_stop_test.rb` — FOUND
- `app/services/gate_check_service.rb` — CONFIRMED DELETED
- `app/services/emergency_stop_service.rb` — CONFIRMED DELETED
- Commit `93e0d3a` — FOUND
- Commit `4511414` — FOUND
- Zero `GateCheckService` or `EmergencyStopService` references — CONFIRMED
- Full suite: 1243 tests, 0 failures — PASSED
