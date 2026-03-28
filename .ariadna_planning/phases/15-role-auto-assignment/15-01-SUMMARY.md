---
phase: 15-role-auto-assignment
plan: 01
status: complete
started: 2026-03-28T11:44:25Z
completed: 2026-03-28T11:46:00Z
duration: ~2 minutes
tasks_completed: 2/2
files_changed: 4
commits: 2
---

# 15-01 Summary: Role Auto-Assignment Callback

## Objective

Implemented role auto-assignment logic in the Role model: when an agent is assigned to a role for the first time (agent_id changes from nil to a non-nil value), the system automatically attaches that role's default skills from `config/default_skills.yml` to the agent.

## What Was Done

### Task 1: Role model callback + fixture updates

**`app/models/role.rb`** — Added three new components:

1. `after_save :assign_default_skills_to_agent, if: :first_agent_assignment?` callback placed after `before_destroy`.

2. `first_agent_assignment?` private guard method using Rails dirty tracking:
   - `saved_change_to_agent_id?` — confirms agent_id actually changed
   - `agent_id.present?` — new value is non-nil
   - `agent_id_before_last_save.nil?` — previous value was nil
   This precisely targets nil→agent transitions while ignoring agent→agent (reassignment) and agent→nil (unassignment).

3. `assign_default_skills_to_agent` private implementation:
   - Loads skill keys via `self.class.default_skill_keys_for(title)`
   - Finds matching skills in the agent's company (tenant isolation)
   - Checks existing assignments to avoid uniqueness violations
   - Creates `AgentSkill` records with `create!` for each new skill

4. `default_skill_keys_for` / `default_skills_config` class methods:
   - `@default_skills_config` memoized at class level — YAML read once per process
   - `role_title.to_s.downcase.strip` for case-insensitive lookup
   - `.fetch(key, [])` returns empty array for unknown titles (AUTO-03 graceful degradation)

**`test/fixtures/skills.yml`** — Added 8 acme skill fixtures covering all CEO and CTO default skill keys: `company_vision`, `stakeholder_communication`, `decision_making`, `risk_assessment`, `architecture_planning`, `technical_strategy`, `system_design`, `security_assessment`.

### Task 2: Auto-assignment tests

**`test/models/role_test.rb`** — Added 8 new tests in "Auto-assignment" section:
- First assignment creates all 5 CEO skills on `process_agent` (no prior skills)
- First assignment does not duplicate `strategic_planning` already on `claude_agent`
- Reassignment (CTO: `claude_agent` → `http_agent`) does not create new skills
- Unassignment (CTO: `claude_agent` → nil) does not change skill count
- Unknown role title ("Chief Happiness Officer") skipped with no error
- Missing company skills (widgets company has only `strategic_planning`) silently skipped, only 1 skill assigned
- `default_skill_keys_for("Nonexistent Role")` returns `[]`
- `default_skill_keys_for("CEO")` and `default_skill_keys_for("ceo")` return identical sorted keys

**`test/controllers/roles_controller_test.rb`** — Added 2 new tests in "Agent assignment" section:
- HTTP PATCH to assign `process_agent` to CEO (no prior agent) creates all 5 CEO skills
- HTTP PATCH to reassign CTO from `claude_agent` to `process_agent` creates no new skills

## Patterns Used

- **Rails dirty tracking**: `saved_change_to_agent_id?` and `agent_id_before_last_save` from `ActiveModel::Dirty` — the correct pattern for post-save state inspection (vs `will_save_change_to_*` for pre-save)
- **After save callback with guard**: Keeps callback logic isolated and testable; guard method is a pure predicate
- **Memoized class-level config**: `@default_skills_config ||= YAML.load_file(...)` — file read once per process, not per model save
- **Tenant isolation**: `agent.company.skills.where(key: skill_keys)` scopes skill lookup to the agent's company
- **Idempotent skill assignment**: `existing_skill_ids` check prevents duplicates without relying on rescue-from-uniqueness-error

## Key Links

- `app/models/role.rb` → `config/default_skills.yml` via `YAML.load_file` (memoized)
- `app/models/role.rb` → `app/models/agent_skill.rb` via `agent.agent_skills.create!(skill: skill)`
- `app/models/role.rb` → `app/models/skill.rb` via `agent.company.skills.where(key: skill_keys)`

## Commits

| Hash | Description |
|------|-------------|
| 58bab69 | feat(15-01): add role auto-assignment callback and default skill fixtures |
| 1a83859 | test(15-01): add auto-assignment tests to RoleTest and RolesControllerTest |

## Test Results

- Model tests: 28 pass (20 existing + 8 new)
- Controller tests: 24 pass (22 existing + 2 new)
- Full suite: 691 pass, 0 failures, 0 errors, 0 skips

## Deviations

None. Implementation followed the plan spec exactly.

## Must-Have Verification

| Truth | Status |
|-------|--------|
| First assignment (nil→agent) creates agent_skill records | PASS — test confirms 5 CEO skills created |
| Reassignment (X→Y) does not trigger auto-assignment | PASS — test confirms 0 new skills |
| Unassignment (X→nil) does not trigger auto-assignment | PASS — test confirms unchanged skill count |
| Unknown role title: no error, no skills assigned | PASS — assert_no_difference passes |
| Missing skill key in company: silently skipped | PASS — only 1 of 5 CEO skills created in widgets |
| Already-assigned skills not duplicated | PASS — strategic_planning count remains 1 |

## Self-Check: PASSED

All files found. Both commits verified (58bab69, 1a83859). 691 tests pass.
