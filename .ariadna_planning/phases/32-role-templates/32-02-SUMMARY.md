---
phase: 32-role-templates
plan: 02
status: complete
completed_at: 2026-03-30T14:37:00Z
duration: ~3 minutes
tasks_completed: 1
tasks_total: 1
commits:
  - hash: af6a3d6
    message: "refactor(32-02): relocate ApplyAllRoleTemplatesService to RoleTemplates::BulkApplicator"
files_created:
  - app/models/role_templates/bulk_applicator.rb
  - test/models/role_templates/bulk_applicator_test.rb
files_deleted:
  - app/services/apply_all_role_templates_service.rb
  - test/services/apply_all_role_templates_service_test.rb
---

# Plan 32-02 Summary: RoleTemplates::BulkApplicator Relocation

## Objective

Relocated `ApplyAllRoleTemplatesService` from `app/services/` to `RoleTemplates::BulkApplicator` in `app/models/role_templates/`, completing the role_templates domain namespace. This is the final service relocation — after this plan, `app/services/` is empty.

## Tasks Executed

### Task 1: Relocate ApplyAllRoleTemplatesService to RoleTemplates::BulkApplicator (commit af6a3d6)

- Created `app/models/role_templates/bulk_applicator.rb` with `RoleTemplates::BulkApplicator` — identical behavior, module-wrapped
- Updated 3 internal references:
  - `RoleTemplateRegistry.keys` -> `RoleTemplates::Registry.keys`
  - `ApplyRoleTemplateService.call(` -> `RoleTemplates::Applicator.call(`
  - `ApplyRoleTemplateService::Result.new(` -> `RoleTemplates::Applicator::Result.new(`
- Created `test/models/role_templates/bulk_applicator_test.rb` — all 20 tests relocated with references updated:
  - Class renamed from `ApplyAllRoleTemplatesServiceTest` to `RoleTemplates::BulkApplicatorTest`
  - All `ApplyAllRoleTemplatesService` -> `RoleTemplates::BulkApplicator`
  - All `RoleTemplateRegistry` -> `RoleTemplates::Registry`
- Deleted `app/services/apply_all_role_templates_service.rb`
- Deleted `test/services/apply_all_role_templates_service_test.rb`
- `app/services/` directory is now empty (all three role template services relocated)

## Verification

- `bin/rails test test/models/role_templates/bulk_applicator_test.rb` — 20 tests, 90 assertions, 0 failures, 0 errors
- `bin/rails test test/models/role_templates/` — 74 tests, 589 assertions, 0 failures, 0 errors
- `grep -rn "ApplyAllRoleTemplatesService" app/ test/` — zero results
- `grep -rn "ApplyRoleTemplateService" app/ test/` — zero results
- `grep -rn "RoleTemplateRegistry" app/ test/` — zero results
- `app/services/` — empty (0 files)
- `bin/rails test` — 1243 tests, 3412 assertions, 0 failures, 0 errors

## Patterns Used

- Module namespace wrapping: bare top-level class -> `module RoleTemplates` wrapper
- No behavioral changes — pure relocation with internal reference updates
- Follows the same pattern established in Plan 32-01 for registry and applicator relocations

## Deviations

None. Plan executed exactly as specified.

## State After Plan

- `app/models/role_templates/` contains `registry.rb`, `applicator.rb`, and `bulk_applicator.rb` — full domain namespace established
- `app/services/` is empty — ready for Phase 33 deletion
- All callers of the old service (none found in controllers) are unaffected; no external callers existed

## Self-Check: PASSED

Files verified present:
- FOUND: app/models/role_templates/bulk_applicator.rb
- FOUND: test/models/role_templates/bulk_applicator_test.rb

Files verified deleted:
- CONFIRMED DELETED: app/services/apply_all_role_templates_service.rb
- CONFIRMED DELETED: test/services/apply_all_role_templates_service_test.rb

Commits verified:
- FOUND: af6a3d6
