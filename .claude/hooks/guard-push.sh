#!/bin/bash
input=$(cat)
if printf '%s' "$input" | grep -Eq 'git[^|;&]*push|gh pr merge|kubectl[^|;&]*set image|kubectl[^|;&]*rollout undo|kubectl[^|;&]*delete'; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Pushing/merging/deploying requires approval"}}'
fi
exit 0
