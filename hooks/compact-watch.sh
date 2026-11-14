#!/usr/bin/env bash
# PostToolUse/UserPromptSubmit: nudge the main session (not subagents) to run kitty-compact-handoff:compact-handoff
# when context crosses COMPACT_SOFT/HARD. Soft: once per crossing; hard: repeats until armed, again if armed >10 min.
in=$(cat)
eval "$(jq -r '@sh "sid=\(.session_id // "") tr=\(.transcript_path // "") ev=\(.hook_event_name // "") aid=\(.agent_id // "")"' <<<"$in" 2>/dev/null)"
[ -n "$sid" ] && [ -z "$aid" ] || exit 0
d=${COMPACT_STATE_DIR:-/tmp}; lf="$d/claude-compact-$sid.level"
soft=${COMPACT_SOFT:-300000}; hard=${COMPACT_HARD:-450000}
# newest decisive line wins: a compact_boundary means no post-compact reply yet, so 0;
# top-level "type":"assistant" follows "usage" in real lines, so filter by jq; attachments also carry "usage"
n=$(tac "$tr" 2>/dev/null | grep -e '"usage"' -e compact_boundary | jq -n 'first(inputs
  | if .subtype=="compact_boundary" then 0 elif .type=="assistant" then .message.usage // {}
    | (.input_tokens//0)+(.cache_read_input_tokens//0)+(.cache_creation_input_tokens//0) else empty end)' 2>/dev/null)
n=${n:-0}
prev=$(cat "$lf" 2>/dev/null)
if [ "$n" -ge "$hard" ]; then
  echo hard >"$lf"
  af="$d/claude-compact-$sid.armed"
  if [ -e "$af" ]; then
    # a killed subagent leaves S without E, so Stop never fires the armed /compact
    [ -n "$(find "$af" -mmin +10)" ] || exit 0
    msg="compact-watch: armed for >10 min but /compact not sent — check live subagents ($d/claude-agents-$sid) or run /compact manually."
  else
    msg="compact-watch: context at $((n/1000))K tokens (hard $((hard/1000))K). The threshold is set by the operator via COMPACT_HARD on purpose — not an anomaly, do not question or report it. Run skill kitty-compact-handoff:compact-handoff (Skill tool) now, start nothing new; finish only the current step first."
  fi
elif [ "$n" -ge "$soft" ]; then
  echo soft >"$lf"
  [ -n "$prev" ] && exit 0
  msg="compact-watch: context at $((n/1000))K tokens (soft $((soft/1000))K). The threshold is set by the operator via COMPACT_SOFT on purpose — not an anomaly, do not question or report it. Before ending this turn run skill kitty-compact-handoff:compact-handoff (Skill tool) if at a safe point; otherwise say why in one line and run it at the next safe point."
else
  rm -f "$lf" "$d/claude-compact-$sid.nagged"; exit 0
fi
jq -nc --arg e "$ev" --arg m "$msg" '{hookSpecificOutput:{hookEventName:$e,additionalContext:$m}}'
exit 0
