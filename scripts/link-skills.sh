#!/usr/bin/env bash
set -euo pipefail

# Links all skills into ~/.agents/skills/ for local development.
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
