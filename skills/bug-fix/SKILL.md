---
name: bug-fix
description: "Activate when user reports a bug, broken feature, failing behaviour, or says 'fix this', 'not working', 'doesn't work', 'error', 'regression'. ALWAYS before writing any fix — red-green only."
---

# Bug Fix — Red-Green, No Exceptions

A bug report means our tests are incomplete. The bug is a gap in test coverage, not just a gap in production code. Fix the test first; the production fix follows.

## Hard gate

**Do not write or modify production code until a failing test exists and is confirmed failing.** This is non-negotiable. If you catch yourself reaching for a production file, stop and ask: "Do I have a failing test yet?"

## Step 1 — Expose the bug (red)

1. **Run the existing test suite.** If a test already fails and matches the reported bug, step 1 is done — the test already exposes the gap. Move to step 2.

2. **If all tests pass**, write a new test that reproduces the bug:
   - Place it in the appropriate test file, next to related tests.
   - Use the simplest setup that triggers the failure.
   - The test must assert the *correct* behaviour (what the user expects), so it fails against the *current* (broken) code.

3. **Run the test and confirm it fails.** Show the failure output. This is proof that the test catches the bug. Do not proceed until you see red.

## Step 2 — Fix the bug (green)

1. Modify production code to make the failing test pass.
2. Run the full test suite — all tests must be green.
3. If your fix breaks other tests, investigate: either the fix is wrong, or the other tests were relying on the buggy behaviour (update them too, with justification).

## What not to do

- Do not fix the bug and then write a test that passes. That test proves nothing — it would have passed before the fix too.
- Do not skip step 1 because "the fix is obvious." Obvious fixes still need a guard against regression.
- Do not batch multiple bug fixes into one step-1/step-2 cycle. Each bug gets its own failing test, its own fix. Isolation is the point.

## Example flow

```
User: "Tiles overlap when I drag them."

Agent:
1. Run tests → all green. No existing test covers drag overlap.
2. Write test: "drag into obstacle → actual position must not overlap obstacle."
3. Run test → FAILS (red). Bug confirmed.
4. Fix production code.
5. Run test → PASSES (green).
6. Run full suite → all green.
```
