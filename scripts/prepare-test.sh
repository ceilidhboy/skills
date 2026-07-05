#!/usr/bin/env bash
set -euo pipefail

# Prepares a clean test environment for npx skills@latest add:
#   1. Backs up ~/.agents/skills/ to ~/.agents/skills.bak (aborts if exists)
#   2. Removes only symlinks that point back to this repo
#
# After running this, do:
#   npx skills@latest add ceilidhboy/skills
#   bash scripts/verify-skills.sh
#
# To restore: rm -rf ~/.agents/skills && mv ~/.agents/skills.bak ~/.agents/skills

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.agents/skills"
BACKUP="${DEST}.bak"

# Step 1: Backup
if [ -e "$BACKUP" ]; then
  echo "Aborting: $BACKUP already exists."
  echo "Either restore from it first, or remove it:"
  echo "  rm -rf $BACKUP"
  exit 1
fi

if [ -d "$DEST" ]; then
  cp -a "$DEST" "$BACKUP"
  echo "✓ Backed up $DEST → $BACKUP"
else
  echo "No $DEST directory to back up."
fi

# Step 2: Remove repo-origin symlinks
removed=0
while IFS= read -r -d '' skill_md; do
  name="$(basename "$(dirname "$skill_md")")"
  target="$DEST/$name"
  if [ -L "$target" ]; then
    actual="$(readlink "$target")"
    if [ "$actual" = "$(dirname "$skill_md")" ]; then
      rm "$target"
      removed=$((removed + 1))
    fi
  fi
done < <(find "$REPO/skills" -name SKILL.md -print0)

echo "✓ Removed $removed repo-origin symlinks from $DEST"
echo ""
echo "Ready for clean install:"
echo "  npx skills@latest add ceilidhboy/skills"
echo ""
echo "After install, verify:"
echo "  bash scripts/verify-skills.sh"
echo ""
echo "To restore (if needed):"
echo "  rm -rf $DEST && mv $BACKUP $DEST"
