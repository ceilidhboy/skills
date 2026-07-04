---
name: troubleshooting-backend
description: Troubleshooting Laravel, PHP, and backend-related errors.
---

# Troubleshooting Backend Issues

## When to Activate This Skill

Activate this skill when encountering:
- Laravel framework errors or exceptions
- PHP errors or type errors
- Database connection or query errors
- Route registration issues
- Controller or action problems
- Artisan command failures
- Type generation failures (PHP → TypeScript)

## Common Backend Issues and Solutions

### Route Registration Issues

**Problem**: Wayfinder action file not generated, import fails
**Cause**: Route not registered in `routes/web.php`
**Solution**:
1. Check `routes/web.php` for the route registration
2. Verify the controller class name matches
3. Run `php artisan wayfinder:generate --no-interaction`
4. Verify the file exists in `resources/js/actions/`

See the `routing-and-controllers` skill for detailed workflow.

### Type Generation Failures

**Problem**: TypeScript types not updating after PHP changes
**Cause**: `php artisan typescript:transform` not run
**Solution**:
```bash
php artisan typescript:transform
```

Then regenerate Wayfinder:
```bash
php artisan wayfinder:generate --no-interaction
```

### Artisan Command Failures

**Problem**: Artisan commands fail or hang
**Cause**: Configuration cache or stale files
**Solution**:
```bash
php artisan config:clear
php artisan cache:clear
php artisan view:clear
```

Then retry the command.

### Database Errors

**Problem**: Database connection fails or queries error
**Cause**: Environment variables, migrations not run, or schema issues
**Solution**:
1. Check `.env` file for correct database credentials
2. Run `php artisan migrate` if migrations pending
3. Check database schema with `php artisan tinker` and query directly

### PHP Type Errors

**Problem**: Static analysis or runtime type errors
**Cause**: Missing type hints or incorrect types
**Solution**:
1. Run `composer fix` to check Larastan analysis
2. Add proper type hints to methods and properties
3. Check the error message for the exact location and fix

## Diagnostic Commands

```bash
# Check configuration
php artisan config:show

# Run static analysis
vendor/bin/phpstan analyse

# Check routes
php artisan route:list

# Test database connection
php artisan tinker
```

## When to Activate Other Skills

- **Frontend errors appearing**: Activate `troubleshooting-frontend`
- **Routing/controller questions**: Activate `routing-and-controllers`
- **Testing failures**: Activate `pest-testing`

