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

2. **Launch the `pr-reviewer` sub-agent** with the parsed information:

```javascript
subagent({
  agent: "pr-reviewer",
  task: "PR #<number> on <owner/repo>"
  // or: "https://github.com/owner/repo/pull/<number>"
})
```

3. **Wait for the agent to present its report** — it will gather PR context, create a temporary worktree (or ask whether to clone), run reviewer + oracle sub-agents, consolidate findings, and present the sanitised report to you via `contact_supervisor`.

4. **Review the report and decide:**
   - `Post it` — the agent posts the review as a PR comment
   - `Revise X` — the agent revises the report and presents again
   - `Don't post` — the agent stops without posting

5. **Follow-up questions** — the temporary worktree stays in `/tmp/` so you (or the agent) can explore the codebase. Say `clean up review <number>` when done.

The `pr-reviewer` agent handles everything: PR context, worktree management, sub-agent delegation, consolidation, sanitisation, and your approval flow.
