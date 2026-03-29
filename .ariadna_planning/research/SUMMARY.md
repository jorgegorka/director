# Research Summary: v1.5 Role Templates

**Domain:** AI agent orchestration platform -- builtin department templates
**Researched:** 2026-03-29
**Overall confidence:** HIGH

## Executive Summary

Role templates for Director v1.5 is a lightweight, zero-dependency feature that extends the existing skill seeding pattern to create entire department hierarchies from YAML definitions. The feature requires no new gems, no database migrations, and no new system dependencies. Everything needed already exists in the codebase: YAML loading (stdlib), `find_or_create_by!` (ActiveRecord), TreeHierarchy concern (parent/child role trees), and the RoleSkill join table for skill assignments.

The implementation follows the exact pattern established in v1.2 for builtin skills. YAML files in `db/seeds/role_templates/` define department hierarchies (Engineering, Marketing, Operations, Finance, HR). A `RoleTemplateRegistry` class (plain Ruby, not ActiveRecord) loads and caches these files. An `ApplyRoleTemplateService` creates roles depth-first with skip-duplicate logic -- if a role with the same title already exists, it is left untouched. Skills are pre-assigned at creation time by referencing existing skill keys. The UI is a standard Rails controller with three actions: browse (index), preview (show), and apply (POST).

The dominant risks are operational, not technical. The most critical pitfalls are: (1) parent ordering in YAML -- children must appear after their parents in the flat role list, (2) ConfigVersioned callbacks firing for every bulk-created role (creating audit noise), (3) cross-tenant skill lookups if the service forgets to scope through `company.skills`, and (4) case-sensitive title matching in SQLite making skip-duplicate logic unreliable with user-created roles. All have straightforward mitigations documented in PITFALLS.md.

This is the most straightforward milestone in Director's history. No subprocess management, no streaming, no external APIs. The entire feature is reading YAML, creating ActiveRecord objects in the right order, and rendering HTML.

## Key Findings

**Stack:** No new gems. No migrations. YAML files + plain Ruby class + service object + standard controller. Direct extension of v1.2 skill seeding pattern.

**Architecture:** YAML-only templates (no RoleTemplate database model). `RoleTemplateRegistry` loads/caches definitions. `ApplyRoleTemplateService` walks the role list in dependency order, creating roles with `find_or_create_by!` semantics and assigning skills from the company's existing skill library.

**Critical pitfall:** Parent ordering in YAML templates -- if a child role appears before its parent in the flat list, the parent reference resolves to nil and the role becomes an orphan root. Prevention: validate ordering at load time and test every template file.

## Implications for Roadmap

Based on research, suggested phase structure:

1. **Template Data and Registry** - Foundation phase
   - Addresses: YAML template definitions (5 departments), RoleTemplateRegistry loading/caching, template validation tests
   - Avoids: Parent ordering errors (Pitfall 1 from PITFALLS.md) by validating at load time

2. **Application Service** - Core business logic
   - Addresses: ApplyRoleTemplateService with skip-duplicate logic, skill pre-assignment, structured Result object
   - Avoids: Cross-tenant skill references (always scope through company), partial application issues, ConfigVersion noise

3. **Browse, Preview, and Apply UI** - User-facing layer
   - Addresses: RoleTemplatesController (index, show, apply), template card grid, hierarchy preview tree, flash feedback
   - Avoids: Double-click race conditions (Turbo auto-disables), missing attach point (user selects parent)

**Phase ordering rationale:**
- Registry first because both the service and controller depend on being able to load template data
- Service before UI because the controller delegates to the service; testing the service in isolation catches logic bugs before adding the HTTP layer
- UI last because it composes the registry and service into user-facing flows

**Research flags for phases:**
- Phase 1 (Registry): Standard patterns. YAML loading is identical to skill seeding. No research needed during planning.
- Phase 2 (Service): One design decision to resolve during planning: whether to wrap creation in a transaction (all-or-nothing) or allow partial success. PITFALLS.md documents arguments for both. Recommend allowing partial success (no transaction), matching the additive skip-duplicate philosophy.
- Phase 3 (UI): Standard Rails controller + views. No research needed during planning.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Zero new dependencies confirmed. All patterns verified in existing codebase. |
| Features | HIGH | Requirements clearly defined in PROJECT.md. Feature scope is narrow and well-bounded. |
| Architecture | HIGH | Direct extension of v1.2 skill seeding pattern. Every component has a codebase precedent. |
| Pitfalls | HIGH | 14 pitfalls identified from direct codebase analysis. Critical ones have verified prevention strategies. |

## Gaps to Address

- **Template content quality:** The research defines the YAML structure and which departments to include, but the actual content (job specs, skill assignments per role) requires careful authoring during Phase 1. Job specs should be written as meaningful agent instructions, not placeholder text.

- **ConfigVersioned callback behavior during bulk creation:** PITFALLS.md documents the issue (5-8 ConfigVersion records created per template application). Whether to suppress callbacks, batch them, or accept the audit noise is a design decision for Phase 2 planning. Recommend accepting the noise for v1.5 simplicity and revisiting if audit trail becomes cluttered.

- **Case-sensitive title matching:** SQLite's binary collation means "CTO" and "cto" are different titles. PITFALLS.md documents `COLLATE NOCASE` mitigation. Whether to add title normalization is a design decision for Phase 2. Recommend adding `before_validation :normalize_title` (strip + squeeze) to the Role model as a quick win, deferring COLLATE NOCASE index change.

---
*Research completed: 2026-03-29*
*Ready for roadmap: yes*
