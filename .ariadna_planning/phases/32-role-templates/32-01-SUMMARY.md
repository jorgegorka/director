---
phase: 32-role-templates
plan: 01
status: complete
completed_at: 2026-03-30T14:33:06Z
duration: ~3 minutes
tasks_completed: 2
tasks_total: 2
commits:
  - hash: 779c49c
    message: "refactor(32-01): relocate RoleTemplateRegistry to RoleTemplates::Registry"
  - hash: bedf5ad
    message: "refactor(32-01): relocate ApplyRoleTemplateService to RoleTemplates::Applicator"
files_created:
  - app/models/role_templates/registry.rb
  - app/models/role_templates/applicator.rb
  - test/models/role_templates/registry_test.rb
  - test/models/role_templates/applicator_test.rb
files_modified:
  - app/controllers/role_templates_controller.rb
  - app/models/roles/hiring.rb
files_deleted:
  - app/services/role_template_registry.rb
  - app/services/apply_role_template_service.rb
  - test/services/role_template_registry_test.rb
  - test/services/apply_role_template_service_test.rb
---

# Plan 32-01 Summary: RoleTemplates Namespace Establishment

## Objective

Relocated `RoleTemplateRegistry` and `ApplyRoleTemplateService` from `app/services/` to the `RoleTemplates` module namespace under `app/models/role_templates/`, establishing the domain directory that Plan 02 will extend with `BulkApplicator`.

## Tasks Executed

### Task 1: Relocate RoleTemplateRegistry to RoleTemplates::Registry (commit 779c49c)

- Created `app/models/role_templates/registry.rb` with `RoleTemplates::Registry` class — identical behavior, module-wrapped
- Updated `RoleTemplatesController` — 3 references updated (`RoleTemplates::Registry.all`, `.find`, `::TemplateNotFound`)
- Updated `Roles::Hiring` concern — 2 references updated in `department_template` and `find_department_root`
- Deleted `app/services/role_template_registry.rb`
- Relocated test to `test/models/role_templates/registry_test.rb` with all `RoleTemplateRegistry` -> `RoleTemplates::Registry` references updated

### Task 2: Relocate ApplyRoleTemplateService to RoleTemplates::Applicator (commit bedf5ad)

- Created `app/models/role_templates/applicator.rb` with `RoleTemplates::Applicator` class — identical behavior, module-wrapped, internal `RoleTemplateRegistry.find` updated to `RoleTemplates::Registry.find`
- Updated `RoleTemplatesController` apply action — `ApplyRoleTemplateService.call` -> `RoleTemplates::Applicator.call`
- Deleted `app/services/apply_role_template_service.rb`
- Relocated test to `test/models/role_templates/applicator_test.rb` with all `ApplyRoleTemplateService` -> `RoleTemplates::Applicator` and `RoleTemplateRegistry` -> `RoleTemplates::Registry` references updated

## Verification

- `bin/rails test test/models/role_templates/ test/controllers/role_templates_controller_test.rb` — **71 tests, 542 assertions, 0 failures, 0 errors**
- `grep -rn "RoleTemplateRegistry|ApplyRoleTemplateService" app/ test/` — only hits in `apply_all_role_templates_service.rb` and its test (Plan 02 scope, as expected)
- `app/models/role_templates/` contains `registry.rb` and `applicator.rb`

## Patterns Used

- Module namespace wrapping: bare top-level class -> `module RoleTemplates` wrapper
- No behavioral changes — pure relocation with caller updates
- Files created in `app/models/role_templates/` following existing domain module pattern (agents/, goals/, heartbeats/, documents/, roles/, hooks/, budgets/)

## Deviations

None. Plan executed exactly as specified.

## State After Plan

- `app/models/role_templates/` established with `registry.rb` and `applicator.rb`
- `app/services/` still contains `apply_all_role_templates_service.rb` (Plan 02 will relocate it as `RoleTemplates::BulkApplicator`)
- All callers in controller and `Roles::Hiring` updated to use new namespace

## Self-Check: PASSED

Files verified present:
- FOUND: app/models/role_templates/registry.rb
- FOUND: app/models/role_templates/applicator.rb
- FOUND: test/models/role_templates/registry_test.rb
- FOUND: test/models/role_templates/applicator_test.rb

Commits verified:
- FOUND: 779c49c
- FOUND: bedf5ad
