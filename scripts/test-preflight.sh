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
#   pipeline     - the `fix` script is required: a project without one stops the review with exit 3
#                  and `assertion: pipeline` in preflight.json, and the individual scripts are never
#                  a fallback; post mode discards every formatter rewrite and reports the drift in
#                  formatting.json, while present mode keeps it, stages only what was rewritten, and
#                  pushes
#   harness      - a placeholder that survives a fill stops the suite by name, rather than surfacing
#                  later as a path mismatch or a directory called `<number>`
#
# Usage: scripts/test-preflight.sh        (exit 0 = all checks passed)
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SKILL="${SKILL_UNDER_TEST:-$ROOT/skills/pr-review/SKILL.md}"
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
#
# A `<…>` that survives the fill is a defect in this harness, not in the block under test: a
# placeholder renamed or respaced in SKILL.md silently stops the sed below from matching, and the
# suite then fails on a path mismatch or on a directory literally named `<number>` — pointing at the
# artefact logic instead of at the drift between harness and skill. So the fill is checked, and the
# check is fatal: `exit`, not `return`, because almost every caller redirects straight into a script
# file and a subshell's failure would be swallowed. A block carrying a placeholder this function does
# not know is substituted in the block before it is passed here.
fill() {
  local repo="${2:-Owner/Repo}" branch="${3:-feat/x}" sha="${4:-${HEAD_SHA:-deadbeef}}" out left
  out=$(sed -e "s|^REPO='<owner/repo>'|REPO='$repo'|" \
            -e "s|^HEAD_BRANCH='<PR_HEAD>'|HEAD_BRANCH='$branch'|" \
            -e "s|^HEAD_SHA='<PR_HEAD_SHA>'|HEAD_SHA='$sha'|" \
            -e "s|^PR_HEAD='<PR_HEAD>'|PR_HEAD='$branch'|" \
            -e "s|^PR_HEAD_SHA='<PR_HEAD_SHA>'|PR_HEAD_SHA='$sha'|" \
            -e "s|^CURRENT_BRANCH='<PR_HEAD>'|CURRENT_BRANCH='$branch'|" \
            -e "s|^PR=<number>|PR=7|" \
            -e 's|<owner>-<repo>|Owner-Repo|g' \
            -e 's|<number>|7|g' \
            <<<"$1")
  left=$(grep -oE '<[A-Za-z][^>]*>' <<<"$out" | sort -u)
  if [ -n "$left" ]; then
    printf 'fill: placeholder(s) survived the fill — SKILL.md and this harness have drifted:\n' >&2
    while IFS= read -r p; do printf '  %s\n' "$p" >&2; done <<<"$left"
    printf 'Teach fill() the new spelling, or substitute it in the block before calling fill.\n' >&2
    exit 1
  fi
  printf '%s\n' "$out"
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
echo "== pipeline: composer fix is required, and a project without it stops the review"
RT5="$WORK/rt5"; mkdir -p "$RT5"

# A stand-in for composer: it runs the named script's commands from the fixture's own composer.json,
# expanding `@script` references the way composer does, so the fixture — not the fake — decides what
# a run does.
PBIN="$WORK/pbin"; mkdir -p "$PBIN"
cat > "$PBIN/composer" <<'FAKE'
#!/bin/sh
[ "$1" = "run-script" ] || { echo "fake composer: unsupported: $*" >&2; exit 9; }
expand() {
  jq -r --arg s "$1" '.scripts[$s] // empty | if type=="array" then .[] else . end' composer.json |
  while IFS= read -r line; do
    case "$line" in
      @*) expand "${line#@}" ;;
      *)  sh -c "$line" ;;
    esac
  done
}
expand "$2"
FAKE
# A stand-in for Pint: rewrites app/Styled.php in place, once, the way a fix-mode formatter does.
cat > "$PBIN/pint" <<'FAKE'
#!/bin/sh
[ -f app/Styled.php ] || exit 0
grep -q '// formatted' app/Styled.php && exit 0
printf '// formatted\n' >> app/Styled.php
FAKE
# A stand-in for a script that regenerates a tracked file: it is not a formatter, so its changes are
# discarded like any other and claimed as nothing.
cat > "$PBIN/regen" <<'FAKE'
#!/bin/sh
grep -q '// regenerated' app/Styled.php && exit 0
printf '// regenerated\n' >> app/Styled.php
FAKE
chmod +x "$PBIN/composer" "$PBIN/pint" "$PBIN/regen"

RESOLVE=$(block '^#### Resolve the pipeline' 1)
RUNLIVE=$(block '^#### Present mode: run it' 1)
STAGE=$(block '^#### Stage, commit and push' 1)
RUNPOST=$(block '^#### Post mode: run it' 1)
for pair in "resolve:$RESOLVE" "present run:$RUNLIVE" "stage:$STAGE" "post run:$RUNPOST"; do
  name=${pair%%:*}; body=${pair#*:}
  [ -n "$body" ] || { echo "cannot extract the $name block from $SKILL" >&2; exit 2; }
done

pipeline_fixture() { # dir composer.json — a worktree whose project declares those scripts
  local d="$1"
  fixture "$d"
  git -C "$d/wt" config user.email test@example.com
  git -C "$d/wt" config user.name Test
  mkdir -p "$d/wt/app"; printf '<?php\n' > "$d/wt/app/Styled.php"
  printf '%s\n' "$2" > "$d/wt/composer.json"
  git -C "$d/wt" add -A; git -C "$d/wt" commit -qm declares
}

fmt_artefact() { printf '%s/pr-review/Owner-Repo/7/formatting.json' "$1"; }
flight_artefact() { printf '%s/pr-review/Owner-Repo/7/preflight.json' "$1"; }

# resolved <fixture> [mode] -> the resolved pipeline (one `command<TAB>formatters` line), leaving the
# block's own exit status in $WORK/resolve.rc and its output in $WORK/resolve.out
resolved() {
  rm -rf "$RT5/pr-review"
  fill "$RESOLVE" Owner/Repo feat/x "$(head_sha "$1")" > "$WORK/resolve.sh"
  ( cd "$1/wt" && XDG_RUNTIME_DIR="$RT5" PR_REVIEW_MODE="${2:-present}" bash "$WORK/resolve.sh" ) \
    > "$WORK/resolve.out" 2>&1
  echo $? > "$WORK/resolve.rc"
  cat "$RT5/pr-review/Owner-Repo/7/pipeline.tsv" 2>/dev/null
}
commands_of() { cut -f1 <<<"$1" | paste -sd'|' - ; }
formatters_of_tab() { cut -f2 <<<"$1" | paste -sd'|' - ; }

FX="$WORK/pipe-fix"
pipeline_fixture "$FX" '{"scripts":{"pint":["pint"],"fix":["@pint"],"lint":["pint"]}}'
P=$(resolved "$FX")
ck fix_used "$(commands_of "$P")" "composer run-script fix"
ck fix_alone "$(grep -c . <<<"$P")" 1
ck fix_formatters "$(cut -f2 <<<"$P")" "pint"
ck fix_exit "$(cat "$WORK/resolve.rc")" 0
ck fix_announced "$(grep -c 'pipeline: composer run-script fix' "$WORK/resolve.out")" 1

# The individual scripts are not a fallback. A project that exposes lint, ci:check and types:check but
# no fix is refused, and in post mode the refusal is a preflight artefact naming the missing script —
# the same channel every other "this review cannot start" failure uses.
FX="$WORK/pipe-nofix"
pipeline_fixture "$FX" '{"scripts":{"pint":["pint"],"lint":["pint"],"ci:check":["true"],"types:check":["true"]}}'
P=$(resolved "$FX" post)
ck nofix_exit "$(cat "$WORK/resolve.rc")" 3
ck nofix_nothing_resolved "$(grep -c . <<<"$P")" 0
ck nofix_says_stop "$(grep -c 'HARD STOP' "$WORK/resolve.out")" 1
ck nofix_names_declared "$(grep -c 'found: ci:check, lint, pint, types:check' "$WORK/resolve.out")" 1
ck nofix_no_improvisation "$(grep -c 'will not assemble one' "$WORK/resolve.out")" 1
ck nofix_assertion "$(field "$(flight_artefact "$RT5")" assertion)" pipeline
ck nofix_expected "$(field "$(flight_artefact "$RT5")" expected)" \
  "a composer.json script named fix, running the project code quality pipeline"
ck nofix_actual "$(field "$(flight_artefact "$RT5")" actual)" "ci:check, lint, pint, types:check"
ck nofix_head "$(field "$(flight_artefact "$RT5")" head_sha)" "$(head_sha "$FX")"
ck nofix_artefact_mode "$(stat -c %a "$(flight_artefact "$RT5")")" 600

# Present mode stops with the message and writes no file: a human is reading, exactly as preflight
# does when an assertion fails there.
P=$(resolved "$FX" present)
ck nofix_present_exit "$(cat "$WORK/resolve.rc")" 3
ck nofix_present_no_artefact \
  "$([ -f "$(flight_artefact "$RT5")" ] && echo present || echo absent)" absent

# No composer.json at all is the same failure with a different sentence, not a different outcome.
FX="$WORK/pipe-nocomposer"; fixture "$FX"
git -C "$FX/wt" config user.email test@example.com
git -C "$FX/wt" config user.name Test
git -C "$FX/wt" rm -q composer.json && git -C "$FX/wt" commit -qm drop
P=$(resolved "$FX" post)
ck nocomposer_exit "$(cat "$WORK/resolve.rc")" 3
ck nocomposer_nothing_resolved "$(grep -c . <<<"$P")" 0
ck nocomposer_names_it "$(grep -c "no composer.json in $FX/wt" "$WORK/resolve.out")" 1
ck nocomposer_actual "$(field "$(flight_artefact "$RT5")" actual)" "no composer.json in $FX/wt"

FX="$WORK/pipe-bun"
pipeline_fixture "$FX" '{"scripts":{"fix":["bun run lint"]}}'
printf '{"scripts":{"lint":"biome check --write ."}}\n' > "$FX/wt/package.json"
git -C "$FX/wt" add -A && git -C "$FX/wt" commit -qm pkg
ck formatter_through_package_json "$(cut -f2 <<<"$(resolved "$FX")")" "biome"

# post_run <fixture> [mode] -> the block's exit status; output in $WORK/postrun.out
post_run() {
  fill "$RUNPOST" > "$WORK/postrun.sh"
  ( cd "$1/wt" && env PATH="$PBIN:$PATH" XDG_RUNTIME_DIR="$RT5" PR_REVIEW_MODE="${2:-post}" \
      bash "$WORK/postrun.sh" ) > "$WORK/postrun.out" 2>&1
}

echo
echo "== pipeline: post mode discards the rewrites and reports the drift"
FX="$WORK/post-drift"; pipeline_fixture "$FX" '{"scripts":{"pint":["pint"],"fix":["@pint"]}}'
resolved "$FX" > /dev/null
before_head=$(git -C "$FX/wt" rev-parse HEAD)
post_run "$FX"; rc=$?
FMT=$(fmt_artefact "$RT5")
ck drift_exit "$rc" 0
ck drift_tree_clean "$(git -C "$FX/wt" status --porcelain)" ""
ck drift_head_unchanged "$(git -C "$FX/wt" rev-parse HEAD)" "$before_head"
ck drift_content_identical "$(git -C "$FX/wt" show HEAD:app/Styled.php | cmp -s - "$FX/wt/app/Styled.php" && echo same || echo changed)" same
ck drift_files "$(field "$FMT" files)" 1
ck drift_formatters "$(jq -rc .formatters "$FMT")" '["pint"]'
ck drift_paths "$(jq -rc .paths "$FMT")" '["app/Styled.php"]'
ck drift_exit_status "$(jq -rc '[.runs[].exit]' "$FMT")" "[0]"
ck drift_mode "$(stat -c %a "$FMT")" 600
ck drift_announced "$(grep -c 'formatting: 1 file(s) would be rewritten by pint' "$WORK/postrun.out")" 1

FX="$WORK/post-clean"; pipeline_fixture "$FX" '{"scripts":{"fix":["true"]}}'
resolved "$FX" > /dev/null
post_run "$FX"; rc=$?
ck clean_exit "$rc" 0
ck clean_tree "$(git -C "$FX/wt" status --porcelain)" ""
ck clean_no_drift "$(field "$(fmt_artefact "$RT5")" files)" 0
ck clean_says_so "$(grep -c 'no `formatting` finding' "$WORK/postrun.out")" 1

# A run that creates a file rather than rewriting one is not drift: a formatter rewrites tracked
# files, and a build makes new ones. The new file is left in place and named, so a claim about a
# byte-identical tree is a claim about the tracked tree and says so.
FX="$WORK/post-untracked"
pipeline_fixture "$FX" '{"scripts":{"fix":["touch newfile.txt"]}}'
resolved "$FX" > /dev/null
post_run "$FX"; rc=$?
ck untracked_exit "$rc" 0
ck untracked_not_drift "$(field "$(fmt_artefact "$RT5")" files)" 0
ck untracked_left_in_place "$([ -f "$FX/wt/newfile.txt" ] && echo present || echo absent)" present
ck untracked_announced "$(grep -c 'left untracked files' "$WORK/postrun.out")" 1

# The count is files, not invocations: a `fix` script that runs Pint twice over one file reports one.
FX="$WORK/post-twice"
pipeline_fixture "$FX" '{"scripts":{"pint":["pint"],"fix":["@pint","@pint"]}}'
resolved "$FX" > /dev/null
post_run "$FX"; rc=$?
ck counted_once_exit "$rc" 0
ck counted_once_files "$(field "$(fmt_artefact "$RT5")" files)" 1
ck counted_once_paths "$(jq -rc .paths "$(fmt_artefact "$RT5")")" '["app/Styled.php"]'
ck counted_once_formatters "$(jq -rc .formatters "$(fmt_artefact "$RT5")")" '["pint"]'
ck counted_once_runs "$(jq -rc '[.runs[].files]' "$(fmt_artefact "$RT5")")" "[1]"

# A command that rewrites a tracked file without naming a formatter is discarded and named, but not
# claimed as formatting drift: the label's meaning is a formatter's rewrite, and this is not one.
FX="$WORK/post-non-formatter"
pipeline_fixture "$FX" '{"scripts":{"fix":["regen"]}}'
resolved "$FX" > /dev/null
post_run "$FX"; rc=$?
ck non_formatter_exit "$rc" 0
ck non_formatter_not_drift "$(field "$(fmt_artefact "$RT5")" files)" 0
ck non_formatter_no_formatters "$(jq -rc .formatters "$(fmt_artefact "$RT5")")" "[]"
ck non_formatter_recorded "$(jq -rc '[.runs[].files]' "$(fmt_artefact "$RT5")")" "[1]"
ck non_formatter_named "$(grep -c 'names no recognised formatter' "$WORK/postrun.out")" 1
ck non_formatter_no_finding "$(grep -c 'no `formatting` finding' "$WORK/postrun.out")" 1

# The guards. A tree that was dirty before the run is refused rather than measured, because nothing a
# formatter rewrites could be told apart from what was already there; exit 4 says "nothing reviewed,
# no preflight.json" where exit 3 would send a caller looking for one.
FX="$WORK/post-dirty"; pipeline_fixture "$FX" '{"scripts":{"pint":["pint"],"fix":["@pint"]}}'
resolved "$FX" > /dev/null
printf 'stray\n' > "$FX/wt/app/Untracked.php"
head_before=$(git -C "$FX/wt" rev-parse HEAD)
post_run "$FX"; rc=$?
ck dirty_refused_exit "$rc" 4
ck dirty_refused_no_artefact \
  "$([ -f "$(fmt_artefact "$RT5")" ] && echo present || echo absent)" absent
ck dirty_refused_untouched "$(git -C "$FX/wt" show HEAD:app/Styled.php | cmp -s - "$FX/wt/app/Styled.php" && echo same || echo changed)" same
ck dirty_refused_names_it "$(grep -c 'refused' "$WORK/postrun.out")" 1
ck dirty_refused_head "$(git -C "$FX/wt" rev-parse HEAD)" "$head_before"

# The block is post mode's alone: run in present mode it would discard the rewrites that mode has to
# keep, and run in post mode the present block would push them to the PR.
FX="$WORK/guard"; pipeline_fixture "$FX" '{"scripts":{"pint":["pint"],"fix":["@pint"]}}'
resolved "$FX" > /dev/null
post_run "$FX" present; rc=$?
ck post_block_refuses_present "$rc" 2
ck post_block_refused_nothing "$(git -C "$FX/wt" status --porcelain)" ""
ck post_block_says_why "$(grep -c 'post-mode block' "$WORK/postrun.out")" 1
fill "$RUNLIVE" > "$WORK/presentrun-guard.sh"
( cd "$FX/wt" && env PATH="$PBIN:$PATH" XDG_RUNTIME_DIR="$RT5" PR_REVIEW_MODE=post \
    bash "$WORK/presentrun-guard.sh" ) > "$WORK/presentrun-guard.out" 2>&1; rc=$?
ck present_block_refuses_post "$rc" 2
ck present_block_says_why "$(grep -c 'present-mode block' "$WORK/presentrun-guard.out")" 1

# An unresolved pipeline is a usage error, not a review failure: exit 2, and no pipeline is invented.
FX="$WORK/unresolved"; pipeline_fixture "$FX" '{"scripts":{"pint":["pint"],"fix":["@pint"]}}'
resolved "$FX" > /dev/null
: > "$RT5/pr-review/Owner-Repo/7/pipeline.tsv"     # resolved to nothing: the run must not become a no-op
post_run "$FX"; rc=$?
ck unresolved_post_exit "$rc" 2
ck unresolved_post_says_why "$(grep -c 'missing or empty' "$WORK/postrun.out")" 1
( cd "$FX/wt" && env PATH="$PBIN:$PATH" XDG_RUNTIME_DIR="$RT5" bash "$WORK/presentrun-guard.sh" ) \
  > "$WORK/presentrun-guard.out" 2>&1; rc=$?
ck unresolved_present_exit "$rc" 2

echo
echo "== pipeline: present mode keeps the rewrites, stages only those, and pushes"
# A fixture whose origin is a real bare repository, so the push is genuinely exercised; and a local
# edit the pipeline never touches, which must not be swept into the auto-fix commit.
pushable_fixture() { # dir composer.json
  local d="$1"
  mkdir -p "$d"
  git init -q --bare --initial-branch=master "$d/origin.git"
  git init -q --initial-branch=master "$d/seed"
  git -C "$d/seed" config user.email test@example.com
  git -C "$d/seed" config user.name Test
  printf 'vendor/\nnode_modules/\n' > "$d/seed/.gitignore"
  mkdir -p "$d/seed/app"; printf '<?php\n' > "$d/seed/app/Styled.php"
  printf 'keep\n' > "$d/seed/stray.txt"
  printf '%s\n' "$2" > "$d/seed/composer.json"
  git -C "$d/seed" add -A && git -C "$d/seed" commit -qm base
  git -C "$d/seed" remote add origin "$d/origin.git"
  git -C "$d/seed" push -q origin master
  git -C "$d/seed" checkout -qb feat/x
  printf 'branch work\n' >> "$d/seed/stray.txt"
  git -C "$d/seed" add -A && git -C "$d/seed" commit -qm head
  git -C "$d/seed" push -q origin feat/x
  git clone -q "$d/origin.git" "$d/wt"
  git -C "$d/wt" config user.email test@example.com
  git -C "$d/wt" config user.name Test
  git -C "$d/wt" checkout -q feat/x
  mkdir -p "$d/wt/vendor" "$d/wt/node_modules"
  printf '<?php\n' > "$d/wt/vendor/autoload.php"
  printf 'local, unpushed edit\n' >> "$d/wt/stray.txt"
}

FX="$WORK/present"; pushable_fixture "$FX" '{"scripts":{"pint":["pint"],"fix":["@pint"]}}'
resolved "$FX" > /dev/null
fill "$RUNLIVE" > "$WORK/presentrun.sh"
fill "$STAGE" > "$WORK/stage.sh"
( cd "$FX/wt" && env PATH="$PBIN:$PATH" XDG_RUNTIME_DIR="$RT5" bash "$WORK/presentrun.sh" ) \
  > "$WORK/presentrun.out" 2>&1; rc=$?
ck present_exit "$rc" 0
ck present_kept_rewrite "$(git -C "$FX/wt" diff --name-only -- app/Styled.php)" "app/Styled.php"
ck present_names_scripts "$(grep -c 'composer run-script fix: exit 0' "$WORK/presentrun.out")" 1
ck present_no_drift_artefact \
  "$([ -f "$(fmt_artefact "$RT5")" ] && echo present || echo absent)" absent
( cd "$FX/wt" && XDG_RUNTIME_DIR="$RT5" bash "$WORK/stage.sh" ) > "$WORK/stage.out" 2>&1; rc=$?
ck stage_exit "$rc" 0
ck stage_commit "$(git -C "$FX/wt" log -1 --format=%s)" "style: quality pipeline auto-fixes"
ck stage_only_touched "$(git -C "$FX/wt" show --pretty=format: --name-only HEAD | grep -c .)" 1
ck stage_only_touched_path "$(git -C "$FX/wt" show --pretty=format: --name-only HEAD | grep .)" \
  "app/Styled.php"
ck stage_stray_still_local "$(git -C "$FX/wt" status --porcelain stray.txt)" " M stray.txt"
ck stage_pushed "$(git -C "$FX/wt" rev-parse HEAD)" "$(git -C "$FX/wt" rev-parse origin/feat/x)"

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
fill "$STEP0" > "$WORK/step0.sh"
out=$( XDG_RUNTIME_DIR="$RT3" bash -c "$(cat "$WORK/step0.sh")
printf '%s\n' \"\$REVIEW_DIR\"" )
ck step0_review_dir "$out" "$RT3/pr-review/Owner-Repo/7"
ck step0_dir_mode "$(stat -c %a "$RT3/pr-review/Owner-Repo/7")" 700
fill "$(sed -e 's|<name>|t0|' <<<"$STAMP")" > "$WORK/stamp.sh"
out=$( XDG_RUNTIME_DIR="$RT3" bash -c "$(cat "$WORK/stamp.sh")
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
fill "$REPORT_BLOCK" > "$WORK/report.sh"
out=$( XDG_RUNTIME_DIR="$RT4" bash -c "$(cat "$WORK/report.sh")
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
echo "== harness: a placeholder that survives the fill stops the suite by name"
# Rename one placeholder in a scratch copy of the skill and run this suite against it. The point is
# the message: without the check this arrives as a path mismatch or a directory literally named
# `<number>`, which sends the reader into the artefact logic instead of at the renamed placeholder.
DRIFT_SKILL="$WORK/skill-drift.md"
sed "s|HEAD_BRANCH='<PR_HEAD>'|HEAD_BRANCH='<PR_HEAD_RENAMED>'|" "$SKILL" > "$DRIFT_SKILL"
ck drift_copy_differs "$(cmp -s "$SKILL" "$DRIFT_SKILL" && echo same || echo changed)" changed
if [ "${PREFLIGHT_SKIP_DRIFT_CASE:-0}" = 1 ]; then
  printf '  skip  the drift case (this run is the case itself)\n'
else
  SKILL_UNDER_TEST="$DRIFT_SKILL" PREFLIGHT_SKIP_DRIFT_CASE=1 bash "$0" > "$WORK/drift.out" 2>&1
  rc=$?
  ck drift_nonzero "$([ "$rc" -ne 0 ] && echo yes || echo no)" yes
  ck drift_explains "$(grep -c 'placeholder(s) survived the fill' "$WORK/drift.out")" 1
  ck drift_names_it "$(grep -c '^  <PR_HEAD_RENAMED>$' "$WORK/drift.out")" 1
  ck drift_not_an_artefact_failure "$(grep -c 'FAIL ' "$WORK/drift.out")" 0
  ck drift_not_a_pass "$(grep -c 'ALL CHECKS PASSED' "$WORK/drift.out")" 0
fi

echo
if [ $FAILED -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED"; fi
exit $FAILED
