#!/bin/bash
input=$(cat)
if printf '%s' "$input" | grep -Eq 'git[^|;&]*push|gh pr merge'; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Pushing/merging requires approval"}}'
fi
exit 0
