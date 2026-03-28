---
phase: 15-role-auto-assignment
verified: 2026-03-28T13:15:00Z
status: passed
score: "6/6 truths verified | security: 0 critical, 0 high | performance: 0 high"
must_haves:
  - truth: "First agent assignment (nil->agent) creates agent_skill records for role default skills"
    status: passed
  - truth: "Reassignment (agent_A->agent_B) does NOT trigger auto-assignment"
    status: passed
  - truth: "Unassignment (agent->nil) does NOT trigger auto-assignment"
    status: passed
  - truth: "Unknown role title causes no error and no skills assigned"
    status: passed
  - truth: "Missing skill key in company is silently skipped"
    status: passed
  - truth: "Already-assigned skills are not duplicated"
    status: passed
---

# Phase 15 Verification: Role Auto-Assignment

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | First agent assignment (nil->agent) creates agent_skill records for role default skills | PASS | `after_save :assign_default_skills_to_agent, if: :first_agent_assignment?` on Role (line 22). Guard checks `saved_change_to_agent_id? && agent_id.present? && agent_id_before_last_save.nil?` (line 30-32). Implementation loads keys from YAML, finds company skills, creates AgentSkill records (lines 34-46). Tested by `role_test.rb:141` (5 CEO skills created on process_agent) and `roles_controller_test.rb:174` (HTTP PATCH triggers same). Both pass. |
| 2 | Reassignment (agent_A->agent_B) does NOT trigger auto-assignment | PASS | Guard `first_agent_assignment?` returns false because `agent_id_before_last_save` is non-nil when reassigning. Tested by `role_test.rb:177` (CTO reassignment from claude_agent to http_agent, 0 new skills) and `roles_controller_test.rb:189` (HTTP PATCH reassignment, 0 new skills). Both pass. |
| 3 | Unassignment (agent->nil) does NOT trigger auto-assignment | PASS | Guard returns false because `agent_id.present?` is false when setting to nil. Tested by `role_test.rb:189` (CTO set to nil, unchanged skill count). Passes. |
| 4 | Unknown role title causes no error and no skills assigned | PASS | `default_skill_keys_for` uses `.fetch(key, [])` returning empty array for unknown titles (line 11). Early return `if skill_keys.empty?` (line 36). Tested by `role_test.rb:201` (`assert_no_difference("AgentSkill.count")`). Passes. |
| 5 | Missing skill key in company is silently skipped | PASS | `agent.company.skills.where(key: skill_keys)` returns only matching skills; unmatched keys produce empty results with no error. Tested by `role_test.rb:211` (widgets company with only 1 of 5 CEO skills, only 1 AgentSkill created). Passes. |
| 6 | Already-assigned skills are not duplicated | PASS | `existing_skill_ids` check (line 40) skips skills the agent already has. Tested by `role_test.rb:155` (claude_agent with existing strategic_planning, count remains 1 after CEO assignment). Passes. |

## Artifact Status

| Artifact | Exists | Substantive | Notes |
|----------|--------|-------------|-------|
| `app/models/role.rb` | YES | YES | 55 lines. Contains `after_save` callback, `first_agent_assignment?` guard, `assign_default_skills_to_agent` implementation, `default_skill_keys_for` and `default_skills_config` class methods. No stubs, no TODOs. |
| `test/models/role_test.rb` | YES | YES | 245 lines. 28 tests total (20 existing + 8 new auto-assignment). Covers first assignment, no-duplication, reassignment, unassignment, unknown title, missing keys, class method edge cases. |
| `test/controllers/roles_controller_test.rb` | YES | YES | 223 lines. 24 tests total (22 existing + 2 new auto-assignment). Covers HTTP PATCH first assignment and reassignment. |
| `test/fixtures/skills.yml` | YES | YES | 136 lines. 15 skill fixtures (6 original + 8 new CEO/CTO + 1 widgets). All CEO keys (strategic_planning, company_vision, stakeholder_communication, decision_making, risk_assessment) and CTO keys (code_review, architecture_planning, technical_strategy, system_design, security_assessment) present as acme fixtures. |
| `config/default_skills.yml` | YES | YES | Phase 14 artifact. 80 lines with 11 role mappings (ceo, cto, cmo, cfo, engineer, designer, pm, qa, devops, researcher, general). Consumed by Role.default_skills_config. |

## Key Links (Wiring)

| From | To | Via | Verified |
|------|----|-----|----------|
| `app/models/role.rb` | `config/default_skills.yml` | `YAML.load_file(Rails.root.join("config/default_skills.yml"))` memoized at class level | YES -- file exists, keys match (ceo -> 5 keys, cto -> 5 keys, etc.) |
| `app/models/role.rb` | `app/models/agent_skill.rb` | `agent.agent_skills.create!(skill: skill)` | YES -- AgentSkill validates uniqueness(skill_id, scope: agent_id) and same-company constraint |
| `app/models/role.rb` | `app/models/skill.rb` | `agent.company.skills.where(key: skill_keys)` | YES -- Skill has Tenantable, validates key uniqueness per company, scope works |
| `app/controllers/roles_controller.rb` | `app/models/role.rb` | `@role.update(role_params)` where role_params permits :agent_id | YES -- controller update triggers after_save callback |

## Cross-Phase Integration

| Connection | Status | Evidence |
|------------|--------|----------|
| Phase 14 -> 15: `config/default_skills.yml` consumed | PASS | Phase 14 created the YAML file with role-to-key mappings. Phase 15 reads it via `Role.default_skills_config`. Keys in YAML match seeded skill keys. |
| Phase 14 -> 15: Company skills available for lookup | PASS | `Company#seed_default_skills!` (phase 14) populates skills table on company creation. Phase 15's `agent.company.skills.where(key:)` finds these seeded skills. |
| Phase 13 -> 15: AgentSkill join model used | PASS | Phase 13 created `AgentSkill` with agent_id/skill_id uniqueness + same-company validation. Phase 15 creates AgentSkill records via `agent.agent_skills.create!(skill:)`. |
| Phase 15 -> UI: Skills visible on agent page | PASS | `app/views/agents/show.html.erb` line 174 displays `@agent.skills` with badges. Auto-assigned skills appear automatically. Agent card partial also shows skill count. |
| E2E flow: Company created -> skills seeded -> agent assigned to role -> skills auto-attached -> visible in UI | PASS | All links verified: Company.after_create seeds skills (ph14), Role.after_save assigns skills on first agent assignment (ph15), agent show page renders skills (ph13). |

## Commit Verification

| Hash | Claimed | Verified |
|------|---------|----------|
| `58bab69` | feat(15-01): add role auto-assignment callback and default skill fixtures | YES -- `git show --stat` confirms 2 files: role.rb (+27 lines), skills.yml (+72 lines) |
| `1a83859` | test(15-01): add auto-assignment tests to RoleTest and RolesControllerTest | YES -- `git show --stat` confirms 2 files: role_test.rb (+107 lines), roles_controller_test.rb (+28 lines) |

## Test Results

- Role model tests: 28 pass (20 existing + 8 new)
- Roles controller tests: 24 pass (22 existing + 2 new)
- **Full test suite: 691 runs, 1691 assertions, 0 failures, 0 errors, 0 skips**
- Rubocop: 0 offenses on all 3 Ruby files

## Security Analysis

| Check | Severity | Finding |
|-------|----------|---------|
| YAML deserialization | None | `YAML.load_file` on Ruby 3.4/Psych 5.3.1 uses safe mode by default (restricted classes). Config file contains only strings and arrays. No vulnerability. |
| Tenant isolation | None | `agent.company.skills.where(key:)` scopes skill lookup to the agent's company. No cross-tenant data leakage possible. |
| Mass assignment | None | `role_params` in controller permits only `:title, :description, :job_spec, :parent_id, :agent_id`. No over-permitting. |
| Authorization | None | `set_role` uses `Current.company.roles.find(params[:id])` -- scoped to current company. Agent assignment is authorized through company membership. |

No critical or high security findings.

## Performance Analysis

| Check | Severity | Finding |
|-------|----------|---------|
| YAML file reads | None | Memoized at class level (`@default_skills_config ||=`). Read once per process, not per save. |
| N+1 queries | Low | `assign_default_skills_to_agent` issues up to 5 individual INSERT statements (one per skill). Acceptable for a callback that fires rarely (only on first agent assignment to a role). Bulk insert would be marginally faster but adds complexity for no practical benefit. |
| Callback overhead | None | `first_agent_assignment?` is a pure predicate using Rails dirty tracking -- zero database queries. Callback only fires when guard is true. |

No high performance findings.

## Anti-Patterns Check

- No TODOs, FIXMEs, or debug statements in changed files
- No stubs or placeholder implementations
- No duplicated logic (only one place creates agent_skills programmatically)
- No hardcoded values -- skill keys come from YAML config
- Guard method uses proper Rails dirty tracking APIs (`saved_change_to_*`, `*_before_last_save`)
