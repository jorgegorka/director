# Phase 17: Agent Skill Management — Context

## Decisions

### Skill Assignment UI: Inline Checkboxes
On the agent show page, display all company skills as checkboxes grouped by category. Checked = assigned to agent, unchecked = not assigned. Toggling a checkbox immediately creates/destroys the AgentSkill record (via Turbo or form submission). This replaces the current read-only skill badge display.

### Skill Removal: Via Checkbox Toggle
No separate removal UI needed — unchecking a checkbox in the inline list removes the skill. Same mechanism as assignment.

### Agent Card/Partial: Skill Names as Tags
Show first 3-4 skill names as small inline tags with "+N more" overflow text when there are more. Replaces current "N skills" count-only display.

## Claude's Discretion

- Checkbox grouping by category (collapsible sections vs flat list)
- Whether checkbox toggles use Turbo Frames, Turbo Streams, or standard form POST
- CSS styling details for checkbox list and skill tags in card
- How to handle the 50-skill list (scrollable area, category accordion, etc.)

## Deferred Ideas

- Search/filter within checkbox list (can add later if 50 skills feels unwieldy)
- Drag-and-drop skill ordering
- Skill recommendations based on role
