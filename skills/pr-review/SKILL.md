---
name: pr-review
description: Review a GitHub pull request by orchestrating reviewer + oracle sub-agents directly from the orchestrating session, consolidating their findings into a single report, and asking for approval before posting. Interactive by default; set PR_REVIEW_MODE=post to post the review as a plain comment without asking, for headless dispatch. Use when user says "review PR #N", "review pull request", "review this PR", "review N on owner/repo", provides a PR URL, or asks for a PR review.
---

# PR Review

You are the orchestrator of the PR review. You run the `reviewer` and `oracle` sub-agents directly as your own children — there is no intermediate review agent. This flat shape is intentional: both children appear in your fleet with live per-child detail (model, context mode, tool/token/elapsed counters, current activity), so a working-but-slow child is distinguishable from a stuck one, and a stuck leg can be steered or re-dispatched individually without losing the other leg's work. Never reintroduce a wrapper agent for this flow.

**Before starting any review, read `guide.md`** — it contains hard-won lessons and constraints that prevent real failures (timeout budgets, context mode, baseline rules). This is not optional. `GLOSSARY.md` beside it fixes the vocabulary — leg, finding, disposition, verdict, split — and
names the words not to use for each. Use its terms in the report, in the record and in anything you post,
because the same thing under two names is how a review ends up arguing with itself.

## Review artefacts directory

Review artefacts (context file, report, split log, preflight failure) must live in a RAM disk, not in the project directory, in one directory per repository per pull request:

`${XDG_RUNTIME_DIR}/pr-review/<owner>-<repo>/<number>/`

`XDG_RUNTIME_DIR` is the user-specific runtime directory (`/run/user/$(id -u)`, typically `/run/user/1000`) and it is **mandatory**: a run with it unset stops before doing anything else. There is no fallback, because a shared `/tmp/pr-review/` is readable by every local account and a report names a repository's vulnerabilities. For the same reason the directory is created mode 700 and the report is written mode 600. The owner and the repository name are joined by a hyphen (`Socially-Free-auto-pr-review`) so that the directory names one repository in one segment: splitting on `/` would put every repository of one owner under a shared parent, which is not a repository's directory and reads as one to anything that lists them. Do NOT create review artefacts inside the project worktree — it pollutes the working tree and risks them being committed.

## Mode: present or post

The skill runs in one of two modes, chosen by the caller:

| Mode | Set by | Behaviour |
|---|---|---|
| `present` (default) | nothing | Review, present the report, wait, then post it as an approval or a request for changes |
| `post` | `PR_REVIEW_MODE=post` | Review, then post the report as a **plain PR comment** without asking. No inline fixes, no commits, no pushes, no issues, no approval, no change request |

**In post mode the worktree arrives as the process's working directory and nothing else** — no
variable but `PR_REVIEW_MODE` crosses the boundary, so there is no `--workdir` to get wrong and no
second source of truth about which tree is being reviewed. Preflight asserts the directory instead,
which is step 2's post-mode block: the caller provisioned the workspace, and preflight is what proves
it arrived.

Read the mode, do not infer it — it is one command, and the default leaves interactive use exactly as it was:

```bash
MODE="${PR_REVIEW_MODE:-present}"
case "$MODE" in
  present|post) ;;
  *) echo "unknown PR_REVIEW_MODE='$MODE' (expected present or post)" >&2; exit 2 ;;
esac
```

**Why the gate exists, and why `post` removes it.** Present mode exists so a human can read the report and interact — fix a finding, ask a question, revise the wording — before it goes public. A dispatcher has no such human, so the gate becomes a stall: the only answer it could ever give is "post it". `post` states that answer in advance, and changes nothing else about the review itself.

**`post` mode is advisory by design.** It never edits, commits or pushes, so it needs no write access to code, and a comment it posts can be withdrawn or edited. That is what makes it safe to run unattended over a queue: the worst a mistaken or manipulated review can do is leave a wrong comment on a pull request. It also means every finding stays the author's to fix — the review recommends, it never acts.

The variable belongs to the caller. This skill defines the two values and no others, and names nothing about who is calling it.

## Workflow
### 0. Resolve the artefact directory, then open the split-time log

Every artefact this run produces lives in one directory, and it is resolved first, before anything
else can fail — a preflight failure has to be written somewhere, and that somewhere cannot depend on
the step that failed. This is the **artefact-directory preamble**, and every later block that needs
the directory repeats it verbatim, because a bash call is its own shell:

```bash
[ -n "${XDG_RUNTIME_DIR:-}" ] || { echo "XDG_RUNTIME_DIR is not set — review artefacts live under it and there is no fallback" >&2; exit 2; }
REVIEW_DIR="$XDG_RUNTIME_DIR/pr-review/<owner>-<repo>/<number>"
mkdir -p "$REVIEW_DIR" && chmod 700 "$REVIEW_DIR"
```

Fill in `<owner>-<repo>` (owner and repository joined by a hyphen, `Socially-Free-auto-pr-review`) and
`<number>` before running it, and the same two values in every later copy — a variable set here is gone
by the next call, and a block that reads `$REVIEW_DIR` without setting it writes `/context.md`.

Split times are captured **as each phase ends**, never reconstructed afterwards. They go into a file,
one append per phase, and each append re-derives the path in its own call:

Each stamp is this command, with the name substituted; it is a whole call, so it re-derives the path:

```bash
[ -n "${XDG_RUNTIME_DIR:-}" ] || { echo "XDG_RUNTIME_DIR is not set — review artefacts live under it and there is no fallback" >&2; exit 2; }
REVIEW_DIR="$XDG_RUNTIME_DIR/pr-review/<owner>-<repo>/<number>"
mkdir -p "$REVIEW_DIR" && chmod 700 "$REVIEW_DIR"
SPLITS="$REVIEW_DIR/splits.tsv"
printf '%s\t%s\n' <name> "$(date +%s%3N)" >> "$SPLITS"
```

| Stamp | Emit at | Means |
|---|---|---|
| `t0` | here, before any preflight | skill activated |
| `preflight_end` | end of step 3 | PR parsed, worktree ready, context and standards files written |
| `legs_start` | step 4, after both launches have returned | both legs are running |
| `legs_end` | step 5, the moment the last leg returns | both legs finished |
| `assembly_end` | end of step 9 | consolidation, reversal check, sanitisation and report write done |
| `t4` | step 13 after posting — or immediately before the final answer when the review is not posted | delivered |

Emit `t0` now. Then emit each remaining stamp **at the step named**, as that phase ends.

If a phase genuinely did not happen — a leg died, the review was not posted — stamp the moment you
decided that. A `legs_end` recorded at the instant you gave up on a leg is true and useful; a stamp
you leave out because the step did not run cleanly is a measurement you lose for good. Step 9.5
treats a missing stamp as a failure and says so.

### 1. Parse the request

Extract the PR number and optional owner/repo from:

| Input format | Extracted |
|---|---|
| `Review PR #44` | number=44, repo from git remote |
| `Review PR #44 on owner/repo` | number=44, owner/repo given |
| `https://github.com/owner/repo/pull/44` | number=44, owner/repo parsed from URL |
| `owner/repo#44` | number=44, owner/repo parsed |

If the owner/repo cannot be determined from the task or the git remote, ask the user before proceeding.

### 1.5. Resolve the PR, then verify it targets master (hard gate)

Fetch the PR's branches **before** any workspace decision. Step 2's "already on the PR branch" check compares the current branch against `headRefName`, so fetching it later makes that check impossible to evaluate — that ordering bug is why an already-checked-out PR branch gets missed.

```bash
gh pr view <number> --repo <owner/repo> --json number,title,url,state,headRefName,baseRefName,headRefOid
```

Hold `PR_HEAD`, `PR_BASE`, `PR_TITLE` and `PR_HEAD_SHA` for the rest of the workflow. `PR_HEAD_SHA` is
the head **this review was asked to review**: the sha the caller recorded when it named one — a queue
claims an entry at a head, and that head is what the review is for — and `headRefOid` when it named
none. Substituting the current tip for a recorded sha would review a commit nobody asked about, so a
caller's sha is never silently upgraded. If `state` is not `OPEN`, say so and confirm the user still
wants a review.

**Now the target-branch gate. Do not skip it.**

**If `PR_BASE` is not `master`:**

1. Check whether the user explicitly mentioned the non-master target in their request (e.g., "review PR #123 which targets develop").
2. **If the user did NOT explicitly mention it:** Stop immediately. Report:
   > ⚠️ **PR #<number> targets `<PR_BASE>`, not `master`.** This PR appears to be aimed at the wrong branch. Aborting review to avoid wasted effort. Please verify with the PR author.
   Do **not** proceed with the review. Do **not** merge master. Do **not** run any review steps.
3. **If the user DID explicitly mention it:** Continue, but note the non-master target in the context file and in your final report.

**If `PR_BASE` is `master`:** proceed to step 2.

Running this before the workspace questions means a mis-targeted PR is rejected without ever asking the user where to work.

### 2. Choose the review workspace (current directory first)

#### Post mode asserts the workspace; it does not choose one

In post mode the worktree arrived as the process's working directory, and the caller created it,
checked the head out and installed its dependencies. There is nothing to ask, and nothing to infer
from the path: the path-names-the-branch heuristic below encodes one operator's personal layout, and a
caller's `wt/<number>` is not named for a branch at all. So post mode runs the six assertions below, in
order, and goes straight to step 2a. Everything else in this section — Checks 1 to 3, the guard, the
announcement — is present mode's.

Each assertion is a fact about the tree the review is about to read, and each failure names what was
wanted and what was found in `preflight.json`, so a wrong tree stops the run at the front instead of
becoming forty minutes of findings about somebody else's branch. Exit status is 3 for a failed
assertion and 2 for a missing `XDG_RUNTIME_DIR`.

```bash
# Fill in the four values resolved above, then run the block as one shell call.
REPO='<owner/repo>'          # owner/name — compared as owner/name, whatever the URL looks like
PR=<number>
HEAD_BRANCH='<PR_HEAD>'      # the PR's head branch
HEAD_SHA='<PR_HEAD_SHA>'     # the head this review was asked for, in full

[ -n "${XDG_RUNTIME_DIR:-}" ] || { echo "XDG_RUNTIME_DIR is not set — review artefacts live under it and there is no fallback" >&2; exit 2; }
REVIEW_DIR="$XDG_RUNTIME_DIR/pr-review/<owner>-<repo>/$PR"
mkdir -p "$REVIEW_DIR" && chmod 700 "$REVIEW_DIR"
ARTEFACT="$REVIEW_DIR/preflight.json"
rm -f "$ARTEFACT"            # a stale failure is not this run's result

fail() { # assertion expected actual
  jq -nc --arg assertion "$1" --arg expected "$2" --arg actual "$3" --arg head_sha "$HEAD_SHA" \
    '{assertion:$assertion,expected:$expected,actual:$actual,head_sha:$head_sha}' > "$ARTEFACT"
  chmod 600 "$ARTEFACT"
  printf 'preflight failed at %s: expected %s, actual %s\n' "$1" "$2" "$3" >&2
  exit 3
}

# 1. the working directory is the worktree itself, not a directory somewhere inside a repository:
#    the caller set the cwd to the tree, and every later assertion — and the pipeline — assumes the top
TOP="$(git rev-parse --show-toplevel 2>/dev/null)"
[ -n "$TOP" ] || fail worktree "the top of a git worktree" "$PWD is not in a repository"
[ "$TOP" = "$(pwd -P)" ] || fail worktree "the top of the worktree, $PWD" "inside $TOP"

# 2. origin is the repository under review, compared as owner/repo whatever form the URL takes
ORIGIN="$(git remote get-url origin 2>/dev/null)"
SLUG="$(printf '%s' "$ORIGIN" | sed -e 's#^[a-z][a-z+]*://[^/]*/##' -e 's#^[^@/]*@[^:]*:##' -e 's#/$##' -e 's#\.git$##')"
[ "$(printf '%s' "$SLUG" | tr '[:upper:]' '[:lower:]')" = "$(printf '%s' "$REPO" | tr '[:upper:]' '[:lower:]')" ] \
  || fail remote "$REPO" "${ORIGIN:-no origin remote} -> ${SLUG:-nothing}"

# 3. the branch, where the worktree is on one, is the PR's head branch. A detached worktree makes no
#    branch claim — a caller checks the head out by sha — and assertion 4 is what pins it instead.
ON="$(git branch --show-current)"
[ -z "$ON" ] || [ "$ON" = "$HEAD_BRANCH" ] || fail branch "$HEAD_BRANCH" "on $ON"

# 4. HEAD is the head the review was asked for, not the one an earlier run left behind
AT="$(git rev-parse HEAD)"
[ "$AT" = "$HEAD_SHA" ] || fail head_sha "$HEAD_SHA" "$AT"

# 5. the working tree is clean, so every difference the review reports belongs to the PR
DIRT="$(git status --porcelain)"
[ -z "$DIRT" ] || fail clean "nothing modified, staged, untracked or deleted" "$DIRT"

# 6. the dependencies are there. They are never installed here: provisioning is the caller's job
MISSING=""
[ -f composer.json ] && [ ! -f vendor/autoload.php ] && MISSING="vendor/autoload.php"
[ -f package.json ] && [ ! -d node_modules ] && MISSING="${MISSING:+$MISSING, }node_modules/"
[ -z "$MISSING" ] || fail dependencies "vendor/autoload.php and node_modules/ where the project declares them" "missing $MISSING"

printf 'preflight ok: %s PR #%s, %s at %s, in %s — six assertions passed\n' \
  "$REPO" "$PR" "${ON:-detached}" "$HEAD_SHA" "$PWD"
```

**Never create a worktree and never install a dependency.** Both are the caller's; a skill that
provisions its own workspace can no longer be told which tree it reviewed. A missing `vendor/` is
assertion 6 failing, not a build step to run.

Check whether the current working directory is inside a git repo:

```bash
TOPLEVEL="$(git rev-parse --show-toplevel 2>/dev/null)" || TOPLEVEL=""
CURRENT_REMOTE="$(git remote get-url origin 2>/dev/null)"
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
WORKTREE_PATH=""
```

**Check 1 — Already on the PR branch. This is the expected case, not a lucky one.** The user normally checks out the PR branch into a worktree and starts the session there, so check the current directory first and prefer it. A match requires all three:

- `CURRENT_REMOTE` is the same repo as `<owner/repo>` — compare owner/repo, not the raw URL (`git@github.com:<owner>/<repo>.git` and `https://github.com/<owner>/<repo>.git` both count)
- `CURRENT_BRANCH` equals `PR_HEAD`
- `git status --porcelain` shows no modified *tracked* files (see the guard below)

**On a match: set `WORKTREE_PATH="$TOPLEVEL"` and continue. Do not ask the user where to work, do not offer alternatives, do not create or switch anything.** Asking here is the exact failure this check exists to prevent. Then bring the branch up to date:

```bash
CURRENT_BRANCH='<PR_HEAD>'   # a match means this directory holds the PR branch; its own shell, so name it
git fetch origin "$CURRENT_BRANCH"
BEHIND="$(git rev-list --count HEAD..origin/"$CURRENT_BRANCH" 2>/dev/null)"
if [ "$BEHIND" != "0" ]; then
  git merge --ff-only origin/"$CURRENT_BRANCH"
fi
```

If the fast-forward fails, stop and ask the user rather than forcing anything.

**Guard — dirty working tree.** Before doing any review work, verify the review directory is clean. Run `git status --porcelain` and stop if there is *any* output — modified tracked files, untracked files, new files, deleted files, or staged changes. Previous reviews, abandoned experiments, or other branches may have left debris. Report the full `git status --porcelain` output and ask the user whether to commit, stash, or discard everything before proceeding. Ignored build artifacts (see step 2b) do not count — they are expected. Do not review over a dirty tree; it produces false findings and makes it impossible to tell which changes belong to the PR.

**Check 2 — Same repo, different branch. Present mode only** — post mode has already asserted and never asks, so a directory's name decides nothing there. The directory is the right repository but not the PR branch. **Compare the directory's path with the branch it is holding before deciding anything** — the user keeps one worktree per branch, named for it **in full** (`src/master`, `src/develop`, then one per ticket branch under whatever prefix that branch uses: `src/chore/<ticket>`, `src/feat/<ticket>`, `src/tickets/<ticket>`), so the name is an assertion about the contents and their navigation depends on it. Never parse the prefix — it is `chore/`, `fix/`, `bugfix/`, `hotfix/`, `docs/`, `refactor/`, or nothing at all, and it changes — so compare the whole path suffix against the whole branch name. Only the generic ones (`src/wip`, `src/review/wip`) change branch by design. That gives one test with no list of magic names to maintain: **does the directory's path name the branch it holds?**

| Path names… | What it means | What to do |
|---|---|---|
| **`PR_HEAD`** | This worktree is the PR branch's home; the checkout was simply forgotten | Confirm, then check out `PR_HEAD` here, and recommend it plainly |
| **the branch it holds, not `PR_HEAD`** (`master`, `develop`, `staging`, or any other branch under any prefix) | Another branch's home. The name promises those contents | **Do not offer this directory and do not switch it.** Name the mismatch and ask where to work — this is the case that needs a scratch worktree or a new one |
| **neither** | Scratch space, reused across reviews on purpose | Offer it as the default (below): a clean tree means the switch was forgotten, not that the directory is taken |

Compare words, not characters — case and separator style are cosmetic, so `hotfix/Payments-Down` and `hotfix/payments_down` are one name. Compare the whole path, not the basename, and keep the prefix in the comparison: `src/feat/issue-96-dashboard` names `feat/issue-96-dashboard` and `src/chore/install-vitest` names `chore/install-vitest`, though neither basename carries the prefix.

```bash
norm() { printf '%s' "$1" | tr 'A-Z' 'a-z' | tr '_-' '//'; }
ends_with() { case "$1" in *"$2") return 0;; esac; return 1; }
PR_HEAD='<PR_HEAD>'                   # its own shell: the comparison needs the PR branch named here
held="$(git branch --show-current)"   # the branch this directory currently holds
if [ -z "$held" ]; then echo "generic (detached HEAD) -> offer, default yes"
elif ends_with "$(norm "$PWD")" "$(norm "$PR_HEAD")"; then echo "names PR_HEAD -> switch here"
elif ends_with "$(norm "$PWD")" "$(norm "$held")"; then echo "another branch's home -> do not offer"
else echo "generic -> offer, default yes"; fi
```

For a generic directory or one named for `PR_HEAD`:

1. **Check out `PR_HEAD` in the current directory — the default whenever `git status --porcelain` is empty.** Confirm with the user and recommend it. Run `git fetch origin "$PR_HEAD"`, then `git checkout "$PR_HEAD"`. If the checkout is refused, fall through to option 2 or 3 rather than forcing it.
2. **Use a different existing worktree** — especially one already named for `PR_HEAD`. Run `git worktree list` and go there.
3. **Let the user create one** — ask them to create/check out a worktree and tell you the path.

**Do not create worktrees yourself** — creation needs project-specific setup beyond git — but checking out an existing branch in an existing worktree is not creation. If the user nonetheless directs you to use a directory named for another branch, follow the instruction and say which branch it will hold, so the exception is theirs and on the record rather than silent.

A dirty tree blocks the switch: clear it through the guard above first, then offer this choice. Set `WORKTREE_PATH` to whichever path results, and announce it in the pre-flight line below before any further step.

Step 16 re-checks the branch before any later read, for the same reason this step may switch it: the directory is shared, and it can move under you between turns.

**Check 3 — Not in a repo with the right remote.** Ask the user: diff-only review (fast, GitHub API) or full clone (slower, better). Diff-only means both children use `gh pr diff <number> --repo <owner/repo>` and have no surrounding codebase.

**Workspace pre-flight — announce it before continuing (present mode).** Post one line stating the resolved workspace and branch before any further step, for example:

> Workspace: `/path/to/worktree` — branch `feat/x`, PR #<number> head `feat/x` ✓, base `master` ✓

This makes a wrong workspace visible immediately instead of surfacing 40 minutes later as bogus findings. If the announced line disagrees with the PR, stop and fix it before step 2a.

### 2a. Merge master into the PR branch (conflict check)

Before reviewing, confirm the branch still integrates with master. This catches merge conflicts early and confirms the branch merges cleanly. The merge itself is then discarded (below), because it is a probe, not a change to the PR.

**Fetch latest master:**

```bash
cd "${WORKTREE_PATH:-$PWD}"   # post mode sets no WORKTREE_PATH: the process cwd is the worktree
git fetch origin master
```

**Merge master into the PR branch:**

```bash
# Fill these in from step 1.5: this is its own shell, so nothing set earlier is here.
PR_HEAD='<PR_HEAD>'
PR_HEAD_SHA='<PR_HEAD_SHA>'

# The remote-tracking ref the reset below needs, asserted first: a worktree added at a sha has no
# local branch and need not have this ref, and that failure belongs here rather than after a merge
# that then has to be undone.
git rev-parse --verify --quiet "refs/remotes/origin/$PR_HEAD" >/dev/null || {
  if [ "${PR_REVIEW_MODE:-present}" = post ]; then
    [ -n "${XDG_RUNTIME_DIR:-}" ] || { echo "XDG_RUNTIME_DIR is not set — review artefacts live under it and there is no fallback" >&2; exit 2; }
    REVIEW_DIR="$XDG_RUNTIME_DIR/pr-review/<owner>-<repo>/<number>"
    mkdir -p "$REVIEW_DIR" && chmod 700 "$REVIEW_DIR"
    jq -nc --arg assertion head_ref --arg expected "refs/remotes/origin/$PR_HEAD" \
      --arg actual "no such ref in $PWD" --arg head_sha "$PR_HEAD_SHA" \
      '{assertion:$assertion,expected:$expected,actual:$actual,head_sha:$head_sha}' \
      > "$REVIEW_DIR/preflight.json"
    chmod 600 "$REVIEW_DIR/preflight.json"
  fi
  printf 'preflight failed at head_ref: expected refs/remotes/origin/%s, actual none in %s\n' "$PR_HEAD" "$PWD" >&2
  exit 3
}
git merge origin/master --no-edit 2>&1
MERGE_EXIT=$?
```

**Interpret the result:**

| Outcome | Action |
|---|---|
| The block exits 3 before merging | `refs/remotes/origin/<PR_HEAD>` is absent, so the reset would fail after the merge. Stop: the branch was never fetched into this checkout, and the merge probe cannot answer anything about it. In post mode the artefact names the assertion `head_ref`. |
| Merge succeeds (exit 0) | The branch integrates cleanly. **Drop the merge again** (below), then proceed to step 2b. |
| Merge conflicts | **Stop.** Report the conflicts to the user and ask for a decision. Do **not** auto-resolve. |

**The merge is a conflict probe, not a change to the PR — drop it before you commit anything.**

This step answers one question: does the branch integrate with master? It is answered the moment the merge succeeds, and the merge commit then has no further job. Leaving it in place is what makes the later pushes awkward: every commit the review makes sits on top of a commit the remote has never seen, and the tempting fix is to rebase your work onto the PR head to get rid of it. **Never do that** — rebase is forbidden (`guide.md`, Hard constraints). Reset instead, and do it now, while nothing of yours is committed:

```bash
PR_HEAD='<PR_HEAD>'   # its own shell: the reset needs the branch named again
git reset --hard origin/"$PR_HEAD"
```

The branch is exactly the author's head again, every commit this review makes lands on it directly, and each push is a plain fast-forward. What this step contributes is the finding — "master merges cleanly" — which belongs in the context file and the report, not a commit.

Do not skip the reset and push the merge commit instead "because it is a fast-forward anyway". It would be one, but it puts a merge into the PR's history that the author did not make, and the next agent reading the branch cannot tell whose merges are whose.

**If there are merge conflicts:**

1. Abort the failed merge: `git merge --abort`
2. Report to the user:
   > ⚠️ **Merge conflicts detected** when merging `master` into `<headRefName>`. This means the PR branch is out of date with master.
   >
   > How would you like to proceed?
   > 1. **Fix the conflicts now** — I'll resolve them and commit, then continue with the review.
   > 2. **Hand back to the PR author** — ask them to merge master themselves before the review.
   > 3. **Abort the review** — stop here.
3. **Wait for the user's decision** before doing anything else.

### 2b. Build production assets (before the pipeline)

Generated frontend artifacts are **gitignored**, so a freshly checked-out worktree starts with whatever a previous build left behind — not what this branch needs. Wayfinder route and action definitions, Inertia/Ziggy helpers, and the Vite manifest are all in this category. When the branch adds or renames routes, `tsc` then fails on phantom errors such as `Property 'form' does not exist on type '...RouteDefinition...'` in files the PR never touched. Those errors burn review budget and mask real findings. They are caused by an unbuilt workspace, not by the branch, so the remedy is to build — never to report them, and never to dismiss them as pre-existing.

Build the assets so the workspace matches production before anything type-checks against it:

```bash
cd "${WORKTREE_PATH:-$PWD}"
# choose the package manager from the lockfile:
# bun.lock(b) → bun, pnpm-lock.yaml → pnpm, yarn.lock → yarn, package-lock.json → npm
bun run build
```

Look for a `build` script in `package.json` — in Laravel + Wayfinder projects it is typically `php artisan typescript:transform && vite build`, and `vite build` is what regenerates `resources/js/actions` and `resources/js/routes`. A production build of a large app can take several minutes; give it a generous timeout and do not interrupt it. **The shell tool's `timeout` is in seconds, not milliseconds** — `timeout: 900` is generous for a large app, whereas `900000` is read as ~10 days and rejected outright (`Invalid timeout: maximum is 2147483.647 seconds`), so the build never runs. This is different from a child's `timeoutMs`, which *is* milliseconds (`7_200_000` = 2h). Context-mode's `timeout` is also milliseconds: `timeout: 900000` for the same build — the value the shell tool rejects.

**Interpret the result:**

| Outcome | Action |
|---|---|
| Build succeeds | Proceed to step 2.5. Commit nothing — build outputs (`public/build`, generated route definitions) are gitignored. |
| Build succeeds but modifies **tracked** files | Commit them as auto-fixes (`git add -A && git commit -m "chore: regenerate build artifacts"`), then proceed. If the diff is substantial rather than obviously generated, stop and ask the user. |
| Build fails because dependencies are missing, or artifacts are absent or stale | **Fix it.** Install dependencies and rebuild, then re-run. This is yours to solve, not a finding to report. |
| Build fails on the branch's own code (a dangling import, a type error) | **Stop.** This **is** a PR finding and a blocker — report it with the failing output. It is not an environment defect, and the review must see it. |
| No frontend build script (backend-only repo) | Skip this step, note it, and proceed to step 2.5. |

**In post mode nothing is installed.** Dependencies are the caller's, and preflight assertion 6 has already failed the run if they are absent, so a build that cannot run here is reported and stop — the caller provisions. Installing would put this run's workspace under the review's own hand, which is exactly what the caller's provisioning exists to prevent.

**If generated-artifact errors appear anyway** — a missing Vite manifest, missing properties on Wayfinder definitions — do not classify them as pre-existing and do not hand them to the review. Run the build and re-run the pipeline. An error the merge would ship is an error, whatever produced it: production does not care that it predates the diff. Only a build that fails on the branch's own code is reportable, and then it is a blocker, not an environment note.

**Why before the pipeline, not after:** the pipeline's fix run invokes `tsc`, and `tsc` reads those generated definitions. Building afterwards validates a different tree than the one that failed. See `guide.md` for the rationale.

### 2.5. Establish a green baseline from the project's code quality pipeline

Before doing any review work, run the project's code quality pipeline in the worktree to confirm a
green starting point. This is non-negotiable: if you review against a dirty baseline, pre-existing
failures become your noise, not the PR author's signal. Production assets are already built (step 2b),
so a type-check reads current generated definitions rather than whatever a previous build left behind.

**The pipeline is the `composer.json` script named `fix`, and a project without it fails here.** One
command, by design: `fix` is the project's single entry point for its formatting, linting, tests and
type-checks, so the skill runs exactly that and nothing else. The individual scripts are not a
fallback — a project exposing `lint` and `types:check` but no `fix` has an incomplete toolchain, and
the review stops rather than assembling a substitute out of the parts it can find.

**Why the absence is a hard failure and not something to work around.** A review that quietly
improvises a pipeline judges the branch by a different standard from the one the project claims, and
nobody can tell which standard was applied; worse, it hides the missing script for months, which is
how a project gets reviewed weekly without anyone noticing it has no pipeline at all. This is a
development pipeline, and the whole point of one is to fail fast: the missing script is a defect in
the project, it surfaces the first time a PR is reviewed, and it is fixed in minutes. Filling the gap
so the review can carry on turns that into slow, silent rot — the failure does not go away, it goes
underground. So: no `fix` script, no review.

#### Resolve the pipeline, or stop

Each bash call is its own shell, so the command is written down once, where every later call and the
report can read it: `$REVIEW_DIR/pipeline.tsv`, the command and the formatters it invokes beside it.
Nothing is run here — and if there is no `fix` script, this block ends the review instead of returning
an empty answer for later steps to interpret.

```bash
# The one command the review will run, and the formatters it invokes — or a hard stop. Runs nothing.
[ -n "${XDG_RUNTIME_DIR:-}" ] || { echo "XDG_RUNTIME_DIR is not set — review artefacts live under it and there is no fallback" >&2; exit 2; }
REVIEW_DIR="$XDG_RUNTIME_DIR/pr-review/<owner>-<repo>/<number>"
mkdir -p "$REVIEW_DIR" && chmod 700 "$REVIEW_DIR"
PIPELINE="$REVIEW_DIR/pipeline.tsv"
: > "$PIPELINE"
PR_HEAD_SHA='<PR_HEAD_SHA>'   # its own shell: the refusal names the head it was asked to review

# A formatter is named from the commands the script actually invokes: composer's `@script` references
# resolve inside composer.json, and a package manager's `run` with a script name resolves in package.json.
FORMATTER_RE='pint|php-cs-fixer|phpcbf|biome|prettier|eslint|stylelint'

script_body() { # manifest file, script name — one command per line
  jq -r --arg s "$2" '.scripts[$s] // empty | if type=="array" then .[] else . end' "$1" 2>/dev/null
}

formatters_of() { # composer script name, recursion depth — the formatters it invokes, de-duplicated
  local name="$1" depth="${2:-0}" line sub out=""
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in
      @*) [ "$depth" -lt 4 ] && out+="$(formatters_of "${line#@}" $((depth + 1)))"$'\n' ;;
      "bun run "*|"npm run "*|"pnpm run "*|"yarn run "*)
        sub="${line#* run }"; sub="${sub%% *}"
        out+="$(script_body package.json "$sub" | grep -oE "$FORMATTER_RE")"$'\n' ;;
      *) out+="$(grep -oE "$FORMATTER_RE" <<<"$line")"$'\n' ;;
    esac
  done <<<"$(script_body composer.json "$name")"
  printf '%s' "$out" | grep -v '^$' | sort -u
}

if [ -f composer.json ] && jq -e '(.scripts // {}) | has("fix")' composer.json >/dev/null 2>&1; then
  printf 'composer run-script fix\t%s\n' "$(formatters_of fix | paste -sd, -)" > "$PIPELINE"
  printf 'pipeline: composer run-script fix — the project declares one code quality pipeline\n'
else
  if [ -f composer.json ]; then
    DECLARED="$(jq -r '.scripts // {} | keys | join(", ")' composer.json 2>/dev/null)"
    [ -n "$DECLARED" ] || DECLARED="nothing: composer.json has no scripts"
  else
    DECLARED="no composer.json in $PWD"
  fi
  printf 'HARD STOP — this project declares no `fix` script, so it has no code quality pipeline to run.\n  found: %s\n  expected: a composer.json script named `fix` that runs formatting, linting, tests and type-checks\nFix the project, not the review: the review has no substitute for its pipeline and will not assemble one.\n' "$DECLARED" >&2
  if [ "${PR_REVIEW_MODE:-present}" = post ]; then
    jq -nc --arg assertion pipeline \
      --arg expected 'a composer.json script named fix, running the project code quality pipeline' \
      --arg actual "$DECLARED" --arg head_sha "$PR_HEAD_SHA" \
      '{assertion:$assertion,expected:$expected,actual:$actual,head_sha:$head_sha}' > "$REVIEW_DIR/preflight.json"
    chmod 600 "$REVIEW_DIR/preflight.json"
  fi
  exit 3
fi
```

`pipeline.tsv` holds one line — `composer run-script fix` — for the rest of the run, so step 11 re-runs
that command instead of re-deriving it, and a project cannot redeclare its toolchain mid-review. The
second column is what lets post mode's finding name a formatter, and it is derived from what `fix`
invokes rather than guessed from file extensions. A formatter the resolver does not recognise leaves
the column empty, and that command's rewrites are then **not** claimed as formatting drift: naming the
command instead would put a `formatting` row into the recurrence query that no formatter reported, and
calling a regenerated file a format is a worse error than staying quiet about it.

#### Present mode: run it, and keep what the formatters changed

Present mode is where the fixers earn their keep: they make the branch meet its own declared standard,
and the rewrites are committed and pushed as pre-review sync. Nothing else is staged — the two
snapshots around the run decide which files those are.

```bash
# Present mode: run the pipeline and keep what it changed, so the fixers' rewrites can be staged.
cd "${WORKTREE_PATH:-$PWD}"
[ -n "${XDG_RUNTIME_DIR:-}" ] || { echo "XDG_RUNTIME_DIR is not set — review artefacts live under it and there is no fallback" >&2; exit 2; }
REVIEW_DIR="$XDG_RUNTIME_DIR/pr-review/<owner>-<repo>/<number>"
mkdir -p "$REVIEW_DIR" && chmod 700 "$REVIEW_DIR"
[ "${PR_REVIEW_MODE:-present}" = present ] || { echo "pipeline: this is the present-mode block and PR_REVIEW_MODE is $PR_REVIEW_MODE — post mode discards rewrites instead of pushing them" >&2; exit 2; }
PIPELINE="$REVIEW_DIR/pipeline.tsv"
[ -s "$PIPELINE" ] || { echo "pipeline: $PIPELINE is missing or empty — the project declares no fix script, which is a hard stop, not a review with nothing to run" >&2; exit 2; }
rm -f "$REVIEW_DIR/formatting.json"   # post mode's artefact; a stale one would invent a finding here

git status --porcelain > "$REVIEW_DIR/pipeline-before.txt"
while IFS=$'\t' read -r cmd _formatters; do
  [ -n "$cmd" ] || continue
  printf '\n== %s\n' "$cmd"
  if $cmd 2>&1; then printf '== %s: exit 0\n' "$cmd"; else printf '== %s: exit %s\n' "$cmd" "$?"; fi
done < "$PIPELINE"
git status --porcelain > "$REVIEW_DIR/pipeline-after.txt"
printf '\n== files the pipeline changed:\n'
comm -13 <(sort "$REVIEW_DIR/pipeline-before.txt") <(sort "$REVIEW_DIR/pipeline-after.txt")
```

#### Stage, commit and push what the pipeline rewrote

```bash
CURRENT_BRANCH='<PR_HEAD>'   # its own shell, and so is this call: the branch is named here
[ "${PR_REVIEW_MODE:-present}" = present ] || { echo "pipeline: this pushes, so it is present mode's alone; PR_REVIEW_MODE is $PR_REVIEW_MODE" >&2; exit 2; }
[ -n "${XDG_RUNTIME_DIR:-}" ] || { echo "XDG_RUNTIME_DIR is not set — review artefacts live under it and there is no fallback" >&2; exit 2; }
REVIEW_DIR="$XDG_RUNTIME_DIR/pr-review/<owner>-<repo>/<number>"
TOUCHED="$(comm -13 <(sort "$REVIEW_DIR/pipeline-before.txt") <(sort "$REVIEW_DIR/pipeline-after.txt") | awk '{print $2}')"
if [ -n "$TOUCHED" ]; then
  printf 'staging the %s file(s) the pipeline rewrote:\n%s\n' "$(grep -c . <<<"$TOUCHED")" "$TOUCHED"
  printf '%s\n' "$TOUCHED" | xargs -d '\n' -r git add
  git commit -m "style: quality pipeline auto-fixes"
  git push origin "$CURRENT_BRANCH"
else
  printf 'the pipeline changed nothing — nothing to stage, commit or push\n'
fi
```

> **Do not use `git add -A`.** The two snapshots are taken around the run and diffed, so the staged
> set is the files whose status the pipeline actually changed — a file that was already modified
> before the run has the same line in both snapshots and is never staged. `git add -A` would sweep
> unrelated working-tree changes into a commit labelled "style" and push them to the PR.

**Push the auto-fixes before launching the review — do not stop at committing.** A local-only commit means the review validates code the PR does not contain, and GitHub's diff still shows the unformatted version. Pushing mechanical formatting fixes back to the PR branch is normal pre-review sync, not a review change. If the push is rejected (no write access, protected branch), report it and ask whether to continue with the fix committed locally only.

**Push every formatting correction, including files this PR does not touch — Boy Scout rule.** Do not filter the auto-fix diff by whether a file appears in the PR's own changes. Formatting is the project's declared standard (Pint/Biome config), so correcting drift applies the standard rather than expressing an opinion, and the change is semantically inert. More importantly, in these projects nothing else will ever make the correction: CI runs the pipeline in fix mode (`composer fix`, `composer pint`, `biome check --write`) with no dirty-tree check, so drift is rewritten inside the runner and discarded, and the auto-commit step that would have pushed it is normally disabled. Drift inherited from `master` therefore persists forever unless a review pushes it — and because every review's baseline pipeline re-formats the same files, it resurfaces on every PR until corrected. Do not revert those files and do not defer them to a separate PR. If the report mentions them at all, it is only to label them mechanical pre-review formatting sync, never as an out-of-scope defect.

**The review target is the resulting HEAD — the complete PR as it will merge.** HEAD now contains the author's commits *plus* any pre-review auto-fix commits just pushed. That whole entity is what gets accepted into master, so it is what the reviewers judge: never scope a review to the author's original commit, and never to a SHA resolved before this step. In the worktree the reviewed diff is everything from the merge base:

```bash
git diff $(git merge-base HEAD origin/master)..HEAD --stat
```

#### Post mode: run it, then discard every rewrite

`post` mode never commits, and "never pushes" is the weaker half of that: the fixers' rewrites must
not survive the run either. The author's tree is not the review's to edit, and a reformat left in it
would be a change nobody authorised, made by a process with nobody reading it. So the pipeline still
runs — the baseline is the baseline in both modes — the rewrites are discarded, and the drift they
represented becomes a finding instead of a silent prose line.

```bash
# Post mode: run the pipeline, then put the tree back exactly as it arrived. Nothing is staged,
# committed or pushed; the rewrites become a finding instead.
cd "${WORKTREE_PATH:-$PWD}"
[ -n "${XDG_RUNTIME_DIR:-}" ] || { echo "XDG_RUNTIME_DIR is not set — review artefacts live under it and there is no fallback" >&2; exit 2; }
REVIEW_DIR="$XDG_RUNTIME_DIR/pr-review/<owner>-<repo>/<number>"
mkdir -p "$REVIEW_DIR" && chmod 700 "$REVIEW_DIR"
[ "${PR_REVIEW_MODE:-present}" = post ] || { echo "pipeline: this is the post-mode block and PR_REVIEW_MODE is ${PR_REVIEW_MODE:-present} — refusing to discard rewrites the other mode has to keep" >&2; exit 2; }
PIPELINE="$REVIEW_DIR/pipeline.tsv"
ARTEFACT="$REVIEW_DIR/formatting.json"
[ -s "$PIPELINE" ] || { echo "pipeline: $PIPELINE is missing or empty — the project declares no fix script, which is a hard stop, not a review with nothing to run" >&2; exit 2; }
RUNS="$REVIEW_DIR/pipeline-runs.jsonl"
: > "$RUNS" && rm -f "$ARTEFACT"

# Exit 4, not 3: nothing was reviewed and no preflight.json was written, so a caller must not go
# looking for one. 3 means an assertion about the workspace failed and the file says which.
DIRT="$(git status --porcelain)"
[ -z "$DIRT" ] || { printf 'pipeline: refused — the tree was not clean, so nothing a formatter rewrites could be told apart from it:\n%s\n' "$DIRT" >&2; exit 4; }

while IFS=$'\t' read -r cmd formatters; do
  [ -n "$cmd" ] || continue
  printf '\n== %s\n' "$cmd"
  if $cmd 2>&1; then status=0; else status=$?; fi
  changed="$(sort -u <<<"$(git diff --name-only; git diff --cached --name-only)" | grep -v '^$')"
  files=$(grep -c . <<<"$changed")
  git reset -q --hard HEAD            # the rewrite is discarded here, before anything reads the tree
  jq -nc --arg command "$cmd" --argjson exit "$status" --argjson files "$files" \
    --arg formatters "$formatters" --arg paths "$changed" \
    '{command:$command,exit:$exit,files:$files,
      formatters:($formatters|split(",")|map(select(.!=""))),
      paths:($paths|split("\n")|map(select(.!="")))}' >> "$RUNS"
  printf '== %s: exit %s, %s file(s) discarded\n' "$cmd" "$status" "$files"
done < "$PIPELINE"

# One artefact for the whole run — the report and the record both read it, so neither can disagree
# with the other about what the formatters wanted. Only commands that name a formatter contribute:
# files are counted once each, not once per command, because two scripts running the same formatter
# on one file is one file. A command that changed tracked files and names no formatter is recorded
# in `runs` and claimed as nothing.
jq -s '(map(select((.formatters|length) > 0))) as $f
      | {mode:"post",
         files:($f|map(.paths)|add // [] | unique | length),
         paths:($f|map(.paths)|add // [] | unique),
         formatters:($f|map(select(.files > 0))|map(.formatters)|add // [] | unique),
         runs:.}' "$RUNS" > "$ARTEFACT"
chmod 600 "$ARTEFACT" && rm -f "$RUNS"

STILL="$(git diff --name-only; git diff --cached --name-only)"
[ -z "$STILL" ] || { printf 'pipeline: the tree did not come back to HEAD — the review would judge a dirty tree:\n%s\n' "$STILL" >&2; exit 4; }

# A formatter rewrites files; a build script makes new ones, and those are already ignored or were
# there before. Say what is left, so "byte-identical" is a claim about the tracked tree and the
# reader can see the difference rather than taking it on trust.
UNTRACKED="$(git status --porcelain | grep '^??' || true)"
[ -z "$UNTRACKED" ] || printf 'pipeline: the run left untracked files — build output, not drift, and left in place:\n%s\n' "$UNTRACKED"

UNNAMED=$(jq -r '[.runs[] | select((.formatters|length) == 0 and .files > 0) | .command] | join(", ")' "$ARTEFACT")
[ -z "$UNNAMED" ] || printf 'pipeline: %s changed tracked files and names no recognised formatter — discarded, and not claimed as formatting drift\n' "$UNNAMED"

FILES=$(jq -r .files "$ARTEFACT")
if [ "$FILES" -gt 0 ]; then
  printf 'formatting: %s file(s) would be rewritten by %s — rewrites discarded, so this becomes a minor `formatting` finding\n' \
    "$FILES" "$(jq -r '.formatters|join(", ")' "$ARTEFACT")"
else
  printf 'formatting: no formatter drift, and the tracked tree is back at HEAD — no `formatting` finding\n'
fi
```

**Read `formatting.json` and carry one finding — or none.** `files` is how many tracked files a
formatter would rewrite — counted once each, not once per invocation, so a `fix` script that runs
the same formatter twice over one file still reports one file — `paths` are those files, `formatters` the tools whose
runs changed something, and `runs` every command with its exit status and what it touched. When
`files` is zero there is no finding: a clean tree is a clean tree, and inventing a formatting note
for it is noise. When it is greater than zero the review carries exactly one finding — one for the
drift, never one per file:

> ❔ [Inline fix] `formatting` — the project's declared formatters (`pint`) would rewrite 7 files:
> `app/Foo.php`, `app/Bar.php`, … The branch does not meet the project's own formatting standard;
> running the pipeline and committing the result closes it.

Minor severity because `standards.md` names formatting as a minor: no judgement is needed, and the
`formatting` label is in its vocabulary precisely so the recurrence is countable. The bucket is
`Inline fix` — the remedy is a formatter run, not a decision — and in this mode it is advice to the
author, because the review itself never acts. Present mode never raises this finding: there the
drift was fixed and pushed, and the label's absence is information too.

#### Say what ran

Both modes print the command and its exit status, and the report carries one line naming it —
`Baseline: composer run-script fix — exit 0` — beside the legend at the top (step 6). This is what
lets a reader of the review tell "green" from "never checked": the report names the pipeline that
actually ran, and a project that has none never reaches the report at all.

**Interpret the result:**

| Outcome | Action |
|---|---|
| Every command exits 0 | Proceed to step 3. In present mode, whatever the pipeline rewrote has been staged, committed and pushed first. |
| Every command exits 0, and post mode reports formatter drift | Proceed to step 3, carrying the `formatting` finding above into the report. The tree is already back at HEAD. |
| A command exits non-zero | **Stop.** Report the failing command and its output to the user. Ask whether to fix the failure first or proceed with the review knowing it pre-exists. Do not proceed silently. |
| The project declares no `fix` script | **Stop** — the resolution block already did, with exit 3 and a `preflight.json` naming assertion `pipeline` in post mode. Nothing to review against is not a review with fewer checks. |
| The post-mode block refuses (exit 4): a dirty tree, or one that did not return to HEAD | **Stop.** Nothing was reviewed, nothing is claimed, and no `preflight.json` exists — exit 4 is that case, and exit 3 always means an assertion wrote one. A tree that was dirty before the run contradicts preflight's assertion 5, so the workspace is wrong rather than the PR. |

**In post mode nothing is installed.** Dependencies are the caller's, and preflight assertion 6 has already failed the run if they are absent, so a build that cannot run here is reported and stop — the caller provisions. Installing would put this run's workspace under the review's own hand, which is exactly what the caller's provisioning exists to prevent.

> **Tip:** If you're unsure why we run the pipeline before reviewing, or what to do with the results, check `guide.md` for the rationale.

### 3. Gather PR metadata, the whole conversation, and previous review history

Pass both children the path to the committed standards file:

```bash
STANDARDS_FILE="$(dirname "$0")/standards.md"   # skills/pr-review/standards.md
```

It fixes severity (🔴 / 🟡 / ❔) and owns the finding-label vocabulary. It is read by reference, not
copied into the context file, so amending it changes the next review without editing any prompt.

`PR_HEAD`, `PR_BASE`, and `PR_TITLE` are already resolved (step 1.5). This step adds the description, file manifest, commits, and **the whole conversation**.

**Read the whole conversation, not just the description.** A PR is a dialogue: a developer answers a review question, confirms a decision, or corrects the review's reading of the code **in a comment**, because that is what the comment box is for. A review built from the description and the reviews alone re-asks questions that have already been answered and reports answered items as open, which reads to the author as though the conversation was never opened. All four reads are required:

```bash
gh pr view <number> --repo <owner/repo> --json number,title,body,headRefName,baseRefName,files,additions,deletions,author,state,createdAt
gh pr view <number> --repo <owner/repo> --json commits
gh api "repos/<owner>/<repo>/pulls/<number>/reviews?per_page=100" --jq '.[] | select(.state != "PENDING") | {id: .id, user: .user.login, body: .body, state: .state, commit_id: .commit_id, submitted_at: .submitted_at}'
gh api "repos/<owner>/<repo>/pulls/<number>/comments?per_page=100" --jq '.[] | {id: .id, user: .user.login, body: .body, path: .path, line: .line, diff_hunk: .diff_hunk}'
gh api "repos/<owner>/<repo>/issues/<number>/comments?per_page=100" --jq '.[] | {id: .id, user: .user.login, body: .body, created_at: .created_at}'
```

The last read is the **discussion thread**, and it is the one that gets dropped: `pulls/.../comments` returns *review* comments, while the author's reply to a review arrives as a *discussion* comment, so a round that fetches only the first three cannot see an answer at all. `gh pr view <number> --repo <owner/repo> --comments` prints the description and the whole thread in one read — keep it as the sanity check that nothing was missed.

**A reply that answers a review question closes that item.** When the author comments "confirmed X was the target" or "no change needed here", the item is answered: mark it ✅ in the report and do not carry it forward as still open. Re-asking an answered question is a review defect rather than caution, and it was never the author's fault for answering where comments belong. A reply is an answer, so it outranks an inference from the code or the description.

**Check any factual claim inside a reply against the code.** The two are not in tension: the decision a reply makes is the author's to make, and the fact it asserts is testable. A reply can be honest and still wrong about what the code does — for example one that says a change was scoped, when the same commit also removed a value other surfaces depended on. Honour the decision; verify the fact.

Extract a compact summary: title, description, file list (path + additions + deletions), commit SHAs and messages, base branch, head branch, **all previous review comments and change requests**, and **every discussion comment in chronological order with its author and timestamp**. Record each previous review's `commit_id` — that is the SHA GitHub recorded for the round, and it is the only reliable way to tell what state a previous finding referred to once the branch has moved. Use it when reconciling change requests in step 6 and when checking for reversals in step 7.

**Write the shared context file** — one file both children read, so task strings stay short and the two legs work from identical input:

```bash
[ -n "${XDG_RUNTIME_DIR:-}" ] || { echo "XDG_RUNTIME_DIR is not set — review artefacts live under it and there is no fallback" >&2; exit 2; }
REVIEW_DIR="$XDG_RUNTIME_DIR/pr-review/<owner>-<repo>/<number>"
mkdir -p "$REVIEW_DIR" && chmod 700 "$REVIEW_DIR"
CTX_FILE="$REVIEW_DIR/context.md"
```

It contains: PR number/repo, title, description, file manifest, commit list, base/head branches, the review workspace path, **the baseline the code quality pipeline produced** — that `composer run-script fix` ran, and what it exited with, and in post mode the formatter drift the run found, since a leg that repeats that drift is a duplicate finding rather than a second opinion — **the full previous review history** (all prior review bodies and inline comments including change requests), **and the whole discussion thread in chronological order** — every comment with its author, timestamp and body. The thread is where the author answers the review, so a round cannot reconcile change requests without it.

### 4. Launch reviewer and oracle in parallel

**Read `children.md` now** — it contains the exact task templates for both agents and the launch script.

Launch both as direct children in **one async `workflowScript`** with `runs.all`. Both use `context: "fresh"`, `cwd: $WORKTREE_PATH`, and an explicit generous `timeoutMs`. Task text references the shared context file rather than duplicating it.

If no worktree was created (diff-only mode), tell both children to use `gh pr diff <number> --repo <owner/repo>` and note they will not have full codebase access.

### 5. Monitor while they run

Do not block. Keep responding to the user. The two children are yours: check `subagent({ action: "status", view: "fleet" })`, tail a leg's transcript, and use `/subagents-fleet` for live per-child detail (steer `s`, stop `D`).

**Liveness signal:** a leg whose tool/turn/elapsed counters are advancing is working, even if it has produced no output for a while — a 45-minute review with test runs is normal. A leg whose counters are frozen for a long stretch may be stuck.

**Failure recovery — one leg at a time:** if a leg fails, times out, or is stopped, re-dispatch **only that leg** with the same agent and task (optionally with `resume` if its run is retained and resumable). Do not restart the healthy leg. A completed leg's output is preserved; proceed with what you have rather than burning the whole wave.

> **Tip:** If a leg appears stuck or fails, check `guide.md` for failure recovery guidance.

### 6. Consolidate

Merge the two reports into one structured document:

1. **Standards** — from the reviewer's Standards findings, plus post mode's `formatting` finding when the baseline pipeline reported drift (step 2.5; present mode never raises it)
2. **Spec Fidelity** — from the reviewer's Spec findings
3. **Pattern Consistency** — from the oracle's pattern/architecture findings
4. **Authorisation & Scoping** — from the oracle's auth findings
5. **Risk Areas** — from the oracle's risk findings
6. **Previous Review Follow-up** — only when previous reviews exist: per-request status (✅ addressed / still open written severity-then-❌, e.g. `🔴❌` `🟡❌` `❔❌`), reconciled against **both the author's replies in the discussion thread and the code at HEAD** — an item the author has answered in a comment is ✅ addressed even when the code never changed. Still-open items carry forward as repeat findings.
7. **Tests to add** — the tests the production-code findings call for, red-first where the code is currently wrong
8. **Most actionable before merge** — your own prioritised list

**Glyph vocabulary — one meaning each.** `🔴` blocker, `🟡` warning, `❔` minor, for findings that are still open; `✅` for fixed this round or verified correct, with the severity dropped; `⚠️` for reversal notes only; `🟢` is never a finding marker — it appears only in the Bottom line verdict, where green means "no problem, go". The red X is reserved for follow-up reviews and means *you were asked for this and did not fix it*: write it after the severity of a previously-requested item that is still open (`🔴❌`, `🟡❌`, `❔❌`), never on a new finding and never in an initial review. Open the report with the legend on one line so the code is self-describing, and name the three buckets beside it — `Inline fix`, `Issue`, `Decision` (step 10). **The line under the legend is the baseline line** — the commands that actually ran and what each exited with (step 2.5) — because a reader who cannot see which scripts ran cannot tell "green" from "never checked". Findings carry their bucket as a bracketed tag after the severity glyph, e.g. `❔ [Inline fix] …`, and the buckets are presented as separate groups in step 10's order, never interleaved. The bucket labels are words rather than glyphs, so the glyph vocabulary above stays one-meaning-each.

**Never write a bare number for a GitHub artefact.** Issues and pull requests share one numbering sequence per repository, so `#221` is ambiguous by construction and a reader cannot resolve it. Write `PR #221` or `issue #223` everywhere — headings, tables, prose, and anything that will be posted (review bodies, PR comments, issue bodies, commit messages). The prefix is required even when the surrounding context seems to make it obvious, because these lines are usually skimmed in isolation.

**Findings that require a change to production code carry a `Test:` line.** A defect in shipped behaviour is evidence that the suite has a hole, so the finding answers: which test should have caught this — `Test: <suite/file> — <assertion that fails without the fix>`? This is the preferred remedy, not an absolute one. State the reason on the same line when a test is impractical (a query-plan regression, a timing behaviour) or when the fix cannot be expressed as a test at all (a name that only reads badly), and name the owning workstream when the test belongs to other work — another ticket or a declared follow-up — so it is tracked rather than lost with the review. Skipping the line silently is the one thing not allowed: a preference nobody has to account for is a preference that quietly stops being followed.

**Findings that need no production-code change carry no `Test:` line.** A stale PR description, a plan doc naming a class that no longer exists, an ADR that contradicts shipped behaviour, a naming or readability observation: the remedy is an edit to the prose or to the shape of the code, and inventing a test for them is category confusion. Where an automated check would genuinely have caught one — a reference check that fails when a documented class is deleted, a shared constant that makes a wrong label unrepresentable — name it, because that check is worth having. Otherwise say plainly that the remedy is prose.

**Untested behaviour is worth flagging, and it is not the same as behaviour that is wrong.** Code that is correct only because nothing pins it will drift on the next touch, so name the missing test. But the test starts green, so it cannot be written red-first — it is a guard to add, not a defect to reveal. Flag it as a test gap and let the author schedule it; it does not carry the weight of wrong behaviour.

**Issues keep full depth** (code snippets, impact, fix recommendations, file/line references). **Confirmed-correct items collapse to terse "✅" one-liners.** Do not merge or rerank across axes — keep sections separate.

Append a **"What's Correct"** appendix collecting every confirmed-correct item into one checklist, then the **Bottom line** verdict as the very last block:

- 🟢 **APPROVE** — no blockers, no warnings, fewer than 3 ❔ minors (safe to track as follow-ups)
- 🟡 **CONSIDER NOT APPROVING** — no hard blockers, but any 🟡 warning or 3+ ❔ minors
- 🔴 **DO NOT APPROVE** — one or more 🔴 blockers

Format (exactly one line plus a one-sentence reason):

```markdown
---

## Bottom line

🟢 **APPROVE** — no blockers, no warnings; only [N] minor nit(s), safe to track as follow-ups.

Reason: [one sentence — the single most important factor behind the verdict]
```

### 7. Check for contradiction reversals

Before sanitising, cross-check every change request in the new report against the previous review history **and the author's replies to it** (both from the context file). A reversal is a new request demanding the *opposite* of what a previous review asked for (rename X→Y then Y→X; action-class→service-class then back; extract-then-inline; approve-then-reject-code-that-was-approved). Refinements in the same direction, requests about new code, and repeats of never-implemented requests are NOT reversals.

For each reversal, read the actual code in the worktree, weigh both arguments against project conventions and the PR's intent, then:

| Determination | Action |
|---|---|
| New recommendation is clearly correct | Keep it + add ⚠️ **Reversal note:** explaining the earlier recommendation and why it is walked back |
| Previous recommendation is clearly correct | Drop the new request; move it to "Confirmed correct" with a one-line explanation |
| Genuinely ambiguous | Do not include in the report; escalate to the user for arbitration with the tradeoff summarised |

### 8. Sanitise

Remove all internal process references from the report before presenting: no "reviewer", "oracle", "sub-agent", "orchestrator", "context: fresh", "worktree", "delegation", or methodology talk. Write as if you performed all the analysis yourself — "I" or "We", never "the reviewer found" or "the oracle noted". The PR author should see a clean, professional review.

### 9. Write the report to a file

```bash
[ -n "${XDG_RUNTIME_DIR:-}" ] || { echo "XDG_RUNTIME_DIR is not set — review artefacts live under it and there is no fallback" >&2; exit 2; }
REVIEW_DIR="$XDG_RUNTIME_DIR/pr-review/<owner>-<repo>/<number>"
mkdir -p "$REVIEW_DIR" && chmod 700 "$REVIEW_DIR"
REPORT_FILE="$REVIEW_DIR/report.md"
: > "$REPORT_FILE" && chmod 600 "$REPORT_FILE"   # created empty and owner-only, then filled
```

Write the sanitised report into that file — it is already mode 600, and truncating it does not change
the mode, so the report never exists readable by another account even for a moment. The file lives in
the review workspace and survives for follow-up questions.

### 9.5. Split times

Record the splits; do not narrate them in the report. A review is long enough that the shape of its
cost is worth knowing, and knowing whether 18 minutes is the legs or the assembly changes what to
optimise — but a timing block on every report is noise. So: **always measure, log into the record,
and show the numbers only when asked** (or in the aggregate over the record).

Derive them from the stamps emitted in step 0. Those values are epoch **milliseconds**, so the
differences are already milliseconds:

```bash
[ -n "${XDG_RUNTIME_DIR:-}" ] || { echo "XDG_RUNTIME_DIR is not set — review artefacts live under it and there is no fallback" >&2; exit 2; }
REVIEW_DIR="$XDG_RUNTIME_DIR/pr-review/<owner>-<repo>/<number>"
SPLITS="${SPLITS:-$REVIEW_DIR/splits.tsv}"   # a caller that already has the path may pass it in
declare -A S
while IFS=$'\t' read -r k v; do S[$k]=$v; done < "$SPLITS"

missing=()
for k in t0 preflight_end legs_start legs_end assembly_end t4; do
  [ -n "${S[$k]:-}" ] || missing+=("$k")
done

if [ ${#missing[@]} -eq 0 ]; then
  TIMING=$(jq -nc \
    --argjson t0 "${S[t0]}"   --argjson p  "${S[preflight_end]}" \
    --argjson ls "${S[legs_start]}" --argjson le "${S[legs_end]}" \
    --argjson a  "${S[assembly_end]}" --argjson t4 "${S[t4]}" \
    --argjson rev "${REVIEWER_MS}" --argjson ora "${ORACLE_MS}" \
    '{t0:$t0,
      preflight_ms:($p-$t0),
      dispatch_ms:($ls-$p),
      legs_ms:($le-$ls),
      assembly_ms:($a-$le),
      delivery_ms:($t4-$a),
      total_ms:($t4-$t0),
      reviewer_ms:$rev,
      oracle_ms:$ora,
      timing_complete:true}')
else
  TIMING=$(printf '%s\n' "${missing[@]}" | jq -R . | jq -sc \
    '{timing_complete:false, timing_missing:.}')
  echo "⚠ TIMING INCOMPLETE — missing stamp(s): ${missing[*]}" >&2
fi
```

`REVIEWER_MS` and `ORACLE_MS` are each leg's own elapsed time, as returned by its launch.

Two facts that make the numbers mean something:

- **The legs run in parallel, so the splits overlap.** `reviewer_ms + oracle_ms` exceeds
  `legs_ms`, and that is correct, not a bug — `legs_ms` is the wall clock from the first launch to
  the last return.
- **Only `total_ms` is a duration a human experiences.** Preflight and assembly are the parts you
  control; the legs are the parts the model controls. If total grows, check which one before
  reaching for anything else.

Never block or re-run a step to tidy up a measurement.

**A missing split is loud, never silent.** The record is still written — the findings are worth more
than the timings — but it carries `timing_complete:false` and the names of the stamps that never
landed, and the run says so in its own output. Six `null`s look exactly like a fast review to
anybody reading the log a month later, which is worse than having no timing at all.


### 9.6. Append the review record

One line per review, appended to the durable log — this is the only artefact that outlives the run,
and the only way a recurring finding can ever be spotted. The RAM-disk report is deliberately
ephemeral; the log is deliberately not.

```bash
MODE="${PR_REVIEW_MODE:-present}"     # its own shell: the mode is read again, not remembered
PR_HEAD_SHA='<PR_HEAD_SHA>'           # and so is the head this review was for
TIMING='<paste the object step 9.5 produced>'   # one object, not a reconstruction
REVIEW_LOG="${REVIEW_LOG:-$HOME/.pi/agent/state/reviews.jsonl}"
mkdir -p "$(dirname "$REVIEW_LOG")"
printf '%s\n' "$(jq -nc \
  --arg date "$(date -Iseconds)" \
  --arg repo "<owner/repo>" \
  --argjson pr <number> \
  --arg sha "$PR_HEAD_SHA" \
  --arg verdict "<approve|request-changes|commented|not-posted>" \
  --argjson legs '{"reviewer":"<ok|died|timeout>","oracle":"<ok|died|timeout>"}' \
  --argjson counts '{"blocker":N,"warning":N,"minor":N}' \
  --argjson labels '["<label>"]' \
  --arg mode "$MODE" \
  --arg comment_url "${COMMENT_URL:-}" \
  --argjson timing "$TIMING" \
  '{date:$date,repo:$repo,pr:$pr,sha:$sha,verdict:$verdict,mode:$mode,comment_url:$comment_url,legs:$legs,counts:$counts,labels:$labels,timing:$timing}')" >> "$REVIEW_LOG"
```

- `labels` is the de-duplicated set of labels from `standards.md` that this review actually raised.
  A fixed vocabulary makes recurrence a `GROUP BY`, not a text search:
  `jq -r .labels[] "$REVIEW_LOG" | sort | uniq -c | sort -rn`. A `formatting` finding from the
  baseline pipeline (step 2.5) belongs in this set like any other, and it is the reason the label
  exists: twelve reviews carrying `formatting` is one missing formatter run, not twelve defects.
- `timing.legs_ms` is the **longer** leg, not the sum — the legs overlap.
- `timing.timing_complete` is `false` when a split stamp never landed, and `timing.timing_missing`
  names it. Those rows are still worth keeping for the findings, but exclude them from timing
  statistics or a broken measurement re-enters the average as if it were a fast review.
- Write the line **even when the review is not posted** (user declined, or a leg died): a killed
  review is exactly the evidence needed for "this keeps happening".
- Never write findings prose here. The line records what kind, how much and how long — never what
  was said.

Then answer timing questions from the log rather than from memory. Everything below is **minutes**;
`total_min`/`total_mean`/`total_max` are the likely band for planning a batch, and rows with an
incomplete measurement are counted but excluded from the statistics:

```bash
jq -s '[.[] | select(.timing.timing_complete)] as $r
| { reviewed: length,
    timed: ($r|length),
    incomplete: (length - ($r|length)),
    total_min:    (($r|map(.timing.total_ms)|min) / 60000),
    total_mean:   (($r|map(.timing.total_ms)|add / ($r|length)) / 60000),
    total_median: (($r|map(.timing.total_ms)|sort|.[length/2|floor]) / 60000),
    total_max:    (($r|map(.timing.total_ms)|max) / 60000),
    median_legs:     (($r|map(.timing.legs_ms)|sort|.[length/2|floor]) / 60000),
    median_assembly: (($r|map(.timing.assembly_ms)|sort|.[length/2|floor]) / 60000)
  }' "$REVIEW_LOG"
```

### 10. Bucket every finding and recommend a disposition

Assign **every** finding to exactly one of three buckets, and present each bucket as its own group, in this order:

1. **Inline fix** — anything the review can correct in this session: prose, formatting, a comment or docblock, a name, a dangling reference, a missing test, a behaviour change pinnable with a red-first test, a small refactor. **Size is never a reason to knock a finding back to the author.** A finding leaves this bucket only when it needs a decision the review cannot make, needs access the review lacks, or belongs to work owned elsewhere.
2. **Issue** — a finding that must not be fixed in this PR: out of scope, cross-cutting, or needing its own scheduling. Propose a title and an assignee — the PR author by default, the operator for administrative or data tasks that need their access.
3. **Decision** — a finding whose remedy needs a choice only a human owns: product behaviour, whether a built-but-unrouted feature ships, a trade-off between defensible options, a deploy or production-data call, or access the review lacks. Give the options, the pros and cons of each, and your recommendation, so accepting the recommendation is a one-word answer.

**The grouping and the order are deliberate: never interleave the three buckets in one table or list.** Inline fix comes first because approving that group unblocks work immediately; the other two can then be considered at leisure.

**The bucket is part of the finding, not a later summary of it.** Every finding carries its bucket from the moment it is raised, and the disposition rules that bind it — "optional" is not a bucket, a remedy that splits gets two, re-bucketing between turns is a defect — are in `standards.md` under **Disposition**. A finding that reaches the disposition table in no bucket, or that changes bucket when challenged, has fallen through a crack the count then hides.

Lead with the recommended disposition — `Inline fix: 7 (~2h) · Issue: 3 · Decision: 0` — so the operator's default answer is "accept", with per-item overrides. Flag any inline fix estimated over ~30 minutes, touching more than three files, or changing behaviour beyond the finding it fixes, so it can be vetoed individually. The disposition line is also the operator's signal of how much work the review is taking on.

**Do not fix anything yet.** Fixing is the review's recommendation, never its own decision — wait for authorisation.

**Red-first applies to every production-code fix, whatever its size.** A finding that changes production code carries a `Test:` line and is fixed test-first (step 11.5): write the test against the unchanged code, watch it fail for the right reason, then fix, then revert the fix to confirm the test still fails. An inline fix that skips this leaves the suite as blind as it was when the finding was found, and a silent fix is never acceptable — every fix is listed in the report with its commit and its test. Prose-only findings carry no test line.

An inline fix is still a change, so it is committed and pushed like any other (step 11).

**In `present` mode**, present the report (step 12) with the disposition and a note like:

> Recommended disposition: Inline fix: [N] (~[effort]) · Issue: [M] · Decision: [K]. Want me to fix the inline group now?

Then:
- **Operator accepts** → Fix the inline findings, commit each, proceed to step 11, then propose the issues for approval (step 14).
- **Operator overrides** → Apply the overrides; leave everything not authorised for the author.

**In `post` mode**, there is nobody to authorise anything, so the buckets are structure for the comment and nothing more. State the disposition line as a recommendation — `Recommended disposition: Inline fix: 7 (~2h) · Issue: 3 · Decision: 0` — and never ask. Fixing is off the table (see Mode), so the line reads as advice to the author, not as a question.

### 11. Run the code quality pipeline on your changes (only if inline fixes were applied)

**`post` mode never fixes anything, so this step and step 11.5 are skipped entirely.** There are no changes of its own to pipeline, no commits to push, and no red-first ordering to honour — the review reports and stops. Reading them is still worth it: they are the standard the comment asks the author to meet.

After any inline fixes are committed, run the pipeline again to catch auto-fixes your changes introduced. **Re-run step 2.5's blocks — the Present mode run block, then Stage, commit and push — and do not resolve again.** The project's declaration has not changed, and the two blocks re-derive `REVIEW_DIR` and `PIPELINE` themselves, which is all a second shell needs; copying the loop here would be a second copy of the rule that has to be kept in step with the first. The snapshots are re-taken by the run block, so the stage block stages exactly what this run rewrote.

| Outcome | Action |
|---|---|
| Every command exits 0, no files changed | Proceed to push. |
| Every command exits 0, but the fixers rewrote files | Stage, commit and push through step 2.5's block — it stages only what the pipeline touched — then proceed. |
| A command fails because of your fixes | **Revert your changes.** Do not post broken code. Report the failure to the user. |

**Push all commits before presenting.** Baseline auto-fixes from step 2.5 were already pushed before the review launched; this covers commits made after it. After any inline fixes (and auto-fixes) are committed, push immediately:

```bash
CURRENT_BRANCH='<PR_HEAD>'   # its own shell again: set the branch this pushes
git push origin "$CURRENT_BRANCH"
```

**Do not skip this.** An unpushed commit means the merged PR will not contain the fixes you just made — the approval is posted on code that doesn't include your changes.

**If the push is rejected as non-fast-forward, or you find a local merge commit under your work, reset — never rebase.** A rebase rewrites commits, and the moment one of them is on the remote it needs a force push to land. Step 2a drops its merge commit precisely so this cannot arise; if it does anyway, get your work back onto the PR head without rewriting anything: `git reset --hard origin/"$PR_HEAD"` and cherry-pick your commits from a backup branch (a cherry-pick creates new commits, so nothing on the remote is rewritten). Never `git push --force`, and never rebase a commit that is already on the remote — merge instead.

> **Same rule applies after the review is posted.** If the user asks you to fix findings on the PR branch later, treat every pipeline run the same way: check `git diff` for auto-fixed files, commit them, and push before declaring the task done. The pipeline discipline does not stop at step 13.

### 11.5. Red first — fixing a production-code finding

A defect in shipped behaviour means the suite had a hole, so the fix is not complete until the suite closes it. Work in this order — for your own fixes, and (stated in the posted review) for the author's. It applies to findings that change production code; a prose-only finding has no test step.

**Shape A — the code is wrong.**

1. **Decide the test.** Name the suite and the file (Pest feature/unit, Pest arch, Vitest component, lint rule) and the assertion that has to fail.
2. **Write it against unchanged production code.**
3. **Run it and record the failure** — the test must fail, and fail for the reason the finding describes. A test that passes before the fix does not reproduce the finding, so fix the test until it does. This is the point of the exercise: it proves the defect is real *and* that the test can detect it.
4. **Only then change production code** — the smallest change that turns the test green. Never fix first and back-fill the test afterwards: a back-filled test is written to match the implementation, so it can no longer detect the defect.

**Shape B — the code is right but nothing pins it.** Write the test; it starts green, because there is no defect to reveal. Its value is the guard, so validate it the same way: break the implementation temporarily, confirm the test fails, then restore.

For both shapes: **re-run the full suite and the code quality pipeline** (step 11's discipline: stage only fixer-touched files, commit, push); **confirm the test is a real guard** by reverting the production change and watching the test fail again before restoring it — a test that stays green when the fix is removed is documentation; and **commit the test with the fix when a test applies**, because a fix commit with no test leaves no evidence the hole was closed.

When a test is genuinely impractical, the fix still ships and the reason is recorded in one clause, naming the check that would catch it instead. When a previous round's fix is re-checked, the same standard applies: a change request counts as addressed if a test now fails without it, or the report says why no test applies.

### 12. Present for approval

**In `post` mode there is no approval gate.** Do the thread re-read and the report write below — both exist for correctness, not for the gate — then go straight to step 13. Do not ask "post it?", do not wait, and do not treat the absence of an answer as a reason to stop.

**Re-read the discussion thread before presenting.** The review ran for 45–90 minutes, so the author may have replied while it did — re-run the `issues/<number>/comments` read from step 3 and compare the timestamps with the context file. If a reply has answered an outstanding question or corrected a point, close or amend that finding in the report before presenting it. A review that arrives asking about something already answered on the PR spends the author's time and shows the conversation was never opened.

**Write the full report contents as your actual response text** — copy the Markdown directly into what you say to the user. Do NOT summarize it. Do NOT just read it into a tool output block and describe it. The user reads the report inline.

If step 10 assigned findings to buckets, append the disposition line and the three bucket groups — **Inline fix first, then Issue, then Decision**, as separate groups (step 10) — and ask about the inline group:

> Recommended disposition: Inline fix: [N] (~[effort]) · Issue: [M] · Decision: [K]. Want me to fix the inline group now?

Then ask: "Post it? Revise something? Don't post?" — and act on the answer:

- **Post it** → Step 13
- **Revise X** → update REPORT_FILE, then re-present
- **Don't post** → stop; the report stays on disk (tell the user they can say "post the review of PR #<number>" later)

**If the user approved inline fixes in step 10** (and those fixes have been applied and pipeline-validated in step 11), re-present the updated report before posting.

### 13. Post the review

**Before posting, verify the report body matches the verdict.** Read through `$REPORT_FILE` and confirm that:

1. Every finding that was fixed inline (step 10/11) has been updated in the report body — not just the Bottom line. If a 🟡 finding was fixed, its text should now say ✅ (fixed) or be removed entirely. A report that still says "🟡 **X is broken**" in the body but shows 🟢 **APPROVE** in the Bottom line will confuse the PR author.
2. The Bottom line verdict matches the remaining findings. If all 🟡/🔴 findings were fixed inline, the Bottom line should be 🟢 APPROVE and the body should contain no unresolved warnings.
3. Nothing in the report asks a question the author has answered in the discussion thread since the report was assembled — re-check that thread, as step 12 does. The user's read of the report takes time too, and an author can reply in the meantime; amend the report body before posting.

If there is a mismatch, fix the report body first, then post.

**A request for changes asks for the tests alongside the fixes it asks for in production code.** Section 7 names each test, its file and its assertion, and step 11.5 fixes the order; say in the review body that the test for a production-code finding comes with the fix, and that a fix landing without one leaves the suite as blind as it was. Prose-only findings need no test — do not pad the review with synthetic ones. Lead the requested-changes section with the tests, then the code changes.

Determine the review state from the report's Bottom line, then post.

**`present` mode** — a human has read it and said post, so the verdict is theirs too:

```bash
[ -n "${XDG_RUNTIME_DIR:-}" ] || { echo "XDG_RUNTIME_DIR is not set — review artefacts live under it and there is no fallback" >&2; exit 2; }
REVIEW_DIR="$XDG_RUNTIME_DIR/pr-review/<owner>-<repo>/<number>"
REPORT_FILE="$REVIEW_DIR/report.md"
if grep -q '🟢 \*\*APPROVE\*\*' "$REPORT_FILE"; then
  REVIEW_STATE="--approve"
else
  REVIEW_STATE="--request-changes"
fi
gh pr review <number> --repo <owner/repo> $REVIEW_STATE --body-file "$REPORT_FILE"
```

**`post` mode** — a comment, never `--approve` and never `--request-changes`. An automated first pass has not earned a verdict on someone's merge, and a review that blocks a merge with nobody standing behind it is worse than a comment the author can read and judge:

```bash
[ -n "${XDG_RUNTIME_DIR:-}" ] || { echo "XDG_RUNTIME_DIR is not set — review artefacts live under it and there is no fallback" >&2; exit 2; }
REVIEW_DIR="$XDG_RUNTIME_DIR/pr-review/<owner>-<repo>/<number>"
REPORT_FILE="$REVIEW_DIR/report.md"
PR_HEAD_SHA='<PR_HEAD_SHA>'   # its own shell: the marker names the sha this comment belongs to
MARKER="<!-- pr-review:${PR_HEAD_SHA} -->"
COMMENT_FILE="$REVIEW_DIR/comment.md"
{
  printf '%s\n\n' '**Automated review — not a final review.** This is an automated first pass, posted while no reviewer was available to read it beforehand. It is a comment: it is not an approval and not a request for changes, and it neither blocks nor unblocks the merge. Expect a human follow-up; treat the findings as a starting point.'
  cat "$REPORT_FILE"
  printf '\n%s\n' "$MARKER"
} > "$COMMENT_FILE"

# One comment per head SHA: a re-review of the same commit edits what is already
# there rather than adding a second.
EXISTING_ID=$(gh api "repos/<owner/repo>/issues/<number>/comments" --paginate \
  | jq -r --arg m "$MARKER" '.[] | select(.body | contains($m)) | .id' | tail -1)

if [ -n "$EXISTING_ID" ]; then
  jq -n --rawfile body "$COMMENT_FILE" '{body:$body}' \
    | gh api -X PATCH "repos/<owner/repo>/issues/comments/$EXISTING_ID" --input - --jq .html_url
else
  gh pr comment <number> --repo <owner/repo> --body-file "$COMMENT_FILE"
fi
```

Hold the URL it prints as `COMMENT_URL` for the record (step 9.6). **If the post fails, fail the run out loud** — a review that reviewed and did not post is a failed run, not a quiet one, and a dispatcher told it succeeded on one will never notice.

**The traffic light stays, and gains one honesty clause.** The report's Bottom line keeps its 🟢/🟡/🔴 verdict. In `post` mode the comment must also say plainly, in its first line after the banner, when the review is **partial** — a leg that died or timed out, a baseline that could not run, a suite that was absent. "One leg did not complete; these are the reviewer's findings alone" is the sentence. A clean verdict over a dead oracle is the one thing this mode must never publish.

**Sanitisation matters more here, not less.** In `present` mode a human reading the report is the last check on leaked paths, credentials, internal hostnames and half-finished reasoning. With that check removed, step 8 is load-bearing: no local paths, no artefact paths, no harness or session detail, no credentials, nothing about the machine it ran on.

### 14. Offer to escalate outstanding findings to GitHub issues

**Skip this step entirely in `post` mode.** Creating issues needs an explicit yes and there is nobody to give one, so unfixed findings are named in the comment as follow-ups for the author or the operator to raise.

Propose a GitHub issue for every finding left unfixed once the disposition is settled — whether the review is posted as an approval or as a request for changes — so nothing is lost between rounds. This is the Issue bucket from step 10, presented with a proposed title and assignee: **the PR author by default**, and the operator for administrative or data tasks that need their access. Group only what shares a subsystem or fix class; keep self-contained fixes as their own issue. Check `gh issue list` for duplicates first, present the proposed list, and wait for an explicit yes — never create issues unprompted. Skip documentation-only items and anything another issue tracks.

Link the created issues from the PR (review bodies are immutable, so links go in a comment):

```bash
# every issue body references the PR in the exact form: PR #<number>
gh pr comment <number> --repo <owner/repo> --body "Outstanding follow-ups from the review: #<n> #<n> …"
```

Verify the comment is visible on the PR before moving on.

### 15. Cleanup

When the user says "clean up review <number>": **only when the PR has been merged or closed.** If the PR is still open, remind them the report and context file are active reference material and suggest waiting.

- Delete `${XDG_RUNTIME_DIR}/pr-review/<owner>-<repo>/<number>/` (review artefacts directory)
- If the user created a worktree for this review, ask them whether to remove it — do not remove it yourself

### 16. Follow-up questions

**Re-check the workspace before you trust any read of it.** The review directory is a shared worktree, deliberately reused across reviews, and it gets switched to other branches between sessions. A session that ended on the PR branch can reopen on a different one, and every `git` or `grep` result then describes the wrong tree. A `grep` for a symbol the PR added returns nothing on a branch that never had it — which reads exactly like the author having fixed it. The failure is silent and confident, so it survives scrutiny: this has already produced a near-miss, where a ledger correct in every other respect was one command away from being posted about the wrong branch.

```bash
PR_HEAD='<PR_HEAD>'                  # its own shell again
cd "${WORKTREE_PATH:-$PWD}"          # post mode sets no WORKTREE_PATH: the worktree is the cwd
git fetch origin "$PR_HEAD"
git branch --show-current   # must equal PR_HEAD, or be empty where the worktree was added detached
git rev-parse HEAD          # must equal the head recorded for this review, not an earlier commit
git status --porcelain      # must be empty before any read is trusted
```

When any of the four disagrees, repair the workspace before reading anything — check the PR head out into it, or ask the user when the switch was theirs and other work is in flight.

The children's reports are in your session's context and the report/transcripts are on disk. Answer codebase questions directly, run tests the reviewer flagged, or revise the report on request. A completed leg can be resumed with `subagent({ action: "resume", id, message })` when its run is retained/resumable.

### 17. Review post-mortem (optional)

When the user says "run the review post-mortem" (or "post-mortem"), produce the standard metrics analysis: for each leg (reviewer, oracle) report duration, tool-call mix (`serena_*` vs `bash` vs `read`/`grep`/`find`), turns, tokens (input/output/cache-read) and cost where available, with diff-size context, and compare against previous rounds. Attribute differences honestly (diff size vs serena vs test infrastructure). Note: serena availability is machine-dependent — a run with no serena calls is not a defect and must never be flagged as one; the review flow is identical with or without it.
