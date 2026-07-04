# TDD Philosophy

## Core Principle

**Tests should verify behavior through public interfaces, not implementation details.** Code can change entirely; tests shouldn't.

## Good Tests vs Bad Tests

### Good Tests

Good tests are **integration-style**: they exercise real code paths through public APIs. They describe _what_ the system does, not _how_ it does it.

A good test reads like a specification:
- "user can checkout with valid cart" tells you exactly what capability exists
- These tests survive refactors because they don't care about internal structure
- They verify observable behavior, not implementation details

### Bad Tests

Bad tests are **coupled to implementation**. They:
- Mock internal collaborators
- Test private methods
- Verify through external means (like querying a database directly instead of using the interface)

**Warning sign**: Your test breaks when you refactor, but behavior hasn't changed. If you rename an internal function and tests fail, those tests were testing implementation, not behavior.

## The Key Insight

**Tests are a specification of behavior, not a verification of code structure.**

When you write a test that depends on how the code is organized internally, you've written a brittle test that will break during refactoring even though the behavior is correct.

Instead, write tests that describe what the system does from the outside. These tests will survive any internal reorganization.

