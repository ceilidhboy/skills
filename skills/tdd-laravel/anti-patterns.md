# TDD Anti-Patterns

## Horizontal Slices (❌ WRONG)

**DO NOT write all tests first, then all implementation.** This is "horizontal slicing" - treating RED as "write all tests" and GREEN as "write all code."

### Why Horizontal Slices Produce Bad Tests

- Tests written in bulk test _imagined_ behavior, not _actual_ behavior
- You end up testing the _shape_ of things (data structures, function signatures) rather than user-facing behavior
- Tests become insensitive to real changes - they pass when behavior breaks, fail when behavior is fine
- You outrun your headlights, committing to test structure before understanding the implementation

### Example of Horizontal Slicing

```
WRONG (horizontal):
  RED:   test1, test2, test3, test4, test5
  GREEN: impl1, impl2, impl3, impl4, impl5
```

## Vertical Slices via Tracer Bullets (✅ CORRECT)

**One test → one implementation → repeat.** Each test responds to what you learned from the previous cycle. Because you just wrote the code, you know exactly what behavior matters and how to verify it.

### Example of Vertical Slicing

```
RIGHT (vertical):
  RED→GREEN: test1→impl1
  RED→GREEN: test2→impl2
  RED→GREEN: test3→impl3
  ...
```

## Why Vertical Slices Work

- Each test is written with fresh knowledge of what the code actually does
- You discover real behavior, not imagined behavior
- Tests are sensitive to actual changes
- You stay within your headlights - understanding grows with each cycle

