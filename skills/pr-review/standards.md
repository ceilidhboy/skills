# Review standards

The criteria both legs apply. This file exists so **severity is a rule rather than an opinion**:
the same finding must reach the same severity in the reviewer, in the oracle, and in every review
run months from now. It does not find more defects; it makes findings comparable.

Read this before reporting. Apply it to your own severity choices. If you believe a rule here is
wrong, say so in your report — do not silently apply a different one.

## Severity

| Glyph | Means | The decisive test |
|---|---|---|
| 🔴 **Blocker** | must be resolved before this merges | Would the merge ship wrong behaviour, a security or authorisation hole, data loss, a non-rollback-able migration, a leaked secret, or a build/type error? If the merge would ship it, it is a blocker. |
| 🟡 **Warning** | should be fixed in this PR; not fatal | A real risk, omission or trap that a reviewer would insist on: missing test on new behaviour, missing validation, debug logging left in, an error swallowed, docs that will actively mislead. |
| ❔ **Minor** | worth saying; no judgement needed | Naming, duplication, dead code, readability, formatting. Anything the review can correct inline without asking anyone anything. |

**The rule that stops inflation:** if the review can fix it inline without a decision, it is ❔ at
most — however irritating it is. Severity is not emphasis.

**The rule that stops deflation:** a missing test on new behaviour is 🟡, not ❔. Untested new
behaviour is a gap in the change, even though adding the test is mechanically simple.

Both legs assign severity independently. When they disagree, the orchestrator resolves it by
applying this table — **not** by preferring the more severe leg, and not by splitting the difference.

## Finding labels

Tag **every** finding with exactly one label from this list. The label is what makes recurrence
countable later: twelve reviews with `debug-logging` is one missing lint rule, not twelve defects.

| Label | Use for |
|---|---|
| `correctness` | wrong behaviour, wrong result, broken edge case |
| `missing-test` | behaviour added or changed with no test pinning it |
| `authz` | authorisation, permissions, tenancy, who-can-see-what |
| `security` | injection, secrets, unsafe deserialisation, exposure |
| `data-integrity` | migrations, backfills, destructive writes, rollback safety |
| `error-handling` | swallowed exceptions, unchecked results, silent failure |
| `debug-logging` | stray dumps, console noise, commented-out code left in |
| `naming` | names that mislead or contradict the glossary |
| `duplication` | the same logic in a second place |
| `dead-code` | unreachable, unused, or superseded code left behind |
| `spec-drift` | the change does not match the PR description or spec |
| `stale-doc` | prose, comments or plans that now describe something else |
| `formatting` | a formatter the project declares would rewrite files, and the run discarded the rewrite rather than pushing it |
| `scope-creep` | unrelated change bundled into this PR |
| `perf` | a real cost on a hot path |

Adding a label is a change to this file and is reviewed like code. Do not invent one at report
time: pick the nearest, and say in the finding if none fits — an unmatched finding is a signal that
the vocabulary needs extending, which is itself worth knowing.

**`formatting` comes from the baseline pipeline, not from a leg.** It is raised when the project's
formatter would rewrite files and the run discarded the rewrites instead of pushing them (step 2.5,
post mode), and it is **one finding per review**: the formatter names and the count, never one
finding per file. Twenty files of drift is one missing formatter run, and the recurrence query reads
reviews, not files — a per-file report would inflate the count until it told you nothing.

## Disposition

Every finding carries exactly one bucket **at the point it is raised**, not once the fixes have been
agreed: `Inline fix`, `Issue`, or `Decision`. The bucket is part of the finding, like its severity
and its label.

| Bucket | Use for |
|---|---|
| `Inline fix` | anything the review can correct itself: prose, a comment, a name, a missing test, a behaviour change pinnable with a red-first test, a small refactor |
| `Issue` | work that must not be fixed in this PR — out of scope, cross-cutting, or needing its own scheduling |
| `Decision` | a remedy that needs a choice only a human owns — product behaviour, a trade-off between defensible options, a deploy or production-data call |

**"Optional" is not a bucket.** A finding described as optional, "worth saying", "flagging because",
or "if you want it" still gets one of the three. An open ❔ with no bucket is a finding already
falling through a crack: it reads as a dropped item to whoever has to act on it, and it will be
re-raised as new work a round later.

**An `Issue` must name what un-defers it.** Every `[Issue]` carries three things: what is deferred,
why it cannot be done here, and the specific condition that would bring it back — a decision someone
will make, a ticket someone will pick up, a PR that must land first.

An `Issue` whose un-defer condition is "someone does it eventually" is not deferred, it is
unstarted. **If you cannot name the trigger in one sentence, the finding is either an `Inline fix`
you have not done yet or a `Decision` you have not surfaced**, and it must be re-bucketed before the
report is written. The same test applies to the words "optional", "worth saying" and "if you want
it": each is a deferral with the condition left out.

**A remedy that splits gets both buckets.** When one part of the fix needs no decision — making a
map exhaustive, writing the explicit case, pinning the behaviour that exists — and another part
does (which colour, which policy, which wording), the finding is an `Inline fix` **and** an `Issue`
or `Decision`. Neither part subsumes the other, and the part that needs no decision is never grounds
for leaving the part that does unrecorded.

**Re-bucketing between turns is a review defect.** A finding that was an `Inline fix` in the
disposition table and becomes a `Decision` when challenged — or the reverse — was misclassified the
first time. Correct it explicitly, say which reading was wrong, and restate the counts; do not
quietly move the item and leave the earlier figure standing.

**The verdict decides where an unfixed finding lives.** On a 🟢 approve verdict nothing stays in
the report: every finding not fixed inline becomes an issue, assigned to the PR author, before
the review is delivered (`SKILL.md` step 14). On a 🟡 or 🔴 verdict the PR returns to the author,
so findings stay in the report and are carried into the follow-up ledger for the next review to
verify. A note that survives only in an approved review's body is a finding nobody schedules —
"noted for later" is not a disposition.

This section is a change to this file and is reviewed like code.
