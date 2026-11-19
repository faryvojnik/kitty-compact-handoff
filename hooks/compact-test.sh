#!/usr/bin/env bash
# Self-check for compact-watch.sh, compact-fire.sh, agent-count.sh and session-id.sh: fake transcript, stub `kitty`
here=$(cd "$(dirname "$0")" && pwd)
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir "$t/bin"
printf '#!/bin/sh\necho "$*" >>"%s/kitty.log"\n' "$t" >"$t/bin/kitty"; chmod +x "$t/bin/kitty"
export PATH=$t/bin:$PATH COMPACT_STATE_DIR=$t COMPACT_SOFT=1000 COMPACT_HARD=2000 COMPACT_FIRE_DELAY=0 COMPACT_ENTER_DELAY=0
export KITTY_WINDOW_ID=7 KITTY_LISTEN_ON=unix:$t/sock
sid=s1; tr=$t/tr.jsonl; armed=$t/claude-compact-$sid.armed
fail=0
ok() { [ "$1" = 0 ] || { echo "FAIL: $2"; fail=1; }; }
tok() { printf '{"type":"assistant","message":{"usage":{"input_tokens":%s,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}\n' "$1" >>"$tr"; }
watch() { out=$(jq -nc --arg s "$sid" --arg t "$tr" --arg a "${1:-}" \
  '{session_id:$s,transcript_path:$t,hook_event_name:"PostToolUse"} + (if $a=="" then {} else {agent_id:$a} end)' \
  | bash "$here/compact-watch.sh"); }
fire() { rm -f "$t/kitty.log"; out=$(jq -nc --arg s "$sid" --arg a "${2:-}" '{session_id:$s} + (if $a=="" then {} else {agent_id:$a} end)' \
  | bash "$here/compact-fire.sh" "$1"); sleep 0.5; }

tok 500; watch; [ -z "$out" ]; ok $? "below soft: output: $out"
tok 1500; watch; [[ $out == *"soft 1K"*"not an anomaly"*"Before ending this turn"*"next safe point"* ]] && jq -e '.hookSpecificOutput.hookEventName=="PostToolUse"' <<<"$out" >/dev/null
ok $? "soft: $out"
watch; [ -z "$out" ]; ok $? "soft twice: output: $out"
tok 2500; watch; [[ $out == *"hard 2K"*"COMPACT_HARD"*"start nothing new"* ]]; ok $? "hard 1: $out"
watch; [[ $out == *"hard 2K"* ]]; ok $? "hard 2: $out"
watch sub; [ -z "$out" ]; ok $? "agent_id: output: $out"
echo 'keep the plan' >"$armed"
watch; [ -z "$out" ]; ok $? "hard armed: output: $out"
touch -d '-11 min' "$armed"; watch; [[ $out == *"armed for >10 min"* ]]; ok $? "hard armed stale: $out"
rm -f "$armed"
tok 500; watch; [ ! -e "$t/claude-compact-$sid.level" ]; ok $? "below soft: level file kept"
tok 1500; watch; [[ $out == *"soft 1K"* ]]; ok $? "soft after reset: $out"
echo '{"type":"attachment","attachment":{"usage":{"input_tokens":9999}}}' >>"$tr"
watch; [ -z "$out" ] && [ "$(cat "$t/claude-compact-$sid.level")" = soft ]; ok $? "non-assistant usage counted: $out"
tok 2500; echo '{"type":"system","subtype":"compact_boundary","content":"Conversation compacted"}' >>"$tr"
watch; [ -z "$out" ] && [ ! -e "$t/claude-compact-$sid.level" ]; ok $? "pre-compact usage counted: $out"

echo 'T-1' >"$armed"
af=$t/claude-agents-$sid; now=$(date +%s)
ac() { jq -nc --arg s "$sid" --arg a "$2" '{session_id:$s,agent_id:$a,agent_type:"worker"}' | bash "$here/agent-count.sh" "$1"; }
printf 'S %s old x\n' $((now - 10800)) >"$af"
ac start a1; [ "$(bash "$here/agent-count.sh" live "$af")" = 1 ] && [[ $(tail -n1 "$af") == "S "*" a1" ]]
ok $? "start, stale S ignored: live=$(bash "$here/agent-count.sh" live "$af") file=$(cat "$af")"
fire stop; [ -e "$armed" ] && [ ! -e "$t/kitty.log" ]; ok $? "fresh open id: armed gone or sent"
printf 'E %s other\n' "$now" >>"$af"
(unset KITTY_WINDOW_ID; fire stop; [ -e "$armed" ] && [ ! -e "$t/kitty.log" ]); ok $? "no kitty env: armed gone or sent"
fire stop; [ -e "$armed" ] && [ ! -e "$t/kitty.log" ]; ok $? "E of other id closed S: armed gone or sent"
ac end a1; [[ $(tail -n1 "$af") == "E "*" a1" ]]; ok $? "end: $(tail -n1 "$af")"
[ "$(bash "$here/agent-count.sh" live "$t/missing")" = 0 ]; ok $? "live missing file"
fire stop
[ ! -e "$armed" ] && [ "$(cat "$t/kitty.log")" = "@ --to unix:$t/sock send-text --match id:7 /compact Keep what $t/claude-handoff-$sid.md lists: task ids, paths, next step.
@ --to unix:$t/sock send-key --match id:7 enter" ]
ok $? "stop: armed=$(ls "$armed" 2>/dev/null) log=$(cat "$t/kitty.log" 2>/dev/null)"
[ "$(head -n1 "$t/kitty.log" | sed 's/.*send-text --match id:7 //' | wc -c)" -lt 400 ]; ok $? "stop: send-text payload >=400 chars"
nf=$t/claude-compact-$sid.nagged; echo soft >"$t/claude-compact-$sid.level"
KITTY_WINDOW_ID= fire stop; [ -z "$out" ] && [ ! -e "$nf" ]; ok $? "level, no kitty: $out"
ac start a2
fire stop; [ -z "$out" ]; ok $? "level + live subagent: $out"
ac end a2
fire stop; jq -e '.decision=="block" and (.reason|contains("soft threshold") and contains("not an anomaly") and contains("next safe point"))' <<<"$out" >/dev/null
ok $? "stop level no armed: $out"
fire stop; [ -z "$out" ]; ok $? "stop after block, same level: $out"
echo hard >"$t/claude-compact-$sid.level"
fire stop; jq -e '.decision=="block" and (.reason|contains("hard threshold"))' <<<"$out" >/dev/null; ok $? "soft->hard after nag: $out"
fire stop; [ -z "$out" ]; ok $? "stop after hard block: $out"
tok 500; watch; [ ! -e "$nf" ] && [ ! -e "$t/claude-compact-$sid.level" ]; ok $? "below soft: nagged cleared"

fire resume; [ -z "$out" ] && [ ! -e "$t/kitty.log" ]; ok $? "resume no handoff: $out"
hf=$t/claude-handoff-$sid.md; echo h >"$hf"
fire resume sub; [ -z "$out" ] && [ -e "$hf" ] && [ ! -e "$t/kitty.log" ]; ok $? "resume agent_id: $out"
fire resume; [ ! -e "$hf" ] && [ -e "$hf.restored" ]; ok $? "resume: handoff not renamed"
jq -e --arg p "$hf.restored" '.hookSpecificOutput.hookEventName=="SessionStart" and (.hookSpecificOutput.additionalContext|contains($p))' <<<"$out" >/dev/null \
  && [ "$(cat "$t/kitty.log")" = "@ --to unix:$t/sock send-text --match id:7 next
@ --to unix:$t/sock send-key --match id:7 enter" ]
ok $? "resume: out=$out log=$(cat "$t/kitty.log" 2>/dev/null)"

jq -nc --arg s "$sid" '{session_id:$s}' >"$t/in.json"
CLAUDE_ENV_FILE=$t/env bash "$here/session-id.sh" <"$t/in.json"
[ "$(cat "$t/env")" = "export CLAUDE_SESSION_ID=s1" ]; ok $? "session-id: $(cat "$t/env" 2>/dev/null)"

[ $fail = 0 ] && echo "compact-test: all passed"
exit $fail
