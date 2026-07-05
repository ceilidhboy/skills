#!/usr/bin/env bash
set -euo pipefail

# Verifies that all skills in this repo are correctly installed
# in ~/.agents/skills/.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.agents/skills"
VERBOSE=false
MODE="auto"
COLOR_MODE="auto"

# ── Colour support ──────────────────────────────────────────────
if [ -t 1 ]; then
  GREEN=$'\033[0;32m'; RED=$'\033[0;31m'; YELLOW=$'\033[0;33m'
  BOLD=$'\033[1m'; DIM=$'\033[2m'; NC=$'\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; BOLD=''; DIM=''; NC=''
fi

apply_color() {
  local cm="$1"
  if [ "$cm" = "always" ]; then
    GREEN=$'\033[0;32m'; RED=$'\033[0;31m'; YELLOW=$'\033[0;33m'
    BOLD=$'\033[1m'; DIM=$'\033[2m'; NC=$'\033[0m'
  elif [ "$cm" = "never" ]; then
    GREEN=''; RED=''; YELLOW=''; BOLD=''; DIM=''; NC=''
  fi
}

# ── Help ─────────────────────────────────────────────────────────
show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Verify that all skills in this repo are correctly installed
in ~/.agents/skills/.

Options:
  --mode MODE      Verification mode: auto, dev, or prod (default: auto)
                     auto - accepts symlinks or real directories
                     dev  - strict: must be a symlink pointing to this repo
                     prod - strict: must be a real directory with SKILL.md
  --color WHEN     Colour output: auto, always, or never (default: auto)
  -v               Verbose output (shows file details on failures)
  -h, --help       Show this help message

Examples:
  $(basename "$0")                         # auto mode, colour if terminal
  $(basename "$0") --mode dev              # after link-skills.sh
  $(basename "$0") --mode prod             # after npx skills add
  $(basename "$0") --color never           # no colour (e.g. piped output)
EOF
  exit 0
}

# ── Parse arguments ──────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      shift
      case "$1" in
        auto|dev|prod) MODE="$1"; shift ;;
        *) echo "Error: --mode must be auto, dev, or prod. Use --help for details."; exit 1 ;;
      esac
      ;;
    --color)
      shift
      case "$1" in
        auto|always|never) COLOR_MODE="$1"; shift ;;
        *) echo "Error: --color must be auto, always, or never. Use --help for details."; exit 1 ;;
      esac
      ;;
    -v) VERBOSE=true; shift ;;
    -h|--help) show_help ;;
    *) echo "Unknown option: $1. Use --help for usage."; exit 1 ;;
  esac
done

apply_color "$COLOR_MODE"

# ── Collect results ──────────────────────────────────────────────
declare -a names types details statuses
max_name_len=0
passed=0; failed=0; missing=0; total=0

while IFS= read -r -d '' skill_md; do
  total=$((total + 1))
  src="$(dirname "$skill_md")"
  name="$(basename "$src")"
  target="$DEST/$name"

  # Track longest name for column alignment
  [ ${#name} -gt $max_name_len ] && max_name_len=${#name}

  names+=("$name")

  if [ ! -e "$target" ]; then
    statuses+=("fail")
    types+=("${RED}missing${NC}")
    details+=("")
    missing=$((missing + 1))
    continue
  fi

  if [ -L "$target" ]; then
    actual=$(readlink "$target")
    if [ "$actual" = "$src" ]; then
      if [ "$MODE" = "prod" ]; then
        statuses+=("fail")
        types+=("${RED}symlink${NC}")
        details+=("${RED}expected directory copy${NC}")
        failed=$((failed + 1))
      else
        statuses+=("pass")
        types+=("${DIM}symlink${NC}")
        details+=("→ ${actual#$REPO/skills/}")
        passed=$((passed + 1))
      fi
    else
      statuses+=("fail")
      types+=("${RED}symlink${NC}")
      details+=("${RED}wrong target: ${actual#$REPO/}${NC}")
      failed=$((failed + 1))
    fi
    continue
  fi

  # Real directory
  if [ "$MODE" = "dev" ]; then
    statuses+=("fail")
    types+=("${RED}directory${NC}")
    details+=("${RED}expected symlink${NC}")
    failed=$((failed + 1))
    continue
  fi

  if [ ! -f "$target/SKILL.md" ]; then
    statuses+=("fail")
    types+=("${RED}directory${NC}")
    details+=("${RED}no SKILL.md${NC}")
    failed=$((failed + 1))
    continue
  fi

  statuses+=("pass")
  types+=("directory")
  details+=("")
  passed=$((passed + 1))
done < <(find "$REPO/skills" -name SKILL.md -print0)

# ── Print results table ──────────────────────────────────────────
col_width=$(( max_name_len + 2 ))  # +2 for breathing room

header_status="${BOLD}Status${NC}"
header_skill=$(printf "${BOLD}%-${col_width}s${NC}" "Skill")
header_type="${BOLD}Type${NC}"
header_details="${BOLD}Details${NC}"
printf "  %s  %s %s  %s\n" "$header_status" "$header_skill" "$header_type" "$header_details"
echo ""

for i in $(seq 0 $((total - 1))); do
  name="${names[$i]}"
  type="${types[$i]}"
  detail="${details[$i]}"
  stat="${statuses[$i]}"

  if [ "$stat" = "pass" ]; then
    ico="${GREEN}✓${NC}"
  else
    ico="${RED}✗${NC}"
  fi

  padded=$(printf "%-${col_width}s" "$name")
  printf "  %s  %s %s  %s\n" "$ico" "$padded" "$type" "$detail"
done

# ── Summary ──────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}=== Summary ===${NC}"
echo "Mode: $MODE"
echo "Total skills in repo: $total"
echo -e "  ${GREEN}✓${NC} Passed: $passed"
echo -e "  ${RED}✗${NC} Failed: $failed"
echo -e "  ${RED}✗${NC} Missing: $missing"

if [ "$failed" -eq 0 ] && [ "$missing" -eq 0 ]; then
  echo ""
  echo -e "${GREEN}All $total skills verified OK — everything is in order.${NC}"
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
