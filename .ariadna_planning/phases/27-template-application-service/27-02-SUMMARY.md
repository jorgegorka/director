---
phase: 27-template-application-service
plan: 02
subsystem: api
tags: [ruby, data-define, services, role-templates, apply-all, tdd]

# Dependency graph
requires:
  - phase: 27-01
    provides: ApplyRoleTemplateService.call with parent_role parameter + Result Data.define
  - phase: 26-02
    provides: RoleTemplateRegistry.keys returning all 5 template keys
  - phase: 03-org-chart-and-roles
    provides: Role model with parent/child hierarchy, company.roles association
provides:
  - ApplyAllRoleTemplatesService.call(company:) -> ApplyRoleTemplateService::Result
  - CEO find-or-create with meaningful description/job_spec
  - Combined result aggregating CEO creation + all 5 template applications
  - 20 comprehensive tests covering APPLY-05 requirements
affects:
  - 28-xx (Templates UI can call ApplyAllRoleTemplatesService for one-click company setup)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - .call class method delegating to new.call (consistent with BudgetEnforcementService pattern)
    - Reuses ApplyRoleTemplateService::Result -- no new types introduced
    - find_or_create_ceo instance method with @ceo_was_created tracking flag
    - Iterates RoleTemplateRegistry.keys -- automatically picks up future templates

key-files:
  created:
    - app/services/apply_all_role_templates_service.rb
    - test/services/apply_all_role_templates_service_test.rb

key-decisions:
  - "Reuses ApplyRoleTemplateService::Result for the combined result -- same Data.define structure, no new types"
  - "CEO tracked separately so created/skipped counts accurately reflect whether CEO was new or pre-existing"
  - "Iterates RoleTemplateRegistry.keys -- picks up any future templates automatically"
  - "No transaction wrapper -- consistent with locked v1.5 decision (partial success preferred)"

patterns-established:
  - "ApplyAllRoleTemplatesService as a thin orchestrator: finds/creates CEO, delegates to single-template service for each key, aggregates results"

# Metrics
duration: ~2min
completed: 2026-03-29
---

# Phase 27-02: ApplyAllRoleTemplatesService Summary

**Service that applies all 5 department templates in sequence under a shared CEO role, fulfilling APPLY-05 (one-call full company setup with no duplicates)**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-03-29T15:46:43Z
- **Completed:** 2026-03-29T15:48:23Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Implemented ApplyAllRoleTemplatesService following the project's .call class method pattern
- CEO find-or-create: uses `find_by(title:)` consistent with single-template skip-duplicate behavior; tracks creation via `@ceo_was_created` flag so result counts are accurate
- Iterates `RoleTemplateRegistry.keys` to delegate each template to `ApplyRoleTemplateService.call(parent_role: ceo)` -- department roots (CTO, CMO, COO, CFO, HR Director) are all nested under CEO
- Aggregates created/skipped/errors/created_roles from CEO + all 5 templates into a single `ApplyRoleTemplateService::Result`
- No transaction wrapper (partial success preferred per locked v1.5 decision)
- 20 tests, 90 assertions covering all APPLY-05 requirements plus integration with APPLY-01 through APPLY-04

## Requirements Covered
| REQ-ID | Requirement | Evidence |
|--------|-------------|----------|
| APPLY-05 | Apply All creates all 5 departments under CEO with no conflicts | Test: "creates CEO plus all department roles on empty company"; "all five department roots are children of CEO" |
| APPLY-05 | Find-or-create CEO, no duplicate CEO on re-application | Test: "finds existing CEO instead of creating duplicate" |
| APPLY-05 | No duplicates on second call | Test: "applying all twice creates no duplicates"; "second apply all skips all roles" |
| APPLY-04 | Combined result aggregation | Tests: "result aggregates created/skipped count from all templates"; "result created_roles contains all newly created Role records" |
| APPLY-02 | Skip-duplicate with correct parent resolution | Test: "children of skipped CTO still get correct parent in acme" |

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement ApplyAllRoleTemplatesService** - `2785c11` (feat)
2. **Task 2: Write comprehensive tests** - `6e2b625` (test)

## Files Created/Modified
- `app/services/apply_all_role_templates_service.rb` - Orchestrator service: CEO find-or-create, delegates to ApplyRoleTemplateService for each template, aggregates results
- `test/services/apply_all_role_templates_service_test.rb` - 20 tests, 90 assertions covering APPLY-05 requirements

## Role Counts (widgets clean-slate)
- CEO: 1
- Engineering: 5 (CTO, VP Engineering, Tech Lead, Engineer, QA)
- Operations: 5 (COO, Operations Manager, Project Manager, Business Analyst, Executive Assistant)
- Marketing: 5 (CMO, Content Manager, SEO Specialist, Social Media Manager, Marketing Analyst)
- Finance: 4 (CFO, Controller, Compliance Officer, Financial Analyst)
- HR: 4 (HR Director, Recruiter, Training Specialist, Compensation Analyst)
- **Total: 24 new roles per clean company**

## Decisions Made
- Reused `ApplyRoleTemplateService::Result` for combined output -- no new types needed, same Data.define structure covers the aggregate case cleanly
- `@ceo_was_created` flag preferred over `find_or_create_by!` because it gives explicit control over which branch adds to created vs skipped count

## Deviations from Plan
- None. Plan was implemented exactly as specified.

## Issues Encountered
- None. All tests passed on first run.

## User Setup Required
None.

## Next Phase Readiness
- `ApplyAllRoleTemplatesService.call(company:)` is ready for Phase 28 controller use
- One-call full company setup (CEO + all 5 departments) confirmed working
- Both single-template and all-templates services tested in isolation and together

---
*Phase: 27-template-application-service*
*Completed: 2026-03-29*

## Self-Check: PASSED

All created files verified present. All task commits (2785c11, 6e2b625) verified in git history.
