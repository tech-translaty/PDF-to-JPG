#!/bin/bash
# SessionStart hook: mechanical sync check (runs automatically when a session opens).
# Fetches origin, fast-forwards only when unambiguously safe (behind + clean tree),
# and reports the repo's sync state into the session context. Never pushes,
# never merges, never touches uncommitted work.
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0
export GIT_TERMINAL_PROMPT=0

if ! git fetch --quiet 2>/dev/null; then
  echo "[sync] Could not reach GitHub (offline or auth issue) - unable to check whether this branch is behind. Proceed, but treat local state as possibly stale."
  exit 0
fi

branch=$(git symbolic-ref --short -q HEAD)
if [ -z "$branch" ]; then
  echo "[sync] Detached HEAD - no sync check performed. Surface this to the user before changing anything."
  exit 0
fi

counts=$(git rev-list --left-right --count '@{u}...HEAD' 2>/dev/null)
if [ -z "$counts" ]; then
  echo "[sync] Branch '$branch' has no upstream on GitHub - nothing to compare. Surface this to the user."
  exit 0
fi
behind=$(printf '%s' "$counts" | awk '{print $1}')
ahead=$(printf '%s' "$counts" | awk '{print $2}')
dirty=$(git status --porcelain | wc -l | tr -d ' ')

if [ "$behind" -gt 0 ] && [ "$ahead" -gt 0 ]; then
  echo "[sync] DIVERGED: branch '$branch' is behind GitHub by $behind commit(s) AND ahead by $ahead. Do NOT guess a resolution - explain the situation to the user and wait."
elif [ "$behind" -gt 0 ]; then
  if [ "$dirty" = "0" ]; then
    if git pull --ff-only --quiet 2>/dev/null; then
      echo "[sync] Auto-pulled $behind commit(s) from GitHub - branch '$branch' is now up to date."
    else
      echo "[sync] Branch '$branch' is behind by $behind commit(s) but the safe fast-forward pull failed - investigate before working."
    fi
  else
    echo "[sync] Branch '$branch' is behind GitHub by $behind commit(s) but has $dirty uncommitted file(s) - NOT pulling automatically. Surface this to the user before working."
  fi
elif [ "$ahead" -gt 0 ]; then
  echo "[sync] Branch '$branch' has $ahead local commit(s) not yet on GitHub. Per the sync policy, offer the user a push."
else
  echo "[sync] Branch '$branch' is in sync with GitHub."
fi

if [ "$dirty" != "0" ]; then
  echo "[sync] Working tree has $dirty uncommitted file(s). At the end of this session, offer to commit and push so all devices stay in sync."
fi
exit 0
