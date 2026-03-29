---
phase: 28-templates-browse-and-apply-ui
plan: "01"
subsystem: ui
tags: [rails, hotwire, turbo, stimulus, erb, css, role-templates]

# Dependency graph
requires:
  - phase: 26-template-data-and-registry
    provides: RoleTemplateRegistry with all/find, Template and TemplateRole value objects, 5 YAML department template files
  - phase: 27-template-application-service
    provides: ApplyRoleTemplateService.call(company:, template_key:) returning Result with success?, summary, errors

provides:
  - RoleTemplatesController with index, show, apply actions
  - Browse page at /role_templates with template card grid
  - Detail page at /role_templates/:key with hierarchy tree visualization
  - POST /role_templates/:id/apply action wired to ApplyRoleTemplateService
  - CSS for templates-page, templates-grid, template-card, template-detail, hierarchy-tree components

affects: [phase-28, navigation, roles-ui]

# Tech tracking
tech-stack:
  added: []
  patterns: [controller-delegates-to-service, string-key-resource-id, lambda-tree-renderer, BEM-component-css]

key-files:
  created:
    - app/controllers/role_templates_controller.rb
    - app/views/role_templates/index.html.erb
    - app/views/role_templates/show.html.erb
  modified:
    - config/routes.rb
    - app/assets/stylesheets/application.css

key-decisions:
  - "params[:id] used as string template key — not integer DB ID, maps to RoleTemplateRegistry.find(key)"
  - "TemplateNotFound rescued and re-raised as RecordNotFound for standard 404 rendering"
  - "Hierarchy tree rendered via ERB lambda (render_tree) avoiding a partial or helper for self-contained simplicity"
  - "Apply action uses standard POST -> redirect pattern with flash (locked decision from 28-CONTEXT.md)"
  - "CSS appended as new @layer components block following existing file pattern"

patterns-established:
  - "String-keyed resources: controller uses params[:id] as a string key, rescues domain NotFound to RecordNotFound"
  - "Lambda tree renderer: recursive ERB lambda for tree structure instead of recursive partial"
  - "Card-as-link: entire template card is wrapped in link_to for full-card click target"

requirements_covered:
  - id: "UI-01"
    description: "Browse page listing all department templates"
    evidence: "app/views/role_templates/index.html.erb"
  - id: "UI-02"
    description: "Detail page with role hierarchy tree"
    evidence: "app/views/role_templates/show.html.erb"
  - id: "UI-03"
    description: "One-click apply action with flash feedback"
    evidence: "app/controllers/role_templates_controller.rb#apply"

# Metrics
duration: 12min
completed: 2026-03-29
---

# Plan 28-01: Role Templates Browse and Apply UI Summary

**Full user-facing UI for role templates: card browse grid at /role_templates, hierarchy tree detail at /role_templates/:key, and one-click POST apply action wired to ApplyRoleTemplateService**

## Performance

- **Duration:** 12 min
- **Started:** 2026-03-29T16:22:00Z
- **Completed:** 2026-03-29T16:34:30Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments

- RoleTemplatesController with index, show, and apply actions delegating to RoleTemplateRegistry and ApplyRoleTemplateService
- index.html.erb renders a responsive card grid showing all 5 department templates with name, description, and role count
- show.html.erb renders a full hierarchy tree using HTML entity tree-line characters (├── └──) with recursive ERB lambda, plus skill badges reusing existing `.skill-badge` class
- apply action uses standard POST -> redirect with flash notice (success) or alert (errors), with turbo_confirm dialog on the button
- CSS component set covering browse page layout, card grid, card hover states, detail page, and hierarchy tree nodes — all using existing design tokens and logical properties

## Task Commits

Each task was committed atomically:

1. **Task 1: Create routes and RoleTemplatesController** - `ec86941` (feat)
2. **Task 2: Create index and show view templates** - `34ac72e` (feat)
3. **Task 3: Add CSS for template pages** - `c4a2210` (feat)

## Files Created/Modified

- `config/routes.rb` - Added role_templates resource with index, show, member apply routes
- `app/controllers/role_templates_controller.rb` - Controller delegating to RoleTemplateRegistry and ApplyRoleTemplateService
- `app/views/role_templates/index.html.erb` - Card grid browse page with pluralized role count
- `app/views/role_templates/show.html.erb` - Hierarchy tree with tree-line chars, descriptions, skill badges, apply button
- `app/assets/stylesheets/application.css` - New @layer components block with templates-page, template-card, template-detail, hierarchy-tree CSS

## Decisions Made

- `params[:id]` serves as the template key (string like "engineering"), not an integer DB ID — `RoleTemplateRegistry.find(key)` handles lookup, `TemplateNotFound` is rescued and re-raised as `ActiveRecord::RecordNotFound` for standard 404 handling
- Hierarchy tree rendered using a recursive lambda in ERB rather than a recursive partial — keeps the tree logic self-contained in one file
- Entire template card wrapped in `link_to` (card-as-link pattern) for maximum click target area
- `button_to` with `data-turbo-confirm` on the apply button — warns user about role count before creating

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 28-01 is the only plan in phase 28 — the full v1.5 UI is now shipped
- All 5 department templates (Engineering, Finance, Human Resources, Marketing, Operations) are browsable and applyable
- The apply flow is end-to-end: controller -> ApplyRoleTemplateService -> roles created -> redirect to /roles with summary flash
- v1.5 Role Templates feature is complete across phases 26, 27, and 28

---
*Phase: 28-templates-browse-and-apply-ui*
*Completed: 2026-03-29*

## Self-Check: PASSED

- config/routes.rb - FOUND
- app/controllers/role_templates_controller.rb - FOUND
- app/views/role_templates/index.html.erb - FOUND
- app/views/role_templates/show.html.erb - FOUND
- 28-01-SUMMARY.md - FOUND
- Commit ec86941 (Task 1) - FOUND
- Commit 34ac72e (Task 2) - FOUND
- Commit c4a2210 (Task 3) - FOUND
