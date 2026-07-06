---
name: wayfinder-conventions
description: Project routing conventions and patterns. Complements the Laravel Wayfinder skill with project preferences for actions over routes.
author: Mike Scott
---

# Wayfinder Conventions

## When to Activate This Skill

Activate this skill alongside the `wayfinder-development` skill whenever:
- Working with routing in frontend components
- Creating links, navigation, or form submissions
- Importing from `@/actions/` or `@/routes/`
- Making decisions about which routing pattern to use

## Project Preference: Actions Over Routes

**In this project, strongly prefer using actions (invokable controllers) over named routes whenever possible.**

### Why Actions Are Better for This Project

- **Type Safety**: Invokable controllers provide better IDE support and type checking
- **Discoverability**: Actions are tied to specific controller classes, making them easier to find and understand
- **Refactoring**: Renaming a controller method automatically updates all imports
- **Intent**: Actions clearly show which controller handles the request
- **Consistency**: Keeps routing patterns consistent across the codebase

### When to Use Actions (Preferred)

```typescript
// ✅ Preferred: Import from controller action
import DashboardController from '@/actions/App/Http/Controllers/DashboardController';

// Use it
DashboardController().url  // "/dashboard"
```

### When to Use Named Routes (Exception)

Use named routes only when:
- The route doesn't map to a specific controller action
- The route is a simple redirect or view-only route
- There's a specific architectural reason

```typescript
// ⚠️ Only when necessary: Import from named route
import { home } from '@/routes';

home().url  // "/"
```

## Project Examples

### Navigation Links

```typescript
// ✅ Good: Use action for controller-based route
import ClientsController from '@/actions/App/Http/Controllers/ClientController';

<Link href={ClientsController().url}>View Clients</Link>
```

### Form Submissions

```typescript
// ✅ Good: Use action for form handling
import StorePostController from '@/actions/App/Http/Controllers/PostController';

<Form {...StorePostController().form()}>
    <input name="title" />
</Form>
```

## Refer to Laravel Wayfinder Skill

For detailed Wayfinder documentation, patterns, and API reference, see the `wayfinder-development` skill that comes with Laravel.

