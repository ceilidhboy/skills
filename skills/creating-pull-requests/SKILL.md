---
name: creating-pull-requests
description: Company pull request workflow and branch policy. Use when user says "create a PR", "make a pull request", "open a PR", or when managing GitHub pull requests for company projects.
author: Mike Scott
version: '1.0.0'
updated: '2026-07-11'
---

# Creating Pull Requests

## Branch Policy

```
feature branches ──→ develop (merge for testing/preview)
feature branches ──→ master  (via PR, when signed off)

NEVER develop ──→ master
NEVER PR into develop
```

### Branch roles

| Branch | Purpose | Disposable? | Gets PRs? |
|--------|---------|-------------|-----------|
| `develop` | Sandbox / WIP / experimental. Non-technical staff preview work here. | ✅ Yes — recreate from `master` if broken | ❌ Never — merge directly |
| `master` | Production. Only clean, signed-off code. | ❌ No | ✅ Yes — from feature branches only |
| `staging` (if exists) | Pre-production gate. Final testing before release. | Conditional | ✅ From feature branches |

### Non-negotiable rules

- **Never create a PR from `develop` to `master`.** `develop` may contain half-baked or abandoned work. A PR from `develop` risks merging experimental code into production.
- **Never create a PR into `develop`.** Merging directly is faster and keeps `develop` a simple sandbox. If it breaks, recreate from `master`.
- **Always PR from a clean feature branch into `master`.** The feature branch should contain only the work for that specific feature or fix.
- **`develop` is disposable.** If `develop` gets into a bad state, drop it and create a fresh one from `master`.

### The reasoning

`develop` is used not just for developers to test features in combination, but also to allow non-technical staff within the business to preview and sign off work. Features on `develop` may be incomplete, abandoned, or never signed off. Pulling `develop` into `master` would put experimental or rejected code into production — a serious issue.

## How to Create a PR

1. Identify the correct feature branch (e.g. `feat/my-feature` or `fix/my-bugfix`)
2. Ensure the branch is pushed to GitHub
3. Create the PR targeting `master`:
   ```bash
   gh pr create \
     --base master \
     --head <feature-branch-name> \
     --title '<descriptive title>' \
     --body '<summary of changes>'
   ```
4. Verify the PR was created successfully (check the URL)

### What to include in the PR body

- Summary of changes (what and why)
- Key technical decisions
- Testing notes (what was tested, how)
- Links to related ADRs if applicable

## Common Mistakes - Anti-Patterns

| Mistake | Why it's wrong | Correct approach |
|---------|---------------|------------------|
| PR from `develop` → `master` | May include unfinished/abandoned work | PR from clean feature branch |
| PR into `develop` | Adds unnecessary process to a sandbox | Merge directly into `develop` |
| Including multiple features in one PR | Hard to review, hard to roll back | One feature per PR |
