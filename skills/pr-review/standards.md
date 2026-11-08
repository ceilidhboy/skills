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
| `scope-creep` | unrelated change bundled into this PR |
| `perf` | a real cost on a hot path |

Adding a label is a change to this file and is reviewed like code. Do not invent one at report
time: pick the nearest, and say in the finding if none fits — an unmatched finding is a signal that
the vocabulary needs extending, which is itself worth knowing.
