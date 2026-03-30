# Requirements: Director

**Defined:** 2026-03-30
**Core Value:** Codebase aligns with the established convention -- all business logic lives in models as concerns or namespaced plain Ruby objects, not service objects.

## v1.6 Requirements

Requirements for service refactor. Each maps to roadmap phases.

### Role Templates

- [ ] **TMPL-01**: RoleTemplateRegistry relocated to RoleTemplates::Registry in app/models/role_templates/registry.rb -- *centralizes template logic under the model namespace it serves*
- [ ] **TMPL-02**: ApplyRoleTemplateService relocated to RoleTemplates::Applicator in app/models/role_templates/applicator.rb -- *single-template application belongs with template domain*
- [ ] **TMPL-03**: ApplyAllRoleTemplatesService relocated to RoleTemplates::BulkApplicator in app/models/role_templates/bulk_applicator.rb -- *bulk operations belong alongside single-template applicator*

### Roles

- [ ] **ROLE-01**: WakeRoleService relocated to Roles::Waking in app/models/roles/waking.rb -- *agent wake logic belongs with the role it operates on*
- [ ] **ROLE-02**: GateCheckService relocated to Roles::GateCheck in app/models/roles/gate_check.rb -- *governance gate checks are role-level behavior*
- [ ] **ROLE-03**: EmergencyStopService relocated to Roles::EmergencyStop in app/models/roles/emergency_stop.rb -- *emergency stop operates on company roles*

### Hooks

- [ ] **HOOK-01**: ExecuteHookService relocated to Hooks::Executor in app/models/hooks/executor.rb -- *hook execution is core hook domain logic*
- [ ] **HOOK-02**: ProcessValidationResultService relocated to Hooks::ValidationProcessor in app/models/hooks/validation_processor.rb -- *validation result processing is part of the hook lifecycle*

### Budgets

- [ ] **BUDG-01**: BudgetEnforcementService relocated to Budgets::Enforcement in app/models/budgets/enforcement.rb -- *budget enforcement belongs with the budget domain*

### Goals

- [ ] **GOAL-01**: GoalEvaluationService relocated to Goals::Evaluation in app/models/goals/evaluation.rb -- *goal evaluation is core goal domain logic*

### Heartbeats

- [ ] **BEAT-01**: HeartbeatScheduleManager relocated to Heartbeats::ScheduleManager in app/models/heartbeats/schedule_manager.rb -- *heartbeat scheduling is heartbeat domain logic*

### Agents

- [ ] **AGNT-01**: AiClient relocated to Agents::AiClient in app/models/agents/ai_client.rb -- *AI client serves agent execution*

### Documents

- [ ] **DOCS-01**: CreateDocumentService relocated to Documents::Creator in app/models/documents/creator.rb -- *document creation belongs with the document model*

### Cleanup

- [ ] **CLEN-01**: All references updated -- controllers, jobs, views, and tests reference new namespaced classes -- *no broken references after migration*
- [ ] **CLEN-02**: All tests pass after migration -- *refactoring must not break existing behavior*
- [ ] **CLEN-03**: app/services/ directory deleted -- *single source of truth for business logic is app/models/*
- [ ] **CLEN-04**: Related code quality issues addressed -- dead code, naming inconsistencies, or unused imports discovered during migration -- *leave the codebase cleaner than we found it*

## Future Requirements

None -- this is a focused refactoring milestone.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Rewriting service logic | Only relocating and renaming -- logic stays the same |
| Adding new business logic | This milestone is purely structural cleanup |
| Changing public APIs | Method signatures and return values remain identical |
| Database migrations | No schema changes needed |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ROLE-01 | 29 - Roles Domain | Pending |
| ROLE-02 | 29 - Roles Domain | Pending |
| ROLE-03 | 29 - Roles Domain | Pending |
| HOOK-01 | 30 - Hooks & Budgets | Pending |
| HOOK-02 | 30 - Hooks & Budgets | Pending |
| BUDG-01 | 30 - Hooks & Budgets | Pending |
| AGNT-01 | 31 - Agents, Goals, Heartbeats & Documents | Pending |
| GOAL-01 | 31 - Agents, Goals, Heartbeats & Documents | Pending |
| BEAT-01 | 31 - Agents, Goals, Heartbeats & Documents | Pending |
| DOCS-01 | 31 - Agents, Goals, Heartbeats & Documents | Pending |
| TMPL-01 | 32 - Role Templates | Pending |
| TMPL-02 | 32 - Role Templates | Pending |
| TMPL-03 | 32 - Role Templates | Pending |
| CLEN-01 | 33 - Final Cleanup | Pending |
| CLEN-02 | 33 - Final Cleanup | Pending |
| CLEN-03 | 33 - Final Cleanup | Pending |
| CLEN-04 | 33 - Final Cleanup | Pending |

**Coverage:**
- v1.6 requirements: 17 total
- Mapped to phases: 17
- Unmapped: 0

---
*Requirements defined: 2026-03-30*
*Last updated: 2026-03-30 after roadmap creation*
