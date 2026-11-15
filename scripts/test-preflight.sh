#!/usr/bin/env bash
# Verifies the pr-review preflight and artefact blocks in SKILL.md without duplicating them.
#
# The bash is read out of the skill at run time, so there is one copy of it: edit SKILL.md and this
# script tests what you edited. What is checked:
#
#   assertions   - each of the six post-mode assertions is broken on its own, and the run stops
#                  with preflight.json naming that assertion, its expected value and its actual one
#   order        - several broken conditions name the first in the documented order
#   dependencies - a missing vendor/ or node_modules/ fails, and nothing is ever installed
#   artefact     - preflight.json lands in $XDG_RUNTIME_DIR/pr-review/<owner>-<repo>/<number>/,
#                  mode 600, in a directory mode 700; an unset XDG_RUNTIME_DIR stops the run
#                  without falling back to a temporary directory
#   merge probe  - the head branch's remote-tracking ref is asserted before the merge, so a merge
#                  never starts without the ref the reset needs
#   report       - the report file is created owner-only (600) before anything is written into it
#   single shell - every block that reads a variable this skill derives also sets it, because each
#                  bash call is its own shell; and the three artefact paths agree
#   consistency  - no block creates a worktree or installs a package, and the artefacts keep the four
#                  keys a caller reads
#
# Usage: scripts/test-preflight.sh        (exit 0 = all checks passed)
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
# A fence is tracked first, so a `#` comment inside a block never ends the section — the skill's own
# blocks are commented, and those comments are part of what the tests exercise.
block() {
  awk -v s="$1" -v want="$2" '
    inb && /^```/              { inb=0; if (n==want) exit; next }
    inb                        { print; next }
    $0 ~ s                     { f=1; n=0; next }
    f && /^#/ && $0 !~ s       { exit }
    f && /^```bash/            { n++; inb=(n==want); next }
  ' "$SKILL"
}

echo "== extracting blocks from $SKILL"
STEP0=$(block '^### 0[.]' 1)
PREFLIGHT=$(block '^#### Post mode asserts' 1)
MERGE=$(block '^### 2a[.]' 2)
for pair in "step 0:$STEP0" "preflight:$PREFLIGHT" "merge probe:$MERGE"; do
  name=${pair%%:*}; body=${pair#*:}
  [ -n "$body" ] || { echo "cannot extract the $name block from $SKILL" >&2; exit 2; }
done
printf '  0: %s lines, preflight: %s lines, 2a: %s lines\n' \
  "$(wc -l <<<"$STEP0")" "$(wc -l <<<"$PREFLIGHT")" "$(wc -l <<<"$MERGE")"

# fill <block> [repo] [branch] [sha]  ->  the block with its placeholders filled in, which is what an
# agent does by hand. Done here so the skill holds one copy of each block, not two.
fill() {
  local repo="${2:-Owner/Repo}" branch="${3:-feat/x}" sha="${4:-${HEAD_SHA:-deadbeef}}"
  sed -e "s|^REPO='<owner/repo>'|REPO='$repo'|" \
      -e "s|^HEAD_BRANCH='<PR_HEAD>'|HEAD_BRANCH='$branch'|" \
      -e "s|^HEAD_SHA='<PR_HEAD_SHA>'|HEAD_SHA='$sha'|" \
      -e "s|^PR_HEAD='<PR_HEAD>'|PR_HEAD='$branch'|" \
      -e "s|^PR_HEAD_SHA='<PR_HEAD_SHA>'|PR_HEAD_SHA='$sha'|" \
      -e "s|^PR=<number>|PR=7|" \
      -e 's|<owner>-<repo>|Owner-Repo|g' \
      -e 's|<number>|7|g' \
      <<<"$1"
}

# --------------------------------------------------------------------------------------------------
# fixtures

# A clone whose origin reads as github Owner/Repo, carrying a feat/x branch whose head commit declares
# both dependency manifests, and the installed dependencies themselves — gitignored, so the tree is
# still clean and `git status --porcelain` is empty.
fixture() { # dir
  local d="$1" up="$1/upstream" wt="$1/wt"
  mkdir -p "$up"
  git -C "$up" init -q --initial-branch=master
  git -C "$up" config user.email test@example.com
  git -C "$up" config user.name Test
  printf 'vendor/\nnode_modules/\n' > "$up/.gitignore"
  printf 'base\n' > "$up/base.txt"
  git -C "$up" add -A && git -C "$up" commit -qm base
  git -C "$up" checkout -qb feat/x
  printf '{}\n' > "$up/composer.json"
  printf '{}\n' > "$up/package.json"
  git -C "$up" add -A && git -C "$up" commit -qm head
  git clone -q "$up" "$wt"
  git -C "$wt" remote set-url origin https://github.com/Owner/Repo.git
  mkdir -p "$wt/vendor" "$wt/node_modules"
  printf '<?php\n' > "$wt/vendor/autoload.php"
  git -C "$wt" checkout -q --detach "$(git -C "$up" rev-parse feat/x)"
}

head_sha() { git -C "$1/wt" rev-parse HEAD; }
# run_flight <fixture> <runtime-dir> [repo] [branch] [sha] — the preflight block, cwd = the worktree
# CEIL, when set, keeps git from walking up past $WORK to a repository that encloses the test tree.
run_flight() {
  local fx="$1" runtime="$2"
  fill "$PREFLIGHT" "${3:-Owner/Repo}" "${4:-feat/x}" "${5:-$(head_sha "$fx")}" > "$WORK/flight.sh"
  ( cd "$fx/wt" && env XDG_RUNTIME_DIR="$runtime" \
      ${CEIL:+GIT_CEILING_DIRECTORIES=$CEIL} bash "$WORK/flight.sh" ) \
    2>"$WORK/stderr" >"$WORK/stdout"
}

artefact() { printf '%s/pr-review/Owner-Repo/7/preflight.json' "$1"; }
field() { jq -r ".$2" "$1" 2>/dev/null; }

# --------------------------------------------------------------------------------------------------
echo
echo "== post mode: the six assertions pass on the right tree"
FX="$WORK/good"; fixture "$FX"
RT="$WORK/rt"; mkdir -p "$RT"
run_flight "$FX" "$RT"; rc=$?
ck exit "$rc" 0
ck no_artefact "$([ -e "$(artefact "$RT")" ] && echo present || echo absent)" absent
ck announces "$(grep -c 'preflight ok: Owner/Repo PR #7' "$WORK/stdout")" 1
ck dir_mode_700 "$(stat -c %a "$RT/pr-review/Owner-Repo/7")" 700

echo
echo "== post mode: each assertion broken on its own"
case_run() { # label fixture expected-assertion
  local label="$1" fx="$2" want="$3" a
  run_flight "$fx" "$RT"; local rc=$?
  a="$(artefact "$RT")"
  ck "$label/exit" "$rc" 3
  ck "$label/assertion" "$(field "$a" assertion)" "$want"
  ck "$label/expected_named" "$([ -n "$(field "$a" expected)" ] && echo yes || echo no)" yes
  ck "$label/actual_named"   "$([ -n "$(field "$a" actual)" ] && echo yes || echo no)" yes
  ck "$label/head_sha" "$(field "$a" head_sha)" "$(head_sha "$fx")"
  ck "$label/stderr_names" "$(grep -c "preflight failed at $want" "$WORK/stderr")" 1
  rm -rf "$RT/pr-review"
}

FX="$WORK/notrepo"; mkdir -p "$FX/wt"
ZERO=0000000000000000000000000000000000000000
CEIL="$WORK" run_flight "$FX" "$RT" Owner/Repo feat/x "$ZERO"; rc=$?
ck notrepo/exit "$rc" 3
ck notrepo/assertion "$(field "$(artefact "$RT")" assertion)" worktree
ck notrepo/actual "$(field "$(artefact "$RT")" actual)" "$FX/wt is not in a repository"
ck notrepo/head_sha_still_named "$(field "$(artefact "$RT")" head_sha)" "$ZERO"
rm -rf "$RT/pr-review"

# A cwd one level down is inside the repo but is not the worktree: the pipeline would run there and
# the manifests would be missing, so it must fail on the first assertion rather than on dependencies.
FX="$WORK/subdir"; fixture "$FX"
mkdir -p "$FX/wt/app"
fill "$PREFLIGHT" > "$WORK/flight-sub.sh"
( cd "$FX/wt/app" && XDG_RUNTIME_DIR="$RT" bash "$WORK/flight-sub.sh" ) 2>"$WORK/stderr" >/dev/null; rc=$?
ck subdir/exit "$rc" 3
ck subdir/assertion "$(field "$(artefact "$RT")" assertion)" worktree
ck subdir/actual "$(field "$(artefact "$RT")" actual)" "inside $FX/wt"
rm -rf "$RT/pr-review"

FX="$WORK/remote"; fixture "$FX"
git -C "$FX/wt" remote set-url origin https://github.com/Other/Repo.git
case_run wrong_remote "$FX" remote

FX="$WORK/noorigin"; fixture "$FX"
git -C "$FX/wt" remote remove origin
case_run no_origin "$FX" remote

FX="$WORK/sshurl"; fixture "$FX"
git -C "$FX/wt" remote set-url origin git@github.com:Owner/Repo.git
HEAD_SHA=$(head_sha "$FX")
fill "$PREFLIGHT" > "$WORK/sshurl.sh"
( cd "$FX/wt" && XDG_RUNTIME_DIR="$RT" bash "$WORK/sshurl.sh" ) >/dev/null 2>&1; rc=$?
ck ssh_url_accepted "$rc" 0

FX="$WORK/sshscheme"; fixture "$FX"
git -C "$FX/wt" remote set-url origin ssh://git@github.com/Owner/Repo.git
HEAD_SHA=$(head_sha "$FX")
fill "$PREFLIGHT" > "$WORK/sshscheme.sh"
( cd "$FX/wt" && XDG_RUNTIME_DIR="$RT" bash "$WORK/sshscheme.sh" ) >/dev/null 2>&1; rc=$?
ck ssh_scheme_accepted "$rc" 0

FX="$WORK/case"; fixture "$FX"
git -C "$FX/wt" remote set-url origin https://github.com/owner/repo.git
HEAD_SHA=$(head_sha "$FX")
fill "$PREFLIGHT" 'owner/repo' > "$WORK/case.sh"
( cd "$FX/wt" && XDG_RUNTIME_DIR="$RT" bash "$WORK/case.sh" ) >/dev/null 2>&1; rc=$?
ck case_insensitive "$rc" 0

FX="$WORK/branch"; fixture "$FX"
git -C "$FX/wt" switch -q -c not-the-pr-branch
case_run wrong_branch "$FX" branch

FX="$WORK/head"; fixture "$FX"
git -C "$FX/wt" checkout -q --detach "$(git -C "$FX/wt" rev-parse feat/x~1)"
run_flight "$FX" "$RT" Owner/Repo feat/x "$(git -C "$FX/wt" rev-parse feat/x)"; rc=$?
ck wrong_head/exit "$rc" 3
ck wrong_head/assertion "$(field "$(artefact "$RT")" assertion)" head_sha
ck wrong_head/expected "$(field "$(artefact "$RT")" expected)" "$(git -C "$FX/wt" rev-parse feat/x)"
ck wrong_head/actual   "$(field "$(artefact "$RT")" actual)" "$(git -C "$FX/wt" rev-parse feat/x~1)"
rm -rf "$RT/pr-review"

FX="$WORK/dirty"; fixture "$FX"
printf 'drift\n' >> "$FX/wt/base.txt"
case_run dirty_tracked "$FX" clean

FX="$WORK/untracked"; fixture "$FX"
printf 'stray\n' > "$FX/wt/stray.txt"
case_run dirty_untracked "$FX" clean

FX="$WORK/novendor"; fixture "$FX"
rm -f "$FX/wt/vendor/autoload.php"
case_run no_vendor "$FX" dependencies

FX="$WORK/nonode"; fixture "$FX"
rm -rf "$FX/wt/node_modules"
run_flight "$FX" "$RT"; rc=$?
ck no_node_modules/exit "$rc" 3
ck no_node_modules/assertion "$(field "$(artefact "$RT")" assertion)" dependencies
ck no_node_modules/actual "$(field "$(artefact "$RT")" actual)" "missing node_modules/"
rm -rf "$RT/pr-review"

echo
echo "== post mode: the artefact itself"
FX="$WORK/artefact"; fixture "$FX"
RT2="$WORK/rt2"; mkdir -p "$RT2/pr-review/Owner-Repo/7"
printf 'stale\n' > "$RT2/pr-review/Owner-Repo/7/preflight.json"
git -C "$FX/wt" remote set-url origin https://github.com/Other/Repo.git
run_flight "$FX" "$RT2"; rc=$?
ck artefact_exit "$rc" 3
ck artefact_path "$([ -f "$(artefact "$RT2")" ] && echo yes || echo no)" yes
ck artefact_mode "$(stat -c %a "$(artefact "$RT2")")" 600
ck artefact_dir_mode "$(stat -c %a "$RT2/pr-review/Owner-Repo/7")" 700
ck artefact_is_json "$(jq -e 'has("assertion") and has("expected") and has("actual") and has("head_sha")' \
  "$(artefact "$RT2")" >/dev/null 2>&1 && echo yes || echo no)" yes
ck stale_replaced "$(field "$(artefact "$RT2")" assertion)" remote

echo
echo "== post mode: an unset XDG_RUNTIME_DIR stops the run, with no fallback"
FX="$WORK/nowhere"; fixture "$FX"
HEAD_SHA=$(head_sha "$FX")
fill "$PREFLIGHT" > "$WORK/flight-noxdg.sh"
before=$(find "$WORK" -name preflight.json 2>/dev/null | wc -l)
( cd "$FX/wt" && env -u XDG_RUNTIME_DIR bash "$WORK/flight-noxdg.sh" ) 2>"$WORK/stderr2" >/dev/null; rc=$?
ck no_xdg_exit "$rc" 2
ck no_xdg_names_variable "$(grep -c 'XDG_RUNTIME_DIR is not set' "$WORK/stderr2")" 1
ck no_xdg_no_artefact "$(find "$WORK" -name preflight.json 2>/dev/null | wc -l)" "$before"
ck no_tmp_fallback "$(grep -c '/tmp' "$WORK/flight-noxdg.sh")" 0

echo
echo "== post mode: order — several broken conditions name the first"
FX="$WORK/order"; fixture "$FX"
git -C "$FX/wt" remote set-url origin https://github.com/Other/Repo.git
git -C "$FX/wt" checkout -q --detach "$(git -C "$FX/wt" rev-parse feat/x~1)"
printf 'drift\n' >> "$FX/wt/base.txt"
run_flight "$FX" "$RT"; rc=$?
ck order_exit "$rc" 3
ck order_assertion "$(field "$(artefact "$RT")" assertion)" remote
rm -rf "$RT/pr-review"

echo
echo "== post mode: nothing is installed, and no worktree is created"
FAKEBIN="$WORK/fakebin"; mkdir -p "$FAKEBIN"
for cmd in composer bun npm pnpm yarn; do
  printf '#!/bin/sh\necho "%s $*" >> "%s/installed.log"\nexit 0\n' "$cmd" "$WORK" > "$FAKEBIN/$cmd"
  chmod +x "$FAKEBIN/$cmd"
done
FX="$WORK/noinstall"; fixture "$FX"
HEAD_SHA=$(head_sha "$FX")
rm -rf "$FX/wt/vendor"
fill "$PREFLIGHT" > "$WORK/flight-install.sh"
( cd "$FX/wt" && XDG_RUNTIME_DIR="$RT" PATH="$FAKEBIN:$PATH" bash "$WORK/flight-install.sh" ) \
  >/dev/null 2>&1; rc=$?
ck install_fails "$rc" 3
ck install_never_attempted "$( [ -f "$WORK/installed.log" ] && wc -l < "$WORK/installed.log" || echo 0 )" 0
ck artefact_mode_after_install "$(stat -c %a "$(artefact "$RT")")" 600
ck vendor_still_absent "$([ -d "$FX/wt/vendor" ] && echo present || echo absent)" absent
ck no_worktree_add "$(grep -cE 'git +worktree +add' <<<"$PREFLIGHT")" 0
ck no_install_commands "$(grep -cE '\b(composer|bun|npm|pnpm|yarn) +(install|add|ci)\b' <<<"$PREFLIGHT")" 0
rm -rf "$RT/pr-review"

echo
echo "== merge probe: the head branch's ref is asserted before the merge"
# merge_run <worktree> <runtime-dir> [post|present]
# The block is run with a trailer that prints MERGE_EXIT, because each bash call is its own shell in
# the skill too: MERGE_EXIT only exists inside the call that produced it. PR_HEAD and PR_HEAD_SHA are
# NOT exported from here — the block fills them from its own placeholders, as an agent would, so a
# block that forgot to would fail rather than inherit them.
merge_run() {
  local wt="$1" rt="$2" mode="${3:-post}" sha
  sha="$(git -C "$wt" rev-parse HEAD)"
  fill "$MERGE" Owner/Repo feat/x "$sha" > "$WORK/merge.sh"
  { cat "$WORK/merge.sh"; printf 'printf "MERGE_EXIT=%%s\\n" "${MERGE_EXIT:-none}"\n'; } \
    > "$WORK/merge-run.sh"
  if [ "$mode" = post ]; then
    ( cd "$wt" && XDG_RUNTIME_DIR="$rt" PR_REVIEW_MODE=post bash "$WORK/merge-run.sh" ) \
      2>"$WORK/stderr3"
  else
    ( cd "$wt" && env -u PR_REVIEW_MODE bash "$WORK/merge-run.sh" ) 2>"$WORK/stderr3" >/dev/null
  fi
}

FX="$WORK/merge-noip"; fixture "$FX"
before_commits=$(git -C "$FX/wt" rev-list --count HEAD)
git -C "$FX/wt" update-ref -d refs/remotes/origin/feat/x
merge_run "$FX/wt" "$RT" >/dev/null; rc=$?
ck merge_noip_exit "$rc" 3
ck merge_noip_assertion "$(field "$(artefact "$RT")" assertion)" head_ref
ck merge_noip_expected "$(field "$(artefact "$RT")" expected)" refs/remotes/origin/feat/x
ck merge_noip_artefact_mode "$(stat -c %a "$(artefact "$RT")")" 600
ck merge_never_ran "$(git -C "$FX/wt" rev-list --count HEAD)" "$before_commits"
ck merge_no_merge_head "$(git -C "$FX/wt" rev-parse --verify --quiet MERGE_HEAD >/dev/null && echo present || echo absent)" absent
ck merge_stderr_names "$(grep -c 'preflight failed at head_ref' "$WORK/stderr3")" 1
rm -rf "$RT/pr-review"

FX="$WORK/merge-present"; fixture "$FX"
git -C "$FX/wt" update-ref -d refs/remotes/origin/feat/x
merge_run "$FX/wt" "$RT" present; rc=$?
ck merge_present_exit "$rc" 3
ck merge_present_no_artefact "$(find "$RT" -name preflight.json 2>/dev/null | wc -l)" 0
ck merge_present_names_stop "$(grep -c 'preflight failed at head_ref' "$WORK/stderr3")" 1

FX="$WORK/merge-ok"; fixture "$FX"
out=$(merge_run "$FX/wt" "$RT")
ck merge_ok_ran "$(grep -o 'MERGE_EXIT=[0-9]*' <<<"$out")" "MERGE_EXIT=0"
ck merge_ok_no_artefact "$(find "$RT" -name preflight.json 2>/dev/null | wc -l)" 0

echo
echo "== step 0: the artefact directory and the split log"
STAMP=$(block '^### 0[.]' 2)
[ -n "$STAMP" ] || { echo "cannot extract the step 0 stamp block" >&2; exit 2; }
RT3="$WORK/rt3"; mkdir -p "$RT3"
out=$( XDG_RUNTIME_DIR="$RT3" bash -c "$(fill "$STEP0")
printf '%s\n' \"\$REVIEW_DIR\"" )
ck step0_review_dir "$out" "$RT3/pr-review/Owner-Repo/7"
ck step0_dir_mode "$(stat -c %a "$RT3/pr-review/Owner-Repo/7")" 700
out=$( XDG_RUNTIME_DIR="$RT3" bash -c "$(sed -e 's|<name>|t0|' <<<"$(fill "$STAMP")")
printf '%s\n' \"\$SPLITS\"" )
ck step0_splits "$out" "$RT3/pr-review/Owner-Repo/7/splits.tsv"
ck step0_stamped "$(cut -f1 "$out")" t0
ck step0_stamp_is_ms "$(cut -f2 "$out" | grep -cE '^[0-9]{13}$')" 1
env -u XDG_RUNTIME_DIR bash -c "$(fill "$STEP0")" >/dev/null 2>"$WORK/stderr5"; rc=$?
ck step0_requires_xdg "$rc" 2
ck step0_no_tmp "$(grep -c '/tmp' <<<"$STEP0$STAMP")" 0

echo
echo "== step 9: the report is created owner-only"
REPORT_BLOCK=$(block '^### 9[.] Write the report' 1)
[ -n "$REPORT_BLOCK" ] || { echo "cannot extract the step 9 block" >&2; exit 2; }
RT4="$WORK/rt4"; mkdir -p "$RT4"
out=$( XDG_RUNTIME_DIR="$RT4" bash -c "$(fill "$REPORT_BLOCK")
printf '%s\n' \"\$REPORT_FILE\"" )
ck report_path "$out" "$RT4/pr-review/Owner-Repo/7/report.md"
ck report_exists "$([ -f "$out" ] && echo yes || echo no)" yes
ck report_mode "$(stat -c %a "$out")" 600
ck report_empty "$(wc -c < "$out")" 0
printf 'rewritten contents\n' > "$out"
ck report_mode_survives_truncation "$(stat -c %a "$out")" 600

echo
echo "== consistency: the three path lines agree, and the blocks keep their rules"
norm() { sed -e 's|\$PR\b|<number>|g' -e 's|\$number\b|<number>|g' <<<"$1"; }
P0=$(norm "$(grep -o 'pr-review/<owner>-<repo>/\(<number>\|\$PR\)' <<<"$STEP0")")
PP=$(norm "$(grep -o 'pr-review/<owner>-<repo>/\(<number>\|\$PR\)' <<<"$PREFLIGHT")")
PM=$(norm "$(grep -o 'pr-review/<owner>-<repo>/\(<number>\|\$PR\)' <<<"$MERGE")")
ck path_step0 "$P0" "pr-review/<owner>-<repo>/<number>"
ck path_preflight "$PP" "$P0"
ck path_merge "$PM" "$P0"
ck post_mode_named "$(grep -c 'PR_REVIEW_MODE:-present' <<<"$MERGE")" 1
ck artefact_keys "$(grep -c "'{assertion:\$assertion,expected:\$expected,actual:\$actual,head_sha:\$head_sha}'" <<<"$PREFLIGHT")" 1
ck no_review_record "$(grep -c 'reviews\.jsonl\|REVIEW_LOG' <<<"$PREFLIGHT$MERGE")" 0

echo
echo "== every block sets what it reads: a bash call is its own shell"
BLOCKS="$WORK/blocks"; mkdir -p "$BLOCKS"
awk -v dir="$BLOCKS" '
  /^```bash/ { n++; f = dir "/" sprintf("%03d.sh", n); inb=1; next }
  inb && /^```/ { inb=0; next }
  inb { print > f; next }
' "$SKILL"
block_count=$(ls "$BLOCKS" | wc -l)
printf '  %s bash blocks in %s\n' "$block_count" "$(basename "$SKILL")"
ck blocks_found "$([ "$block_count" -ge 10 ] && echo yes || echo no)" yes

leaks=""
for file in "$BLOCKS"/*.sh; do
  for var in REVIEW_DIR SPLITS CTX_FILE REPORT_FILE ARTEFACT PR_HEAD PR_HEAD_SHA CURRENT_BRANCH MODE TIMING; do
    grep -qE "\\\$\{?$var([^A-Za-z0-9_]|$)" "$file" || continue
    grep -qE "^[[:space:]]*(export[[:space:]]+)?$var=" "$file" && continue
    leaks="$leaks $(basename "$file"):$var"
  done
  # WORKTREE_PATH is allowed only in its defaulted form: present mode's own value, or the cwd
  if grep -qE '\$WORKTREE_PATH' "$file" && ! grep -qE '\$\{WORKTREE_PATH:-\$PWD\}' "$file"; then
    leaks="$leaks $(basename "$file"):WORKTREE_PATH"
  fi
done
ck no_leaked_variables "$leaks" ""

echo
if [ $FAILED -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED"; fi
exit $FAILED
