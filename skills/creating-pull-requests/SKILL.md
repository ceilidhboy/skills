---
name: creating-pull-requests
description: Company pull request workflow and branch policy. Use when user says "create a PR", "make a pull request", "open a PR", or when managing GitHub pull requests for company projects.
author: Mike Scott
version: '1.1.4'
updated: '2026-11-08'
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

## Comment voice and attribution

### First, check which identity is acting

Attribution depends on how the agent reaches GitHub, not on the tool it uses.

| The agent acts as | Comments, PRs and issues appear as | This section |
|---|---|---|
| A **GitHub App** — a personal one, or the company one | the app, which is named so that it is obviously an agent and not a person | **does not apply**: attribution is already unambiguous, so write in whichever voice is clearest. Signing as the coding agent is optional. |
| The **operator's own credentials** — `gh` logged in as them, or a personal access token | the operator personally | **applies**: follow the rules below |

Check before writing, because it changes the rules: `gh auth status` reports the account the CLI will use. If it names the operator rather than an app, you are posting as the operator.

### When the comment posts as the operator

Comments and PR bodies then appear **under the operator's GitHub account**. A first-person sentence reads as the operator speaking, and an apology reads as the operator apologising for something the agent did.

Neutral project voice is the default: write the record, not a personal note. "The base branch was wrong" is better than "I got the base wrong".

If the agent does write in the first person, or names itself, it must do both of these:

1. **Open with an attribution note**, for example:
   ```markdown
   ### **Note: me, I and mine in this comment refer to a coding agent, not to me**
   ```
2. **Sign the comment `coding agent`.** The words carry the meaning: a bare name could pass for a person. Add the agent's name if it has one — `Jarvis, coding agent` — but `coding agent` alone is enough.

Rules that hold either way:

- **Never attribute a fault to the operator that the agent caused.** Name the agent when the sentence is about its mistake: "the agent opened this against `develop`".
- **First person for the operator's own decisions is fine**, and still worth phrasing neutrally where practical.
- **A closed PR gets a comment saying why**, so nobody reconstructs the reason later. The same holds for a closed issue.

## Common Mistakes - Anti-Patterns

| Mistake | Why it's wrong | Correct approach |
|---------|---------------|------------------|
| PR from `develop` → `master` | May include unfinished/abandoned work | PR from clean feature branch |
| PR into `develop` | Adds unnecessary process to a sandbox | Merge directly into `develop` |
| Including multiple features in one PR | Hard to review, hard to roll back | One feature per PR |
| Closing a PR without a comment | The reason is lost, and it looks arbitrary later | Comment why, and where the work went instead |
| First-person comment posting as the operator, with no attribution | Reads as the operator confessing the agent's mistake | Neutral voice, or an attribution note and a `coding agent` signature. Not needed when posting as a GitHub App |
