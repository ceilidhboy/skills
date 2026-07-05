#!/usr/bin/env bash
set -euo pipefail

# Removes old test backup directories created by prepare-test.sh.
#
# Usage:
#   bash scripts/cleanup-backup.sh              # interactive, prompt per backup
#   bash scripts/cleanup-backup.sh -y           # remove ALL backups without prompting
#   bash scripts/cleanup-backup.sh --help       # show this

BACKUP_DIR="$HOME/.agents/skills.bak"
AUTO=false

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Remove backup directories created by prepare-test.sh.

Backups are stored as ~/.agents/skills.bak or ~/.agents/skills.bak.YYYYMMDD-HHMMSS.

Options:
  -y    Remove all backups without prompting
  a     (interactive) Remove remaining backups all at once
  -h, --help  Show this help message
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y) AUTO=true; shift ;;
    -h|--help) show_help ;;
    *) echo "Unknown option: $1. Use --help for usage."; exit 1 ;;
  esac
done

# Collect backup directories
mapfile -t backups < <(find "$HOME/.agents" -maxdepth 1 -name 'skills.bak*' -type d 2>/dev/null | sort)

if [ ${#backups[@]} -eq 0 ]; then
  echo "No backup directories found."
  exit 0
fi

count=${#backups[@]}
plural="directories"
[ "$count" -eq 1 ] && plural="directory"
echo "Found $count backup $plural:"
echo ""

for dir in "${backups[@]}"; do
  size=$(du -sh "$dir" 2>/dev/null | cut -f1)
  echo "  $dir  ($size)"
done

echo ""

if [ "$AUTO" = true ]; then
  for dir in "${backups[@]}"; do
    rm -rf "$dir"
    echo "Removed: $dir"
  done
  echo "Done."
  exit 0
fi

ALL=false
for dir in "${backups[@]}"; do
  echo ""
  if [ "$ALL" = true ]; then
    reply="y"
  else
    read -r -p "Remove $dir? [y/N/a] " reply
    if [[ "$reply" =~ ^[Aa](ll)?$ ]]; then
      ALL=true
      reply="y"
    fi
  fi
  if [[ "$reply" =~ ^[Yy](es)?$ ]]; then
    rm -rf "$dir"
    echo "Removed."
  else
    echo "Skipped."
  fi
done

echo ""
echo "Done."
