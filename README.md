# kitty-compact-handoff

**Requires the kitty terminal (remote control enabled); does not self-compact in other terminals.**

A Claude Code session approaching its context limit saves its state, compacts itself and resumes
without the user typing anything.

## How it works

1. `compact-watch` (UserPromptSubmit / PostToolUse hook) reads token usage from the transcript. Past the soft or
   hard threshold it nudges the model to run the `compact-handoff` skill.
2. The skill persists state to `/tmp/claude-handoff-<sid>.md` and writes an armed flag file.
3. The Stop hook waits until no subagent is running (SubagentStart/SubagentStop paired by `agent_id`), then types a fixed short `/compact` line pointing at the handoff file into the kitty window
   via `kitty @ send-text` + `send-key enter`.
4. The SessionStart `compact` hook renames the handoff file to `.restored` and types `next`; the model re-reads
   the file and continues.

## Requirements

- kitty terminal with `allow_remote_control socket-only` (or `yes`) and `listen_on unix:/tmp/kitty` in `kitty.conf`,
  Claude Code started inside kitty
- Linux, jq, GNU coreutils/findutils, util-linux (`setsid`)

Degraded mode without kitty: the skill only saves state and asks you to run `/compact` yourself.

## Install

```
/plugin marketplace add faryvojnik/kitty-compact-handoff
/plugin install kitty-compact-handoff@kitty-compact-handoff
```

If you wired these hooks into `settings.json` by hand, remove them first, or both copies fire.

## Configuration

Environment variables:

| variable | default | meaning |
|---|---|---|
| `COMPACT_SOFT` | `800000` | soft threshold, tokens |
| `COMPACT_HARD` | `950000` | hard threshold, tokens |
| `COMPACT_STATE_DIR` | `/tmp` | where state files live |
| `COMPACT_FIRE_DELAY` | `2` | seconds before typing `/compact` |
| `COMPACT_ENTER_DELAY` | `0.5` | seconds between text and Enter |
| `COMPACT_AGENT_STALE_MIN` | `120` | minutes after which a subagent start with no matching stop counts as dead |

The defaults assume a 1M-token context window; with a 200K window set `COMPACT_SOFT`/`COMPACT_HARD` lower
(e.g. `150000`/`180000`).

## Test

```
bash hooks/compact-test.sh
```

## License

MIT
