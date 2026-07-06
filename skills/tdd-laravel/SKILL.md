---
name: tdd-laravel
description: Test-driven development with red-green-refactor loop using Pest PHP. Use when user wants to build features or fix bugs using TDD, mentions "red-green-refactor", wants integration tests, asks for test-first development, or needs guidance on writing testable code with Pest.
author: Mike Scott
---

# Test-Driven Development

## 🛑 CRITICAL: The Refactor Phase Is Mandatory

**After EVERY red-green cycle, you MUST:**

1. **Complete the refactor checklist** (see [refactor-checklist.md](refactor-checklist.md))
2. **Propose refactors to the user** with specific code examples
3. **Get explicit user approval** before making any changes
4. **Execute approved refactors** and verify tests still pass
5. **Display the completed checklist** to the user before proceeding

**Do NOT skip refactoring. Do NOT proceed to the next test without user approval of refactoring.**

The TDD Mantras are:
- 🕉️ **RED → GREEN → REFACTOR (with user approval) → RED → GREEN → REFACTOR (with user approval) → ...**
- 🛑 Production code may not be written or modified unless we have a RED test and are trying to make it GREEN.

When activating the TDD skill, you MUST state the above TDD mantras to demonstrate that you understand the
red-green-refactor cycle with mandatory user approval of refactoring along with requiring a red test before 
writing or modifying any production code.

---

## 🛑 CRITICAL: Pre-Action Verbalization Requirement

**Before writing ANY test, you MUST verbalize the following statement:**

> "I am writing ONE test for [specific behavior]. I will not write or modify production code unless it's to make a failing red test pass (green). I will write the simplest code possible. I will present a checkpoint before proceeding to any next step."

This verbalization must:
1. State specifically what behavior this ONE test covers
2. Explicitly acknowledge the rule: no production code except to make a RED test GREEN
3. Commit to writing the simplest code
4. Commit to presenting checkpoints

**You must NOT write more than one test before getting user approval to proceed.**

---

## Checkpoints and User Approval

**⚠️ CRITICAL: You MUST use the `question` tool for all checkpoints. Do not output plain text options.**

Present checkpoints using the `question` tool with `multiple: false`. The user clicks or presses a number to select. Never ask the user to type an answer when they can select from options.

There are **three types of checkpoints** in the TDD cycle:

### 1. RED Checkpoint (After writing test)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CHECKPOINT - TDD Cycle #[N] RED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
File:  [path]:[line]  (current test)
Test:  [test name]
Phase: RED
Result: ✗ Test fails (as expected)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Options after RED:**
1. **"Write the simplest code to make the test pass"** - Proceed to GREEN phase (write minimal code only)
2. **"Stop and discuss"** - User wants to review/refine the test before proceeding
3. **"Type your own answer"** - User has custom feedback

### 2. GREEN Checkpoint (After test passes)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CHECKPOINT - TDD Cycle #[N] GREEN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
File:  [path]:[line]  (current test)
Test:  [test name]
Phase: GREEN
Code:  [one-line code summary]
Result: ✓ Test passes
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Options after GREEN:**
1. **"Next test"** - Proceed to RED phase for next test
2. **"Refactor"** - Enter REFACTOR phase
3. **"Stop and discuss"** - Pause to discuss

### 3. REFACTOR Checkpoint (After refactor)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CHECKPOINT - TDD Cycle #[N] REFACTOR
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
File:  [path]:[line]  (current test)
Phase: REFACTOR
Changes: [summary of refactor]
Result: ✓ Tests still pass
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Options after REFACTOR:**
1. **"Continue refactoring"** - More refactoring, stay in REFACTOR phase
2. **"Next test"** - Proceed to RED phase for next test
3. **"Stop and discuss"** - Pause to discuss

---

## 🛑 ABSOLUTE RULE: Stop Points After Every Phase

**After completing RED, GREEN, or REFACTOR phase, you MUST stop and use the `question` tool to get user approval before any tool use.**

**Do NOT:**
- Write any code
- Run any commands
- Make any changes
- Proceed to next phase

**until the user has clicked an option and you have received their response.**

**Do NOT:**
- Write any code
- Run any commands
- Make any changes
- Proceed to next phase

**until the user has clicked an option and you have received their response.**

---

## Quick Start

TDD follows the **red-green-refactor** cycle:

1. **RED**: Write a test that fails
2. **GREEN**: Write the **simplest code** that passes (not optimal code)
3. **REFACTOR**: Clean up, extract duplication, apply patterns (with user approval)
4. **Repeat** for next behavior

## Triangulation: How Code Evolves to Perfection

**The critical insight:** Don't try to write perfect code in the GREEN phase. Write the simplest thing that works, then let multiple tests guide you to the best solution.

### The Process

1. **First test (degenerate):** Write the simplest test. Make it pass with hardcoded values if needed.
2. **Second test (different case):** Now you can't hardcode - write actual logic (still simple, may be oversimplified).
3. **Third test (more complex):** Oversimplified logic breaks. Now you write more general, correct code.
4. **Refactor after each test:** With multiple tests as a safety net, improve code quality and apply SOLID principles.

### Why This Works

Each new test **triangulates** you toward the best solution. The code naturally converges on the cleanest, most general implementation because:
- You're always writing the simplest thing that works
- Multiple tests prevent overengineering (you only add complexity when forced by a failing test)
- Refactoring is safe (tests catch regressions)

**Without TDD:** You anticipate all cases upfront and write overly complex code.
**With TDD:** Tests guide you to the right level of complexity naturally.

## Core Principles

- **Tests verify behavior, not implementation** — See [philosophy.md](philosophy.md)
- **Vertical slices, not horizontal** — See [anti-patterns.md](anti-patterns.md)
- **One test at a time** — Each test responds to what you learned from the previous cycle
- **Minimal code to pass** — Don't anticipate future tests
- **Deep modules with real dependencies** — Test through real interfaces, not mocks of internal parts — See [deep-modules.md](deep-modules.md)
- **Integration-style testing** — Exercise real code paths through public APIs, not implementation details

## ⚠️ CRITICAL: Feature Tests Required for Laravel Code

**Any test that uses Eloquent models, facades, or the Laravel application container MUST be a Feature test, not a Unit test.**

Unit tests do not load the Laravel application. If your test uses `Model::factory()`, `app()`, `Mail::`, `Storage::`, or any other Laravel feature, it must be in `tests/Feature/`, not `tests/Unit/`.

## Degenerate Tests: Your Safety Net

**Always write the degenerate (negative) test first** before the positive test.

### Why?

The degenerate test becomes your **safety net** that catches accidental behavior. Once it's GREEN, it will immediately go RED if you accidentally implement the behavior you're trying to avoid.

### Example

When implementing "fire event when PDF fields change":

1. **First (degenerate)**: Write test "event does NOT fire when non-PDF fields change" → GREEN (no code yet)
2. **Second (positive)**: Write test "event fires when PDF fields change" → RED (event not implemented)
3. **Implement**: Fire event (simplest thing) → First test goes RED (oops, firing for all changes)
4. **Refine**: Only fire for PDF-relevant fields → Both tests GREEN

The degenerate test caught your mistake in step 3 and guided you to the correct implementation.

## Default Testing Pattern: Deep Modules with Real Dependencies

This project's default approach is **integration-style testing with real dependencies**:

- **Create real data** using factories (e.g., `Property::factory()->create()`)
- **Use real dependencies** - Inject actual actions and services, not mocks
- **Test observable behavior** - Verify what the system does through its public interface
- **Avoid mocking internal collaborators** - Only mock at system boundaries (external APIs, time, randomness)

**Why this approach?**
- Catches real integration issues that mocks would hide
- Tests are simpler to write (no complex mock setup)
- Tests survive refactoring because they test behavior, not implementation
- More confidence in the code working end-to-end

**When to mock:**
- External APIs (payment gateways, email services, etc.)
- Time/randomness (use `now()`, `fake()`)
- File system operations (use `Storage::fake()`)
- Never mock your own classes or internal collaborators

See [deep-modules.md](deep-modules.md) and [mocking.md](mocking.md) for detailed guidance.

## The Workflow

See [workflow.md](workflow.md) for detailed step-by-step guidance on:
- Planning before you code
- Writing tracer bullets
- The incremental loop
- When and how to refactor

## Important: Single Task Responsibility

**See [single-task-responsibility](../single-task-responsibility/SKILL.md) skill.**

While implementing a task, if you discover you're addressing **multiple distinct responsibilities**, STOP immediately and consult the user. Each task should have a single, well-defined responsibility.

## Refactor Checklist

**See [refactor-checklist.md](refactor-checklist.md) for the mandatory checklist you must complete after every GREEN phase.**

You MUST display the completed checklist to the user with all items marked complete before proceeding to the next task.

## Reference Materials

- [tests.md](tests.md) — Testing examples and patterns
- [mocking.md](mocking.md) — Mocking guidelines
- [deep-modules.md](deep-modules.md) — Designing deep modules
- [interface-design.md](interface-design.md) — Designing for testability
- [refactoring.md](refactoring.md) — Refactoring patterns
