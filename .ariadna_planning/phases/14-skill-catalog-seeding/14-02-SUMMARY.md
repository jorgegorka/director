---
phase: 14-skill-catalog-seeding
plan: 02
subsystem: models
tags: [rails, models, seeding, skills, rake]

# Dependency graph
requires:
  - phase: 14-01
    provides: "50 YAML skill files in db/seeds/skills/ and config/default_skills.yml"
  - phase: 13-skill-data-model
    provides: "Skill model with key/name/description/category/markdown/builtin columns"

provides:
  - Company#seed_default_skills! method (idempotent YAML-driven skill creation)
  - after_create :seed_default_skills! callback on Company
  - lib/tasks/skills.rake with skills:reseed task
  - 6 new company seeding tests in test/models/company_test.rb

affects:
  - 15-auto-assignment (companies now auto-seeded with skills on creation)
  - All future Company.create! calls automatically get 50 builtin skills

# Tech tracking
tech-stack:
  added: []
  patterns:
    - find_or_create_by! for idempotent seeding (skip existing keys, never overwrite)
    - YAML.load_file + Dir glob for catalog-driven skill creation
    - after_create callback for automatic seeding on company creation
    - find_each in rake task for memory-efficient batch processing

key-files:
  modified:
    - app/models/company.rb
    - test/models/company_test.rb
  created:
    - lib/tasks/skills.rake

key-decisions:
  - "find_or_create_by!(key:) used for idempotency -- the block only executes on create, so existing skills are never updated/overwritten"
  - "assert_difference('Skill.count', skill_count) used instead of plan's assert_difference('Skill.count') -- default arg of 1 would fail since 50 skills are created; auto-fixed per Rule 2"
  - "after_create does not fire during fixture loading (Rails uses bulk INSERT) so existing test companies (acme, widgets) are unaffected"

patterns-established:
  - "Company#seed_default_skills! is the canonical seeding entry point -- callable directly for backfills, wired via after_create for new companies"
  - "builtin scope on Skill used for accurate counting in rake task (excludes custom skills)"

requirements_covered:
  - id: "SEED-03"
    description: "Company after_create seeds builtin skills from YAML catalog"
    evidence: "after_create :seed_default_skills! callback in app/models/company.rb"
  - id: "SEED-04"
    description: "Rake task for backfilling existing companies"
    evidence: "lib/tasks/skills.rake skills:reseed task"

# Metrics
duration: 2min
completed: 2026-03-28
---

# Phase 14-02: Skill Catalog Seeding -- Company Seeding Logic

**Company auto-seeds 50 builtin skills on creation; rake task backfills existing companies**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-03-28T11:13:48Z
- **Completed:** 2026-03-28T11:15:25Z
- **Tasks:** 3
- **Files modified:** 2
- **Files created:** 1
- **Tests:** 6 new, 681 total passing

## Accomplishments

- Added `after_create :seed_default_skills!` callback to `Company` — every new company created via `Company.create!` automatically receives all 50 builtin skill records
- Added `Company#seed_default_skills!` public method that reads `db/seeds/skills/*.yml` via Dir glob, uses `find_or_create_by!(key:)` for idempotency, and sets `builtin: true` on all seeded skills
- Created `lib/tasks/skills.rake` with `skills:reseed` task that iterates all companies via `find_each` and reports per-company counts distinguishing created vs already-present skills
- Added 6 new CompanyTest seeding tests covering: full catalog creation, attribute mapping, idempotency, no-overwrite preservation, partial backfill, and after_create automation

## Task Commits

1. **Task 1: Add seed_default_skills! method and after_create callback to Company** - `018f62b`
2. **Task 2: Create skills:reseed rake task** - `c808691`
3. **Task 3: Add Company seeding tests** - `2d05db7`

## Files Modified/Created

- `app/models/company.rb` — added `after_create :seed_default_skills!` callback + `seed_default_skills!` public method
- `lib/tasks/skills.rake` — new rake task `skills:reseed` iterating all companies with progress output
- `test/models/company_test.rb` — 6 new seeding tests appended to existing CompanyTest class

## Decisions Made

- **find_or_create_by!(key:) for idempotency:** The block passed to `find_or_create_by!` only executes when a record is CREATED (not found). This means re-running the method on a company with existing skills skips those skills entirely, guaranteeing zero overwrites and zero duplicates.
- **assert_difference fix (Rule 2):** The plan's test code used `assert_difference("Skill.count")` (default delta=1) but the callback creates 50 skills. Auto-fixed to `assert_difference("Skill.count", skill_count)` where `skill_count = Dir[...].size`. This is a correctness fix for the test to actually pass.
- **after_create bypasses fixtures:** Rails fixture loading uses bulk SQL INSERT which bypasses ActiveRecord callbacks. The `acme` and `widgets` fixture companies do NOT trigger `seed_default_skills!` during test setup, so existing fixtures are unaffected and the full test suite passes (681 tests, 0 failures).

## Deviations from Plan

- **Rule 2 auto-fix:** Changed `assert_difference("Skill.count")` to `assert_difference("Skill.count", skill_count)` in the `after_create` test. The plan's code had a bug: default delta is 1 but 50 skills are created. Fixed inline without user permission per Rule 2.

## Issues Encountered

None beyond the test assertion fix above.

## User Setup Required

None.

## Next Phase Readiness

- Phase 14 is complete: YAML catalog (Plan 01) + seeding logic (Plan 02) are both done
- Phase 15 (auto-assignment) can proceed: companies now auto-populate with 50 builtin skills, and `config/default_skills.yml` maps 11 role titles to skill key arrays for role-based assignment
- `bin/rails skills:reseed` can be run against any existing environment to backfill companies that existed before this seeding logic was added

---
*Phase: 14-skill-catalog-seeding*
*Completed: 2026-03-28*

## Self-Check: PASSED

- FOUND: app/models/company.rb
- FOUND: lib/tasks/skills.rake
- FOUND: test/models/company_test.rb
- FOUND: .ariadna_planning/phases/14-skill-catalog-seeding/14-02-SUMMARY.md
- FOUND commit 018f62b (Task 1)
- FOUND commit c808691 (Task 2)
- FOUND commit 2d05db7 (Task 3)
