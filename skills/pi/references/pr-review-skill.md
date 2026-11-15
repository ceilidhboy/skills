# Running a two-leg review skill under Pi

For skills shaped like `pr-review`: an orchestrator session that fans out named
reviewer/oracle legs and consolidates their output. Applies to any harness or queue that
invokes one of these headlessly.

## Invoking it

- The canonical form is the skill's own slash command with the PR URL (`/pr-review <url>`).
  A prose instruction naming the PR also selects the skill by description match, so both
  work — prefer the slash form when reproducing the user's workflow, and **verify it
  expands under `-p` / `--mode json` before relying on it in a queue**, because slash
  commands are an interactive-surface feature.
- Start it with the working directory **inside a clone of the target repo**. The workspace
  step resolves from the current directory and cannot answer a question in `-p` mode.
- **The clone must be authenticated.** The skill fetches the PR branch, so a clone whose
  remote URL had its token scrubbed fails partway through with
  `fatal: could not read Username for 'https://github.com'` — the run then spends turns
  fabricating credentials instead of reviewing. Supply a credentialed remote or a helper.
- `gh` must be authenticated: the skill uses both `gh pr view` and `gh api`. If `gh`
  rejects a `--json` field the skill asks for (older releases lag the schema),
  `gh api repos/<owner>/<repo>/pulls/<n>` returns base and head SHAs plus mergeable state
  directly, and the run recovers on its own.

## What it needs of the host

- The repo's own quality toolchain. A Laravel/JS baseline step runs an aggregate fix script
  (formatting, lint, tests, type-check) and a frontend build; without the language runtime
  and a JS package manager, the baseline cannot be established and the report's confidence
  should be read accordingly.

## Cost and shape

- Pre-flight is the orchestrator working alone: **order of 50 tool calls and about five
  minutes** before any leg starts — parse, PR lookups, diff and review history, toolchain
  probe, asset inspection, sometimes live-site checks.
- The legs launch as one async workflow: a `subagent` call with `workflow: true`, then a
  `subagent_launch` per named leg, while the parent polls `subagent status` (fleet view).
- Budget **10–15 minutes** for a trivial diff and **20–25 minutes** for a real two-file change
  in an application repo: measured once at 20.6 min, of which pre-flight was 6.4, the legs 6.7
  and **assembly 6.2** — consolidation costs as much as the reviewing. For concurrency, each
  review is one orchestrator **plus two legs** — size the cap on the sum, not on "N reviews".

## Observability limits

- In `--mode json` the `subagent` tool's outputs arrive as **`null`**. You can see that a
  leg finished, not which one, nor why. A headless watcher therefore cannot detect a dead
  leg from the JSON stream: have the legs write their own files, use `--mode rpc`, or read
  the run's own record —  the JSONL line the skill appends carries per-leg status, the mode it ran in, the posted
  comment URL, and the split timings with an explicit `timing_complete` flag. Read those fields
  rather than inferring success from the exit code alone.
- Artefacts land in a predictable few places: a shared context file under
  `$XDG_RUNTIME_DIR/pr-review/<n>/`, the report where the skill's report step puts it, and
  the durable record at its record step. Check those rather than parsing prose.

## Steps that assume a human

- **The approval gate is the one a headless run cannot satisfy, so give the skill a mode.** A
  skill that presents for approval and posts on a yes has no answer to give a dispatcher. An
  environment variable read by a command (`<SKILL>_MODE=post`) switches that gate off and posts
  instead, leaving interactive behaviour as the unchanged default. The unattended path must then
  be comment-only — never approve or request changes with nobody standing behind the verdict —
  carry a marker naming the head SHA so a retry edits its own comment instead of adding a
  second, and fail the run loudly when the post fails.
- **The arbitration branch.** A consolidation step that resolves contradictions by
  "escalate to the user for arbitration" is interactive by design. In a queue, convert it
  to park-and-escalate: the run must never wait for input it cannot receive.
- **The push branch.** A baseline step that commits and pushes the formatter's fixes is
  right for a person reviewing and an irreversible side effect on a colleague's branch for
  a dispatcher. Constrain a verification run explicitly, and decide the push policy
  deliberately rather than relying on what the token happens to allow.
- **Sanitisation.** The consolidation step strips internal process language so the posted
  output reads as one voice — do not add tool or leg attribution back into it.

## Pitfalls

- **A static read of the repo's config does not predict the run.** A `composer.json` with
  no aggregate fix script does not mean the skill halts at its baseline step: the executing
  model probes the toolchain, finds nothing, and continues down its documented degradation
  path. Run it and read the output before claiming what it will do — and when a prediction
  from config contradicts the user's own experience of the same skill, the run is the
  evidence and the prediction is the hypothesis.
- **Pick a verification target by fit, then by diff size.** The smallest PR in a repo whose
  conventions the skill does not implement exercises the adaptation path, not the pipeline.
- **Pre-flight is not free when sizing concurrency.** Every review pays the orchestrator's
  tool calls against the same box as the legs, so the memory and CPU budget is the parent
  plus its children, measured rather than assumed.
