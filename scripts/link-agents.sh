#!/usr/bin/env bash
set -euo pipefail

# Copies all custom agents into ~/.pi/agent/agents/.
# Run from the repo root. Copies rather than symlinks so the agents
# persist even if the clone is removed.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.pi/agent/agents"

mkdir -p "$DEST"

found=0
while IFS= read -r -d '' agent_file; do
  name="$(basename "$agent_file" .md)"
  target="$DEST/$name.md"

  cp "$agent_file" "$target"
  echo "installed $name"
  found=$((found + 1))
done < <(find "$REPO/agents" -name '*.md' -print0)

echo ""
echo "Done — $found agents copied to $DEST"
