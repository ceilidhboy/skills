---
name: single-task-responsibility
description: Recognize when task implementation violates Single Responsibility Principle and stop to consult the user. Use when implementing a task and discovering you're addressing multiple distinct responsibilities.
---

# Single Task Responsibility

## Core Principle

**Each task should have a single, well-defined responsibility.**

When implementing a task, if you find yourself writing code that addresses **multiple distinct responsibilities**, this is a violation of the Single Responsibility Principle (SRP) and a signal to **STOP and consult the user**.

## Recognition Pattern

You're violating SRP when:

1. **The task description covers one responsibility** (e.g., "Write tests for PDF actions")
2. **Your implementation requires addressing another responsibility** (e.g., "Create mocking solution for external package")
3. **These responsibilities are distinct enough to warrant separate tasks**

### The Test

Ask yourself:
- Would an average developer expect to see this secondary work in the task description?
- Would an average developer expect this to be covered by a **separate, more detailed task**?
- Is this secondary work **significant enough** to warrant its own task?

If the answer is **YES** to any of these, you've found a responsibility violation.

## What to Do When You Hit SRP Violation

**STOP immediately.** Do not create pseudo-tasks or workarounds.

Report to the user:

1. **Identify the primary responsibility** (from task description)
2. **Identify the secondary responsibility** (what you're trying to implement)
3. **Explain why they're separate** (each warrants its own task)
4. **Propose solutions**:
   - Create a new task for the secondary responsibility
   - Find a different approach that keeps the task focused
   - Defer the secondary responsibility

## Example: PDF Generation Testing

**Task**: "Write tests for PDF generation actions"

**Primary responsibility**: Test the action code

**Secondary responsibility discovered**: Create mocking solution for `spatie/laravel-pdf`

**Why separate?**: 
- Mocking an external package is significant work
- It's not expected in a "write tests" task
- It warrants its own task: "Create mock for PDF package"

**Action**: STOP and ask the user which approach to take.

## Remember

SRP applies to **tasks** just as it applies to **code**. When a task starts to require multiple responsibilities, it's a sign the task itself needs to be split or reconsidered.

