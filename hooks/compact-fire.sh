#!/usr/bin/env bash
# stop (Stop): types "/compact <armed instructions>" once no subagent runs; else blocks turn end once per level.
# resume (SessionStart compact, main session only): renames handoff to .restored, points at it, types "next".
# Typed late, detached (TUI reads input after hook returns); Enter via send-key: send-text's \r pastes as newline.
in=$(cat)
eval "$(jq -r '@sh "sid=\(.session_id // "") aid=\(.agent_id // "")"' <<<"$in" 2>/dev/null)"
[ -n "$sid" ] || exit 0
d=${COMPACT_STATE_DIR:-/tmp}
type_later() {
  [ -n "$KITTY_WINDOW_ID" ] && [ -n "$KITTY_LISTEN_ON" ] || return 0
  setsid nohup bash -c 'sleep "$1"; kitty @ --to "$2" send-text --match "id:$3" "$4"; sleep "$5"
    kitty @ --to "$2" send-key --match "id:$3" enter' _ \
    "${COMPACT_FIRE_DELAY:-2}" "$KITTY_LISTEN_ON" "$KITTY_WINDOW_ID" "$1" "${COMPACT_ENTER_DELAY:-0.5}" </dev/null >/dev/null 2>&1 &
}
case "$1" in
  stop)
    af="$d/claude-compact-$sid.armed"; cf="$d/claude-agents-$sid"
    [ -n "$KITTY_WINDOW_ID" ] && [ -n "$KITTY_LISTEN_ON" ] || exit 0
    [ -s "$cf" ] && [ "$(grep -c '^S ' "$cf")" -gt "$(grep -c '^E ' "$cf")" ] && exit 0
    if [ -e "$af" ]; then
      # kitty send-text applies Python escape rules to its text
      instr=$(head -n1 "$af" | tr -d '\\')
      rm -f "$af" "$d/claude-compact-$sid.level" "$d/claude-compact-$sid.nagged"
      type_later "/compact $instr"
      exit 0
    fi
    # nagged holds the level already blocked for: one block per crossing, no loop; compact-watch clears it on reset
    lvl=$(cat "$d/claude-compact-$sid.level" 2>/dev/null); nf="$d/claude-compact-$sid.nagged"
    [ -n "$lvl" ] && [ "$(cat "$nf" 2>/dev/null)" != "$lvl" ] || exit 0
    echo "$lvl" >"$nf"
    jq -nc --arg r "compact-watch: context over the $lvl threshold and kitty-compact-handoff:compact-handoff has not run. The threshold is operator-set, not an anomaly. Run skill kitty-compact-handoff:compact-handoff (Skill tool) now if at a safe point; otherwise say why in one line and run it at the next safe point." \
      '{decision:"block",reason:$r}'
    ;;
  resume)
    hf="$d/claude-handoff-$sid.md"
    [ -z "$aid" ] && [ -e "$hf" ] || exit 0
    # renamed first so a stale handoff cannot re-trigger on a later compact
    mv -f "$hf" "$hf.restored" || exit 0
    jq -nc --arg m "compact-handoff resume: the session was just compacted by skill kitty-compact-handoff:compact-handoff. Re-read your project instructions (CLAUDE.md), then read $hf.restored and continue from its next step. Delete $hf.restored once restored." \
      '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$m}}'
    type_later next
    ;;
esac
exit 0
