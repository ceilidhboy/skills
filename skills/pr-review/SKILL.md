---
name: pr-review
description: Review a GitHub pull request by orchestrating reviewer + oracle sub-agents directly from the orchestrating session, consolidating their findings into a single report, and asking for approval before posting. Use when user says "review PR #N", "review pull request", "review this PR", "review N on owner/repo", provides a PR URL, or asks for a PR review.
---

# PR Review

You are the orchestrator of the PR review. You run the `reviewer` and `oracle` sub-agents directly as your own children — there is no intermediate review agent. This flat shape is intentional: both children appear in your fleet with live per-child detail (model, context mode, tool/token/elapsed counters, current activity), so a working-but-slow child is distinguishable from a stuck one, and a stuck leg can be steered or re-dispatched individually without losing the other leg's work. Never reintroduce a wrapper agent for this flow.

## Hard lessons (why it works this way)

- **Run the quality pipeline (`composer fix`) before starting any review work.** A green baseline means any errors found later are unambiguously the PR author's, not pre-existing drift. Auto-fixes should be committed immediately so the branch starts clean.
- **Always pass an explicit generous `timeoutMs` on every child** (minimum 7,200,000 = 2h today). The default run budget is 30 minutes and has killed far too many reviews of mid-size PRs — the parent died at the budget wall and cascade-killed a still-working oracle mid-analysis, losing ~30 minutes of work. A review of a 20+ file PR with test runs regularly needs 45–90 minutes per leg.
- **Children are launched with `context: "fresh"` + a shared context file**, never `context: "fork"` — forking would drag this session's entire conversation into the children. The orchestration metadata lives in one file both children read.
- **Keep the parent as orchestrator and final decision-maker.** Never post anything to the PR without the user's explicit approval.

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

Define the review workspace base — a per-user tmpfs wiped on reboot:

```bash
BASE="${XDG_RUNTIME_DIR:-/run/user/1000}/pr-review"
mkdir -p "$BASE"
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

**Check 2 — Same repo, different branch:** create a temporary worktree under `$BASE/<owner>/<repo>/<number>/`. It shares git objects, so it is near-instant. Clean stale review worktrees (older than 1 hour) first; always use `git worktree remove` (removes directory AND admin record atomically), never `rm -rf` first:

```bash
git worktree prune
# … (list `git worktree list --porcelain`, remove any under $BASE that are older than 60 min,
#    using `git worktree remove --force` for the directory and `git branch -D` for its branch)
git fetch origin pull/<number>/head:refs/heads/pr-review-tmp-<number>
mkdir -p "$BASE/<owner>/<repo>"
git worktree add "$BASE/<owner>/<repo>/<number>" pr-review-tmp-<number>
WORKTREE_PATH="$BASE/<owner>/<repo>/<number>"
```

**Check 3 — Not in a repo with the right remote:** ask the user: diff-only review (fast, GitHub API) or full clone (slower, better). Diff-only means both children use `gh pr diff <number> --repo <owner/repo>` and have no surrounding codebase.

Review dir in all cases: `mkdir -p "$BASE/<owner>/<repo>/<number>"`.

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

**Why commit immediately:** If you leave auto-fixes uncommitted, they pollute the working tree and confuse the review children's diff analysis. Committing them gives the review a clean baseline and attributes any new issues found during review to the PR author's changes, not pre-existing drift.

**Why not skip this:** Running the pipeline at the end (after changes) means you cannot distinguish pre-existing problems from problems you introduced. Running it at the beginning means any errors found later are unambiguously yours to own.

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
CTX_FILE="$BASE/<owner>/<repo>/<number>/context.md"
```

It contains: PR number/repo, title, description, file manifest, commit list, base/head branches, the review workspace path, **and the full previous review history** (all prior review comments and inline comments including change requests).

### 4. Launch reviewer and oracle in parallel

Launch both as direct children in **one async `workflowScript`** with `runs.all`. Both use `context: "fresh"` (see Hard lessons), `cwd: $WORKTREE_PATH`, and an explicit generous `timeoutMs`. Task text references the shared context file rather than duplicating it.

```javascript
subagent({
  workflowScript: `
    const results = await runs.all([
      { key: 'reviewer', agent: 'reviewer', context: 'fresh', cwd: '<WORKTREE>', timeoutMs: 7_200_000,
        task: 'Review PR #<number> on <owner/repo> (<title>). Read the shared context file at <CTX_FILE> first — it has the full PR metadata, file manifest, commits, and the complete previous review history. Worktree: <WORKTREE> (explore the full codebase to check integration, not just the diff). Review along two axes: Standards (conventions, smells) and Spec (fidelity to the PR description). Report per-axis findings with file/line refs; explain what, why, and how to fix for anything needing changes; 🔴 blocker / 🟡 warning / 🟢 minor; terse one-line "✓ works correctly" bullets for confirmed-correct items; one-line summary per axis. Cross-check each finding against the previous review history: flag reversals with a ⚠ Reversal note, and verify each previous change request was implemented (✓ addressed / ⚠ still open — carry still-open ones forward). You have no bash: note any test or git command the orchestrator should run. Use serena_* tools when present.' },
      { key: 'oracle', agent: 'oracle', context: 'fresh', cwd: '<WORKTREE>', timeoutMs: 7_200_000,
        task: 'Check decision consistency for PR #<number> on <owner/repo> (<title>). Read the shared context file at <CTX_FILE> first — it has the full PR metadata, file manifest, commits, and the complete previous review history; treat it as the authoritative contract. Worktree: <WORKTREE>. Check pattern consistency, authorisation alignment, architectural drift, and risk areas; verify imports resolve and patterns match existing code; run tests if useful (you have bash). Report with specific file/line refs; explain what, why, and how to fix for any concern; terse "✓ consistent / clean / no concern" bullets for what verifies; end with a summary of the most important concern or a clean bill. Cross-check against previous review history (reversal notes, ✓ addressed / ⚠ still open). Use serena_* tools when present.' }
    ]);
    return results.map(r => ({ key: r.key, output: r.output }));
  `,
  async: true
})
```

If no worktree was created (diff-only mode), tell both children to use `gh pr diff <number> --repo <owner/repo>` and note they will not have full codebase access.

**Note on context:** the reviewer/oracle agent files already instruct the serena workflow and the review output shape. Their serena tool grants come from `~/.pi/agent/settings.json` → `subagents.agentOverrides` keyed by agent name — they apply to any parent; there is nothing to configure per-launch.

### 5. Monitor while they run

Do not block. Keep responding to the user. The two children are yours: check `subagent({ action: "status", view: "fleet" })`, tail a leg's transcript, and use `/subagents-fleet` for live per-child detail (steer `s`, stop `D`).

**Liveness signal:** a leg whose tool/turn/elapsed counters are advancing is working, even if it has produced no output for a while — a 45-minute review with test runs is normal. A leg whose counters are frozen for a long stretch may be stuck.

**Failure recovery — one leg at a time:** if a leg fails, times out, or is stopped, re-dispatch **only that leg** with the same agent and task (optionally with `resume` if its run is retained and resumable). Do not restart the healthy leg. A completed leg's output is preserved; proceed with what you have rather than burning the whole wave.

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
REPORT_FILE="$BASE/<owner>/<repo>/<number>/report.md"
```

Write the sanitised report there. The file lives alongside the worktree so cleanup removes both together, and it survives for follow-up questions.

### 10. Present for approval

**Write the full report contents as your actual response text** — copy the Markdown directly into what you say to the user. Do NOT summarize it. Do NOT just read it into a tool output block and describe it. The user reads the report inline.

Then ask: "Post it? Revise something? Don't post?" — and act on the answer:

- **Post it** → Step 11
- **Revise X** → update REPORT_FILE, then re-present
- **Don't post** → stop; the report stays on disk (tell the user they can say "post the review of PR #<number>" later)

### 11. Post the review

Determine the review state from the report's Bottom line, then post:

```bash
if grep -q '🟢 \*\*APPROVE\*\*' "$REPORT_FILE"; then
  REVIEW_STATE="--approve"
else
  REVIEW_STATE="--request-changes"
fi
gh pr review <number> --repo <owner/repo> $REVIEW_STATE --body-file "$REPORT_FILE"
```

### 12. Offer to escalate outstanding findings to GitHub issues **only when the review is APPROVED**

If the review is posted as an approval but the report still contains unresolved 🟡/🟢 findings, propose turning them into GitHub issues **assigned to the PR author** so they don't get lost. Do NOT offer this when the review is posted as CHANGES_REQUESTED — those findings already block the merge and are tracked in the PR thread; re-offer later only if the PR is closed without merging or the author explicitly punts a finding. Group only what shares a subsystem or fix class; keep self-contained fixes as their own issue. Check `gh issue list` for duplicates first, present the proposed list, and wait for an explicit yes — never create issues unprompted. Skip documentation-only items and anything another issue tracks.

Link the created issues from the PR (review bodies are immutable, so links go in a comment):

```bash
# every issue body references the PR in the exact form: PR #<number>
gh pr comment <number> --repo <owner/repo> --body "Outstanding follow-ups from the review: #<n> #<n> …"
```

Verify the comment is visible on the PR before moving on.

### 13. Cleanup

When the user says "clean up review <number>": **only when the PR has been merged or closed.** If the PR is still open, remind them the report and worktree are active reference material and suggest waiting.

- Worktree still exists: `git worktree remove --force $BASE/<owner>/<repo>/<number>` (force is needed for the untracked report.md/context.md), then `git branch -D pr-review-tmp-<number>`
- Directory already gone (e.g. tmpfs wiped by a WSL restart): `git worktree prune` to clear the orphaned admin record
- **Never `rm -rf` the worktree directory first** — git cannot see that deletion and the record lingers as "prunable"

### 14. Follow-up questions

The children's reports are in your session's context and the report/transcripts are on disk. Answer codebase questions directly, run tests the reviewer flagged, or revise the report on request. A completed leg can be resumed with `subagent({ action: "resume", id, message })` when its run is retained/resumable.

### 15. Review post-mortem (optional)

When the user says "run the review post-mortem" (or "post-mortem"), produce the standard metrics analysis: for each leg (reviewer, oracle) report duration, tool-call mix (`serena_*` vs `bash` vs `read`/`grep`/`find`), turns, tokens (input/output/cache-read) and cost where available, with diff-size context, and compare against previous rounds. Attribute differences honestly (diff size vs serena vs test infrastructure). Note: serena availability is machine-dependent — a run with no serena calls is not a defect and must never be flagged as one; the review flow is identical with or without it.

## Hard Constraints

- **Establish a green baseline before reviewing** — run `composer fix` in the worktree; commit auto-fixes; report failures to the user.
- **Do not modify project source code during the review itself** — this is review-only work. The one exception is committing quality pipeline auto-fixes (Pint/Biome formatting) during step 2.5 to establish a clean baseline; those are not review changes, they are pre-review hygiene.
- **Never mention the review process** in the posted comment.
- **Keep the review constructive** — focus on code, not people.
- **Never post without approval** — Step 10 always precedes Step 11.
- **Always pass an explicit generous `timeoutMs`** on every child launch.
- **Maximum concurrency for children is 2** — reviewer and oracle, in parallel.
- **Clean stale review worktrees before creating a new one** — only delete worktrees older than 1 hour to avoid disrupting concurrent reviews.
- **Cleanup is explicit or automatic** — only once the PR is merged or closed.