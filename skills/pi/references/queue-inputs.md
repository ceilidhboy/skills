# Queue inputs: the register, the priority page, and repo setup

Depth for "Where a queue's work comes from" in SKILL.md. Read it when wiring a review queue to
its sources, or when a queue is reviewing the wrong set of things.

## Two inputs

| Input | Edited by | Answers | Never derive it from |
|---|---|---|---|
| **Eligibility register** | the owner, rarely | which repos are **scanned** | the priority page's contents |
| **Priority page** | the team, daily | the **order** work is taken in | the register |

The register is a decision that outlives the work in front of it: a repo is on it because its PRs
are cleared for automated review, not because it currently has any. The priority page is a snapshot
of a human's judgement about urgency, and it goes stale between edits.

## The register

One row per **repo**, and the label is the identity every other component keys on — the page prefix,
the board label, the queue key, the clone directory.

| Repo | Label | Project | Open PRs | Listed today |
|---|---|---|---|---|
| `app-core` | `app` | App | 96 | 93 |
| `app-site` | `app-site` | App | 14 | 14 |
| `es-site` | `site-es` | Website | 7 | 1 |
| `nl-site` | `site-nl` | Website | 6 | 1 |

- **A project is not a repo.** An app plus its marketing site, or one site per language, is one
  project across several repos. A project-level name cannot identify a row, so it cannot be a label.
- **Keep both counts in the table and read the disagreement.** Repo X: 6 open, 1 listed → five PRs
  nobody has ranked. Repo Y: 3 listed, 2 open → at least one line is stale and must be parked rather
  than reviewed. Those two diagnoses come free from the columns and are invisible with one column.
- **Never build the register by querying the page.** "Repos that currently have entries" shrinks and
grows with the team's editing and will silently drop a repo that is still in scope.

## Parsing a priority page

Assume prose, not a data structure. It is edited by several people by hand, and its shape drifts.

1. **Split off the completed section first.** Live and retired items share one page; parsing before
   the split re-queues finished work.
2. **Match on the `/pull/<n>` URL, never the link text.** One project writes `[PR #473]`, another
   writes `[Spanish PR #89]` — an umbrella with a repo per language. Matching `PR #` drops the second
   kind silently, and a smaller queue looks like a correct queue.
3. **Take order from line order**, within section order. If the page has ranked and unranked sections,
   the ranked ones come first.
4. **Prove completeness before trusting any count.** Count the distinct `(repo, number)` pairs behind
   every `/pull/` link in the live part, and compare with the entries parsed. They must be equal;
   anything unparsed is work you are about to ignore. Print the difference rather than asserting a
   hard-coded total — the page grows.
5. **Resolve the prose prefix to a project** (`Heads-up Mercers`, `App`, `CCH`) through a mapping you
   keep beside the register, not by pattern-matching the page each run.

A category the owner has marked as needing no review (documentation-only changes, for instance) is a
policy decision, not a parser special case: confirm what it means before skipping it, because the same
label is often applied to work a reviewer still wants to see.

## Dispatch order

1. Pull the priority source; parse entries.
2. Scan the register's repos for open PRs.
3. Review the intersection: listed entries in page order, then open-but-unlisted per repo.
4. **Serialise per repo, parallel across repos.** Take a per-repo lock; a clone reused between PRs
   cannot hold two branches at once.
5. Skip a PR whose head SHA is already in the record; re-review when the head moves.
6. Park a listed PR that is merged or closed, and report it as a stale line for housekeeping.

The per-repo lock, as a queue wants it — a held lock is "come back later", not a failure:

```bash
mkdir -p "$HOME/repos/.locks"
exec 9>"$HOME/repos/.locks/$repo.lock"
flock -n 9 || exit 75      # EX_TEMPFAIL: another review owns this repo
```

## Repo setup on the reviewer host

One clone per registered repo is enough when reviews are serial per repo. No worktree per review, no
package hard-linking, no per-review clone:

```bash
git clone "https://github.com/$OWNER/$REPO.git" "$HOME/repos/$REPO"
```

Fetch a PR without storing a credential in the remote — mint a short-lived token and pass it in a
header, so nothing is left at rest and an expiring token cannot become a broken remote:

```bash
T="$(token-helper)"                     # fresh installation token
git -C "$HOME/repos/$REPO" -c \
  http.extraheader="AUTHORIZATION: basic $(printf 'x-access-token:%s' "$T" | base64 -w0)" \
  fetch --prune origin "+refs/pull/$N/head:refs/remotes/origin/pr-$N"
git -C "$HOME/repos/$REPO" checkout -B "pr-$N" "origin/pr-$N"
```

- **`refs/pull/<n>/head` works for any PR** without knowing its branch name, and survives a force-push
  by moving the ref.
- **Do not install `vendor/` or `node_modules/` for advisory reviews.** A review that reads code and
  reports findings needs neither; measured on a real app, the substantive findings (an untested wiring
  decision, a link pointing at a page that cannot do what it promises) came entirely from reading. Add
  a build only when the findings themselves look thin on runtime behaviour — that is the evidence, and
  it is worth checking before paying hundreds of megabytes per repo.
- **Budget the clone set before starting**: sum the repo sizes and compare with free disk. A dozen
  repos is usually well under a gigabyte of git, but the built trees are not, which is the second
  reason to skip them.

## Sizing the backlog

Measure one real review on the host, then multiply per repo — and expect one project to dominate the
total. A single project with ninety-odd PRs at twenty minutes each is a day and a half of serial work,
and it is also the floor for the whole batch: other repos run alongside it, so they add parallelism,
not hours. Quote the floor, not the sum, when telling the user when a backlog will clear.
