# Requirements: Director v1.5 Role Templates

**Defined:** 2026-03-29
**Core Value:** Users can bootstrap their AI company's org chart with pre-built department structures instead of creating every role manually

## v1.5 Requirements

### Template Data

- [ ] **TMPL-01**: App ships with 5 builtin department YAML templates (Engineering, Marketing, Operations, Finance, HR) each defining a role hierarchy with titles, descriptions, job specs, and skill key references — *users get instant org chart setup instead of building from scratch*
- [ ] **TMPL-02**: RoleTemplateRegistry class loads, caches, and exposes all YAML template definitions with find-by-key access — *foundation for both service and UI to read template data*
- [ ] **TMPL-03**: Each template defines 4-7 roles with parent references in dependency order and 3-5 skill assignments per role — *departments are rich enough to be immediately useful*

### Application Service

- [ ] **APPLY-01**: ApplyRoleTemplateService creates roles in dependency order (parents before children) with correct hierarchy — *department structure is faithfully reproduced*
- [ ] **APPLY-02**: Service skips roles whose title already exists in the company — *safe to apply multiple templates and re-apply without duplicates*
- [ ] **APPLY-03**: Service pre-assigns skills from the company's skill library to each created role — *roles come ready with capabilities, no manual skill setup*
- [ ] **APPLY-04**: Service returns a structured result with created/skipped/errors counts — *enables clear user feedback*
- [ ] **APPLY-05**: Apply All action applies all 5 department templates in sequence — *one-click full company setup*

### Templates UI

- [ ] **UI-01**: Dedicated templates browse page lists all available department templates as cards with name, description, and role count — *users discover and compare available departments*
- [ ] **UI-02**: Template detail page shows the full role hierarchy tree with descriptions and skill badges — *users understand what they're getting before applying*
- [ ] **UI-03**: One-click apply button creates the department and redirects with flash summary (created X, skipped Y) — *frictionless application with clear feedback*
- [ ] **UI-04**: Link from roles index page to templates browse page — *users discover templates from the natural starting point*

### Skill Mappings

- [ ] **SKILL-01**: Extended default_skills.yml with ~17 new role-title-to-skill mappings for template roles — *template roles also get auto-assigned skills on agent configuration*

## Future Requirements

### v2 Considerations

- **TMPL-F01**: User-created custom templates — save current org structure as reusable template
- **TMPL-F02**: Template marketplace ("Clipmart") — share and discover community templates
- **TMPL-F03**: User-selected attach point — choose which role to nest the department under
- **TMPL-F04**: Diff preview before apply — show new vs existing roles with visual indicators

## Out of Scope

| Feature | Reason |
|---------|--------|
| Custom template creation by users | Scope creep; users can create roles manually. Defer to v2. |
| Template marketplace / sharing | Requires user-generated content infrastructure. Defer to v2. |
| Auto-connecting agents to template roles | Agent connection requires user-specific adapter configuration |
| Goal templates bundled with departments | Goals are company-specific strategy; generic goals would be misleading |
| Budget auto-assignment to template roles | Budget amounts are highly context-dependent |
| Template editing/customization before apply | Apply-then-edit workflow: apply standard template, edit individual roles via existing CRUD |
| Department deletion / rollback | Roles may have agents, tasks, or skills attached after creation |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| TMPL-01 | Pending | Pending |
| TMPL-02 | Pending | Pending |
| TMPL-03 | Pending | Pending |
| APPLY-01 | Pending | Pending |
| APPLY-02 | Pending | Pending |
| APPLY-03 | Pending | Pending |
| APPLY-04 | Pending | Pending |
| APPLY-05 | Pending | Pending |
| UI-01 | Pending | Pending |
| UI-02 | Pending | Pending |
| UI-03 | Pending | Pending |
| UI-04 | Pending | Pending |
| SKILL-01 | Pending | Pending |

**Coverage:**
- v1.5 requirements: 13 total
- Mapped to phases: 0
- Unmapped: 13 ⚠️

---
*Requirements defined: 2026-03-29*
*Last updated: 2026-03-29 after initial definition*
