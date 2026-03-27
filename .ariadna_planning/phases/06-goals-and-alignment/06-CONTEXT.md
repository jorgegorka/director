# Phase 6: Goals & Alignment — Context

## Decisions

### Goal hierarchy: Self-referential tree
Single `Goal` model with `parent_id` — flexible nesting, consistent with the `Role` pattern already in the codebase. Mission is a goal with no parent, objectives are children, sub-objectives nest further. No fixed levels or type enforcement.

### Task-to-goal linking: goal_id foreign key on Task
Add a nullable `goal_id` FK to the existing tasks table. Simple, direct — tasks can exist without goals. No polymorphic hierarchy or shared tree with goals.

### Progress roll-up: Simple percentage
`completed tasks / total tasks` under a goal, rolled up recursively through the goal tree. No weights or points.

## Claude's Discretion

- Goal CRUD UI design (list vs tree view)
- Whether to add a "mission" display on the company show page or a dedicated goals page
- Goal model validations and scopes
- How the progress percentage is displayed (progress bar, percentage text, etc.)

## Deferred Ideas

None.
