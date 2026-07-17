---
name: pr-review
description: Review a GitHub pull request using reviewer + oracle sub-agents and post findings as a PR review comment. Use when user says "review PR #N", "review pull request", "review this PR", or asks for a PR review.
---

# PR Review

When asked to review a GitHub pull request:

1. **Determine the PR number** — extract it from the user's request (e.g. "PR #44", "pull request 44")
2. **Optionally determine the repo** — if the user mentions an owner/repo, note it
3. **Launch the `pr-reviewer` sub-agent** with the PR number (and repo if given) as the task:

```javascript
subagent({
  agent: "pr-reviewer",
  task: "Review PR #<number>"
})
```

If a repo was specified (e.g. `SociallyEnterprise/elody/shiftcore`), include it:

```javascript
subagent({
  agent: "pr-reviewer",
  task: "Review PR #<number> on owner/repo"
})
```

4. **Wait for the agent to complete** — the agent will gather PR context, delegate to sub-agents, consolidate findings, and present the report to you for approval via `contact_supervisor`.
5. **Review the report** — read the consolidated findings the agent presents.
6. **Decide** — either approve posting, request revisions, or decline.

The `pr-reviewer` agent handles everything: gathering PR context, delegating to reviewer + oracle, consolidating findings, and sanitising the report. It will ask you for approval before posting anything to the PR. You just need to pass the PR number and wait for it to present its findings.
