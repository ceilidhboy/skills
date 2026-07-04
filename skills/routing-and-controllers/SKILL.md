---
name: routing-and-controllers
description: Creating controllers, registering routes, and understanding how routes map to Wayfinder TypeScript actions.
---

# Routing and Controllers

## When to Activate This Skill

Activate this skill whenever:
- Creating new controllers or modifying existing ones
- Registering routes in `routes/web.php` or other route files
- Working with RESTful resource routing
- Understanding how routes map to Wayfinder TypeScript actions
- Troubleshooting missing controller actions or route registration issues

## The Complete Workflow

When creating a new controller with a route:

1. **Create the controller** using Artisan:
   ```bash
   php artisan make:controller JobController --no-interaction
   ```

2. **Implement the controller action** with proper type hints and return types:
   ```php
   final class JobController
   {
       public function show(int $id): string
       {
           return "Job details for job {$id}";
       }
   }
   ```

3. **Register the route** in `routes/web.php`:
   ```php
   use App\Http\Controllers\JobController;
   
   Route::middleware(['auth', 'verified'])->group(function () {
       Route::resource('jobs', JobController::class)
            ->only(['show']);
   });
   ```

4. **Generate Wayfinder TypeScript actions**:
   ```bash
   php artisan wayfinder:generate --no-interaction
   ```

5. **Use the generated action** in React components:
   ```typescript
   import JobController from '@/actions/App/Http/Controllers/JobController';
   
   <Link href={JobController.show(jobId).url}>View Job</Link>
   ```

## RESTful Resource Routing

This project uses Laravel's resource routing convention:

```php
Route::resource('jobs', JobController::class)
     ->only(['index', 'show', 'create', 'store', 'edit', 'update', 'destroy']);
```

Common patterns:
- `.only(['index', 'show'])` — Read-only resources
- `.only(['show'])` — Single action (like job details)
- `.only(['store', 'update', 'destroy'])` — Mutation actions

## Critical: Routes Must Be Registered for Wayfinder

**Wayfinder only generates TypeScript action files for routes that are actually registered in your route files.**

If you create a controller but don't register its route, Wayfinder won't generate the TypeScript action file, and you'll get import errors in your React components.

### Troubleshooting Missing Action Files

If `import JobController from '@/actions/...'` fails:

1. Check that the route is registered in `routes/web.php`
2. Verify the controller class name matches the import path
3. Run `php artisan wayfinder:generate --no-interaction` again
4. Check that the generated file exists in `resources/js/actions/`

If still missing, activate the `troubleshooting` skill for further diagnosis.

