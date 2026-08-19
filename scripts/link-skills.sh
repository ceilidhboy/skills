#!/usr/bin/env bash
set -euo pipefail

# Links all skills into ~/.agents/skills/ and custom agents into
# ~/.pi/agent/agents/ for local development.
# Run from the repo root after cloning or pulling updates.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.agents/skills"

mkdir -p "$DEST"

found=0
while IFS= read -r -d '' skill_md; do
  src="$(dirname "$skill_md")"
  name="$(basename "$src")"
  target="$DEST/$name"

  if [ -e "$target" ] && [ ! -L "$target" ]; then
    rm -rf "$target"
  fi

  ln -sfn "$src" "$target"
  echo "linked $name -> $src"
  found=$((found + 1))
done < <(find "$REPO/skills" -name SKILL.md -print0)

echo ""
echo "Done — $found skills linked to $DEST"

# Also link custom agents into ~/.pi/agent/agents/ so pi can use them.
AGENT_DEST="$HOME/.pi/agent/agents"
mkdir -p "$AGENT_DEST"

agents_found=0
while IFS= read -r -d '' agent_md; do
  name="$(basename "$agent_md")"
  target="$AGENT_DEST/$name"

  if [ -e "$target" ] && [ ! -L "$target" ]; then
    rm -rf "$target"
  fi

  ln -sfn "$agent_md" "$target"
  echo "linked agent $name -> $agent_md"
  agents_found=$((agents_found + 1))
done < <(find "$REPO/agents" -name '*.md' -print0 2>/dev/null || true)

echo ""
echo "Done — $agents_found agents linked to $AGENT_DEST"
