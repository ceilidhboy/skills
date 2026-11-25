#!/usr/bin/env bash
# Verifies the pr-review verdict wording on a self-authored pull request, without duplicating it.
#
# The bash is read out of the skill at run time, so there is one copy of it: edit SKILL.md and this
# script tests what you edited. What is checked:
#
#   identity      - step 1.5 reports self-authorship when the poster is the author (case-insensitively),
#                   and never when the poster has no user identity (an installation token)
#   posting       - step 13 posts a comment review when author and poster match, and still posts
#                   --approve / --request-changes for a reviewer who is somebody else
#   wording       - NO BLOCKERS is the green verdict for REVIEW_IS_SELF=1, declared in the legend,
#                   tied to the flag in step 6, and defined in the glossary beside APPROVE
#   no bare claim - the post the skill builds for a comment review never says APPROVE
#
# Usage: scripts/test-verdict-wording.sh        (exit 0 = all checks passed)
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SKILL="${SKILL_UNDER_TEST:-$ROOT/skills/pr-review/SKILL.md}"
GLOSSARY="${GLOSSARY_UNDER_TEST:-$ROOT/skills/pr-review/GLOSSARY.md}"
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

# block <section-regex> <nth-fenced-bash-block-in-that-section>   (same reader as test-preflight.sh)
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
IDENT=$(block '^### 1[.]5[.]' 2)
POST=$(block '^### 13[.]' 2)
for pair in "identity:$IDENT" "posting:$POST"; do
  name=${pair%%:*}; body=${pair#*:}
  [ -n "$body" ] || { echo "cannot extract the $name block from $SKILL" >&2; exit 2; }
done
printf '  identity: %s lines, posting: %s lines\n' \
  "$(wc -l <<<"$IDENT")" "$(wc -l <<<"$POST")"

# fill <text>  -> the placeholders an agent fills in by hand
fill() {
  sed -e 's|<number>|42|g' -e 's|<owner/repo>|acme/widget|g' -e 's|<owner>-<repo>|acme-widget|g'
}

# stub_gh <author> <viewer or "">  -> a $WORK/bin/gh recording its argv, printing the two logins
stub_gh() {
  mkdir -p "$WORK/bin"; : > "$WORK/gh-calls"
  cat > "$WORK/bin/gh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$WORK/gh-calls"
case "\$1 \$2" in
  "pr view") printf '%s\n' "$1" ;;
  "api user") if [ -n "$2" ]; then printf '%s\n' "$2"; else
                echo "gh: Not Found (HTTP 403)" >&2; exit 1; fi ;;
  "pr review") exit 0 ;;
esac
exit 0
EOF
  chmod +x "$WORK/bin/gh"
}

echo
echo "== identity: who is posting, and is it the PR's author"
run_identity() { # author viewer
  stub_gh "$1" "$2"
  PATH="$WORK/bin:$PATH" bash -c "$(fill <<<"$IDENT")" 2>&1
}
ck self_when_author_matches    "$(run_identity 'pr-author' 'pr-author' | grep -c 'REVIEW_IS_SELF=1')" 1
ck self_is_case_insensitive    "$(run_identity 'PR-Author' 'pr-author' | grep -c 'REVIEW_IS_SELF=1')" 1
ck not_self_for_another_login  "$(run_identity 'pr-author' 'a-reviewer' | grep -c 'REVIEW_IS_SELF=0')" 1
ck not_self_without_an_actor   "$(run_identity 'pr-author' '' | grep -c 'REVIEW_IS_SELF=0')" 1
ck installation_actor_named    "$(run_identity 'pr-author' '' | grep -c 'app-installation')" 1

echo
echo "== posting: the state follows the reviewer's authority"
run_post() { # author viewer report-body
  stub_gh "$1" "$2"
  RUNTIME="$WORK/run"; rm -rf "$RUNTIME"; mkdir -p "$RUNTIME/pr-review/acme-widget/42"
  printf '%s\n' "$3" | sed -e 's|<number>|42|g' -e 's|<owner/repo>|acme/widget|g' \
    -e 's|<owner>-<repo>|acme-widget|g' > /dev/null
  printf '%s\n' "$3" > "$RUNTIME/pr-review/acme-widget/42/report.md"
  XDG_RUNTIME_DIR="$RUNTIME" PATH="$WORK/bin:$PATH" bash -c "$(fill <<<"$POST")" >/dev/null 2>&1
  grep '^pr review' "$WORK/gh-calls" | tail -1
}
GREEN='## Bottom line

🟢 **NO BLOCKERS** — no blockers, no warnings. Not an approval.'
APPROVE='## Bottom line

🟢 **APPROVE** — no blockers, no warnings.'
YELLOW='## Bottom line

🟡 **CONSIDER NOT APPROVING** — one warning open.'

ck self_posts_a_comment      "$(run_post 'pr-author' 'pr-author' "$GREEN" | grep -c -- '--comment')" 1
ck self_never_approves       "$(run_post 'pr-author' 'pr-author' "$GREEN" | grep -c -- '--approve')" 0
ck other_approves            "$(run_post 'pr-author' 'a-reviewer' "$APPROVE" | grep -c -- '--approve')" 1
ck other_requests_changes    "$(run_post 'pr-author' 'a-reviewer' "$YELLOW" | grep -c -- '--request-changes')" 1
ck the_banner_explains_it    "$(run_post 'pr-author' 'pr-author' "$GREEN" >/dev/null; \
    grep -c 'not a verdict' "$WORK/run/pr-review/acme-widget/42/comment.md")" 1

echo
echo "== wording: one name for one finding, and the claim matches the authority"
ck legend_declares_no_blockers   "$(grep -c '🟢 \*\*NO BLOCKERS\*\*' "$SKILL")" 2
ck step6_ties_it_to_the_flag     "$(grep -c 'REVIEW_IS_SELF=1` the green verdict reads `NO BLOCKERS`' "$SKILL")" 1
ck glossary_keeps_one_term       "$(grep -c '\*\*NO BLOCKERS\*\*' "$GLOSSARY")" 1
ck guide_carries_the_lesson      "$(grep -c 'NO BLOCKERS' "$ROOT/skills/pr-review/guide.md")" 1
ck wording_survives_the_fill     "$([ -n "$(fill <<<"$POST")" ] && echo yes)" yes
ck no_placeholder_left          "$(fill <<<"$POST" | grep -c '<[a-z-]*>')" 0

echo
if [ "$FAILED" -ne 0 ]; then echo "FAILED"; exit 1; fi
echo "all checks passed"
