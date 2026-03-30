# Phase 28 Context: Templates Browse and Apply UI

## Decisions

- **Hierarchy tree visualization**: Indented list with tree-line characters (├── └──) — matches existing roles-list patterns, low CSS complexity
- **Apply action UX**: Standard POST → redirect to roles index with flash message summarizing created/skipped — matches existing button_to + redirect patterns throughout the app

## Claude's Discretion

- Card grid layout for browse page (columns, card content density)
- CSS class naming and structure (follow existing BEM patterns)
- Route naming and controller structure

## Deferred Ideas

- None identified
