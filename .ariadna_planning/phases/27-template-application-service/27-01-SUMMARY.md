---
phase: 27-template-application-service
plan: 01
subsystem: api
tags: [ruby, data-define, services, role-templates, skill-assignment, tdd]

# Dependency graph
requires:
  - phase: 26-template-data-and-registry/26-02
    provides: RoleTemplateRegistry.find with Template/TemplateRole Data.define value objects
  - phase: 13-skill-data-model
    provides: Skill model + company.skills association for tenant-scoped lookup
  - phase: 03-org-chart-and-roles
    provides: Role model with parent/child hierarchy, company.roles association
provides:
  - ApplyRoleTemplateService.call(company:, template_key:, parent_role: nil) -> Result
  - Result Data.define value object: created, skipped, errors, created_roles, success?, summary, total
  - Skip-duplicate logic preserving both created and pre-existing roles in parent resolution hash
  - 28 comprehensive tests covering hierarchy creation, skip-duplicate, skill assignment, result object
affects:
  - 27-02 (UI controller will call ApplyRoleTemplateService.call and handle the Result)
  - 28-xx (Templates UI can display what the service returned)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Data.define value object for structured service result (Result)
    - .call class method delegating to new.call (consistent with BudgetEnforcementService pattern)
    - roles_by_title hash covering both created AND skipped roles for correct parent resolution
    - company.skills.where(key:) for tenant-scoped skill lookup (never crosses tenant boundary)
    - rescue ActiveRecord::RecordInvalid in assign_skills for idempotent skill assignment

key-files:
  created:
    - app/services/apply_role_template_service.rb
    - test/services/apply_role_template_service_test.rb

key-decisions:
  - "No transaction wrapper -- partial success preferred over all-or-nothing (locked decision from v1.5-Roadmap)"
  - "roles_by_title hash populated with BOTH newly created and pre-existing (skipped) roles so children of skipped roles always resolve their parent correctly"
  - "role.save (not save!) -- errors collected into result array, not raised, enabling partial success"
  - "assign_skills uses company.skills.where(key:) -- cross-tenant boundary would be caught by RoleSkill validation but we avoid the attempt entirely"
  - "SQLite title column has no COLLATE NOCASE -- find_by(title:) is case-sensitive; test documents this behavior"

patterns-established:
  - "Service result as Data.define: immutable structured object with named attrs and helper methods"
  - "roles_by_title hash as parent resolution registry covering both runs in one iteration pass"

requirements_covered:
  - id: "APPLY-01"
    description: "Hierarchy creation: parents before children, correct parent-child relationships"
    evidence: "ApplyRoleTemplateService creates roles in template order; resolve_parent looks up roles_by_title"
  - id: "APPLY-02"
    description: "Skip duplicates: existing title skipped, children still get correct parent"
    evidence: "company.roles.find_by(title:) check; skipped roles added to roles_by_title for parent resolution"
  - id: "APPLY-03"
    description: "Skill pre-assignment from company's own skill library"
    evidence: "assign_skills uses company.skills.where(key:) -- tenant-scoped, graceful on missing keys"
  - id: "APPLY-04"
    description: "Structured result object with created/skipped/errors/created_roles"
    evidence: "Result = Data.define with created_count, skipped_count, success?, total, summary methods"

# Metrics
duration: ~3min
completed: 2026-03-29
---

# Phase 27-01: ApplyRoleTemplateService Summary

**Service that creates a complete department hierarchy from a template definition with skip-duplicate logic, tenant-scoped skill pre-assignment, and structured result reporting**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-03-29T15:41:47Z
- **Completed:** 2026-03-29T15:44:24Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Implemented ApplyRoleTemplateService following the project's .call class method pattern
- Result Data.define value object with created, skipped, errors, created_roles, plus helper methods (success?, total, summary, created_count, skipped_count)
- Skip-duplicate logic: `company.roles.find_by(title:)` for each template role; both created AND skipped roles tracked in roles_by_title hash so children of skipped roles still resolve parents correctly
- assign_skills scoped through `company.skills.where(key:)` -- tenant-isolated, handles missing keys gracefully
- Optional `parent_role:` parameter allows nesting department roots under a specified role (e.g., under CEO for Apply All)
- No transaction wrapper (partial success preferred per locked decision)
- 28 tests covering all five APPLY requirements plus edge cases including cross-tenant isolation, idempotency, case-sensitive title matching documentation

## Requirements Covered
| REQ-ID | Requirement | Evidence |
|--------|-------------|----------|
| APPLY-01 | Hierarchy creation with correct parent-child order | Test: "creates full engineering hierarchy with correct parent-child relationships" |
| APPLY-02 | Skip-duplicate with graceful parent resolution | Test: "children of skipped roles still get correct parent" |
| APPLY-03 | Skill pre-assignment from company's own library | Test: "assigns skills from company skill library to created roles" |
| APPLY-04 | Structured result with counts and methods | Tests: created/skipped/total/success?/summary coverage |

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement ApplyRoleTemplateService** - `4bf67d3` (feat)
2. **Task 2: Write comprehensive tests** - `358af32` (test)

## Files Created/Modified
- `app/services/apply_role_template_service.rb` - Service with Result value object, skip-duplicate logic, tenant-scoped skill assignment
- `test/services/apply_role_template_service_test.rb` - 28 tests, 70 assertions covering all APPLY requirements

## Decisions Made
- `roles_by_title` hash serves as parent resolution registry -- populated immediately when a role is created OR skipped, so the second iteration finds the right parent regardless of whether CTO was just created or already existed
- `role.save` (not `save!`) with error collection enables partial success and matches the "no transaction" design decision
- `assign_skills` rescues `ActiveRecord::RecordInvalid` (not `StandardError`) for idempotent behavior on duplicate skill assignment

## Deviations from Plan
- Added unconditional assertion to `test_does_not_assign_skills_from_another_company` (plan left the assertion implicit via `each` block); used explicit RoleSkill query to guarantee the assertion fires even when no skills are assigned

## Issues Encountered
- Pre-existing intermittent test failure in `ExecuteRoleJobTest` (race condition in parallel execution indicated by "duplicate session" warnings) -- confirmed unrelated to this plan's changes by running the test file in isolation

## User Setup Required
None.

## Next Phase Readiness
- `ApplyRoleTemplateService.call(company:, template_key:)` is ready for use by Phase 27-02 controller
- Result object provides all information needed for UI feedback (created/skipped counts, success?, summary string)
- Service accepts `parent_role:` for the Apply All nesting use case (Phase 27-02)

---
*Phase: 27-template-application-service*
*Completed: 2026-03-29*

## Self-Check: PASSED

All created files verified present. All task commits (4bf67d3, 358af32) verified in git history.
