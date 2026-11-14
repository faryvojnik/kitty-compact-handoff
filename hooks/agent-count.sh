#!/usr/bin/env bash
# Subagent start/end counter read by compact-fire.sh: S/E lines in $COMPACT_STATE_DIR/claude-agents-<sid> (default /tmp)
in=$(cat)
sid=$(jq -r '.session_id // "unknown"' <<<"$in")
f="${COMPACT_STATE_DIR:-/tmp}/claude-agents-$sid"
case "$1" in
  start) printf 'S %s %s\n' "$(date +%s)" "$(jq -r '.tool_input.description // "agent"' <<<"$in" | tr -d '\n')" >> "$f" ;;
  end)   printf 'E %s\n' "$(date +%s)" >> "$f" ;;
esac
exit 0
