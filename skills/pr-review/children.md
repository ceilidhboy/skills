# PR Review — Agent Task Templates

This file contains the exact task strings for the reviewer and oracle sub-agents, and the shared context file format. Read this at step 4 when launching the children.

## Reviewer agent task template

```
Review PR #<number> on <owner/repo> (<title>). Read the shared context file at <CTX_FILE> first — it has the full PR metadata, file manifest, commits, and the complete previous review history. Worktree: <WORKTREE> (explore the full codebase to check integration, not just the diff). Review along two axes: Standards (conventions, smells) and Spec (fidelity to the PR description). Report per-axis findings with file/line refs; explain what, why, and how to fix for anything needing changes; 🔴 blocker / 🟡 warning / 🟢 minor; terse one-line "✓ works correctly" bullets for confirmed-correct items; one-line summary per axis. Cross-check each finding against the previous review history: flag reversals with a ⚠ Reversal note, and verify each previous change request was implemented (✓ addressed / ⚠ still open — carry still-open ones forward). You have no bash: note any test or git command the orchestrator should run. Use serena_* tools when present.
```

## Oracle agent task template

```
Check decision consistency for PR #<number> on <owner/repo> (<title>). Read the shared context file at <CTX_FILE> first — it has the full PR metadata, file manifest, commits, and the complete previous review history; treat it as the authoritative contract. Worktree: <WORKTREE>. Check pattern consistency, authorisation alignment, architectural drift, and risk areas; verify imports resolve and patterns match existing code; run tests if useful (you have bash). Report with specific file/line refs; explain what, why, and how to fix for any concern; terse "✓ consistent / clean / no concern" bullets for what verifies; end with a summary of the most important concern or a clean bill. Cross-check against previous review history (reversal notes, ✓ addressed / ⚠ still open). Use serena_* tools when present.
```

## Shared context file format

The context file (`$CTX_FILE`) is written at step 3 and read by both children. It contains:

- **PR metadata:** number, repo, title, description, base branch, head branch
- **File manifest:** each file path with additions/deletions counts
- **Commit list:** SHA and message for each commit
- **Review workspace path:** `$WORKTREE_PATH`
- **Previous review history:** all prior review comments, inline comments, and change requests (fetched from the GitHub API)

Both children read this file first in their task. Do not duplicate its contents in the task string — reference the path.

## Launch script

Both children are launched in one async `workflowScript` with `runs.all`:

```javascript
subagent({
  workflowScript: `
    const results = await runs.all([
      { key: 'reviewer', agent: 'reviewer', context: 'fresh', cwd: '<WORKTREE>', timeoutMs: 7_200_000,
        task: '<reviewer task template>' },
      { key: 'oracle', agent: 'oracle', context: 'fresh', cwd: '<WORKTREE>', timeoutMs: 7_200_000,
        task: '<oracle task template>' }
    ]);
    return results.map(r => ({ key: r.key, output: r.output }));
  `,
  async: true
})
```

Replace `<reviewer task template>` and `<oracle task template>` with the templates above, substituting the actual values for `<number>`, `<owner/repo>`, `<title>`, `<CTX_FILE>`, and `<WORKTREE>`.

If no worktree was created (diff-only mode), tell both children to use `gh pr diff <number> --repo <owner/repo>` and note they will not have full codebase access.

## Note on serena grants

The reviewer/oracle agent files already instruct the serena workflow and the review output shape. Their serena tool grants come from `~/.pi/agent/settings.json` → `subagents.agentOverrides` keyed by agent name — they apply to any parent; there is nothing to configure per-launch.
