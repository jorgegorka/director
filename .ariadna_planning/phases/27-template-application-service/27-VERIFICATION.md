---
phase: 27-template-application-service
verified: 2026-03-29T18:15:00Z
status: passed
score: "5/5 truths verified | security: 0 critical, 0 high | performance: 0 high"
---

# Phase 27 Verification: Template Application Service

## Phase Goal

> ApplyRoleTemplateService creates a complete department hierarchy with skill pre-assignment, skip-duplicate logic, and structured result reporting. ApplyAllRoleTemplatesService creates all 5 departments under a CEO.

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Applying the Engineering template to an empty company creates the full role hierarchy (CTO -> VP Engineering -> Tech Lead, etc.) with correct parent-child relationships | PASSED | Test `creates full engineering hierarchy with correct parent-child relationships` explicitly asserts CTO has no parent, VP Engineering parent is CTO, Tech Lead parent is VP Engineering, Engineer parent is Tech Lead, QA parent is VP Engineering. 5 roles created. Engineering template YAML confirms ordering: CTO (parent: null), VP Engineering (parent: CTO), Tech Lead (parent: VP Engineering), Engineer (parent: Tech Lead), QA (parent: VP Engineering). |
| 2 | Applying the same template twice to the same company creates no duplicate roles -- all existing roles are skipped | PASSED | Test `applying same template twice creates no new roles on second run` asserts first call created=5, second call created=0, skipped=5. Role model validates `uniqueness: { scope: :company_id }` on title. Service uses `find_by(title:)` before creating. |
| 3 | Each created role has skills from the company's skill library pre-assigned (not from another tenant) | PASSED | Test `assigns skills from company skill library to created roles` verifies VP Engineering gets `project_planning` from acme fixtures. Test `does not assign skills from another company` verifies no widgets role has acme skill IDs via explicit RoleSkill query. Service uses `company.skills.where(key:)` which is inherently tenant-scoped. |
| 4 | The service returns a result object reporting how many roles were created, how many were skipped, and any errors | PASSED | `Result = Data.define(:created, :skipped, :errors, :created_roles)` with helper methods `created_count`, `skipped_count`, `success?`, `total`, `summary`. 8 dedicated result-object tests verify counts, success?, summary text, frozen collections. |
| 5 | "Apply All" creates all 5 departments under the CEO with no conflicts or duplicates | PASSED | Test `creates CEO plus all department roles on empty company` asserts 24 new roles (1 CEO + 23 template roles). Test `all five department roots are children of CEO` asserts CTO, CMO, COO, CFO, HR Director all have CEO as parent. Test `applying all twice creates no duplicates` confirms second call created=0, role count unchanged. |

**Score: 5/5 truths verified**

## Artifact Status

| Artifact | Exists | Substantive | Notes |
|----------|--------|-------------|-------|
| `app/services/apply_role_template_service.rb` | YES | YES (85 lines) | Result Data.define, skip-duplicate logic, tenant-scoped skill assignment, parent_role parameter |
| `app/services/apply_all_role_templates_service.rb` | YES | YES (66 lines) | CEO find-or-create, delegates to ApplyRoleTemplateService for each of 5 templates, aggregates results |
| `test/services/apply_role_template_service_test.rb` | YES | YES (28 tests, 70+ assertions) | Covers hierarchy, skip-duplicate, skill assignment, result object, cross-tenant, error handling, idempotency |
| `test/services/apply_all_role_templates_service_test.rb` | YES | YES (20 tests, 90+ assertions) | Covers full company creation, CEO find-or-create, idempotency, combined results, cross-tenant, partial overlap |

No stubs, TODOs, FIXMEs, or placeholder code found in any artifact.

## Key Links (Wiring)

| From | To | Via | Verified |
|------|-----|-----|----------|
| `ApplyRoleTemplateService` | `RoleTemplateRegistry.find` | Loads template definition by key (line 29) | YES -- RoleTemplateRegistry exists from phase 26, `.find(key)` returns Template Data.define |
| `ApplyRoleTemplateService` | `Role` model | `company.roles.build(...)` and `.save` (lines 45-52) | YES -- Role model has `belongs_to :parent` via TreeHierarchy, `validates :title, uniqueness: { scope: :company_id }` |
| `ApplyRoleTemplateService` | `RoleSkill` | `role.role_skills.create(skill:)` (line 80) | YES -- Role `has_many :role_skills`, RoleSkill model exists |
| `ApplyRoleTemplateService` | `company.skills` | `company.skills.where(key:)` (line 78) | YES -- Company `has_many :skills` |
| `ApplyAllRoleTemplatesService` | `ApplyRoleTemplateService.call` | Delegates each template with `parent_role: ceo` (lines 26-30) | YES -- call chain verified in code and tests |
| `ApplyAllRoleTemplatesService` | `RoleTemplateRegistry.keys` | Gets all 5 template keys (line 25) | YES -- RoleTemplateRegistry.keys returns `["engineering", "finance", "hr", "marketing", "operations"]` |
| `ApplyAllRoleTemplatesService` | `ApplyRoleTemplateService::Result` | Reuses Result type for combined output (line 37) | YES -- no new types introduced |

## Cross-Phase Integration

| Integration Point | Status | Notes |
|--------------------|--------|-------|
| Phase 26 -> Phase 27: RoleTemplateRegistry provides templates | CONNECTED | `ApplyRoleTemplateService` calls `RoleTemplateRegistry.find(key)`, `ApplyAllRoleTemplatesService` calls `RoleTemplateRegistry.keys` |
| Phase 27 -> Phase 28: Services ready for controller consumption | READY | Both services expose clean `.call` interfaces returning Result objects; Phase 28 (Templates Browse/Apply UI) not yet started but depends on these services |
| Phase 3 (Role model): parent/child hierarchy | CONNECTED | TreeHierarchy concern provides `belongs_to :parent`, `has_many :children`; service sets `parent:` on role build |
| Phase 13 (Skill model): tenant-scoped skills | CONNECTED | `company.skills.where(key:)` for tenant-scoped skill lookup |

No orphaned modules. No broken E2E flows. Services are self-contained backend logic awaiting controller integration in Phase 28.

## Duplication Analysis

| File A | File B | Pattern | Assessment |
|--------|--------|---------|------------|
| `ApplyRoleTemplateService#assign_skills` | `Role#assign_default_skills` | Both do `company.skills.where(key:)` + create role_skills | **Acceptable divergence**: different triggering contexts (explicit service call vs. after_save callback), different duplicate handling (rescue vs. pre-check), different skill-key sources (template YAML vs. default_skills.yml config). Extracting would over-couple the callback path to the service path. |

## Test Execution

- **Phase 27 tests**: 48 runs, 160 assertions, 0 failures, 0 errors, 0 skips
- **Full suite**: 1167 runs, 3182 assertions, 1 failure (pre-existing in `ExecuteRoleJobTest` -- intermittent race condition confirmed unrelated to phase 27; file not modified by any phase 27 commit)
- **Rubocop**: 4 files inspected, 0 offenses

## Security Findings

No security findings. Phase 27 files are pure service-layer code with no controller endpoints, no user input handling, no SQL interpolation, and no mass assignment. Brakeman reports 1 pre-existing medium finding in `role_hooks_controller.rb` (unrelated).

## Performance Notes

| Severity | File | Detail |
|----------|------|--------|
| LOW | `apply_role_template_service.rb:37` | Individual `find_by(title:)` per template role (max 5 per template). Bounded N, acceptable for template sizes of 4-7 roles. |
| LOW | `apply_role_template_service.rb:80` | Individual `role_skills.create` per skill assignment (max 5 skills x 5 roles = 25 per template). Bounded N, acceptable. |

No high-severity performance findings.

## Commit Verification

| Commit | Message | Verified |
|--------|---------|----------|
| `4bf67d3` | feat(27-01): implement ApplyRoleTemplateService | YES |
| `358af32` | test(27-01): write comprehensive ApplyRoleTemplateService tests | YES |
| `2785c11` | feat(27-02): implement ApplyAllRoleTemplatesService | YES |
| `6e2b625` | test(27-02): write comprehensive ApplyAllRoleTemplatesService tests | YES |

All 4 commits exist in git history and correspond to claimed changes.
