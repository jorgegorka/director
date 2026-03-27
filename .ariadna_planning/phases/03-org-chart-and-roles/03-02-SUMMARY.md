---
phase: 03-org-chart-and-roles
plan: "02"
status: complete
started_at: 2026-03-27T07:53:48Z
completed_at: 2026-03-27T07:56:24Z
duration_seconds: 156
tasks_completed: 2
tasks_total: 2
files_changed: 8
---

# Plan 03-02 Summary: Visual Org Chart SVG Tree

## Objective

Built the visual org chart as an SVG tree that renders the company's role hierarchy with connecting lines and interactive nodes. Delivers ORG-04 (company org chart renders as a visual tree showing roles, hierarchy, and assignments) and completes the visual aspect of ORG-03 (hierarchical reporting lines visible as a tree).

## Tasks Completed

### Task 1: OrgChartsController, route, view, helper, and tests
**Commit:** `56356f0`

- **Route** (`config/routes.rb`): `resource :org_chart, only: [:show]` — creates GET /org_chart -> org_charts#show
- **OrgChartsController** (`app/controllers/org_charts_controller.rb`): `require_company!` guard, loads all company roles with eager loading of `:parent` and `:children`, separates root roles via `.select(&:root?)` on already-loaded collection (no extra query)
- **OrgChartsHelper** (`app/helpers/org_charts_helper.rb`): `roles_tree_data(root_roles)` recursively builds nested JSON tree structure with id, title, description (truncated to 80 chars), url, agent_name (nil placeholder for Phase 4), and children array
- **Org chart view** (`app/views/org_charts/show.html.erb`): page header with New Role and All Roles buttons; SVG container with `data-controller="org-chart"` and `data-org-chart-roles-value` JSON attribute for Stimulus; empty state shown when no roles exist
- **Home page** (`app/views/home/show.html.erb`): updated nav to show "Org Chart" (linking to org_chart_path) and "Roles" (linking to roles_path) as separate links alongside "Team"
- **7 controller tests**: auth gate, page renders, Stimulus container presence, JSON data content, cross-company isolation check on data attribute, empty state, redirect for user without company — all pass

### Task 2: Stimulus org chart controller with SVG tree layout and CSS
**Commit:** `5ef376f`

- **Stimulus controller** (`app/javascript/controllers/org_chart_controller.js`):
  - `rolesValue` (Array type) and `svgTarget` configured via static declarations
  - `connect()` calls `render()` on initialization
  - `calculateLayout(roots)`: bottom-up subtree width calculation (leaf = NODE_WIDTH, internal = max(NODE_WIDTH, sum of children widths + gaps)), then top-down position assignment centering each node above its subtree; multiple roots laid out side by side
  - `drawConnection(svg, conn)`: cubic bezier SVG path (`M x1 y1 C x1 midY, x2 midY, x2 y2`) with class `org-chart-line`
  - `drawNode(svg, node)`: SVG foreignObject containing programmatically-built DOM tree — title, agent dot + text ("Unassigned" or agent name), optional description. All user text set via `element.textContent` (never innerHTML) — XSS safe
  - Constants: NODE_WIDTH=220, NODE_HEIGHT=100, HORIZONTAL_GAP=40, VERTICAL_GAP=80, PADDING=40
- **CSS** (`app/assets/stylesheets/application.css`): added inside `@layer components`:
  - `.org-chart-page`: no max-width (full width for chart)
  - `.org-chart-page__header`: flex row with h1 pushing buttons right via `margin-inline-end: auto`
  - `.org-chart-page__empty`: centered, padded, muted text
  - `.org-chart-container`: overflow auto (scrolls large trees), surface background, border, border-radius, min-block-size 20rem
  - `.org-chart-svg`: block display, centered with margin-inline auto
  - `.org-chart-line`: OKLCH neutral-300 stroke, 2px width, round caps
  - `.org-chart-node__link`: flex column, surface background, border with hover brand highlight, shadow transition, translateY(-1px) on hover
  - `.org-chart-node__title`, `.org-chart-node__agent`, `.org-chart-node__dot`, `.org-chart-node__dot--unassigned`, `.org-chart-node__dot--active`, `.org-chart-node__desc`: full node card styling
  - Dark mode: `.org-chart-line` stroke changes to neutral-500

## Deviations

None. Plan executed as specified.

## Verification Results

| Check | Result |
|-------|--------|
| `bin/rails routes \| grep org_chart` | GET /org_chart -> org_charts#show |
| `bin/rails test test/controllers/org_charts_controller_test.rb` | 7 runs, 22 assertions, 0 failures |
| `bin/rails test` | 127 tests, 338 assertions, 0 failures, 0 errors, 0 skips |
| `bin/rubocop` | 77 files inspected, no offenses |
| `bin/brakeman --quiet --no-pager` | 0 security warnings |

## Key Design Decisions

- **foreignObject for nodes**: Using SVG foreignObject with HTML inside allows full CSS styling of role cards (hover effects, shadows, overflow ellipsis) while keeping the tree layout in SVG coordinates
- **Programmatic DOM construction**: All node HTML is built via `createElement`/`textContent`/`appendChild` — never string interpolation or innerHTML with user data. This prevents XSS even though role data comes from the server
- **Bottom-up + top-down layout**: Standard tree layout algorithm — calculate subtree widths bottom-up, then assign positions top-down centering each node above its subtree. O(n) and handles arbitrary depth/width
- **Multiple roots**: Root nodes each get their own subtree width, laid out left to right with HORIZONTAL_GAP between them
- **No extra DB queries**: `.select(&:root?)` filters on the already-loaded `@roles` collection; `.includes(:parent, :children)` prevents N+1 when building the helper's tree structure
- **agent_name: nil placeholder**: The JSON tree embeds agent_name as null for all nodes. Nodes render "Unassigned" with neutral dot. Phase 4 will populate real agent names and switch to `--active` dot styling

## Success Criteria Status

- [x] GET /org_chart renders the org chart page for the current company
- [x] SVG tree shows all roles as nodes with connecting curved lines representing hierarchy
- [x] Role nodes are HTML inside foreignObject elements, styled with standard CSS
- [x] Each node shows title, "Unassigned" agent placeholder, and truncated description
- [x] Clicking a node navigates to the role detail page (/roles/:id)
- [x] Multiple root roles render as separate trees side by side
- [x] Large trees scroll within the container (overflow: auto on container)
- [x] Empty state with "Create a role" CTA shown when company has no roles
- [x] Home page nav has both "Org Chart" and "Roles" links
- [x] `bin/rails test` passes with zero failures (127 tests)
- [x] `bin/rubocop` and `bin/brakeman` pass clean

## Commits

| Hash | Description |
|------|-------------|
| `56356f0` | feat(03-02): OrgChartsController, routes, view, helper, and tests |
| `5ef376f` | feat(03-02): Stimulus org chart controller with SVG tree layout and CSS |

## Self-Check: PASSED
