---
name: routing-and-controllers
description: Creating or editing a controller, or adding or editing a route in this project. Covers resourceful controllers, Route::resource and Route::singleton registration, why invokable controllers are not used here, and how routes map to Wayfinder TypeScript actions.
author: Mike Scott
version: '1.1.0'
updated: '2026-10-20'
---

# Routing and Controllers

## When to Activate This Skill

Activate this skill whenever you are about to:
- Create a controller, or add, rename, or remove a method on one
- Add, change, or remove a route in `routes/web.php`, `routes/settings.php`, or any other route file
- Decide where a new operation belongs
- Debug a missing or stale Wayfinder TypeScript action

## Conventions

These are rules. Apply them to everything you add or change; do not infer the convention from whatever happens to be in the file you are editing.

1. **A controller is singular and named for the resource it serves** — `JobController`, `ExpenseDocumentDownloadController`, `JobPendingController`. The route resource is plural: `Route::resource('jobs', JobController::class)`.
2. **A controller exposes only the seven resource actions**: `index`, `show`, `create`, `store`, `edit`, `update`, `destroy`. No other public methods, and never `__invoke`.
3. **A bespoke operation becomes its own resource controller**, not a method on an existing one. The controller *is* the resource; the verb comes from the URL and the HTTP method, never from the method name.
   - `POST jobs/{job}/pending` → `JobPendingController@store`
   - `POST placements/{placement}/confirm` → `PlacementConfirmationController@store`
   - `POST timesheets/{timesheet}/approve` → `TimesheetApprovalController@store`
4. **Register with `Route::resource`, narrowed with `->only()` or `->except()`.** Pin only when you must: `->parameters(['records' => 'client'])` when the bound model is not named after the resource; `->names([...])` when a name has to differ. Use `Route::singleton` for a resource there is only one of (e.g. `settings/xero`).
5. **A nested resource keeps its parent's URL** with an explicit registration, but the method is still one of the seven:
   ```php
   Route::post('jobs/{job}/pending', [JobPendingController::class, 'store'])->name('job-pendings.store');
   ```
   A hand-written `Route::get`/`post`/`put`/`patch`/`delete` is for a route that reaches **no** controller action (a closure, a redirect, a view) or for a nested resource. It is never a licence to name the method after the operation.
6. **An external system constrains the URL and the HTTP verb, not our method names.** An OAuth callback (`GET /settings/xero/callback`), a webhook (`POST /webhooks/xero`) and an emailed magic link (`GET /passwordless/login/{token}`) all still use a resource action: `show()` for the GET, `store()` for the POST. If one controller would end up carrying several unrelated operations, split it into one resource controller per operation.
7. **Route names follow resource and action** — `jobs.show`, `placement-confirmations.store`. Never a name that restates a verb (`jobs.pending`) or invents an action (`expense-documents.download`).

## The Complete Workflow

When adding an operation that does not fit an existing resource:

1. **Name the resource.** Often the operation's noun: an approval, a confirmation, a download.
2. **Create the controller** — singular, `final`, with the resource action you need:
   ```bash
   php artisan make:controller JobPendingController --no-interaction
   ```
   ```php
   final class JobPendingController
   {
       public function store(Request $request, Job $job): RedirectResponse
       {
           // …
       }
   }
   ```
3. **Register the route** in `routes/web.php`, inside the group whose middleware and prefix belong to it:
   ```php
   Route::resource('job-pendings', JobPendingController::class)->only(['store']);
   // or, nested under its parent:
   Route::post('jobs/{job}/pending', [JobPendingController::class, 'store'])->name('job-pendings.store');
   ```
4. **Regenerate the Wayfinder actions.** The Vite plugin does this on dev/build; manually:
   ```bash
   php artisan wayfinder:generate --with-form --no-interaction
   ```
5. **Use the generated action** in React — one named import per controller method:
   ```typescript
   import { show } from '@/actions/App/Http/Controllers/JobController';

   <Link href={show(job).url}>View job</Link>
   ```

## Why Not Invokable Controllers

An invokable controller (`__invoke`) and a custom method (`markPending`, `confirm`, `download`) are the same deviation from this convention: a controller whose public interface is not the resource vocabulary. They cause three concrete problems:

- **They hide the resource.** A reader cannot tell what a `SwitchAccountController` creates, or which HTTP verb reaches `markPending`.
- **They multiply.** Every bespoke verb invites another, because the shape says "controllers are a place to put verbs".
- **They generate ambiguous frontend imports.** `ClientsController().url` names no action, and a controller that later needs a second action has to be restructured.

Wayfinder's type safety comes from the controller *method*, not from invokability, so nothing is lost by using `show()`/`store()`.

## Critical: Routes Must Be Registered for Wayfinder

**Wayfinder only generates TypeScript action files for routes that are actually registered.**

If you create a controller but don't register its route, no action file is generated and the frontend import fails.

### Troubleshooting Missing Action Files

If `import { show } from '@/actions/...'` fails:

1. Check that the route is registered in the relevant route file
2. Check that the method is one of the seven resource actions, on a route that reaches it
3. Run `php artisan wayfinder:generate --with-form --no-interaction`
4. Check that the generated file exists in `resources/js/actions/`

If still missing, activate the `troubleshooting` skill for further diagnosis.
