---
phase: 26-template-data-and-registry
plan: 02
subsystem: api
tags: [ruby, data-define, yaml, registry, caching, validation, services]

# Dependency graph
requires:
  - phase: 26-template-data-and-registry/26-01
    provides: db/seeds/role_templates/*.yml with 5 department templates in correct parent-before-child order
  - phase: 14-skill-catalog-seeding
    provides: db/seeds/skills/*.yml with 48 skill definitions used for skill_key validation
provides:
  - RoleTemplateRegistry class with .all, .find, .keys, .reset! class methods
  - Template and TemplateRole Data.define value objects (immutable)
  - Parent ordering validation at load time (raises InvalidTemplate on violation)
  - Memoized template cache (loaded once per process lifetime)
  - 30 comprehensive tests covering all registry behavior
affects:
  - 27-xx (ApplyRoleTemplateService uses RoleTemplateRegistry.find to load templates)
  - 28-xx (Templates UI calls RoleTemplateRegistry.all and .find for display)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Data.define value objects for immutable structured data (Template, TemplateRole)
    - Class-level memoization via @class_instance_variable with reset! for test cleanup
    - Validate-at-load-time pattern: structural constraints checked when data is read, not when consumed
    - fetch for required YAML fields (raises KeyError converted to InvalidTemplate), [] for optional

key-files:
  created:
    - app/services/role_template_registry.rb
    - test/services/role_template_registry_test.rb

key-decisions:
  - "Data.define (Ruby 3.2+) chosen over OpenStruct or PORO -- immutable, memory-efficient, named attributes"
  - "validate_parent_ordering! runs at load time (in load_and_validate_templates) not at query time -- fail fast"
  - "reset! method provided explicitly for test teardown to clear @templates class instance variable"
  - "find accepts both string and symbol keys via key.to_s coercion -- ergonomic for callers"

patterns-established:
  - "Registry pattern: .all loads and caches, .find delegates to .all with error on miss, .keys maps over .all"
  - "Frozen value objects: template roles array and templates array both frozen after construction"
  - "Parent ordering guard: Set of seen titles tracked while iterating roles; child before parent raises"

requirements_covered:
  - id: "TMPL-02"
    description: "Registry with find-by-key access to department templates"
    evidence: "app/services/role_template_registry.rb -- RoleTemplateRegistry.find('engineering') returns Template value object"
  - id: "v1.5-Research-Pitfall"
    description: "Validate parent ordering at load time (children listed before parents)"
    evidence: "RoleTemplateRegistry#validate_parent_ordering! raises InvalidTemplate if child precedes parent"

# Metrics
duration: ~2min
completed: 2026-03-29
---

# Phase 26-02: RoleTemplateRegistry Summary

**RoleTemplateRegistry class with Data.define value objects, load-time parent-ordering validation, and process-lifetime memoization for the 5 department YAML templates**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-03-29T14:53:45Z
- **Completed:** 2026-03-29T14:55:11Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Created RoleTemplateRegistry in app/services/ with .all, .find, .keys, and .reset! class methods
- Template and TemplateRole implemented as Data.define value objects -- immutable, lightweight, named attributes
- Parent ordering validated at load time using a Set of seen titles; raises InvalidTemplate if a child appears before its parent
- Results memoized in @templates class instance variable, loaded once and frozen for process lifetime
- 30 tests written covering count, structure, content quality, hierarchy integrity, skill key validity, caching behavior, and specific template content per department

## Requirements Covered
| REQ-ID | Requirement | Evidence |
|--------|-------------|----------|
| TMPL-02 | Registry with find-by-key access | RoleTemplateRegistry.find("engineering") returns Template; find("nonexistent") raises TemplateNotFound |
| v1.5-Research-Pitfall | Parent ordering validated at load time | validate_parent_ordering! raises InvalidTemplate on child-before-parent |

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement RoleTemplateRegistry class** - `3c7676f` (feat)
2. **Task 2: Write comprehensive registry tests** - `a75e360` (test)

## Files Created/Modified
- `app/services/role_template_registry.rb` - Registry class with Data.define value objects, YAML loading, caching, validation
- `test/services/role_template_registry_test.rb` - 30 tests, 436 assertions covering all registry behavior

## Decisions Made
- Used Data.define (Ruby 3.2+) for Template and TemplateRole -- immutable, no runtime mutation, named read-only attributes; lighter than a full class, safer than OpenStruct
- validate_parent_ordering! placed inside load_and_validate_templates so validation fires exactly once at first call to .all, not on every find/keys call
- reset! exposes nil-assignment of @templates for test teardown -- used in teardown block across all test cases

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- RoleTemplateRegistry.all, .find, and .keys are ready for use by ApplyRoleTemplateService (Phase 27)
- RoleTemplateRegistry.all is ready for the Templates UI listing (Phase 28)
- All 5 department templates load cleanly with valid parent ordering -- registry validates this at startup

---
*Phase: 26-template-data-and-registry*
*Completed: 2026-03-29*

## Self-Check: PASSED

All created files verified present. All task commits verified in git history.
