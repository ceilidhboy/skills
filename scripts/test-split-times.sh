#!/usr/bin/env bash
# Verifies the pr-review split-time blocks in SKILL.md without duplicating them.
#
# The bash is read out of the skill at run time, so there is one copy of it: edit
# SKILL.md and this script tests what you edited. Two things are checked:
#
#   behaviour    - the derivation and the aggregate produce the documented numbers,
#                  and a missing stamp yields timing_complete:false naming it
#   consistency  - the stamps step 0 declares are exactly those step 9.5 validates,
#                  step 9.6 consumes $TIMING, and the pre-fix defects stay gone
#
# Usage: scripts/test-split-times.sh        (exit 0 = all checks passed)
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SKILL="$ROOT/skills/pr-review/SKILL.md"
[ -f "$SKILL" ] || { echo "cannot find $SKILL" >&2; exit 2; }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
FAILED=0

ck() { # label actual expected
  if [ "$2" = "$3" ]; then
    printf '  ok    %s\n' "$1"
  else
    printf '  FAIL  %s\n        got  [%s]\n        want [%s]\n' "$1" "$2" "$3"
    FAILED=1
  fi
}

# block <section-regex> <nth-fenced-bash-block-in-that-section>
block() {
  awk -v s="$1" -v want="$2" '
    $0 ~ s                     { f=1; n=0; next }
    f && /^#/ && $0 !~ s       { exit }
    f && /^```bash/            { n++; inb=(n==want); next }
    f && /^```/                { if (inb) exit; inb=0; next }
    f && inb                   { print }
  ' "$SKILL"
}

echo "== extracting blocks from $SKILL"
B95=$(block '^### 9[.]5[.]' 1)
BAGG=$(block '^### 9[.]6[.]' 2)
[ -n "$B95" ]  || { echo "step 9.5 has no bash block" >&2; exit 2; }
[ -n "$BAGG" ] || { echo "step 9.6 has no second bash block" >&2; exit 2; }
printf '  9.5 derivation: %s lines, 9.6 aggregate: %s lines\n' \
  "$(wc -l <<<"$B95")" "$(wc -l <<<"$BAGG")"

run95() { # splits-file reviewer_ms oracle_ms -> TIMING on stdout
  SPLITS=$1 REVIEWER_MS=${2:-0} ORACLE_MS=${3:-0} \
    bash -c "$B95
printf %s \"\$TIMING\""
}

echo
echo "== behaviour: six stamps"
A=1000000
{
  printf '%s\t%s\n' t0            "$A"
  printf '%s\t%s\n' preflight_end "$((A+285000))"   # 285 s preflight
  printf '%s\t%s\n' legs_start    "$((A+287000))"   #   2 s dispatch
  printf '%s\t%s\n' legs_end      "$((A+707000))"   # 420 s legs
  printf '%s\t%s\n' assembly_end  "$((A+737000))"   #  30 s assembly
  printf '%s\t%s\n' t4            "$((A+742000))"   #   5 s delivery
} > "$WORK/full.tsv"

T_FULL=$(run95 "$WORK/full.tsv" 395000 410000)
echo "  TIMING=$T_FULL"
ck preflight_ms "$(jq -r .preflight_ms <<<"$T_FULL")" 285000
ck dispatch_ms  "$(jq -r .dispatch_ms  <<<"$T_FULL")" 2000
ck legs_ms      "$(jq -r .legs_ms      <<<"$T_FULL")" 420000
ck assembly_ms  "$(jq -r .assembly_ms  <<<"$T_FULL")" 30000
ck delivery_ms  "$(jq -r .delivery_ms  <<<"$T_FULL")" 5000
ck total_ms     "$(jq -r .total_ms     <<<"$T_FULL")" 742000
ck legs_exceed_each_leg \
  "$(jq -r '.legs_ms > .reviewer_ms and .legs_ms > .oracle_ms' <<<"$T_FULL")" true
ck timing_complete "$(jq -r .timing_complete <<<"$T_FULL")" true
ck no_null_in_timing "$(grep -c 'null' <<<"$T_FULL")" 0

echo
echo "== behaviour: a stamp never emitted"
grep -v '^assembly_end' "$WORK/full.tsv" > "$WORK/missing.tsv"
T_MISS=$(run95 "$WORK/missing.tsv" 395000 410000 2>"$WORK/warn.txt")
echo "  TIMING=$T_MISS"
ck incomplete_flag "$(jq -r .timing_complete <<<"$T_MISS")" false
ck missing_named   "$(jq -r '.timing_missing|join(",")' <<<"$T_MISS")" assembly_end
ck warns_on_stderr "$(grep -c 'TIMING INCOMPLETE' "$WORK/warn.txt")" 1

echo
echo "== behaviour: aggregate over a complete and an incomplete row"
LOG="$WORK/reviews.jsonl"; : > "$LOG"
record() { # timing-json pr verdict
  jq -nc --arg date "$(date -Iseconds)" --arg repo "Test/Repo" --argjson pr "$2" \
    --arg sha deadbeef --arg verdict "$3" \
    --argjson legs '{"reviewer":"ok","oracle":"ok"}' \
    --argjson counts '{"blocker":0,"warning":3,"minor":3}' \
    --argjson labels '["missing-test"]' --argjson timing "$1" \
    '{date:$date,repo:$repo,pr:$pr,sha:$sha,verdict:$verdict,
      legs:$legs,counts:$counts,labels:$labels,timing:$timing}' >> "$LOG"
}
record "$T_FULL" 60 posted
record "$T_MISS" 61 not-posted

AGG=$(REVIEW_LOG="$LOG" bash -c "$BAGG")
echo "$AGG" | jq .
ck reviewed   "$(jq -r .reviewed   <<<"$AGG")" 2
ck timed      "$(jq -r .timed      <<<"$AGG")" 1
ck incomplete "$(jq -r .incomplete <<<"$AGG")" 1
ck total_min  "$(jq -r .total_min  <<<"$AGG")" 12.366666666666667
ck total_mean "$(jq -r .total_mean <<<"$AGG")" 12.366666666666667
ck total_max  "$(jq -r .total_max  <<<"$AGG")" 12.366666666666667
ck median_legs_min "$(jq -r .median_legs <<<"$AGG")" 7

echo
echo "== consistency: the skill's own declarations agree"

# the stamps step 0 documents in its table
DECLARED=$(awk '
  /^### 0\./ { f=1; next }
  f && /^### / { exit }
  f && /^\| `[a-z0-9_]+` *\|/ { gsub(/^\| `/, ""); sub(/`.*/, ""); print }
' "$SKILL" | sort | paste -sd, -)

# the stamps step 9.5 insists on
VALIDATED=$(sed -n 's/^for k in \(.*\); do$/\1/p' <<<"$B95" | tr ' ' '\n' | sort | paste -sd, -)

ck stamps_declared "$([ -n "$DECLARED" ] && echo yes || echo no)" yes
ck stamp_sets_match "$DECLARED" "$VALIDATED"
ck six_stamps "$(tr ',' '\n' <<<"$DECLARED" | wc -l)" 6

ck record_takes_TIMING \
  "$(awk '/^### 9\.6\./{f=1} f&&/^### 10\./{exit} f' "$SKILL" | grep -c -- '--argjson timing "\$TIMING"')" 1
ck no_pre_fix_vars \
  "$(awk '/^### 9\.6\./{f=1} f&&/^### 10\./{exit} f' "$SKILL" | grep -cE '\b(T0|T1|T2|T3|T4|MAX_LEG)\b')" 0
ck stamp_file_not_vars "$(awk '/^### 0\./{f=1} f&&/^### 1\./{exit} f' "$SKILL" | grep -c 'splits.tsv')" 1

echo
if [ $FAILED -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED"; fi
exit $FAILED
