#!/usr/bin/env bash
set -euo pipefail

# Verifies that all skills in this repo are correctly installed
# in ~/.agents/skills/.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.agents/skills"
VERBOSE=false
MODE="auto"

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Verify that all skills in this repo are correctly installed
in ~/.agents/skills/.

Options:
  --mode MODE    Verification mode: auto, dev, or prod (default: auto)
                   auto - accepts symlinks or real directories
                   dev  - strict: must be a symlink pointing to this repo
                   prod - strict: must be a real directory with SKILL.md
  -v             Verbose output (shows file details on failures)
  -h, --help     Show this help message

Examples:
  $(basename "$0")                  # auto mode (accepts both)
  $(basename "$0") --mode dev       # after link-skills.sh
  $(basename "$0") --mode prod      # after npx skills add
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      shift
      case "$1" in
        auto|dev|prod) MODE="$1"; shift ;;
        *) echo "Error: --mode must be auto, dev, or prod. Use --help for details."; exit 1 ;;
      esac
      ;;
    -v)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      show_help
      ;;
    *)
      echo "Unknown option: $1. Use --help for usage."
      exit 1
      ;;
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

  if [ ! -e "$target" ]; then
    echo "✗ $name — missing"
    missing=$((missing + 1))
    continue
  fi

  if [ -L "$target" ]; then
    # Symlink found
    if [ "$MODE" = "prod" ]; then
      echo "✗ $name — symlink found but production mode expects a directory copy"
      failed=$((failed + 1))
      continue
    fi
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
    continue
  fi

  # Real directory
  if [ "$MODE" = "dev" ]; then
    echo "✗ $name — directory found but dev mode expects a symlink"
    failed=$((failed + 1))
    if $VERBOSE; then
      file "$target"
    fi
    continue
  fi

  if [ ! -f "$target/SKILL.md" ]; then
    echo "✗ $name — directory exists but has no SKILL.md"
    failed=$((failed + 1))
    continue
  fi

  echo "✓ $name"
  passed=$((passed + 1))
done < <(find "$REPO/skills" -name SKILL.md -print0)

echo ""
echo "=== Summary ==="
echo "Mode: $MODE"
echo "Total skills in repo: $total"
echo "  ✓ Passed: $passed"
echo "  ✗ Failed: $failed"
echo "  ✗ Missing: $missing"

if [ "$failed" -eq 0 ] && [ "$missing" -eq 0 ]; then
  echo ""
  echo "All $total skills verified OK — everything is in order."
  if [ "$MODE" = "prod" ]; then
    echo "No cleanup needed."
  fi
  exit 0
else
  echo ""
  if [ "$MODE" = "auto" ]; then
    echo "If these are symlinks run 'bash scripts/link-skills.sh' to fix."
    echo "If these are copied directories run 'npx skills@latest add ...' to reinstall."
  elif [ "$MODE" = "dev" ]; then
    echo "Run 'bash scripts/link-skills.sh' to create correct symlinks."
  elif [ "$MODE" = "prod" ]; then
    echo "Run 'npx skills@latest add ceilidhboy/skills' to reinstall."
  fi
  exit 1
fi
