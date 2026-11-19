---
name: test-gate
description: "Activate before creating, modifying, or deleting any production code. Two gates depend on the kind of change: a behaviour change needs a failing (red) test for that change first; a refactor needs the whole suite green and the target code already covered first. The trigger is the write itself, not the reason for it."
---

# Test Gate — no production change without the right gate

Every write to production code has to pass a gate. Which gate depends on what
kind of change it is, so classify first, out loud:

| Kind of change | Gate | Proof the gate is open |
|---|---|---|
| **Behaviour change** — bug, feature, tweak, rename with side effects | a **red** test for *this* change | the failure output, failing for the intended reason |
| **Refactor** — behaviour must not change | **all tests green**, *and* the code about to move is **covered** | a green full-suite run before you start, the same run green after |

Say which gate you are opening and why before touching a file. "I'll add a
test afterwards" is not a gate, it is the thing the gate exists to prevent.

## Gate 1 — behaviour change: red first

1. **Run the suite.** If a test already fails for the behaviour you are about
   to change, the gate is open — move on.
2. **Otherwise write the test.** Assert the behaviour you *want*, so it fails
   against the current code. One test, for one behaviour.
3. **Run it and read the failure.** It must be red, and red *for the intended
   reason*: not a typo, not a missing fixture, not a silently broken setup that
   never ran the assertion.
4. **Only now modify production code.** Make the test pass, then run the whole
   suite.
5. If making it pass requires changing another test's assertions, you are
   changing behaviour again — back to step 2 for that second behaviour.

A failure for the wrong reason cannot be fixed by implementing the feature, so
it will not go green and you will be forced to look at it. Reading the failure
is how you satisfy the gate, not a separate discipline.

## Gate 2 — refactor: green first, and covered

1. **Run the whole suite. It must be green before you start.** Red anywhere
   means you are not refactoring, you are changing behaviour.
2. **Name the tests that cover the code you are about to move.** If you cannot
   name them, the gate stays shut: uncovered code may not be refactored.
3. **If it is uncovered, write a characterisation test first.** Assert what the
   code does *today*, including its warts. This test is green the moment it is
   written — the one legitimate case of a test with no red state — because its
   job is to catch your refactor breaking the behaviour, not to expose a defect.
4. **Refactor.** Full suite green afterwards, and **no assertion changed**. A
   changed assertion means behaviour moved, which makes it a Gate 1 change.

## Why the gate, not merely the order

A test written *after* the code is green from the start, so it cannot tell
"the code works" apart from "the test asserts nothing". The failure is usually
silent: a pattern that never matches its target still passes, both before and
after the fix. Treat any assertion that is already green before your change as
a broken assertion.

That is also why the gate is stated as *red for this change* rather than just
*red*: a red test that tears down before it asserts, or that shells out and
ignores the exit status, is not a gate either.

## Anti-patterns

- Fixing first, then writing the test that would have proved it. It proves
  nothing — it would have passed before the fix too.
- Writing the assertion without ever seeing it fail, then assuming green means
  correct. See above.
- Skipping the gate because "the fix is obvious". Obvious changes regress too.
- Batching several behaviours into one cycle. One gate, one behaviour.
- Refactoring uncovered code because the suite is green. Green is necessary,
  not sufficient — the *area* must be covered.
- Per-file gates: one production write per gate, not one gate per branch.

## Mutation testing is an adjunct, not a substitute

Red-then-green proves an assertion distinguishes the current code from the
intended code. It cannot prove the assertion is sensitive — that a half-finished
or subtly wrong implementation would also fail it. Deliberately breaking the
production code to watch the test go red explores that axis, and is worth doing
where "too weak" is the risk. It does not replace the gate: it happens after the
code is written, which is exactly the position this skill says to avoid.
