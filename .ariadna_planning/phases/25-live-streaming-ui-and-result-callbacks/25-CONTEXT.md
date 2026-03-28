# Phase 25 Context: Live Streaming UI and Result Callbacks

## Decisions

1. **Streaming approach**: Action Cable + Turbo Streams via `turbo_stream_from` — consistent with Phase 22 broadcast infrastructure already in place.
2. **Output rendering**: Raw terminal output in monospace pre-formatted text, streamed as-is. No markdown parsing or collapsible sections.
3. **Cancel UX**: Immediate kill — click cancel → kill tmux session → mark run cancelled. No confirmation dialog.

## Claude's Discretion

- Broadcast batching strategy (how often to flush buffered lines)
- Exact HTML/CSS structure of the streaming output container
- API authentication method for result callbacks (token-based)
- Whether to use `after_create_commit` or explicit broadcasts for status changes
