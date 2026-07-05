#!/usr/bin/env bash
set -euo pipefail

# Verifies that all skills in this repo are correctly symlinked
# into ~/.agents/skills/.
#
# Usage:
#   bash scripts/verify-skills.sh
#   bash scripts/verify-skills.sh -v    # show more detail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.agents/skills"
VERBOSE=false

while getopts "v" opt; do
  case $opt in
    v) VERBOSE=true ;;
    *) echo "Usage: $0 [-v]"; exit 1 ;;
  esac
done

passed=0
failed=0
missing=0
total=0

while IFS= read -r -d '' skill_md; do
  total=$((total + 1))
  src="$(dirname "$skill_md")"
  name="$(basename "$src")"
  target="$DEST/$name"

  if [ -L "$target" ]; then
    actual=$(readlink "$target")
    if [ "$actual" = "$src" ]; then
      echo "✓ $name"
      passed=$((passed + 1))
    else
      echo "✗ $name — symlink points to wrong target"
      echo "    expected: $src"
      echo "    actual:   $actual"
      failed=$((failed + 1))
    fi
  elif [ -e "$target" ]; then
    echo "✗ $name — exists but is not a symlink"
    failed=$((failed + 1))
    if $VERBOSE; then
      file "$target"
    fi
  else
    echo "✗ $name — missing"
    missing=$((missing + 1))
  fi
done < <(find "$REPO/skills" -name SKILL.md -print0)

echo ""
echo "=== Summary ==="
echo "Total skills in repo: $total"
echo "  ✓ Correctly linked: $passed"
echo "  ✗ Wrong target:     $failed"
echo "  ✗ Missing:          $missing"

if [ "$failed" -eq 0 ] && [ "$missing" -eq 0 ]; then
  echo ""
  echo "All skills verified OK."
  exit 0
else
  echo ""
  echo "Run 'bash scripts/link-skills.sh' to fix."
  exit 1
fi
