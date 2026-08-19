# Runbook — Retrofit Formatting Enforcement on an Existing Project

Expanded command-level walkthrough for the formatting-enforcement skill. Run top to bottom.

## 0. Baseline

In a checkout of the project (worktree on the current master), measure the drift with check-only commands. All three should exit 0 on a healthy master; non-zero = drift exists.

```bash
composer test:lint          # pint --test            -> exit 1 if PHP files need formatting
npm run format:check        # prettier --check       -> exit 1 if resources/ files need formatting
npm run lint:check          # biome ci .             -> exit 1 if frontend files need formatting
```

Note exactly which files are flagged. These are the one-time cleanup list.

## 1. Clean the drift on a chore branch

Never run the pipeline on a feature branch and commit the results there — that pollutes the feature PR with unrelated churn and collides with other PRs touching the same lines (e.g. a composer.json re-indentation colliding with another PR's dependency change).

```bash
git fetch origin
git checkout -b chore/apply-quality-pipeline origin/master   # or `git worktree add` in a bare-repo setup

# Run the pipeline in gate-consistent order. The last formatter to run owns the
# files on disk, so run it last:
npm run lint          # biome check . --write
npm run format        # prettier --write resources/
composer lint         # pint --parallel

# Resolve formatter conflicts (see Conflict Matrix in SKILL.md) BEFORE committing:
# 1. biome.json: css.formatter.quoteStyle = "single"
# 2. biome.json: assist.enabled = false        (prettier owns import order)
# 3. biome.json: exclude !composer.json from formatter.includes
# Re-run the pipeline after config changes.

# Commit the formatting delta:
git add -A
git commit -m "chore: apply quality pipeline formatting to clear accumulated drift"

# PR to master, get it reviewed and merged. Master is now self-consistent.
```

## 2. Merge master back into open feature branches

For each open feature branch that contains formatting churn:

```bash
git checkout feature/branch
git merge origin/master    # or: git rebase origin/master
```

The merge takes master's formatted versions of the churned files; the feature branch's diff shrinks to just the feature. Resolve any conflicts by taking master's version of files that are formatting-only:

```bash
git checkout --theirs -- path/to/formatted/only/file   # during merge conflict
git add path/to/formatted/only/file
```

## 3. Install the gate and hooks

```bash
# 1. Replace the lint workflow's fix-mode commands with check-only ones
#    (copy references/lint.yml from this skill), remove any dead auto-commit step,
#    set permissions: contents: read.

# 2. Add husky + lint-staged (merge references/package-json.snippets.json):
npm install -D husky lint-staged     # or: bun add -d husky lint-staged
mkdir -p .husky
cp references/pre-commit .husky/pre-commit && chmod +x .husky/pre-commit
npm install                          # or: bun install  -> runs prepare, wires hooks

# 3. Configure biome.json (only if the project keeps Prettier; Biome-only projects skip this):
python3 - <<'PY'
import json
b = json.load(open('biome.json'))
b['css'] = {'formatter': {'quoteStyle': 'single'}}
b['assist'] = {'enabled': False}
b['formatter'] = {'includes': ['**', '!composer.json']}
json.dump(b, open('biome.json', 'w'), indent=2)
PY
```

## 4. Verify

```bash
# Gate green on the cleaned tree:
composer test:lint && npm run format:check && npm run lint:check   # all exit 0

# Hooks wired:
git config core.hooksPath   # -> .husky/_

# Hook fires and reformats on commit (deliberately misformatted staged file):
printf '<?php class Bad{public function x(){return 1;}}' > tmp_bad.php
git add tmp_bad.php
git commit -m "hook test"
git show HEAD:tmp_bad.php   # should be pint-formatted
git reset HEAD~1 && rm tmp_bad.php

# Feature branches show no churn after rebase/merge: git diff --stat origin/master

## 5. Communicate

Tell the team: run `npm install`/`bun install` once per worktree after pulling; commits are now auto-formatted, CI fails on drift. Check hooks with `git config core.hooksPath`.

## Rollback

Remove the workflow steps and delete `.husky/`; the committed drift cleanup commit on master can be reverted without semantic impact (it is formatting-only, verified by the checks it enables).