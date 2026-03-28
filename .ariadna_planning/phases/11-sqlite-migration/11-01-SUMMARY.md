---
phase: 11-sqlite-migration
plan: 01
subsystem: database
tags: [sqlite3, postgresql, migration, jsonb, json, activerecord, schema]

# Dependency graph
requires: []
provides:
  - Primary database switched from PostgreSQL to SQLite
  - All 8 jsonb columns across 5 tables converted to json
  - Fresh SQLite schema.rb with no pg_catalog references
  - database.yml configured for all environments (dev/test/prod) with primary + cache + queue + cable
  - pg gem removed from Gemfile
affects:
  - 11-02-cleanup (depends on SQLite as primary database)
  - deployment (no PostgreSQL server required)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - SQLite multi-database config: primary + solid_cache + solid_queue + solid_cable all using SQLite in storage/
    - json column type (not jsonb) for hash/object columns in SQLite

key-files:
  created: []
  modified:
    - Gemfile
    - config/database.yml
    - db/schema.rb
    - db/migrate/20260327085826_create_agents.rb
    - db/migrate/20260327103011_create_audit_events.rb
    - db/migrate/20260327134948_create_heartbeat_events.rb
    - db/migrate/20260327175602_create_notifications.rb
    - db/migrate/20260327191037_create_config_versions.rb

key-decisions:
  - "Task 1 (Gemfile + database.yml) was already committed before this execution session (commit 4b48b8d)"
  - "Used db:drop + db:create + db:migrate instead of db:prepare because schema.rb had jsonb references that blocked schema:load"
  - "Updated schema.rb manually first (remove enable_extension + replace jsonb with json), then regenerated via db:schema:dump after migrations ran"
  - "bigint columns remain in schema.rb as-is -- SQLite schema dump preserves bigint from migration definitions, SQLite stores all integers natively"

patterns-established:
  - "SQLite json type: use t.json for hash/object columns (t.jsonb is PostgreSQL-only)"
  - "Multi-database config: all four databases (primary/cache/queue/cable) in storage/ directory"

requirements_covered:
  - id: "DB-01"
    description: "Primary database uses SQLite"
    evidence: "config/database.yml adapter: sqlite3, storage/development.sqlite3"
  - id: "DB-02"
    description: "jsonb columns migrated to json"
    evidence: "8 t.json columns in db/schema.rb, 5 migration files updated"
  - id: "DB-03"
    description: "pg gem removed"
    evidence: "Gemfile contains no pg gem, Gemfile.lock has no pg entry"
  - id: "DB-04"
    description: "All environments use SQLite"
    evidence: "config/database.yml: development/test/production all use adapter: sqlite3"

# Metrics
duration: 8min
completed: 2026-03-28
---

# Phase 11-01: SQLite Migration Summary

**pg gem removed and all 8 jsonb columns converted to json; primary database switched to SQLite with 674 tests passing**

## Performance

- **Duration:** 8 min
- **Started:** 2026-03-28T09:04:49Z
- **Completed:** 2026-03-28T09:13:00Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments
- Removed pg gem from Gemfile; sqlite3 is now the sole database adapter
- Rewrote database.yml to configure SQLite for dev/test/production with primary + cache + queue + cable databases in storage/
- Updated 5 migration files to change all 8 jsonb column definitions to json (SQLite-compatible)
- Regenerated schema.rb: no enable_extension, no jsonb, 8 json columns, partial index preserved, all foreign keys intact
- 674 tests pass with 0 failures and 0 errors on SQLite

## Requirements Covered
| REQ-ID | Requirement | Evidence |
|--------|-------------|----------|
| DB-01 | Primary database uses SQLite | config/database.yml adapter: sqlite3 for all environments |
| DB-02 | jsonb columns migrated to json | 8 t.json columns in db/schema.rb across 5 tables |
| DB-03 | pg gem removed | Gemfile and Gemfile.lock have no pg entry |
| DB-04 | All environments use SQLite | dev/test/production all configured with sqlite3 adapter |

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace pg gem with sqlite3-only Gemfile and rewrite database.yml** - `4b48b8d` (feat)
2. **Task 2: Convert jsonb columns to json and regenerate SQLite schema** - `c8c6d77` (feat)

## Files Created/Modified
- `Gemfile` - Removed pg gem; sqlite3 comment updated to "database for Active Record"
- `config/database.yml` - SQLite config for all 3 environments with 4 databases each (primary/cache/queue/cable)
- `db/migrate/20260327085826_create_agents.rb` - t.jsonb -> t.json for adapter_config
- `db/migrate/20260327103011_create_audit_events.rb` - t.jsonb -> t.json for metadata
- `db/migrate/20260327134948_create_heartbeat_events.rb` - t.jsonb -> t.json for request_payload, response_payload, metadata
- `db/migrate/20260327175602_create_notifications.rb` - t.jsonb -> t.json for metadata
- `db/migrate/20260327191037_create_config_versions.rb` - t.jsonb -> t.json for snapshot, changeset
- `db/schema.rb` - Regenerated: SQLite-native, no pg_catalog extension, 8 json columns, partial index preserved

## Decisions Made
- Task 1 (Gemfile + database.yml) was already committed before this session started (`4b48b8d`) -- execution resumed at Task 2
- Used `db:drop + db:create + db:migrate + db:schema:dump` sequence instead of `db:prepare` because schema.rb had `t.jsonb` references that blocked `schema:load` (db:prepare attempts schema:load when schema.rb exists)
- bigint columns preserved as-is in schema.rb -- SQLite schema dump maintains bigint declarations even though SQLite stores all integers natively; this is cosmetic and doesn't affect functionality

## Deviations from Plan

None - plan executed exactly as written. The only issue was a sequencing matter (schema.rb had to be cleaned up before migrations could run) which was handled inline without architectural impact.

## Issues Encountered
- `db:prepare` failed with `NoMethodError: undefined method 'jsonb'` because it tried to load the existing schema.rb (which still had jsonb) before running migrations. Resolution: manually updated schema.rb to remove `enable_extension` and replace `jsonb` with `json`, then used `db:create + db:migrate + db:schema:dump` to get a clean SQLite schema.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- SQLite is fully operational as primary database
- All 674 tests pass
- Phase 11-02 (cleanup: remove dead code, update docs, verify test coverage) can proceed immediately
- No blockers

## Self-Check: PASSED

All files verified present:
- FOUND: `.ariadna_planning/phases/11-sqlite-migration/11-01-SUMMARY.md`
- FOUND: `db/schema.rb`
- FOUND: `Gemfile`
- FOUND: `config/database.yml`

All commits verified:
- FOUND: `4b48b8d` (Task 1: replace pg gem with sqlite3 and rewrite database.yml)
- FOUND: `c8c6d77` (Task 2: convert jsonb columns to json and regenerate SQLite schema)

---
*Phase: 11-sqlite-migration*
*Completed: 2026-03-28*
