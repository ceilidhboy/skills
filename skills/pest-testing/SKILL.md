---
name: pest-testing
description: >-
    Tests applications using the Pest 4 PHP framework. Activates when writing tests, creating unit or feature
    tests, adding assertions, testing Livewire components, browser testing, debugging test failures,
    working with datasets or mocking; or when the user mentions test, spec, TDD, expects, assertion,
    coverage, or needs to verify functionality works.
---

# Pest Testing 4

## When to Apply

Activate this skill when:

- Creating new tests (unit, feature, or browser)
- Modifying existing tests
- Debugging test failures
- Working with browser testing or smoke testing
- Writing architecture tests or visual regression tests

## Documentation

Use `search-docs` for detailed Pest 4 patterns and documentation.

### Creating Tests

All tests must be written using Pest. Use `php artisan make:test --pest {name}`.

### Basic Test Structure

```php
it('is true', function () {
    expect(true)
        ->toBeTrue();
});
```

The expect is on its own line with the actual expectations chained underneath.

### Running Tests

**Full test runs:** `php artisan test --parallel` (distributes across processes for speed)

**Quick iteration:** `php artisan test --compact --filter=testName`

Use `--parallel` for final verification before committing. Don't use `--parallel` for single files—it adds overhead with no benefit since tests in one file run in series.

**PAO output mode (Laravel 12+):** By default, test output is captured and shown as a compact JSON summary. If tests crash with no output or exit code 2, use `PAO_DISABLE=1 php artisan test ...` to get the raw PHP/Pest output and see the actual fatal error.

**Crashes without summary:** If the test run scrolls through green ticks then stops abruptly with no final summary and a non-zero exit code, a PHP fatal error likely killed the process mid-suite. This typically means a class definition error (e.g. extending a final class, interface method mismatch). Run `PAO_DISABLE=1 php -d display_errors=stderr vendor/bin/pest --filter=... 2>&1` on the affected test file to surface the actual fatal.

## Assertions

> See [references/assertions.md](references/assertions.md) for **essential** guidance on assertion chaining patterns.

Use specific assertions (`assertSuccessful()`, `assertNotFound()`) instead of `assertStatus()`:

```php
it('returns all', function () {
    $this->postJson('/api/docs', [])->assertSuccessful();
});
```

| Use                  | Instead of          |
| -------------------- | ------------------- |
| `assertSuccessful()` | `assertStatus(200)` |
| `assertNotFound()`   | `assertStatus(404)` |
| `assertForbidden()`  | `assertStatus(403)` |

### Higher-Order Expectations

When asserting multiple properties on an object, set the subject to the root object and use higher-order expectations:

```php
it('user has correct data', function () {
    $user = User::factory()->create(['name' => 'John', 'email' => 'john@example.com']);

    expect($user)
        ->name->toBe('John')
        ->email->toBe('john@example.com');
});
```

## Datasets

Use datasets for repetitive tests (validation rules, etc.):

```php
it('has emails', function (string $email) {
    expect($email)->not->toBeEmpty();
})->with([
    'james' => 'james@laravel.com',
    'taylor' => 'taylor@laravel.com',
]);
```

## Reference Files

- [Test Organization](references/test-organization.md) - Directory structure, feature vs unit tests
- [Assertions](references/assertions.md) - Chaining patterns and best practices
- [Deep Testing](references/deep-testing.md) - Testing with real dependencies, when to mock
- [Features](references/features.md) - Browser testing, smoke testing, architecture testing
- [Common Pitfalls](references/common-pitfalls.md) - What to avoid
