#!/usr/bin/env bash
set -euo pipefail

# Prepares a clean test environment for npx skills@latest add:
#   1. Backs up ~/.agents/skills/ to ~/.agents/skills.bak.TIMESTAMP
#   2. Removes only symlinks that point back to this repo
#
# After running this, do:
#   npx skills@latest add ceilidhboy/skills
#   bash scripts/verify-skills.sh
#
# To restore: rm -rf ~/.agents/skills && mv ~/.agents/skills.bak.TIMESTAMP ~/.agents/skills
#
# To clean up old backups: bash scripts/cleanup-backup.sh

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.agents/skills"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP="${DEST}.bak.${TIMESTAMP}"

if [ -d "$DEST" ]; then
  cp -a "$DEST" "$BACKUP"
  echo "✓ Backed up $DEST → $BACKUP"
else
  echo "No $DEST directory to back up."
fi

# Step 2: Remove repo-origin skill directories (real dirs or symlinks)
removed=0
while IFS= read -r -d '' skill_md; do
  name="$(basename "$(dirname "$skill_md")")"
  target="$DEST/$name"
  if [ -e "$target" ]; then
    rm -rf "$target"
    removed=$((removed + 1))
  fi
done < <(find "$REPO/skills" -name SKILL.md -print0)

echo "✓ Removed $removed repo-origin skill directories from $DEST"
echo ""
echo "Choose your testing path:"
echo ""
echo "  ── Local (no GitHub push needed) ──"
echo "  scripts/link-skills.sh"
echo "  scripts/verify-skills.sh --mode dev"
echo ""
echo "  ── GitHub (simulates end-user install) ──"
echo "  npx skills@latest add ceilidhboy/skills"
echo "  scripts/verify-skills.sh"
echo ""
echo "To restore (if needed):"
echo "  rm -rf $DEST && mv $BACKUP $DEST"
echo ""
echo "To clean up old backups:"
echo "  scripts/cleanup-backup.sh"
