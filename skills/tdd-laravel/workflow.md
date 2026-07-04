# TDD Workflow

## 1. Planning

Before writing any code:

- [ ] Confirm with user what interface changes are needed
- [ ] Confirm with user which behaviors to test (prioritize)
- [ ] Identify opportunities for deep modules (small interface, deep implementation)
- [ ] Design interfaces for testability
- [ ] List the behaviors to test (not implementation steps)
- [ ] Get user approval on the plan

### Key Questions

Ask: "What should the public interface look like? Which behaviors are most important to test?"

**You can't test everything.** Confirm with the user exactly which behaviors matter most. Focus testing effort on critical paths and complex logic, not every possible edge case.

## 2. Tracer Bullet

Write ONE test that confirms ONE thing about the system:

```
RED:   Write test for first behavior → test fails
GREEN: Write minimal code to pass → test passes
```

This is your tracer bullet - proves the path works end-to-end.

## 3. Incremental Loop

For each remaining behavior:

```
RED:   Write next test → Get user approval → Run test (fails)
GREEN: Minimal code to pass → test passes
```

### Rules

- One test at a time
- **After writing each new test, PAUSE and get explicit user approval before running it**
  - Provide test name and line number only (e.g., "Test: 'creates array from collection' at line 47-62")
  - Do NOT output the code - let the user view it in their IDE
- Only enough code to pass current test
- Don't anticipate future tests
- Keep tests focused on observable behavior

## 4. Refactor

After all tests pass, look for refactor candidates:

- [ ] Extract duplication
- [ ] Deepen modules (move complexity behind simple interfaces)
- [ ] Apply SOLID principles where natural
- [ ] Consider what new code reveals about existing code
- [ ] Run tests after each refactor step

**Never refactor while RED.** Get to GREEN first.
