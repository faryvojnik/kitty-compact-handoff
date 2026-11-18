#!/usr/bin/env bash
# start/end (SubagentStart/SubagentStop): log subagent lifetime by agent_id to $COMPACT_STATE_DIR/claude-agents-<sid>.
# live <file>: prints the number of open agents for compact-fire.sh.
if [ "$1" = live ]; then
  [ -s "$2" ] || { echo 0; exit 0; }
  # ponytail: unstopped S expires after COMPACT_AGENT_STALE_MIN (120) min; revisit-after: lost SubagentStop ruled out
  awk -v min=$(($(date +%s) - ${COMPACT_AGENT_STALE_MIN:-120} * 60)) '
    $1 == "S" { ts[$3] = $2 } $1 == "E" { done[$3] = 1 }
    END { n = 0; for (i in ts) if (!(i in done) && ts[i] > min) n++; print n }' "$2"
  exit 0
fi
in=$(cat)
eval "$(jq -r '@sh "sid=\(.session_id // "unknown") aid=\(.agent_id // "")"' <<<"$in")"
[ -n "$aid" ] || exit 0
f="${COMPACT_STATE_DIR:-/tmp}/claude-agents-$sid"
case "$1" in
  start) printf 'S %s %s\n' "$(date +%s)" "$aid" >> "$f" ;;
  end)   printf 'E %s %s\n' "$(date +%s)" "$aid" >> "$f" ;;
esac
exit 0
