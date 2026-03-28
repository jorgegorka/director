---
phase: 13-skill-data-model
plan: 02
status: complete
completed_at: 2026-03-28T11:00:00Z
duration: ~8 minutes
tasks_completed: 2
files_changed: 11
commits: 2
---

# Plan 13-02 Summary: Drop Capabilities, Wire Skills

## Objective

Dropped the `agent_capabilities` table, removed all capability-related code (model, controller, tests, fixtures, views, routes), and wired Agent with the new skill associations from Plan 01. The entire codebase now references skills instead of capabilities.

## Tasks Completed

### Task 1: Drop agent_capabilities table and remove capability files (commit b8dda75)

- Generated `DropAgentCapabilities` migration (reversible: down recreates the table with index)
- Ran `bin/rails db:migrate` — table dropped successfully
- Deleted `app/models/agent_capability.rb`
- Deleted `app/controllers/agent_capabilities_controller.rb`
- Deleted `test/models/agent_capability_test.rb`
- Deleted `test/controllers/agent_capabilities_controller_test.rb`
- Deleted `test/fixtures/agent_capabilities.yml`
- Preserved original `20260327085837_create_agent_capabilities.rb` migration (never delete old migrations)

### Task 2: Update Agent model, Company model, views, routes, and tests (commit 45a7712)

- **Agent model:** Removed `has_many :agent_capabilities, dependent: :destroy` (skill associations already added in Plan 01)
- **AgentsController:** Updated `includes(:agent_capabilities, ...)` to `includes(:skills, ...)` in both `index` and `set_agent`
- **Routes:** Removed `resources :capabilities, only: [:create, :destroy], controller: "agent_capabilities"` nested under agents
- **agents/show.html.erb:** Replaced the Capabilities section (with add/remove form) with a read-only Skills section displaying skill name + category badges
- **agents/_agent.html.erb:** Replaced `agent-card__capabilities` span with `agent-card__skills` span using `pluralize(agent.skills.size, "skill")`
- **test/models/agent_test.rb:** Replaced `has many agent_capabilities` test with two new tests: `has many skills through agent_skills` and `has many agent_skills`; updated destroy test from `AgentCapability.count` to `AgentSkill.count`

## Deviations

None. All changes were exactly as specified in the plan.

## Artifacts

| File | Change |
|------|--------|
| `db/migrate/20260328103718_drop_agent_capabilities.rb` | New: reversible drop migration |
| `app/models/agent_capability.rb` | Deleted |
| `app/controllers/agent_capabilities_controller.rb` | Deleted |
| `app/views/agents/show.html.erb` | Updated: capabilities section replaced with skills section |
| `app/views/agents/_agent.html.erb` | Updated: agent-card__capabilities replaced with agent-card__skills |
| `app/models/agent.rb` | Updated: removed has_many :agent_capabilities |
| `app/controllers/agents_controller.rb` | Updated: includes use :skills instead of :agent_capabilities |
| `config/routes.rb` | Updated: capability nested resource removed |
| `test/models/agent_test.rb` | Updated: capability tests replaced with skill tests |
| `test/models/agent_capability_test.rb` | Deleted |
| `test/controllers/agent_capabilities_controller_test.rb` | Deleted |
| `test/fixtures/agent_capabilities.yml` | Deleted |

## Key Design Decisions

- Skills section in agent show view is read-only (no add/remove UI) — Phase 17 will add agent skill management UI
- No skill routes added — that is Phase 16/17 work; this plan only wires the associations and updates the display
- Company `has_many :skills` was already added in Plan 01 (as part of the Rule 3 auto-fix for FK constraints); no changes needed to company.rb
- `includes(:skills)` in both index and set_agent actions ensures N+1 safety for the skill count/list display

## Test Results

```
675 runs, 1653 assertions, 0 failures, 0 errors, 0 skips
```

## Success Criteria Verification

- [x] `agent_capabilities` table does not exist (`ActiveRecord::Base.connection.table_exists?(:agent_capabilities)` returns `false`)
- [x] `AgentCapability` class raises `uninitialized constant AgentCapability` (NameError)
- [x] No files named `agent_capability*` exist in `app/` or `test/`
- [x] `grep -r "agent_capabilit" app/ test/ config/routes.rb` returns 0 results
- [x] `Agent#skills` returns Skill collection via agent_skills join (2 skills for claude_agent)
- [x] `Company#skills` association exists (confirmed in company.rb from Plan 01)
- [x] Agent show view displays skills section with skill badges (name + category)
- [x] Agent card partial shows "N skills" instead of "N capabilities"
- [x] `bin/rails test` full suite passes: 675 runs, 0 failures
- [x] `bin/rubocop` passes on modified Ruby files

## Self-Check: PASSED
