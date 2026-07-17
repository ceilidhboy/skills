#!/usr/bin/env bash
set -euo pipefail

# Links all custom agents into ~/.pi/agent/agents/ for local development.
# Run from the repo root after cloning or pulling updates.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.pi/agent/agents"

mkdir -p "$DEST"

found=0
while IFS= read -r -d '' agent_file; do
  name="$(basename "$agent_file" .md)"
  target="$DEST/$name.md"

  if [ -e "$target" ] && [ ! -L "$target" ]; then
    rm -rf "$target"
  fi

  ln -sfn "$agent_file" "$target"
  echo "linked $name -> $agent_file"
  found=$((found + 1))
done < <(find "$REPO/agents" -name '*.md' -print0)

echo ""
echo "Done — $found agents linked to $DEST"
