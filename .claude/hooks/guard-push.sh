#!/bin/bash
# Approval gate: prompts only on real deploy actions - git push, gh pr merge,
# kubectl set image / rollout undo / delete.
# Two false-positive shields: (1) extracts the command from the hook JSON so
# descriptions/filenames never match; (2) strips quoted text first, because
# deploy-looking words inside quotes are data (test strings, commit messages),
# not an executed command.
input=$(cat)
cmd=$(printf '%s' "$input" | python3 -c "
import json, sys
try:
    print(json.load(sys.stdin).get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null)
[ -z "$cmd" ] && cmd="$input"
cmd=$(printf '%s' "$cmd" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")
if printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_-])git[^|;&]*[[:space:]]push([[:space:];&|]|$)|(^|[^[:alnum:]_-])gh[[:space:]]+pr[[:space:]]+merge([[:space:]]|$)|(^|[^[:alnum:]_-])kubectl[^|;&]*[[:space:]](set[[:space:]]+image|rollout[[:space:]]+undo|delete)([[:space:]]|$)'; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Pushing/merging/deploying requires approval"}}'
fi
exit 0
