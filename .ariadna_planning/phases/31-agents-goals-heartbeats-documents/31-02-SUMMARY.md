---
phase: 31-agents-goals-heartbeats-documents
plan: 02
status: complete
completed_at: 2026-03-30
duration: ~3 minutes
tasks_completed: 2/2
files_changed: 8
---

# Plan 31-02 Summary: Heartbeats::ScheduleManager and Documents::Creator Relocation

## Objective

Relocate `HeartbeatScheduleManager` and `CreateDocumentService` from `app/services/` to their domain namespaces as `Heartbeats::ScheduleManager` and `Documents::Creator` in `app/models/`.

## What Was Done

### Task 1: Relocate HeartbeatScheduleManager to Heartbeats::ScheduleManager

- Created `app/models/heartbeats/schedule_manager.rb` with `Heartbeats::ScheduleManager` class — exact logic from old service, wrapped in module namespace
- Relocated test to `test/models/heartbeats/schedule_manager_test.rb` with updated class references
- Updated `Role#sync_heartbeat_schedule` in `app/models/role.rb` (the single caller) to use `Heartbeats::ScheduleManager.sync(self)`
- Deleted `app/services/heartbeat_schedule_manager.rb` and `test/services/heartbeat_schedule_manager_test.rb`
- All 7 tests pass under new namespace

### Task 2: Relocate CreateDocumentService to Documents::Creator

- Created `app/models/documents/creator.rb` with `Documents::Creator` class — exact logic from old service, wrapped in module namespace
- Relocated test to `test/models/documents/creator_test.rb` with updated class references
- No caller updates needed (`CreateDocumentService` had zero callers in `app/`)
- Deleted `app/services/create_document_service.rb` and `test/services/create_document_service_test.rb`
- All 6 tests pass under new namespace

## Patterns Used

- Domain namespace relocation: service objects moved into `app/models/{domain}/` following the concern-driven architecture established in phases 29-31
- `app/models/heartbeats/` and `app/models/documents/` directories created as new domain homes
- No behavioral changes — pure namespace/structural relocation

## Files Created

- `app/models/heartbeats/schedule_manager.rb` — Heartbeats::ScheduleManager
- `app/models/documents/creator.rb` — Documents::Creator
- `test/models/heartbeats/schedule_manager_test.rb` — 7 tests
- `test/models/documents/creator_test.rb` — 6 tests

## Files Deleted

- `app/services/heartbeat_schedule_manager.rb`
- `test/services/heartbeat_schedule_manager_test.rb`
- `app/services/create_document_service.rb`
- `test/services/create_document_service_test.rb`

## Files Updated

- `app/models/role.rb` — `Role#sync_heartbeat_schedule` now calls `Heartbeats::ScheduleManager.sync`

## Verification

- `bin/rails test test/models/heartbeats/schedule_manager_test.rb` — 7/7 pass
- `bin/rails test test/models/documents/creator_test.rb` — 6/6 pass
- `grep -r "HeartbeatScheduleManager" app/ test/` — zero results
- `grep -r "CreateDocumentService" app/ test/` — zero results
- `bin/rails test` — 1243/1243 pass, 0 failures, 0 errors

## Commits

- `89d527d` — refactor(31-02): relocate HeartbeatScheduleManager to Heartbeats::ScheduleManager
- `75b9712` — refactor(31-02): relocate CreateDocumentService to Documents::Creator

## Deviations

None. Both relocations were straightforward as planned.

## Self-Check: PASSED

- app/models/heartbeats/schedule_manager.rb: FOUND
- app/models/documents/creator.rb: FOUND
- test/models/heartbeats/schedule_manager_test.rb: FOUND
- test/models/documents/creator_test.rb: FOUND
- Commits 89d527d and 75b9712: FOUND
