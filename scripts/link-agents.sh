#!/usr/bin/env bash
set -euo pipefail

# Symlinks all custom agents into ~/.pi/agent/agents/.
# Run from the repo root. Creates symlinks so a 'git pull' in the repo
# automatically updates the installed agents (after a Pi restart).
# Keep the clone in a permanent location (e.g. ~/.pi/skills-source/).

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
  echo "linked $name"
  found=$((found + 1))
done < <(find "$REPO/agents" -name '*.md' -print0)

echo ""
echo "Done — $found agents linked to $DEST"
echo "Keep the clone in place so symlinks stay valid."
echo "To update: cd $REPO && git pull && restart Pi."
