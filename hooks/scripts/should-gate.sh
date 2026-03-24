#!/bin/bash
set -euo pipefail

# trustKORF Stop Hook - Deployment Gate Trigger
# Checks if there are uncommitted code changes. If so, injects a system message
# telling Claude to run the deployment-gate skill before stopping.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Check if we're in a git repository
if ! git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
  # Not a git repo — nothing to gate
  exit 0
fi

# Check for uncommitted changes (staged + unstaged)
staged=$(git -C "$PROJECT_DIR" diff --cached --stat 2>/dev/null || echo "")
unstaged=$(git -C "$PROJECT_DIR" diff --stat 2>/dev/null || echo "")

# Check for untracked files that look like code (not config or docs)
untracked=$(git -C "$PROJECT_DIR" ls-files --others --exclude-standard 2>/dev/null | grep -E '\.(ts|tsx|js|jsx|py|go|rs|cs|java|kt|rb|php|ex|exs|vue|svelte)$' || echo "")

if [ -z "$staged" ] && [ -z "$unstaged" ] && [ -z "$untracked" ]; then
  # No code changes — let Claude stop normally
  exit 0
fi

# There are uncommitted code changes — remind Claude (non-blocking)
# Using "allow" instead of "block" to avoid infinite Stop-hook loops.
# A "block" decision on Stop fires after every response, creating an
# unbreakable cycle when uncommitted changes always exist mid-conversation.
cat <<'EOF'
{"decision": "allow", "reason": "Uncommitted code changes detected", "systemMessage": "trustKORF reminder: There are uncommitted code changes. Consider running the deployment-gate skill before committing or claiming completion."}
EOF

exit 0
