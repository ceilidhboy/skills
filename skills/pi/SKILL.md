---
name: pi
description: "Delegate coding to the Pi harness (print, JSON, RPC)."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Coding-Agent, Pi, Harness, RPC, Orchestration]
    related_skills: [codex, claude-code, opencode, hermes-agent]
---

# Pi Coding Agent

Delegate work to [Pi](https://pi.dev) (`@earendil-works/pi-coding-agent`), a
minimal agent harness that ships four interfaces: interactive TUI, print, JSON
event stream, and a long-lived RPC protocol. Unlike Codex it does **not** need a
git repository and does not need a PTY for automation — which makes it the
cleanest of the CLI harnesses to drive from Hermes.

Requires Node.js ≥ 22.19 — and **check which Node that will be, in the shell that
will run the install, before installing anything.** The launcher's shebang is
`#!/usr/bin/env node`, so the PATH decides the interpreter, and the answer differs
by surface on the same box: a bundled Node (e.g. `~/.hermes/tools/node-*/bin`)
commonly lands *after* `/usr/bin` in a login PATH while a systemd unit's
`Environment="PATH=…"` lists it first. The shell that loses resolves an `apt`-era
Node 18 — Pi then fails for the human and works for cron, which reads as a broken
install rather than a path problem. Compare both before installing:

```bash
node --version                                            # interactive shell
systemctl --user cat <unit> | grep Environment=            # what cron/gateway get
```

**The signature of the wrong interpreter is a `SyntaxError` from the launcher: `node:module`
does not provide an export named `enableCompileCache`.** `pi --version` printing that — or
printing nothing at all when its output goes through a pipe — means the interpreter is too
old, not that the install is broken. Read stderr rather than a pipeline's exit status before
touching the package; a dispatch run inherits neither the unit's PATH nor the interactive
rc, so a headless command prepends the Node bin directory itself.

Then fix the surface that is actually wrong, in this order. **(1) Check what the
service already gets** before writing anything: a gateway unit commonly lists a
bundled Node first, so headless runs work untouched and only the interactive
shell is broken — that case needs one rc line, not a wrapper. **(2) A launcher
that execs the bundle with an absolute Node path** is the fallback for when no
PATH you control can be fixed. **(3) A system-wide symlink in `/usr/local/bin` is the right answer when every surface must agree.** `/usr/local/bin` precedes `/usr/bin` in interactive paths, non-interactive paths *and* systemd's default PATH (`/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:…`), so one root command fixes services, cron, `ssh host 'cmd'` and agents at once — with no version number in it and no per-unit `Environment=`:

```bash
# root; self-maintaining because it resolves the newest tools directory
ln -sfn "$(ls -d /home/<user>/.hermes/tools/node-*/bin/node | sort -V | tail -1)" /usr/local/bin/node
# prove it where it was broken, not in the shell you fixed
env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin sh -c 'node --version'
```

It does change `node` for every tool on the box, so it is the owner's decision, stated as such — and the distro package stays installed and shadowed, which is cheaper than removing it. Keep a `~/.bashrc` prepend only until this exists, then delete it as duplication. **Never** use a `~/.local/bin/node` shim instead: `~/.local/bin` is absent from systemd's PATH, so it fixes the shell and leaves the service broken — the same failure moved to a less obvious place. `~/.config/environment.d/` looks like the tidy answer and is not: a user manager only reads it when the manager itself starts fresh, so `daemon-reexec` leaves a running box unchanged (verified: a transient service still reported the old interpreter) — do not leave that file behind as unverified decoration.

Do not write a wrapper before step (1) has been checked. A box whose gateway
already resolves a modern Node needs one line of rc file, and a bespoke launcher
is a second artefact to maintain for no benefit — expect the user to reject it on
exactly those grounds. Also check `npm config get prefix`: on a stock host it prints
`/usr`, which makes `npm i -g @earendil-works/pi-coding-agent` unavailable without
root — that is the case the official installer's user-local prefix fallback
exists for, not a reason to reach for `sudo`.

## When to use

- Offloading a coding task, refactor, or PR/branch review to an external harness.
- Any run that must be started, steered, or resumed **from Hermes** (chat, gateway, cron) where no terminal exists — Pi's JSON and RPC modes need no TTY.
- Long autonomous jobs that should be resumable later with `--session`.

Not for: quick file edits Hermes can do itself, or work needing a git repo
mandate (Codex enforces that; Pi does not).

## Install

Three routes, and they are **not** equivalent — choose by what the host has to support later:

| Route | Pins transitive deps | Update path | Standing |
|---|---|---|---|
| `curl -fsSL https://pi.dev/install.sh \| sh` | **yes** (`npm-shrinkwrap.json`) | `pi update` | the documented, supported install. It selects a user-local prefix when the npm global one is unwritable, so it needs no root |
| `npm i -g --ignore-scripts @earendil-works/pi-coding-agent` | no — ranges resolve at install time | npm | documented fallback |
| `bun add -g --ignore-scripts @earendil-works/pi-coding-agent` | no | `bun update -g` | **documented** — pi.dev's install block has npm / curl / pnpm / bun tabs. Keep `--ignore-scripts` — Pi needs no lifecycle scripts |

- **Prefer the official installer** whenever the host must stay supportable, and for any
  review pipeline in particular: the pinned tree is the one upstream tested, so two hosts do
  not silently review with different dependency resolutions. Users who care about
  supportability will ask for the canonical install — lead with it rather than the Bun or npm
  shorthand. **But once the user has named a package manager, follow it and name what they
  give up** (a bun install does not pin transitive dependencies) instead of re-arguing for the
  canonical one. A stated preference is a decision already made; re-litigating it wastes the
  turn and reads as not listening.
- **Remove a pre-existing global install first.** The installer carries legacy-migration
  logic and will otherwise adopt/overwrite the old tree. Order: `npm rm -g
  @earendil-works/pi-coding-agent` as root, then the installer as the service user.
- **Install as the account that will run it.** The installer writes the tool tree,
  `~/.pi`, and shell rc files, so a root run leaves a tree the service user cannot update
  (`pi update self` fails). Check `whoami` and `echo "$HOME"` before starting.
- **A bun/npm install changes the package manager, not the runtime.** The launcher they create
  is a symlink to `dist/bundle/cli.js`, whose shebang is `#!/usr/bin/env node`, so Pi still
  executes under Node from PATH. Say this when explaining why Bun is involved: it owns the
  dependency tree and the update path, nothing else.
- **Check every documented install route before calling one unsupported.** pi.dev's homepage
  install block offers four tabs (npm, curl, pnpm, bun) while the README lists only curl and
  npm. Reading the README alone produced a flatly wrong "bun is unsupported upstream" claim
  against a command the user had copied from the bun tab. When a user quotes an install
  command, verify it against the project's own page — or its rendered UI — before contradicting
  it.

When the npm prefix is root-owned and root is unavailable (a containerized Hermes runs as
`uid 10000`), use a prefix inside the persistent volume plus a wrapper:

```bash
NODE_BIN=$(ls -d /opt/hermes/tools/node-*/bin | sort -V | tail -1)
PATH="$NODE_BIN:$PATH" npm install --prefix /opt/data/tools/pi \
  --ignore-scripts --no-fund --no-audit @earendil-works/pi-coding-agent
```

```sh
# /opt/data/tools/bin/pi — resolves Node at runtime; survives image updates
#!/bin/sh
NODE_BIN="$(ls -d /opt/hermes/tools/node-*/bin 2>/dev/null | sort -V | tail -1)"
[ -n "$NODE_BIN" ] && PATH="$NODE_BIN:$PATH"
export PATH
export PI_CODING_AGENT_DIR="${PI_CODING_AGENT_DIR:-/opt/data/.pi/agent}"
exec "$NODE_BIN/node" /opt/data/tools/pi/node_modules/@earendil-works/pi-coding-agent/dist/bundle/cli.js "$@"
```

Set `PI_CODING_AGENT_DIR` to a persistent path: it holds `auth.json`,
`models.json`, `settings.json`, extensions, and skills. The default
`~/.pi/agent` is only right when `$HOME` itself is persistent.

### Audit an existing install before installing another one

A box may already have Pi — often installed once as root during host setup, and
then forgotten. Check ownership before recommending anything, because an install
you cannot write to cannot update itself:

```bash
command -v pi && pi --version
ls -l "$(command -v pi)"                 # symlink into an npm global tree?
npm ls -g --depth=0 2>/dev/null | grep -i pi
npm config get prefix                    # root-owned prefix (e.g. /usr) = upgrades need root
ls -la "${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"   # empty {} auth.json = never logged in
```

- **A root-owned global install blocks `pi update self`** and any upgrade. Reinstall
  user-local (`bun add -g @earendil-works/pi-coding-agent@<version>` or
  `npm i --prefix ~/.local …`) so the user owns the tree, then remove the old global
  copy from a root shell so two versions cannot both answer to `pi`.
- **Pin the version to the one that already works** when replicating a setup from
  another machine. Version parity is what makes the same skill give the same review;
  "latest" silently changes behaviour between the two hosts.
- **A user-space bin directory is not on the PATH of the gateway, cron or subagent
  children.** Those are systemd units with a hardcoded `Environment="PATH=…"`; they never
  read `~/.bashrc`, so an installer's PATH line reaches only interactive SSH shells. Two
  fixes, in order of preference: put the launcher in a directory that *is* on that PATH
  (`BUN_INSTALL_BIN=$HOME/.local/bin bun add -g @earendil-works/pi-coding-agent@<version>`,
  then `ln -sf ~/.bun/bin/pi ~/.local/bin/pi` if Bun ignores it — `~/.local/bin` is where
  Hermes puts its own profile wrappers), or resolve Pi by a fixed absolute wrapper path
  (Rule 2). Confirm what children actually inherit rather than trusting the unit file:
  `systemctl --user cat <unit> | grep Environment=` for the configured value (a user unit lives
  under `~/.config/systemd/user/`, not `/etc/systemd/system/`), and
  `tr '\0' '\n' < /proc/<gateway-pid>/environ | grep ^PATH` for what the running process really
  carries — the two disagree whenever one unit was restarted and another was not. Do not conclude
  the Bun or npm install is unusable — the service PATH is the thing that differs, not the binary.
- **`bash -lc` does not prove a `~/.bashrc` edit.** A login shell reads `~/.bashrc` only when it
  is interactive, so `bash -lc 'node --version'` still reports the old interpreter and looks like
  the edit failed. Test with `bash -lic '…'`, which is what an SSH session actually is. Prefer a
  version-independent line in the rc — `_n=$(ls -d "$HOME"/.hermes/tools/node-*/bin 2>/dev/null |
  sort -V | tail -1); [ -n "$_n" ] && export PATH="$_n:$PATH"` — over a hardcoded versioned path.
- **Writing `~/.bun/bin/bun` inside an install command is a same-shell necessity, not a
  permanent path.** The installer appends its PATH export to `~/.bashrc`, which applies to
  the *next* shell; until then the absolute path is the only way to invoke it. Say so
  explicitly — a user who expects `bun` on PATH (correctly) otherwise reads the absolute
  path as evidence the environment is broken, and asks why it is not on the search path.

## Extensions and other resources

Pi has its own extension system, separate from skills. Review skills increasingly call
an extension's API, so a "missing tool" is usually a missing extension:

```bash
pi list                      # extensions/resources currently enabled
pi install <source> [-l]     # install an extension and add it to settings
pi remove <source> [-l]      # (alias: pi uninstall)
pi update [source|self|pi]   # extensions, or Pi itself, or model catalogs
pi config [-l]               # TUI: enable/disable package resources
pi mcp <command>             # inspect/sign in to MCP servers
```

- Extensions add tools and resources under `$PI_CODING_AGENT_DIR`; sub-agent
  definitions (`agents/*.md`) are a further separate resource that a *skills* installer
  does not create. Installing a skill directory is not installing its dependencies.
- **Packages ship more than extensions.** `pi install npm:<pkg>` also registers the skills and
  prompt templates the package carries (`<pkg>/skills/*/SKILL.md`, `<pkg>/prompts/*.md`), which
  is how one install can add 20+ skills and a handful of `/prompts`. Enumerate the package tree
  before re-installing those skills individually from a skills repo.
- **All packages share one npm prefix** (`$PI_CODING_AGENT_DIR/npm`), so installing one
  reconciles the whole tree and can report "removed N packages" belonging to its neighbours.
  After a batch, confirm every package dir still exists under `npm/node_modules/`; re-run
  `pi install <source>` to restore any that lost dependencies.
- **A package with a native dependency needs a compiler on the host.** `gyp ERR! stack
  Error: not found: make` (or `g++`) means install `build-essential` as root and re-run — not
  that the package is incompatible. The error **names the package** that needed it: installing
  the compiler while chasing a different package's failure fixes nothing and leaves a wrong
  conclusion on the record.
- **An extension that wraps an MCP server installs the shim, not the server.** The tool list
  enters the model's context the moment the package lands, so `pi list` and a visible
  `serena_*`-style namespace prove nothing — the first real call fails with the server's own
  "could not find … python/runtime" error. Establish what the backend expects on disk (a
  `uv tool install` interpreter under `~/.local/share/uv/tools/<server>`, a language server, an
  npm tree), install it, then **invoke one tool** — not list them — before calling the
  extension working. A tool the server does not expose is version drift inside the server, not
  a broken install: read its own catalogue rather than assuming the extension's expectations
  still hold.
- **A spec pasted out of rendered markdown records its backticks.** Installing from a command
  copied off a docs page or a chat message can store `npm:@file:`pkg`` verbatim: the package
  installs and works, but every subsequent start warns `file not found` because the recorded
  spec no longer resolves. Install with the plain spec, and re-run `pi install` on the mangled
  entry (quoting the whole spec) to clear the warning rather than leaving it as background noise.
- **Do not replicate host-specific packages to a server.** Completion chimes, Windows helper
  extensions and shell-history sync add nothing to review behaviour and fail or annoy headless.
- **Pi also reads `~/.agents/skills`**, the AGENTS-standard store, on top of
  `$PI_CODING_AGENT_DIR/skills`. A canonical store shared with other harnesses is therefore
  visible to Pi *wholesale* — Pi has no per-skill filter, unlike Hermes which symlinks a chosen
  subset per profile. Curating the store is a cross-harness act; re-check Pi's reported skill
  list after any store edit.

Replicating a Pi setup on a second host: `references/parity-audit.md`.
- `-e <path>` loads one extension explicitly and `--no-extensions` disables discovery —
  use them to make an unattended review run deterministic instead of inheriting whatever
  the host has enabled.

## Pick a mode

| Mode | Invocation | Use it for |
|---|---|---|
| Interactive | `pi` | A human at a terminal; needs a TTY |
| Print | `pi -p "task"` | Fire-and-forget, want only the final text |
| JSON | `pi --mode json "task"` | Background runs with a structured progress log |
| RPC | `pi --mode rpc --no-session` | Sessions you keep steering, resuming, or driving from chat |

Prefer JSON or RPC over terminal scraping. There is no `tmux`/`screen` to lean
on in slim images, and both modes behave the same from a gateway, cron, or
desktop session with no TTY.

## Pi Durable: a framework beside the harness, not another mode

`@earendil-works/pi-durable` is a separate package on the same version line as
`pi-coding-agent` (check `npm view` for both before assuming parity). It is for building
durable agentic *applications*, and its properties are the ones a hand-built queue has to
fake: every step is a task with a checkpoint, so a dead process resumes from the last one
rather than restarting; a `requestId` makes a submission exactly-once, so a retried job
cannot double-post; one harness runs many concurrent conversations, each with its own
model, tools, instructions and working directory; storage is memory, SQLite or JSONL; and
the execution environment can be remote from the harness.

- **It replaces the runner, not the review.** An application in TypeScript takes the place
  of `pi -p` / `--mode json`. Prose skills that *orchestrate* — launch legs, poll them,
  consolidate — must become application code, and the agent is left doing one leg's
  thinking. That removes a whole failure class (a program cannot forget a step the way a
  model can) and reshapes the work, so decide it **before** building a queue around
  one-shot runs. Retrofitting it afterwards means rewriting the orchestration.
- **Spike before adopting.** The evidence is one real task run both ways, compared, plus a
  kill-and-restart showing resume — not the feature list. It is labelled experimental and
  the API may change, so treat version parity as a convenience rather than a promise.
- **Price the spike in hours, not minutes.** A decisive comparison needs the task wired into the
  new API first, then two real runs of it (a real review is 10–20 minutes each — see Cost &
  concurrency) with a kill-and-restart
  between them: budget 2–3 hours for one task. Half an hour can only reach "the package installs
  and calls the model", which looks like progress and settles nothing.
- **A parked candidate needs a trigger, not just a deferral.** Name the evidence that would
  adopt it — two or more runs in the record dying mid-task to an outage or a kill, or a need for
  more than one task in flight. Until that arrives, the one-shot runner plus a small queue is
  less code to own, and the framework's strongest feature is insurance against a loss not yet
  taken.
- **It does not supply the edges.** Posting to GitHub, credentials, and the judgement in
  the skill all stay outside the harness, exactly as they do for a one-shot run.

## Recipes

One-shot, blocking:

```
terminal(command="/opt/data/tools/bin/pi -p 'Summarize the failing tests in this repo'", workdir="/path/to/project", timeout=600)
```

Background with an audit trail (`terminal(background=true)`), then read the log:

```bash
/opt/data/tools/bin/pi --mode json "Review this change" > /tmp/pi-run.jsonl
jq -c 'select(.type=="message_end")' /tmp/pi-run.jsonl
```

Restrict a review run to read-only tools:

```bash
pi --tools read,grep,find,ls -p "Review this project"
```

Long-lived session over RPC — one JSON object per line on stdin, responses and
events on stdout:

```bash
printf '%s\n' '{"id":"1","type":"get_state"}' | /opt/data/tools/bin/pi --mode rpc --no-session
# -> {"id":"1","type":"response","command":"get_state","success":true,"data":{...}}
```

A minimal multi-turn client (from Pi's own docs; use a *binary* line reader):

```python
process = subprocess.Popen(["pi", "--mode", "rpc", "--no-session"],
                           stdin=subprocess.PIPE, stdout=subprocess.PIPE)
process.stdin.write(json.dumps({"id": "p1", "type": "prompt",
                                "message": "Hello"}).encode() + b"\n")
process.stdin.flush()
while line := process.stdout.readline():      # split on LF only
    rec = json.loads(line)
    if rec.get("type") == "agent_settled":     # the real completion signal
        break
process.stdin.close(); process.wait()          # close stdin = orderly shutdown
```

Keep the RPC child alive with `terminal(background=true)` and a driver script
that owns the pipes; do not hand JSON lines to a shell between calls.

## PR review loop

The queue-to-approval shape, with the human gate intact:

```bash
gh search prs --review-requested=@me --state=open        # what is waiting
gh pr diff <n> | pi --tools read,grep,find,ls -p "<review skill>"
gh pr review <n> --comment --body-file report.md          # drafts land as a comment
gh pr review <n> --approve --body-file report.md          # only on an explicit human decision
gh pr review <n> --request-changes --body-file report.md
```

- Key every stored artifact on `(repo, pr, head_sha)` so a re-run is idempotent,
  and keep the Pi `session_id` beside the report: the "fix what you found" step
  must resume *that* session, not start cold on the same diff.
- A review never executes PR code — `--tools read,grep,find,ls` plus a working
  directory inside the clone. Diff text is data, so an untrusted author cannot
  turn a comment into a command.
- GitHub rejects an approval from the account that authored the PR, so the token
  doing the approving must belong to someone other than the author.
- Approving is the one step an agent must not perform on its own findings;
  otherwise the review gate protects nothing.
- **Decide the posting split before building any queue, and pick it for a stated reason.**
  *Orchestrator posts* makes a timeout mean nothing was posted, by construction, and keeps
  GitHub write credentials out of a harness that has a `bash` tool and can read the whole
  volume. *Harness posts* removes the serialisation hop and keeps formatting in one place
  instead of drifting between an interactive skill and a batch one — but only under two
  conditions, both of which are cheap and neither optional: the comment carries a marker
  naming the unit of work it covers (the head SHA reviewed) so a retry **edits its own
  output** rather than adding a second, and a failed post **fails the run loudly** instead
  of reporting success. Without both, a run that dies after posting gets retried and
  duplicates the comment on a colleague's PR, which reads as a broken bot. Either way the
  harness's write scope is comment-only — `issues: write`, never `contents: write` — so the
  worst a bad run can do is leave a wrong comment that can be edited or deleted.
- **Verify an unattended run by its artefacts, not by its exit code.** Exit 0 says the process
  finished, not that anything was delivered. Check four things before reporting success: the
  posted comment's URL and its author identity (it must be the bot, not the user); the record's
  split fields populated with `timing_complete: true` rather than nulls; `mode` and the verdict
  stating what the run was meant to do; and the body still opening with its banner and ending
  with its SHA marker — the marker *is* the idempotency mechanism, so a body-assembly bug loses
  it silently and the next retry duplicates the comment on a colleague's PR.
- **The contract is artefact + exit code, never prose.** Have the harness write a report file
  plus a machine-readable verdict sidecar and exit nonzero on failure; the orchestrator reads
  those and the exit status. A headless run has no TTY so the model cannot ask a question — but
  it can still *emit* one as final text, so parsing the prose is how a "review" that is really
  a request for clarification gets posted. Wrap the child in an outer wall-clock timeout as
  well as its own internal retries: a hung process reports nothing at all.
- **One writer per record file.** N workers appending to one JSONL log is safe only by
  accident of line size — have each run write its own sidecar and let the orchestrator append
  the single log line, so queue fields (attempt count, failure reason, posted comment id) sit
  where the queue can see them.
- **Retry, then park — never spin.** Nonzero exit, timeout, or a missing/invalid artefact →
  requeue with jittered backoff (an outage fails every worker at once, so unjittered retries
  thunder), cap the attempts, then park the item and surface the failure reason to the human
  rather than dropping it.
- **Pre-flight the target repo against the review skill's own assumptions before dispatching.**
  A review skill encodes one project's convention: an aggregate `composer fix` / `npm run fix`
  baseline, a build script, a test command. A repo that does not define them fails at the
  *baseline* step for a skill-assumption reason and nothing to do with the PR — which reads as
  a broken pipeline. Check the repo declares the convention, and that its toolchain exists,
  before spending a run. When picking a target for a first verification run, select by **fit**
  first and diff size second: the smallest PR in a repo the skill does not fit tests nothing.
- **Never let an unattended run reach the step that pushes.** Review skills written for a human
  end with "commit and push the formatter's fixes to the branch" — correct when a person is
  reviewing, an irreversible side effect on a colleague's PR when a dispatcher did it. Until
  the posting policy is decided, constrain the run explicitly (read-only token, an instruction
  not to commit or push, a report instead) rather than relying on what the token happens to be
  allowed to do; treat an unverified write permission as write.
- **Put the harness update in the queue, not in each review.** A per-review
  `pi update` pays a registry round-trip per PR, lets the version drift
  mid-backlog so findings from different PRs are no longer comparable, and
  races on the shared `$PI_CODING_AGENT_DIR/npm` prefix once concurrency > 1.
  Lock the updater, not the reviews: an update never disturbs an instance
  already running — it only changes what the *next* one loads (an interactive
  session catches up with `/reload`). So take one **exclusive** lock for the
  update and a **shared** lock for the seconds a review spends starting
  (`flock -x` for the updater, `flock -s` at launch): N reviews run while an
  update waits, two updaters never reconcile the shared
  `$PI_CODING_AGENT_DIR/npm` tree at once, and the only real window — a review
  launching mid-update against a half-written tree — is closed. Run the update
  once at the start of a batch rather than per review, and record the version
  beside every review so a change in findings is attributable.
- **Install only the extensions the skill actually names.** Grep the skill for
  its real API calls before replicating a full interactive set: one `pr-review`
  skill needed `pi-subagents` alone (`subagent(` / `runs.all` / `workflowScript`)
  and explicitly treated serena as optional. "Optional" in a skill means the run
  degrades gracefully without it, not that it is worthless: a reviewer gains real
  value from serena's find-references, so install it where review quality is the
  goal — and still treat a serena-less run as valid, because the skill's
  degradation path is the floor, not the preference. Host niceties — completion chimes,
  IDE annotators, Windows helpers — add nothing headless.
- **A bun-managed Pi updates with `bun update -g <pkg>`,** not `pi update self`,
  which targets the npm tree. Bun still does not choose the interpreter — that is
  the shebang question at the top of this skill.
- **A two-leg review skill carries its own contract** — slash-command invocation, the
  ~50-tool-call pre-flight before any leg starts, the async leg launch, what `subagent`
  hides in `--mode json`, and which of its steps assume a human:
  `references/pr-review-skill.md`.

### Where a queue's work comes from

- **Two lists answer two different questions, and building one from the other is a mistake.** A
  **curated eligibility register** — repos cleared for automated review, each with one short label —
  decides which repos are *scanned at all*. A **human-maintained priority page** (ours: a repo wiki)
  decides the *order*. Neither derives from the other: a repo can sit on the register with no open
  PRs, and the page can list a PR from a repo nobody has cleared for automation. Ask for both before
  enumerating anything, and never assemble the register out of the page's current contents — a table
  of "repos that happen to have entries" changes under you and is not a decision.
- **Eligibility buys discovery.** Scan the register's repos for open PRs instead of waiting for
  somebody to add a page line; that is what makes review-on-creation possible without a webhook.
  Listed PRs go first, unlisted-but-open after them, because unlisted means unranked. Tightening to
  listed-only is a legitimate choice, and its cost is that the queue idles until a human ranks work.
- **Label per repo, one to one — never per project.** An umbrella project is routinely several repos
  (an app plus its marketing site, or one site per language), so a project-level name identifies
  nothing at PR level. The register maps repo → label; the project note stays a looser grouping, and
  its `aliases` are for linking, not for identity. Register shape, parser, dispatch order and repo
  setup: `references/queue-inputs.md`.
- **A wiki is a separate git repository** (`<repo>.wiki.git`) that neither the REST API nor `gh`
  can read, but the same installation token clones it:
  `git clone https://x-access-token:$T@github.com/<owner>/<repo>.wiki.git`. Pull it at the start of
  every run so the order is current.
- **Parse entries by their `/pull/<n>` URL, never by the link text.** One project's entries read
  `[PR #473]`; another's read `[Spanish PR #89]` — an umbrella with one repo per language. Matching
  on "PR #" silently drops them and the queue merely looks smaller. Prove the parser before
  trusting any count: count `/pull/` links in the active part and assert it equals the entries
  parsed, and split the page at its `Completed` heading first, because retired and live items share
  one page.
- **The project lives in the prose prefix** (`🚨 Mercers`, `ShiftOpera App`, `CCH`), not in a field.
  Resolve it to a project record that owns the repo list, because one project is routinely several
  repos: an app plus its marketing site, or one site per language.
- **Serialise per project, parallel across projects.** Two reviews must never work in one repo at
  once — each checks out a different branch into the same tree. One clone per repo is then enough,
  and no worktree-per-review is needed; but the clone is not itself the lock, so take a per-repo
  lock or nothing enforces the serialisation.
- **Records are per machine.** Timing lives in each host's `~/.pi/agent/state/reviews.jsonl`, so two
  people running the same skill keep two separate files and nothing aggregates them: never quote a
  figure as if it were the team's. "I ran a review and saw no times" is the expected report — the
  splits go to the record, never into the review and never into the posted comment.
- **Scope the register by what the company owns and publicly runs, and write the exclusions down.**
  Enumerating "every repo with a name" fills the register with hosting-only client sites, internal
  tooling and abandoned prototypes, and the scan then spends runs on repos nobody wants reviewed —
  one estate of 43 repos came down to 15 on the single test *sites and applications the company
  manages with a public presence*. Record what was excluded and why (hosting-only, internal,
  superseded) instead of deleting the rows: nobody can re-derive a repo's absence later, so the next
  session either re-adds it or concludes the register is incomplete. Where the test genuinely does
  not settle a repo — a rebuild in progress, split repos of one product, a family of dormant
  services — leave it out and list it for the owner's ruling rather than guessing for them.

## Sessions

- `pi --continue` — most recent session for the current project.
- `pi --session <path|id>` — exact or partial id; `--session-id <id>` creates it.
- `pi --session-dir <dir>` / `--no-session` — relocate or disable persistence.
- `--fork <id>` branches instead of appending.

Sessions are grouped by working folder, so pin `workdir` when resuming or you
resume the wrong project's session.

## Cost & concurrency

Measure the footprint; do not estimate it. A single-agent review of a small
repo peaked at **134 MB RSS / ~95 s** — but that is the wrong number to size a
queue from. A **two-leg** review, orchestrator plus `reviewer` and `oracle`
subagents, peaked at **1.4–1.8 GB for the whole process tree**, four times the
300–450 MB an earlier estimate assumed. Budget **1.5–2 GB per review**, and
measure the host you are actually on before trusting either figure.

The ceiling is set by the *tail*, not the average. Where there is no swap and no
cgroup control (non-root container: `CapEff 0`), one outlier run OOM-kills its
neighbours — including the Hermes gateway. Measured on a 2 vCPU / 7.8 GiB box
over six real two-leg reviews: N=1 17.9 min, 1.8 GB peak; N=2 22.0 min; N=3
25.2 min, 4.0 GB peak, 2.4 GB still available at its worst sample, load 6.5.
**Three concurrent is the number for that box; a fourth is a measurement, not an
inference** — its projection leaves under 1 GB on a box already swapping. Keep
the cap in one config value, and let a `systemd`/`MemoryMax=` host enforce it per
unit after migration.

Two traps in a test of that shape:

- **Concurrency costs preflight, not thinking.** Preflight — worktree checks, the
  merge probe, the baseline build and test run — doubled from 5–6 min alone to
  9–13 min at N≥2, while legs and assembly barely moved. Parallelism buys
  throughput (3.3 → 5.5 → 7.1 reviews/hour) by stretching the local, CPU-bound
  phase, so a bigger box or a faster preflight is the lever; round-robin and
  repo locks are not.
- **A baseline that runs in a container is outside the worker's process tree.**
  `docker run` children belong to `dockerd`, so a per-process RSS cap cannot see
  the largest part of the footprint. Enforce memory per cgroup/unit and read the
  box's MemAvailable floor, never the sum of worker RSS.

`scripts/measure_session_rss.py` runs one real prompt and prints wall time plus
peak RSS (`VmHWM`), so the cap is chosen from evidence.

**Duration is not set by the diff size.** One real two-leg review of a two-file
change in a Laravel app ran **20.6 min** end to end: preflight 6.4, dispatch 0.8,
legs 6.7, assembly 6.2, delivery 0.5. The legs were a third of the wall clock —
consolidation, the reversal check, sanitisation and writing the report cost as much
again — so an estimate built from diff size, or from the legs alone, is wrong by
roughly half. Treat ~9 min as the floor for a trivial diff and 15–25 min as the
ordinary range for real code when telling the user how long a batch will take.

Have the review skill record its splits (preflight, dispatch, legs, assembly,
delivery, total, in milliseconds) into its durable record, and answer throughput
questions from that record rather than from memory or from one earlier run: the
shape of the cost moves between repos, and the record is the only thing that says
which phase is worth attacking. Assembly equalling the legs is the finding to
watch for — it means the pipeline, not the model, is the expense.

## Model auth

- **Do not write `models.json` preemptively.** Pi's own catalog already defines the
  supported models, and `settings.json` records the choice `/login` makes. Create
  the file only after confirming a real gap: an unsupported endpoint, or metadata
  that genuinely must differ.
- **A `models[]` entry replaces the catalog model, it does not merge with it.** A
  stub carrying only `id` and `name` silently discards `reasoning`,
  `thinkingLevelMap`, `compat.thinkingFormat`, `contextWindow`, `maxTokens`,
  `input` and `cost`, which all fall back to constants (128k context, 16k output,
  text-only, zero cost, no thinking). The symptoms — "cheap tier", "model does not
  support thinking" — point at the provider and not at the override, so the
  mistake is easy to defend and expensive to find. Use `modelOverrides` for a
  genuine delta, and never let a provider-level `baseUrl` in: it rewrites the
  endpoint for every model on that provider.

Resolution order: `--api-key` → stored `auth.json` → `apiKey` in `models.json` →
provider environment variables.

- **Headless (Hermes-driven):** set the provider env var (e.g.
  `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`). Nothing else is needed.
- **`/login` needs a TTY**, so it cannot be driven from a normal Hermes tool
  call. Run it from the host, or `docker exec -it <container> bash`.
- **`/login` is the right way to give Pi a credential, including for a provider you declared
  yourself.** Its API-key route lists every provider Pi knows — catalog and `models.json`
  alike — and stores the result in `auth.json`, keyed by provider ID. Run it once on the
  host (it needs a TTY, so it cannot be driven from a Hermes tool call) and both the
  interactive session and every headless run authenticate identically. `No API key found for
  <provider>` means exactly that: the provider and models are registered and `pi list` is
  clean, but no credential is stored. Diagnose it as *auth*, never as config parsing — and
  never conclude from it that the provider is unloggable.
- **OpenAI-, Anthropic-, or Google-compatible endpoints** (aggregators,
  gateways, local servers) go in `$PI_CODING_AGENT_DIR/models.json`; do not
  assume a built-in provider exists for a given aggregator.

**Before declaring a provider, check whether Pi already knows it.** Pi ships a model
catalog (`pi update pi` refreshes it; `/model` or `$PI_CODING_AGENT_DIR/models-store.json`
shows it). If the provider and model are already there you need **no `models.json` at all** —
a one-off `/login` supplies the credential and `settings.json` records the default. Reach for
`models.json` only when the endpoint is genuinely absent from the catalog, and then declare
it as:

```json
{
  "$schema": "https://pi.dev/schemas/models.schema.json",
  "providers": {
    "<name>": {
      "baseUrl": "https://<endpoint>/v1",
      "api": "openai-completions",
      "models": [{ "id": "<model-id>" }]
    }
  }
}
```

- Hermes `api_mode: chat_completions` maps to Pi `api: openai-completions`.
- **A `models[]` entry REPLACES the catalog model; it does not merge with it.** Every field
  the entry omits falls back to a hard-coded constant — `reasoning: false`,
  `contextWindow: 128000`, `maxTokens: 16384`, `input: ["text"]`, cost all zeros, and no
  `thinkingLevelMap` or `compat` at all. A stub carrying only `id` and `name` therefore
  strips a 1M-context, reasoning-capable, image-reading, priced model down to something that
  reports 128K and refuses to think — and both symptoms read as a cheaper tier or a provider
  limitation rather than as your own override. Confirm what Pi actually loaded with an RPC
  `get_state` and read `reasoning`, `contextWindow`, `maxTokens`, `baseUrl`. If metadata must
  differ, use `modelOverrides`, which merges per field; never patch a stub field-by-field,
  because the fields you forget (notably `compat.thinkingFormat`) are the ones that break
  multi-turn reasoning.
- **A provider-level `baseUrl` rewrites the endpoint of every model on that provider**, not
  just the one you named — on a 32-model provider that is a fleet-wide redirect from a
  one-line edit.
- **Do not transplant an endpoint from another tool's config and assume it is canonical.**
  Hermes's `model.base_url` and Pi's catalog `baseUrl` for the same provider can differ, both
  may accept requests, and only the catalog value is the one Pi's metadata was built against.
  Read the catalog's own `baseUrl` rather than copying the Hermes one.
- `apiKey` accepts `$NAME`/`${NAME}` interpolation, a literal, or `!command`;
  the variable must exist in the **child** process env, so the launcher or the
  worker's `subprocess` `env=` has to carry it (reading `.env` in the parent
  shell is not enough once a script spawns Pi).
- **Prefer `auth.json` (one `/login`) to a key in the config or the environment.** A
  literal `apiKey` writes a second copy of the credential to disk — another file to rotate,
  leak and back up. `${VAR}` only resolves when the parent environment carries the variable,
  which an interactive session started from a plain shell does not (Hermes's `.env` is loaded
  into the gateway, not into the user's shell) — so the same config works headless and fails
  interactively, which is precisely the difference between "I run it" and "the agent runs it"
  that should not exist. `auth.json` is read in every mode. Keep `!command`
  (`"apiKey": "!grep -m1 '^<KEY_NAME>=' /path/to/secret.env | cut -d= -f2-"`) for the case
  where no TTY exists to run `/login` once; it resolves the key at use time from the single
  file that already holds it.

  Verify whichever you use with the variable explicitly removed — `env -u <VAR> pi -p "reply
  READY"` — not with it exported. Exporting it passes for both the wrong and the right
  configuration.
- Pin the model on the command line — `pi --model <name>/<model-id> -p "..."` —
  and prove it with a trivial prompt before spending a real run.

If `get_state` reports `"model":{"id":"unknown"}`, auth is missing — Pi starts
happily but no prompt will run.

## Pitfalls

- **`prompt` returning `success:true` means accepted, not finished.** Watch for
  `agent_settled`; `agent_end` still allows retries, compaction, steering, and
  queued follow-ups. If the response carries `disposition:"handled"`, no run
  started at all — do not wait for one.
- **Subscribe to events before sending the prompt.** A fast completion can settle
  before a late listener attaches, and the wait hangs until timeout.
- **Split stdout on LF only.** `readline`-style readers also split on `U+2028` /
  `U+2029`, which are legal inside JSON strings, and corrupt records.
- **Keep reading stdout.** Pi honours backpressure, but a client that stops
  reading stalls the process; use stderr for diagnostics, never stdout.
- **RPC mode rejects `@file` prompt arguments** — send content through the
  `prompt` command instead.
- **Print mode exits nonzero on error, abort, and `length` truncation** while
  still printing partial text, so check the exit status and stderr rather than
  trusting stdout.
- **A harness with a `bash` tool can read the entire persistent volume** — in a
  containerized Hermes that means `.env` keys and `auth.json`. Restrict
  `--tools` and the working directory for untrusted repos.
- **Do not shell-background a run** (`cmd &` plus a polling loop). A `terminal`
  call rejects `&`, and a child owned by a shell dies with it. Use
  `terminal(background=true)` or a Python `subprocess` sampler that owns the
  pipes.
- **`/usr/bin/time` is often absent in slim images.** Read peak RSS from
  `/proc/<pid>/status` `VmHWM` while the child runs instead of guessing memory.
- **A skill that calls `subagent({workflowScript: runs.all([…])})` needs the
  pi-subagents extension installed**, plus the named agents (`agents/*.md`) registered —
  otherwise the run fails at the launch step, not at review time. Check `pi list` and
  `find <skill_dir> -type f` before promising a third-party review skill will work.

## Rules

1. **JSON or RPC, not PTY scraping** — no TTY needed, works from any Hermes surface.
2. **Absolute path to the wrapper** — no writable PATH directory in a container.
3. **Pin `workdir`** — Pi scopes both file discovery and session lookup to it.
4. **`--tools` allowlist for reviews** — Pi has `bash` and `write` enabled by default.
5. **Background + driver for anything over a few minutes** — do not hold a
   foreground call open on a long agent run.
6. **Persist the `session_id` with every artifact the run produces.** A review,
   audit, or triage output that a human later acts on needs the Pi session
   behind it: "fix the issues you found" must resume *that* session
   (`--session <id>`), never start a cold one.
