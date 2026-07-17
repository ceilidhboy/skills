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

4. **If the agent contacts you for approval:** reply quickly with one of:
   - `Post it` — the agent posts the review as a PR comment
   - `Revise X` — the agent revises the report and presents again
   - `Don't post` — the agent stops without posting

5. **If the agent times out before you reply:** the `contact_supervisor` window is about 1–2 minutes. If it expires, the agent exits gracefully but leaves the report file on disk. Handle this when the user asks:

   **If the user says "post the review of PR #<number>" or similar:**
   1. Determine the report file path: `$XDG_RUNTIME_DIR/pr-review/<owner>/<repo>/<number>/report.md` (or `/run/user/1000/pr-review/...`)
   2. Verify the file exists
   3. Post it: `gh pr review <number> --repo <owner/repo> --comment --body-file "<path>"`
   4. Report back that it was posted

   **If the user says "clean up review <number>" or "clean up all reviews":**
   1. Run `rm -rf /run/user/1000/pr-review/<owner>/<repo>/<number>/` or `rm -rf "${XDG_RUNTIME_DIR}/pr-review/"`
   2. If it was a worktree, also remove the git worktree: `cd <repo> && git worktree remove /run/user/1000/pr-review/...` and delete the temp branch

6. **Follow-up questions** — if the worktree still exists, the user can ask about the codebase. Say `clean up review <number>` when done.

The `pr-reviewer` agent handles the review itself; you handle the fallback if the agent times out before a decision.
