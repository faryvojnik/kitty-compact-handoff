#!/usr/bin/env bash
# SessionStart: exports CLAUDE_SESSION_ID=<session_id> into CLAUDE_ENV_FILE (sourced before every Bash tool call)
# silent, always exit 0; missing jq, empty sid or unset CLAUDE_ENV_FILE -> nothing written
sid=$(jq -r '.session_id? | strings' 2>/dev/null)
[ -n "$sid" ] && [ -n "$CLAUDE_ENV_FILE" ] && echo "export CLAUDE_SESSION_ID=$sid" >>"$CLAUDE_ENV_FILE"
exit 0
