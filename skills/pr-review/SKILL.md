---
name: pr-review
description: Review a GitHub pull request by creating a temporary worktree, running reviewer + oracle sub-agents, and asking for approval before posting. Use when user says "review PR #N", "review pull request", "review this PR", provides a PR URL, or asks for a PR review.
---

# PR Review

When asked to review a GitHub pull request:

1. **Parse the request** — extract the PR number and optional owner/repo from:
   - `PR #44` (repo inferred from git remote)
   - `PR #44 on owner/repo`
   - `https://github.com/owner/repo/pull/44`
   - `owner/repo#44`

2. **Launch the `pr-reviewer` sub-agent asynchronously** with the parsed information — this keeps the main conversation responsive:

```javascript
subagent({
  agent: "pr-reviewer",
  task: "PR #<number> on <owner/repo>",
  async: true
  // or: "https://github.com/owner/repo/pull/<number>"
})
```

3. **Do not wait or block.** The agent will report back asynchronously when its review is ready. Continue responding to the user in the meantime.

4. **Review the report and decide:**
   - `Post it` — the agent posts the review as a PR comment
   - `Revise X` — the agent revises the report and presents again
   - `Don't post` — the agent stops without posting

5. **Follow-up questions** — the temporary worktree stays in `/tmp/` so you (or the agent) can explore the codebase. Say `clean up review <number>` when done.

The `pr-reviewer` agent handles everything: PR context, worktree management, sub-agent delegation, consolidation, sanitisation, and your approval flow.
