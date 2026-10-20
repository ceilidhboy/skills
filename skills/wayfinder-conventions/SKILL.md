---
name: wayfinder-conventions
description: Project routing conventions for the frontend. Use when importing from @/actions or @/routes, building links or form submissions, or deciding between a controller action and a named route.
author: Mike Scott
version: '1.1.0'
updated: '2026-10-20'
---

# Wayfinder Conventions

## When to Activate This Skill

Activate this skill alongside the `wayfinder-development` skill whenever:
- Working with routing in frontend components
- Creating links, navigation, or form submissions
- Importing from `@/actions/` or `@/routes/`
- Making decisions about which routing pattern to use

## Project Preference: Controller Actions Over Named Routes

**In this project, prefer Wayfinder's controller-action functions over named-route functions whenever the endpoint is served by a controller.**

A Wayfinder *action* is the typed function generated for one controller **method** — one export per public method, not one per controller. It has nothing to do with whether the PHP controller is invokable: controllers in this project are resourceful, so the exports are named after the resource actions (`index`, `show`, `create`, `store`, `edit`, `update`, `destroy`).

The consequence for backend work: **never invent a controller method to get a nicer frontend import.** A bespoke operation is a new resource controller with one of the seven actions — see the `routing-and-controllers` skill.

### When to Use Actions (Preferred)

```typescript
// ✅ Preferred: the controller method's action
import { show, store } from '@/actions/App/Http/Controllers/ClientController';

show(client).url                    // "/clients/1"
<Form {...store.form()}>…</Form>    // POST /clients
```

### When to Use Named Routes (Exception)

Use named routes only when the route has no controller action:

- a closure route, a redirect, or a view-only route
- a route with a specific architectural reason to bypass a controller

```typescript
// ⚠️ Only when necessary: named route
import { home } from '@/routes';

home().url  // "/"
```

### Why Actions Are Preferred

- **Type safety**: the generated function is typed from the route's parameters — identical whether the controller method is `show()` or `__invoke()`, which is why invokable controllers buy nothing
- **Refactoring**: renaming a controller method regenerates the exports, so every stale import fails to compile
- **Intent**: the import names both the controller and the action it performs

## Project Examples

### Navigation Links

```typescript
// ✅ Good: the index action of a resource controller
import { index } from '@/actions/App/Http/Controllers/ClientController';

<Link href={index().url}>View Clients</Link>
```

### Form Submissions

```typescript
// ✅ Good: the store action of a resource controller
import { store } from '@/actions/App/Http/Controllers/PostController';

<Form {...store.form()}>
    <input name="title" />
</Form>
```

## Refer to Laravel Wayfinder Skill

For detailed Wayfinder documentation, patterns, and API reference, see the `wayfinder-development` skill that comes with Laravel.
