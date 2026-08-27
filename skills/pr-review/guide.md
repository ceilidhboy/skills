# PR Review — Guide

This file contains hard-won lessons and rationale for the PR review workflow. Read this before starting any review — these lessons prevent real failures.

## Hard lessons

- **Run the quality pipeline (`composer fix`) before starting any review work.** A green baseline means any errors found later are unambiguously the PR author's, not pre-existing drift. Auto-fixes should be committed immediately so the branch starts clean.
- **Always pass an explicit generous `timeoutMs` on every child** (minimum 7,200,000 = 2h). The default run budget is 30 minutes and has killed far too many reviews of mid-size PRs — the parent died at the budget wall and cascade-killed a still-working oracle mid-analysis, losing ~30 minutes of work. A review of a 20+ file PR with test runs regularly needs 45–90 minutes per leg.
- **Children are launched with `context: "fresh"` + a shared context file**, never `context: "fork"` — forking would drag this session's entire conversation into the children. The orchestration metadata lives in one file both children read.
- **Keep the parent as orchestrator and final decision-maker.** Never post anything to the PR without the user's explicit approval.

## Why we do things this way

### Why commit auto-fixes immediately (step 2.5)

If you leave auto-fixes uncommitted, they pollute the working tree and confuse the review children's diff analysis. Committing them gives the review a clean baseline and attributes any new issues found during review to the PR author's changes, not pre-existing drift.

### Why not skip the baseline pipeline (step 2.5)

Running the pipeline at the end (after changes) means you cannot distinguish pre-existing problems from problems you introduced. Running it at the beginning means any errors found later are unambiguously yours to own.

### Why merge master before reviewing (step 2b)

Reviewing a branch that can't merge cleanly into master wastes everyone's time. The conflicts will need resolving eventually — better to surface them now, before the review investment.

### Why push after inline fixes (step 11)

An unpushed commit means the merged PR will not contain the fixes you just made — the approval is posted on code that doesn't include your changes. This is a critical failure: never tell the user everything is ready if there are unpushed commits.

### Why the baseline pipeline runs twice (steps 2.5 and 11)

The baseline pipeline run (step 2.5) validated the pre-existing state. Step 11 validates the state after your inline fixes. Skipping step 11 means auto-fixes from your changes land uncommitted, and the approval is posted on code that is not green.

## Hard constraints

- **Verify the PR targets master before doing anything else** — step 2a is a hard gate. If the PR targets a branch other than `master` and the user did not explicitly mention that in their request, stop immediately. Do not merge master, do not review, do not proceed.
- **Merge master before reviewing** — step 2b catches merge conflicts early. If conflicts appear, ask the user; never auto-resolve.
- **Establish a green baseline before reviewing** — run `composer fix` in the worktree; commit auto-fixes; report failures to the user.
- **Run the quality pipeline after any inline fixes** — step 11 exists because your changes may trigger Pint/Biome auto-fixes. Skipping it means the approval is posted on code that is not green.
- **Do not modify project source code during the review itself** — this is review-only work. The two exceptions are: (1) committing quality pipeline auto-fixes (Pint/Biome formatting) during step 2.5 to establish a clean baseline; (2) fixing trivial one-line findings in step 10. Both are pre-review hygiene, not review changes.
- **Never mention the review process** in the posted comment.
- **Keep the review constructive** — focus on code, not people.
- **Never post without approval** — Step 12 always precedes Step 13.
- **Always pass an explicit generous `timeoutMs`** on every child launch.
- **Maximum concurrency for children is 2** — reviewer and oracle, in parallel.
- **Do not create worktrees** — always ask the user where to work (see step 2, Check 2).
- **Cleanup is explicit or automatic** — only once the PR is merged or closed.
