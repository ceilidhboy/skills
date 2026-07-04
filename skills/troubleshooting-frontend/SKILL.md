---
name: troubleshooting-frontend
description: Troubleshooting TypeScript, React, and frontend-related errors.
---

# Troubleshooting Frontend Issues

## When to Activate This Skill

Activate this skill when encountering:
- TypeScript compilation errors
- Import resolution failures
- React component errors
- Inertia.js issues
- Wayfinder action generation issues
- Browser console errors
- Type mismatches in React code

## Common Frontend Issues and Solutions

### Import Resolution Failures

**Problem**: `Cannot find module '@/actions/...'`
**Cause**: Wayfinder action file not generated (route not registered)
**Solution**:
1. Activate `routing-and-controllers` skill
2. Verify the route is registered in `routes/web.php`
3. Run `php artisan wayfinder:generate --no-interaction`
4. Verify the file exists in `resources/js/actions/`

### TypeScript Compilation Errors

**Problem**: `tsc --noEmit` fails with type errors
**Cause**: Type mismatches or missing type definitions
**Solution**:
1. Read the error message carefully — it shows the exact file and line
2. Check if the type is defined in `resources/js/types/generated.d.ts`
3. If missing, run `php artisan typescript:transform` on the backend
4. Verify the PHP class has `@TypeScript` attribute (for Spatie Data)

### Missing Type Definitions

**Problem**: TypeScript can't find types for PHP classes
**Cause**: PHP class not transformed to TypeScript
**Solution**:
1. Ensure the PHP class uses Spatie Data with `@TypeScript` attribute
2. Run `php artisan typescript:transform`
3. Check `resources/js/types/generated.d.ts` for the generated type

### React Component Errors

**Problem**: Component doesn't render or throws error
**Cause**: Props type mismatch, missing data, or logic error
**Solution**:
1. Check browser console for error details
2. Verify props match the component's type definition
3. Check that data is being passed from the backend
4. Use React DevTools to inspect component state

### Wayfinder Action Issues

**Problem**: Action method not available (e.g., `.form()` missing)
**Cause**: Route not generated with form support
**Solution**:
```bash
php artisan wayfinder:generate --with-form --no-interaction
```

Then regenerate TypeScript types:
```bash
php artisan typescript:transform
```

## Diagnostic Steps

1. **Check browser console** — Look for JavaScript errors
2. **Run TypeScript check** — `npm run types`
3. **Check generated files** — Verify files exist in `resources/js/actions/` and `resources/js/types/`
4. **Clear cache** — `npm run build` or `npm run dev`

## When to Activate Other Skills

- **Backend errors appearing**: Activate `troubleshooting-backend`
- **Route/controller questions**: Activate `routing-and-controllers`
- **Component structure questions**: Activate `inertia-react-development`

