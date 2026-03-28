---
phase: 11-sqlite-migration
verified: 2026-03-28T12:00:00Z
status: gaps_found
score: "3/4 truths verified | security: 0 critical, 0 high | performance: 0 high"
gaps:
  - truth: "Developer can clone the repo, run bin/setup, and the app starts with zero external database dependencies -- no PostgreSQL installation required"
    status: partial
    reason: "The technical stack is fully SQLite -- bin/setup runs db:prepare against SQLite with no pg dependency. However, README.md line 29 still states 'PostgreSQL (primary) + SQLite (Solid Queue, Solid Cache, Solid Cable)' and line 36 states 'Prerequisites: Ruby 3.4 and PostgreSQL. No Node.js required.' Any developer cloning the repo and reading the README will believe PostgreSQL is required and may attempt to install it before running bin/setup. The actual runtime behavior is correct (SQLite-only) but the developer-facing entrypoint contradicts the phase goal."
    artifacts:
      - path: "README.md"
        issue: "Lines 29 and 36 state PostgreSQL is a requirement and the primary database. This directly contradicts the phase goal for the 'clone and run' success criterion."
      - path: "CLAUDE.md"
        issue: "Line 17 states 'Database: PostgreSQL (primary), SQLite for Solid Queue/Cache/Cable' -- the hard constraints section still instructs Claude Code (and human contributors) that the stack uses PostgreSQL as primary."
    missing:
      - "README.md must remove PostgreSQL from prerequisites and tech stack section"
      - "CLAUDE.md must update the Database hard constraint to 'SQLite (all databases)'"
human_verification:
  - test: "Run bin/setup on a machine that has never had PostgreSQL installed and only has Ruby + sqlite3 system package"
    expected: "bin/setup completes and app starts without any PostgreSQL error"
    why_human: "Cannot execute bin/setup in this verification context; the Gemfile and database.yml are correctly SQLite-only but runtime confirmation needs a clean environment"
---

## Phase 11: SQLite Migration -- Verification Report

**Phase goal:** The application runs entirely on SQLite -- primary database, queue, cache, and cable all use the same engine.

**Overall status: gaps_found** -- the infrastructure migration is complete and correct, but README.md and CLAUDE.md still instruct developers to install PostgreSQL, which contradicts the phase goal's "zero external database dependencies" success criterion. This is a documentation gap, not a broken feature, but it means success criterion 1 is only partially met. Doc cleanup is formally Phase 12 scope, but the gap is material to phase 11's stated goal.

---

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Developer can clone and run `bin/setup` with zero external database dependencies | Partial | `bin/setup` calls `db:prepare` which works on SQLite; Gemfile has no `pg` gem; `database.yml` is SQLite-only for all environments. **However:** `README.md` lines 29+36 and `CLAUDE.md` line 17 still state PostgreSQL is the primary database and a prerequisite. Any developer reading docs before running setup will be misled. |
| 2 | All 8 jsonb columns function correctly as json columns under SQLite | Passed | `db/schema.rb` contains exactly 8 `t.json` columns (agents.adapter_config, audit_events.metadata, heartbeat_events.request_payload + response_payload + metadata, notifications.metadata, config_versions.snapshot + changeset). All 5 migration files updated in-place to use `t.json`. No `t.jsonb` anywhere in `db/`. |
| 3 | `bin/rails test` passes in full with SQLite as the primary database | Passed | 11-01 and 11-02 SUMMARYs both report 674 tests, 0 failures, 0 errors. No PostgreSQL-specific SQL patterns found in `app/` or `test/` code (no `::jsonb` casts, no raw PostgreSQL functions). Partial index `where: "(status = 0)"` is preserved in schema.rb and works in SQLite. |
| 4 | Docker build completes without PostgreSQL client libraries and production container runs on SQLite only | Passed | Dockerfile base stage installs `sqlite3` runtime package; no `libpq`, `postgresql-client`, or `libpq-dev` in any build stage. `config/deploy.yml` has `director_storage:/rails/storage` volume mount for SQLite file persistence and zero PostgreSQL references (DB_HOST comment block removed in commit `a3d87d8`). `production.rb` has `solid_queue.connects_to = { database: { writing: :queue } }` pointing to the SQLite queue database. |

---

## Artifact Status

| Artifact | Exists | Substantive | Notes |
|----------|--------|-------------|-------|
| `Gemfile` | Yes | Yes | `sqlite3 >= 2.1` is sole database adapter; no `pg` gem present; `Gemfile.lock` resolves sqlite3 2.9.2 for all platforms |
| `config/database.yml` | Yes | Yes | SQLite adapter for all 3 environments (dev/test/prod); all 4 databases (primary/cache/queue/cable) pointing to `storage/*.sqlite3` files; `timeout: 5000` present |
| `db/schema.rb` | Yes | Yes | `ActiveRecord::Schema[8.1]`; 8 `t.json` columns; no `enable_extension`; no `jsonb`; partial index `where: "(status = 0)"` preserved; all foreign keys intact |
| `db/migrate/20260327085826_create_agents.rb` | Yes | Yes | `t.json :adapter_config` (was jsonb) |
| `db/migrate/20260327103011_create_audit_events.rb` | Yes | Yes | `t.json :metadata` (was jsonb) |
| `db/migrate/20260327134948_create_heartbeat_events.rb` | Yes | Yes | `t.json` for request_payload, response_payload, metadata (3 columns, was jsonb) |
| `db/migrate/20260327175602_create_notifications.rb` | Yes | Yes | `t.json :metadata` (was jsonb) |
| `db/migrate/20260327191037_create_config_versions.rb` | Yes | Yes | `t.json` for snapshot and changeset (was jsonb) |
| `Dockerfile` | Yes | Yes | `sqlite3` in base packages; no pg libraries in any stage; already SQLite-clean from Rails 8 defaults |
| `config/deploy.yml` | Yes | Yes | `director_storage:/rails/storage` volume; no DB_HOST, no mysql/db accessory; `SOLID_QUEUE_IN_PUMA: true` |
| `config/environments/production.rb` | Yes | Yes | `cache_store :solid_cache_store`; `solid_queue.connects_to = { database: { writing: :queue } }`; `active_job.queue_adapter = :solid_queue` |
| `db/cache_schema.rb` | Yes | Yes | `solid_cache_entries` table present; SQLite-native |
| `db/cable_schema.rb` | Yes | Yes | `solid_cable_messages` table present; SQLite-native |
| `db/queue_schema.rb` | Yes | Yes | `solid_queue_*` tables present; SQLite-native |

**Note:** Plan 11-01 called for a new migration file `YYYYMMDDHHMMSS_convert_jsonb_to_json.rb`. Instead, the agent updated the 5 original migration files in-place. This is a valid approach (the result is a clean SQLite schema from scratch) and the summary documents this decision. No functional gap.

---

## Key Links (Wiring)

| Link | Status | Evidence |
|------|--------|----------|
| `Gemfile` sqlite3 gem → `config/database.yml` sqlite3 adapter | Intact | `Gemfile` has `sqlite3 >= 2.1`; `database.yml` has `adapter: sqlite3` for all environments |
| `config/database.yml` primary → `db/schema.rb` | Intact | Schema has no pg_catalog, no jsonb; pure SQLite-native types |
| `database.yml` cache db → `config/environments/production.rb` cache_store | Intact | `cache: storage/production_cache.sqlite3` + `config.cache_store = :solid_cache_store` |
| `database.yml` queue db → `production.rb` solid_queue.connects_to | Intact | `queue: storage/production_queue.sqlite3` + `connects_to = { database: { writing: :queue } }` |
| `database.yml` cable db → solid_cable (via Rails defaults) | Intact | `cable: storage/production_cable.sqlite3`; `db/cable_schema.rb` has solid_cable_messages |
| `config/deploy.yml` volume → `storage/*.sqlite3` files | Intact | `director_storage:/rails/storage` persists all 4 SQLite database files across deploys |
| `bin/docker-entrypoint` db:prepare → all 4 SQLite databases | Intact | Entrypoint runs `bin/rails db:prepare` on server start; creates all SQLite files on first boot |

---

## Cross-Phase Integration

**Upstream (Phase 10 → Phase 11):** Phase 10 delivered a complete v1.0 PostgreSQL app. Phase 11 successfully migrated the engine without breaking any existing features -- all 674 tests pass.

**Downstream (Phase 11 → Phase 12):** Phase 12 requires "CLAUDE.md, PROJECT.md, and all planning docs reference SQLite as the primary database -- no stale PostgreSQL mentions remain." The stale references in `CLAUDE.md` and `README.md` are the primary work remaining for Phase 12. They are also a partial gap for Phase 11's success criterion 1, since the "clone and run" experience is confounded by docs that tell developers to install PostgreSQL.

---

## Gaps Narrative

The technical migration is complete and correctly implemented. All four databases (primary, cache, queue, cable) use SQLite. The pg gem is gone, all 8 jsonb columns are converted, the schema is SQLite-native, the Dockerfile is clean, and the deploy config is correct.

The single gap is documentation drift. `CLAUDE.md` line 17 still declares the database constraint as "PostgreSQL (primary), SQLite for Solid Queue/Cache/Cable" and `README.md` lines 29 and 36 still list PostgreSQL as the primary database and a prerequisite for running the app. This directly contradicts the phase goal: success criterion 1 says "Developer can clone the repo, run `bin/setup`, and the app starts with zero external database dependencies." A developer reading README before running setup will install PostgreSQL unnecessarily or believe the setup will fail without it.

The ROADMAP assigns documentation cleanup to Phase 12 (success criterion 1: "CLAUDE.md, PROJECT.md, and all planning docs reference SQLite as the primary database"), so these files are formally out of scope for Phase 11. However, because they touch the "clone and run" success criterion that Phase 11 claims, the truth is marked partial rather than passed.

No security or performance findings from this phase -- the changes are purely in configuration files and schema definitions, with no application logic modified.

---

## Commit Verification

| Commit | Claimed | Verified | Content |
|--------|---------|----------|---------|
| `4b48b8d` | Remove pg gem, rewrite database.yml | Confirmed | Modifies Gemfile, Gemfile.lock, config/database.yml -- correct files for Task 1 |
| `c8c6d77` | Convert jsonb to json, regenerate schema | Confirmed | Modifies 5 migration files + db/schema.rb + db/cache_schema.rb + db/cable_schema.rb + db/queue_schema.rb |
| `a3d87d8` | Clean deploy.yml for SQLite-only stack | Confirmed | Modifies config/deploy.yml only -- removes DB_HOST comments and mysql accessory example |

All three commits are present in git log and their diffs match the summary claims.
