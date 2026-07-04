# Refactor Checklist

## ⚠️ MANDATORY: Refactor Checklist Before Proceeding

**You MUST complete this checklist after every GREEN phase before proceeding to the next task.**

After all tests pass, you MUST:

- [ ] Identify all refactor candidates in the code you just wrote
- [ ] Evaluate each candidate against SOLID principles and existing codebase patterns
- [ ] Propose specific refactors to the user with code examples or explanations
- [ ] Get explicit user approval before making any refactor changes
- [ ] Execute approved refactors and verify tests still pass
- [ ] Do NOT proceed to the next task until refactoring is complete or explicitly deferred by the user

**After completing all checks above, you MUST display this completed checklist to the user** with all items marked as complete. The user should see evidence that you have followed this workflow.

## Per-Cycle Checklist

Before moving to the next test, verify:

```
[ ] Test describes behavior, not implementation
[ ] Test uses public interface only
[ ] Test would survive internal refactor
[ ] Code is minimal for this test
[ ] No speculative features added
```

## Why This Matters

The refactor phase is where you:
- Clean up duplication
- Improve code organization
- Apply design patterns
- Prepare for the next feature

Skipping refactoring leads to code rot. The checklist ensures you don't skip this critical phase.

