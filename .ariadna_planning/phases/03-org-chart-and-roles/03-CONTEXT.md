# Phase 3: Org Chart & Roles — Context

## Decisions

### Org Chart Visualization: SVG Tree
Stimulus controller calculates node positions and draws SVG `<path>` elements for connecting lines. Role nodes rendered as `foreignObject` elements inside the SVG so they can use standard HTML/CSS. Provides precise control over line styling and node positioning.

### Hierarchy Management: Dropdown Parent Selector
When creating or editing a role, users select the parent role from a standard `<select>` dropdown. Works with standard Rails forms and Turbo. No drag-and-drop or JS sorting libraries needed.

### Agent Assignment: Empty Slot Indicator
Each role card shows an "Unassigned" placeholder for the agent field. Phase 4 will replace this with an actual agent selector. The `agent_id` column exists on the Role model as a nullable foreign key, ready for Phase 4.

## Claude's Discretion

- Role card design and layout details
- SVG tree layout algorithm (top-down vs left-right, spacing)
- Form field ordering and validation UX
- How to handle deep hierarchies (scrolling, zooming)

## Deferred Ideas

- Drag-and-drop reordering of roles in the tree
- Collapsible tree sections
- Export org chart as image
