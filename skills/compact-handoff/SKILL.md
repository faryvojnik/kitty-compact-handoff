---
name: compact-handoff
description: Run when a `compact-watch:` line appears in context, or on `/kitty-compact-handoff:compact-handoff`. Brings work to a safe point, persists all state to the issue tracker (if any) and a handoff file, then self-compacts via the Stop hook and resumes from the next step. Requires the kitty terminal.
---

# /compact-handoff

`$sid` = `$CLAUDE_SESSION_ID` (exported per session by the plugin's `hooks/session-id.sh`). Files:
`${COMPACT_STATE_DIR:-/tmp}/claude-handoff-$sid.md` (handoff), `${COMPACT_STATE_DIR:-/tmp}/claude-compact-$sid.armed`
(one line = `/compact` instructions), `${COMPACT_STATE_DIR:-/tmp}/claude-agents-$sid` (subagent counter: more `S` lines than `E` lines = subagents alive).

## Procedure

1. **Safe point.** No live subagents (counter file has more `S` than `E` lines), no question awaiting the user's
   answer, every parallel chain at a stable, recorded point (finish or park it and note where). Soft signal: may
   finish the current step first. Hard signal: start nothing new. Not at a safe point → say why in one line, end the
   turn, retry at the next safe point.
2. **Persist state.** If the project uses an issue tracker (e.g. bd/beads), create issues for untracked work, write a
   per-task handoff note (done, next step, paths/branches, open questions, decisions made in conversation) and set
   real statuses there. Otherwise all of this goes into the handoff file.
3. **Handoff file** `${COMPACT_STATE_DIR:-/tmp}/claude-handoff-$sid.md`, ≤~20 lines: active task ids, current step, next step, what to
   tell the user after resume.
4. **Arm or fall back.** Any of `$KITTY_WINDOW_ID`, `$KITTY_LISTEN_ON`, `$CLAUDE_SESSION_ID` empty → tell the user state is saved and ask them
   to run `/compact` themselves (the resume hook also fires on a manual `/compact`). Otherwise write the armed file —
   one line, no backslashes, no newlines: what the summary must keep (task ids, paths, next step) — tell the user in
   one line you are going to compact, and end the turn. The Stop hook types `/compact <instructions>`.
5. **After compact** (a `compact-handoff resume:` line arrives; the hook renamed the handoff file to
   `${COMPACT_STATE_DIR:-/tmp}/claude-handoff-$sid.md.restored`): re-read the project instructions (CLAUDE.md), the `.restored` file and
   the tracker ids listed in it; delete the `.restored` file; continue from the next step. The first reply says where
   work resumed.
