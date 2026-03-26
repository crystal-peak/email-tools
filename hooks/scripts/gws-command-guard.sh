#!/bin/bash
# gws-command-guard.sh — PreToolUse hook for Bash
# Validates and corrects gws CLI commands before execution.
# Reads the tool input JSON from stdin.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Only check gws commands
if [[ -z "$COMMAND" ]] || ! echo "$COMMAND" | grep -q 'gws' 2>/dev/null; then
  exit 0
fi

ERRORS=""

# 1. Catch "gws gmail list" or "gws gmail get" etc (missing "users" resource level)
if echo "$COMMAND" | grep -qE 'gws gmail (list|get|trash|modify|delete|send|batchModify|batchDelete)' 2>/dev/null; then
  ERRORS="${ERRORS}- Bad command: 'gws gmail <method>' is missing the resource path. Use 'gws gmail users messages <method>' or a helper like 'gws gmail +triage'.\n"
fi

# 2. Catch "gws gmail messages ..." (missing "users")
if echo "$COMMAND" | grep -qE 'gws gmail messages ' 2>/dev/null; then
  ERRORS="${ERRORS}- Bad command: 'gws gmail messages ...' is missing 'users'. Use 'gws gmail users messages ...'.\n"
fi

# 3. Catch "gws gmail labels ..." (missing "users")
if echo "$COMMAND" | grep -qE 'gws gmail labels ' 2>/dev/null; then
  ERRORS="${ERRORS}- Bad command: 'gws gmail labels ...' is missing 'users'. Use 'gws gmail users labels ...'.\n"
fi

# 4. Catch --user-id on API methods (not helper +commands)
if echo "$COMMAND" | grep -qE 'gws gmail users' 2>/dev/null && echo "$COMMAND" | grep -qE '\-\-user-id' 2>/dev/null; then
  ERRORS="${ERRORS}- Bad flag: '--user-id' is not valid. Pass userId inside --params JSON: --params '{\"userId\":\"me\",...}'\n"
fi

# 5. Catch --message-id on API methods (helpers use it correctly)
if echo "$COMMAND" | grep -qE 'gws gmail users' 2>/dev/null && echo "$COMMAND" | grep -qE '\-\-message-id' 2>/dev/null; then
  ERRORS="${ERRORS}- Bad flag: '--message-id' is not valid on API methods. Pass id inside --params: --params '{\"userId\":\"me\",\"id\":\"MSG_ID\"}'\n"
fi

# 6. Catch dot-separated subcommands
if echo "$COMMAND" | grep -qE 'gws gmail users\.' 2>/dev/null; then
  ERRORS="${ERRORS}- Bad syntax: gws uses space-separated subcommands, not dots. Use 'gws gmail users messages list' not 'gws gmail users.messages list'.\n"
fi

# 7. Catch --max-results (not a real flag)
if echo "$COMMAND" | grep -qE '\-\-max-results' 2>/dev/null; then
  ERRORS="${ERRORS}- Bad flag: '--max-results' is not valid. Use --params '{\"maxResults\":N,...}' instead.\n"
fi

# 8. Catch --label-ids on API methods (helpers like +watch use it correctly)
if echo "$COMMAND" | grep -qE 'gws gmail users' 2>/dev/null && echo "$COMMAND" | grep -qE '\-\-label-ids' 2>/dev/null; then
  ERRORS="${ERRORS}- Bad flag: '--label-ids' is not valid on API methods. Use --params '{\"labelIds\":[\"INBOX\"],...}' instead.\n"
fi

if [[ -n "$ERRORS" ]]; then
  REASON="BLOCKED: gws command syntax error(s):\n${ERRORS}Refer to the email-tools skill for correct command syntax. Copy commands exactly as shown."
  # Escape for JSON
  REASON_ESCAPED=$(echo -e "$REASON" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')
  echo "{\"hookSpecificOutput\":{\"permissionDecision\":\"deny\"},\"systemMessage\":${REASON_ESCAPED}}"
  exit 0
fi

# Command looks valid
exit 0
