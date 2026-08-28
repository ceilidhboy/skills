---
name: pr-review
description: Review a GitHub pull request by orchestrating reviewer + oracle sub-agents directly from the orchestrating session, consolidating their findings into a single report, and asking for approval before posting. Use when user says "review PR #N", "review pull request", "review this PR", "review N on owner/repo", provides a PR URL, or asks for a PR review.
---

# PR Review

You are the orchestrator of the PR review. You run the `reviewer` and `oracle` sub-agents directly as your own children — there is no intermediate review agent. This flat shape is intentional: both children appear in your fleet with live per-child detail (model, context mode, tool/token/elapsed counters, current activity), so a working-but-slow child is distinguishable from a stuck one, and a stuck leg can be steered or re-dispatched individually without losing the other leg's work. Never reintroduce a wrapper agent for this flow.

**Before starting any review, read `guide.md`** — it contains hard-won lessons and constraints that prevent real failures (timeout budgets, context mode, baseline rules). This is not optional.

## Review artifacts directory

Review artifacts (context file, report) must live in a RAM disk, not in the project directory. The correct location is `${XDG_RUNTIME_DIR}/pr-review/$number/` where `XDG_RUNTIME_DIR` is the user-specific runtime directory (typically `/run/user/$(id -u)`). Check it with `echo $XDG_RUNTIME_DIR` — it defaults to `/run/user/1000` on most Linux systems. Do NOT create review artifacts inside the project worktree — it pollutes the working tree and risks them being committed.

## Workflow

### 1. Parse the request

Extract the PR number and optional owner/repo from:

| Input format | Extracted |
|---|---|
| `Review PR #44` | number=44, repo from git remote |
| `Review PR #44 on owner/repo` | number=44, owner/repo given |
| `https://github.com/owner/repo/pull/44` | number=44, owner/repo parsed from URL |
| `owner/repo#44` | number=44, owner/repo parsed |

If the owner/repo cannot be determined from the task or the git remote, ask the user before proceeding.

### 2. Detect the current directory / choose the review workspace

Check whether the current working directory is inside a git repo:

```bash
TOPLEVEL="$(git rev-parse --show-toplevel 2>/dev/null)" || TOPLEVEL=""
CURRENT_REMOTE="$(git remote get-url origin 2>/dev/null)"
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
```

**Check 1 — Already on the PR branch and up to date:** if the remote matches the target repo AND `CURRENT_BRANCH` matches the PR's `headRefName`, verify it's current and use it directly:

```bash
git fetch origin "$CURRENT_BRANCH" 2>/dev/null
BEHIND="$(git rev-list --count HEAD..origin/"$CURRENT_BRANCH" 2>/dev/null)"
if [ "$BEHIND" = "0" ]; then
  WORKTREE_PATH="$TOPLEVEL"
else
  git merge --ff-only origin/"$CURRENT_BRANCH" 2>/dev/null
  WORKTREE_PATH="$TOPLEVEL"
fi
```

**Check 2 — Same repo, different branch:** ask the user where to work. **Do not create worktrees yourself** — worktree creation requires project-specific setup beyond git. Give these options:

1. **Use `wip/`** — if a `wip` directory exists at the project root, ask whether to use it
2. **Pick an existing worktree** — list existing worktrees (`git worktree list`) and let the user choose
3. **Create your own** — ask the user to create a worktree and tell you the path

Set `WORKTREE_PATH` to whichever directory the user selects.

**Check 3 — Not in a repo with the right remote:** ask the user: diff-only review (fast, GitHub API) or full clone (slower, better). Diff-only means both children use `gh pr diff <number> --repo <owner/repo>` and have no surrounding codebase.

### 2a. Verify the PR targets master (hard gate)

**This is the very first thing you do after establishing the workspace. Do not skip it.**

Fetch the PR's base branch from GitHub:

```bash
BASE_BRANCH=$(gh pr view <number> --repo <owner/repo> --json baseRefName --jq '.baseRefName')
```

**If `BASE_BRANCH` is not `master`:**

1. Check whether the user explicitly mentioned the non-master target in their request (e.g., "review PR #123 which targets develop").
2. **If the user did NOT explicitly mention it:** Stop immediately. Report:
   > ⚠️ **PR #<number> targets `<BASE_BRANCH>`, not `master`.** This PR appears to be aimed at the wrong branch. Aborting review to avoid wasted effort. Please verify with the PR author.
   Do **not** proceed with the review. Do **not** merge master. Do **not** run any review steps.
3. **If the user DID explicitly mention it:** Continue, but note the non-master target in the context file and in your final report.

**If `BASE_BRANCH` is `master`:** Proceed to step 2b.

### 2b. Merge master into the PR branch (pre-review sync)

Before reviewing, ensure the PR branch is up to date with master. This catches merge conflicts early and confirms the branch integrates cleanly.

**Fetch latest master:**

```bash
cd "$WORKTREE_PATH"
git fetch origin master
```

**Merge master into the PR branch:**

```bash
git merge origin/master --no-edit 2>&1
MERGE_EXIT=$?
```

**Interpret the result:**

| Outcome | Action |
|---|---|
| Merge succeeds (exit 0) | Proceed to step 2.5. Branch is up to date. |
| Merge conflicts | **Stop.** Report the conflicts to the user and ask for a decision. Do **not** auto-resolve. |

**If there are merge conflicts:**

1. Abort the failed merge: `git merge --abort`
2. Report to the user:
   > ⚠️ **Merge conflicts detected** when merging `master` into `<headRefName>`. This means the PR branch is out of date with master.
   >
   > How would you like to proceed?
   > 1. **Fix the conflicts now** — I'll resolve them and commit, then continue with the review.
   > 2. **Hand back to the PR author** — ask them to rebase/merge master themselves before the review.
   > 3. **Abort the review** — stop here.
3. **Wait for the user's decision** before doing anything else.

### 2.5. Establish green baseline

Before doing any review work, run the project's quality pipeline in the worktree to confirm a green starting point. This is non-negotiable: if you review against a dirty baseline, pre-existing failures become your noise, not the PR author's signal.

**Run the pipeline:**

```bash
cd "$WORKTREE_PATH" && composer fix 2>&1
```

This runs Pint (formatting), Biome (JS/TS linting), Pest (tests), and tsc (type-check) in one shot — the standard Laravel quality pipeline.

**Interpret the result:**

| Outcome | Action |
|---|---|
| All green, no file changes | Proceed to step 3. Clean baseline confirmed. |
| All green, but Pint/Biome auto-fixed files | **Commit the fixes immediately** on the PR branch (`git add -A && git commit -m "style: quality pipeline auto-fixes"`) so the branch starts green. Then proceed to step 3. |
| Test failures or type errors | **Stop.** Report the failures to the user. Ask whether to fix them first or proceed with the review knowing the failures pre-exist. Do not proceed silently. |

> **Tip:** If you're unsure why we run the pipeline before reviewing, or what to do with the results, check `guide.md` for the rationale.

### 3. Gather PR metadata and previous review history

```bash
gh pr view <number> --repo <owner/repo> --json number,title,body,headRefName,baseRefName,files,additions,deletions,author,state,createdAt
gh pr view <number> --repo <owner/repo> --json commits
gh api "repos/<owner>/<repo>/pulls/<number>/reviews?per_page=100" --jq '.[] | select(.state != "PENDING") | {id: .id, user: .user.login, body: .body, state: .state, submitted_at: .submitted_at}'
gh api "repos/<owner>/<repo>/pulls/<number>/comments?per_page=100" --jq '.[] | {id: .id, user: .user.login, body: .body, path: .path, line: .line, diff_hunk: .diff_hunk}'
```

Extract a compact summary: title, description, file list (path + additions + deletions), commit SHAs and messages, base branch, head branch, and **all previous review comments and change requests**.

**Write the shared context file** — one file both children read, so task strings stay short and the two legs work from identical input:

```bash
REVIEW_DIR="${XDG_RUNTIME_DIR}/pr-review/$number"
mkdir -p "$REVIEW_DIR"
CTX_FILE="$REVIEW_DIR/context.md"
```

It contains: PR number/repo, title, description, file manifest, commit list, base/head branches, the review workspace path, **and the full previous review history** (all prior review comments and inline comments including change requests).

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

1. **Standards** — from the reviewer's Standards findings
2. **Spec Fidelity** — from the reviewer's Spec findings
3. **Pattern Consistency** — from the oracle's pattern/architecture findings
4. **Authorisation & Scoping** — from the oracle's auth findings
5. **Risk Areas** — from the oracle's risk findings
6. **Previous Review Follow-up** — only when previous reviews exist: per-request status (✓ addressed / ⚠ still open), still-open items carried forward as repeat findings
7. **Most actionable before merge** — your own prioritised list

**Issues keep full depth** (code snippets, impact, fix recommendations, file/line references). **Confirmed-correct items collapse to terse "✓" one-liners.** Do not merge or rerank across axes — keep sections separate.

Append a **"What's Correct"** appendix collecting every confirmed-correct item into one checklist, then the **Bottom line** verdict as the very last block:

- 🟢 **APPROVE** — no blockers, no warnings, fewer than 3 minor issues (safe to track as follow-ups)
- 🟡 **CONSIDER NOT APPROVING** — no hard blockers, but any 🟡 warning or 3+ 🟢 minors
- 🔴 **DO NOT APPROVE** — one or more 🔴 blockers

Format (exactly one line plus a one-sentence reason):

```markdown
---

## Bottom line

🟢 **APPROVE** — no blockers, no warnings; only [N] minor nit(s), safe to track as follow-ups.

Reason: [one sentence — the single most important factor behind the verdict]
```

### 7. Check for contradiction reversals

Before sanitising, cross-check every change request in the new report against the previous review history (from the context file). A reversal is a new request demanding the *opposite* of what a previous review asked for (rename X→Y then Y→X; action-class→service-class then back; extract-then-inline; approve-then-reject-code-that-was-approved). Refinements in the same direction, requests about new code, and repeats of never-implemented requests are NOT reversals.

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
REPORT_FILE="$REVIEW_DIR/report.md"
```

Write the sanitised report there. The file lives in the review workspace and survives for follow-up questions.

### 10. Offer inline fixes

Before presenting the report for approval, identify trivial one-line findings that can be fixed in 30 seconds (missing env var, renamed property, typo, missing docblock, missing test for a simple mapping). Do NOT fix them yet — first present the report to the user and ask whether to fix them inline or leave them for the PR author.

**Present the report (step 12) with a note like:**

> I found [N] trivial finding(s) I can fix inline before posting. Want me to fix them now, or leave them for the author?

Then:
- **User says yes** → Fix the findings, commit each, proceed to step 11.
- **User says no** → Skip step 11, proceed to step 12 with the report as-is.

Do NOT create issues for things that take 30 seconds — issues are for design decisions, non-trivial implementation, or product input.

### 11. Run quality pipeline on your changes (only if inline fixes were applied)

After any inline fixes are committed, run the pipeline again to catch auto-fixes your changes introduced:

```bash
cd "$WORKTREE_PATH" && composer fix 2>&1
```

| Outcome | Action |
|---|---|
| All green, no file changes | Proceed to push. |
| All green, but Pint/Biome auto-fixed files | **Commit the fixes immediately** (`git add -A && git commit -m "style: quality pipeline auto-fixes"`). Proceed to push. |
| Test failures or type errors caused by your fixes | **Revert your changes.** Do not post broken code. Report the failure to the user. |

**Push all commits before presenting.** After any inline fixes (and auto-fixes) are committed, push immediately:

```bash
git push origin "$CURRENT_BRANCH"
```

**Do not skip this.** An unpushed commit means the merged PR will not contain the fixes you just made — the approval is posted on code that doesn't include your changes.

> **Same rule applies after the review is posted.** If the user asks you to fix findings on the PR branch later, treat every `composer fix` run the same way: check `git diff` for auto-fixed files, commit them, and push before declaring the task done. The pipeline discipline does not stop at step 13.

### 12. Present for approval

**Write the full report contents as your actual response text** — copy the Markdown directly into what you say to the user. Do NOT summarize it. Do NOT just read it into a tool output block and describe it. The user reads the report inline.

If step 10 identified trivial findings, append a line like:

> I found [N] trivial finding(s) I can fix inline before posting. Want me to fix them now, or leave them for the author?

Then ask: "Post it? Revise something? Don't post?" — and act on the answer:

- **Post it** → Step 13
- **Revise X** → update REPORT_FILE, then re-present
- **Don't post** → stop; the report stays on disk (tell the user they can say "post the review of PR #<number>" later)

**If the user approved inline fixes in step 10** (and those fixes have been applied and pipeline-validated in step 11), re-present the updated report before posting.

### 13. Post the review

Determine the review state from the report's Bottom line, then post:

```bash
if grep -q '🟢 \*\*APPROVE\*\*' "$REPORT_FILE"; then
  REVIEW_STATE="--approve"
else
  REVIEW_STATE="--request-changes"
fi
gh pr review <number> --repo <owner/repo> $REVIEW_STATE --body-file "$REPORT_FILE"
```

### 14. Offer to escalate outstanding findings to GitHub issues **only when the review is APPROVED**

If the review is posted as an approval but the report still contains unresolved 🟡/🟢 findings that were NOT fixed inline, propose turning them into GitHub issues **assigned to the PR author** so they don't get lost. Do NOT offer this when the review is posted as CHANGES_REQUESTED — those findings already block the merge and are tracked in the PR thread; re-offer later only if the PR is closed without merging or the author explicitly punts a finding. Group only what shares a subsystem or fix class; keep self-contained fixes as their own issue. Check `gh issue list` for duplicates first, present the proposed list, and wait for an explicit yes — never create issues unprompted. Skip documentation-only items and anything another issue tracks.

Link the created issues from the PR (review bodies are immutable, so links go in a comment):

```bash
# every issue body references the PR in the exact form: PR #<number>
gh pr comment <number> --repo <owner/repo> --body "Outstanding follow-ups from the review: #<n> #<n> …"
```

Verify the comment is visible on the PR before moving on.

### 15. Cleanup

When the user says "clean up review <number>": **only when the PR has been merged or closed.** If the PR is still open, remind them the report and context file are active reference material and suggest waiting.

- Delete `${XDG_RUNTIME_DIR}/pr-review/$number/` (review artifacts directory)
- If the user created a worktree for this review, ask them whether to remove it — do not remove it yourself

### 16. Follow-up questions

The children's reports are in your session's context and the report/transcripts are on disk. Answer codebase questions directly, run tests the reviewer flagged, or revise the report on request. A completed leg can be resumed with `subagent({ action: "resume", id, message })` when its run is retained/resumable.

### 17. Review post-mortem (optional)

When the user says "run the review post-mortem" (or "post-mortem"), produce the standard metrics analysis: for each leg (reviewer, oracle) report duration, tool-call mix (`serena_*` vs `bash` vs `read`/`grep`/`find`), turns, tokens (input/output/cache-read) and cost where available, with diff-size context, and compare against previous rounds. Attribute differences honestly (diff size vs serena vs test infrastructure). Note: serena availability is machine-dependent — a run with no serena calls is not a defect and must never be flagged as one; the review flow is identical with or without it.
