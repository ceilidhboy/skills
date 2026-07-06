---
name: troubleshooting
description: General troubleshooting guidance that routes to specific backend or frontend troubleshooting skills.
author: Mike Scott
---

# Troubleshooting

## When to Activate This Skill

Activate this skill **MANDATORY** when:
- Encountering unexpected errors or behavior
- Something doesn't work as expected and the cause is unclear
- You're about to spend time debugging without a clear direction

## How to Use This Skill

This skill acts as a **diagnostic router** to help you identify the type of issue and activate the appropriate specialized skill.

## Validating Your Success Metrics

**CRITICAL: Before you begin diagnosing a problem, you must establish what success looks like and verify that your measurement is actually valid.**

An incorrectly defined success metric can create a phantom problem - you'll see a problem that doesn't exist and spend time "fixing" something that's already working correctly. This wastes effort and pollutes the codebase with unnecessary changes.

### Why This Matters

When you use an invalid metric to measure success, you may conclude that something is broken when it's actually functioning as designed. You then attempt fixes for a problem that doesn't exist, introducing unnecessary code changes, complexity, and technical debt. These failed attempts often get left behind in the codebase, creating confusion and pollution.

### How to Validate Your Success Metrics

1. **Define Success Explicitly** - Before investigating, write down exactly what success looks like and *why* that's the right measurement. Question your assumptions:
   - What behavior am I measuring?
   - Is this the right layer to measure? (Network? Client state? React render?)
   - Does the documentation describe this behavior?
   - Is my metric aligned with how the system is *designed* to work?

2. **Use the Right Tools for Each Layer** - Different layers require different measurements:
   - Network behavior → Browser DevTools Network tab (request/response headers, payload)
   - Client-side state → Browser DevTools Console, Inertia client state
   - React behavior → React DevTools, component props
   - Server behavior → Server logs, database queries

   Don't use one tool's output to measure another layer's behavior.

3. **Verify Against Documentation** - Check the official documentation for the system you're working with. Does it describe the behavior you're measuring? If your metric contradicts the documentation, your metric is likely wrong.

4. **Clean Up Failed Attempts** - If you determine that:
   - There was no problem to begin with, OR
   - Your fixes were addressing symptoms, not root causes, OR
   - Your fixes didn't solve the actual problem

   **You must remove all attempted fixes and restore the code to its original state.** Do not leave behind the debris of failed diagnostic attempts. This pollution makes the codebase harder to understand and creates false history of changes that don't serve the actual solution.

## Binary Search Diagnostic Methodology

**CRITICAL: When diagnosing a problem, use binary search to split the problem space in half with each diagnostic check, rather than making assumptions about where the issue is.**

### The Principle

When something doesn't work as expected:
1. **Never assume** where the problem is
2. **Never make code changes** based on assumptions
3. **Always use diagnostic tools** to eliminate possibilities systematically
4. **Place checks in the middle** of the execution path to split the problem space in half
5. **Iterate** until only one possibility remains - that must be the cause

As Sherlock Holmes said: "When you have eliminated the impossible, whatever remains, however improbable, must be the truth."

### Logging Placement Strategy

**Bad: Logging at the beginning or end of the pipeline**
- Logging at the start tells you "the process started" but not where it failed
- Logging at the end tells you "the process ended" but not where the problem occurred
- Both approaches waste time because they don't split the problem space

**Good: Logging in the middle of the execution path**
- Place your first diagnostic check in the middle of the potential execution path
- If the check shows the problem is in the first half, place your next check in the middle of that half
- If the check shows the problem is in the second half, place your next check in the middle of that half
- Continue iteratively until you've isolated the exact location

### Using Diagnostic Tools

**Browser Logs Tool**: Use `browser-logs` to check frontend console output
- Reveals whether code paths are being executed
- Shows console.log output and JavaScript errors
- Helps determine if a component is being called or if a function is executing

**Laravel Logs**: Use `tail -f storage/logs/laravel.log` to check backend output
- Shows what data is being processed
- Reveals what's being sent to the frontend
- Helps verify backend logic is executing correctly

**Console Logging**: Add strategic console.log statements
- Place them in the middle of execution paths
- Use them to answer: "Is the problem in the first half or second half?"
- Remove them once the diagnosis is complete

### Key Principles

1. **Diagnose before fixing**: Never change code until you understand the root cause
2. **Binary search**: Each diagnostic check should split the problem space in half
3. **Eliminate possibilities**: Use diagnostic tools to eliminate possibilities systematically
4. **Revert failed attempts**: If a fix doesn't work, revert all related changes before trying a new approach
5. **Avoid code rot**: Don't leave artifacts of failed attempts in the codebase

### Real-World Example: Dashboard Pagination Issue

**The Problem**: Clicking pagination links caused "Cannot read properties of undefined (reading 'totalJobs')" error.

**Bad Approach (Assumption-Based)**:
- Assumption: Problem is in how `Inertia::always()` wraps data
- Action: Wrap data in closures, use `Inertia::optional()`, change return types
- Result: Multiple code changes, none of which fixed the issue
- Lesson: Assumptions led to wasted effort and code rot

**Good Approach (Binary Search)**:

1. **First Check (Middle of Pipeline)**: What props is Inertia actually sending to the frontend?
   - Added logging in `DashboardController` to log the props being sent
   - Result: Confirmed all props were being sent correctly
   - Conclusion: Problem is not in the backend

2. **Second Check (Frontend)**: Is the Dashboard component even being called during partial reloads?
   - Added console logging in the Dashboard component
   - Result: Component was NOT being called during partial reloads
   - Conclusion: Problem is in how Inertia handles the partial reload request

3. **Third Check (Request Details)**: What is the actual partial reload request asking for?
   - Checked the `X-Inertia-Partial-Data` header in logs
   - Result: Request was asking for `dashboard.recentActivities` (dot notation)
   - Conclusion: Problem is likely in how Inertia.js handles nested prop paths

4. **Verification**: Check Inertia.js documentation
   - Result: Inertia.js partial reloads only support top-level prop keys, NOT nested paths
   - Root Cause Found: Using `only={['dashboard.recentActivities']}` doesn't work

5. **Solution**: Change to `only={['dashboard']}` to request the top-level prop
   - Result: Partial reloads now work correctly

**Key Takeaway**: By placing diagnostic checks in the middle of the execution path and iteratively narrowing down the problem space, we converged on the root cause in 5 checks instead of making multiple blind code changes.

### Step 1: Identify the Issue Type

Ask yourself: **Where is the error occurring?**

**Backend/Laravel errors** include:
- PHP errors or exceptions
- Laravel framework errors
- Database errors
- Route registration issues
- Controller or action problems
- Type generation failures (PHP → TypeScript)
- Artisan command failures

**Frontend/TypeScript errors** include:
- TypeScript compilation errors
- Import resolution failures
- React component errors
- Inertia.js issues
- Wayfinder action generation issues
- Browser console errors
- Type mismatches in React code

### Step 2: Activate the Appropriate Skill

**If it's a backend/Laravel issue:**
> I'm activating the `troubleshooting-backend` skill because this is a Laravel/PHP error.

**If it's a frontend/TypeScript issue:**
> I'm activating the `troubleshooting-frontend` skill because this is a TypeScript/React error.

### Step 3: Follow the Specialized Skill's Guidance

Each specialized skill contains:
- Common issues and their solutions
- Diagnostic steps to identify the root cause
- Prevention strategies
- When to ask for help

## Common Cross-Cutting Issues

Some issues affect both backend and frontend:

- **Caching problems** — Generated files not updating
- **Configuration issues** — Environment variables or config files
- **Build/compilation failures** — npm or Artisan commands failing
- **File generation issues** — Wayfinder, TypeScript types not generating

For these, start with the skill that matches where the error appears, then check the other if needed.

## When to Ask for Help

If after following the specialized skill's guidance you still can't resolve the issue, ask the user with:
- The exact error message
- What you've already tried
- Which troubleshooting skill you activated
- What the skill recommended
