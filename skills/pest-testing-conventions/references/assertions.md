## Pest Assertion Formatting

### `expect()` must be on its own line

The `expect()` call and its first assertion must be on **separate lines**. Never write `expect(...)->toBe(...)` on a single line.

```php
// Bad: expect() and assertion on same line
expect($response->status())->toBe(302);

// Good: expect() on its own line, assertions chain below
expect($response)
    ->status->toBe(302);
```

This applies even when there is only one assertion. The multi-line format makes it easy to add more assertions later without reformatting.

### Chain multiple assertions with `.and()`

When asserting on multiple values, use `.and()` to chain them on a single `expect()` call rather than separate `expect()` calls.

```php
// Bad: Multiple separate expect() calls
expect($response->status())->toBe(302);
expect($response->headers->get('Location'))->toContain('/dashboard');

// Good: Single expect() with chained assertions
expect($response)
    ->status->toBe(302)
    ->and($response->headers)
    ->get('Location')->toContain('/dashboard');
```

### With Inertia Assertions

```php
test('authenticated user can access dashboard', function () {
    $user = User::factory()->create();
    $response = $this->actingAs($user)->get('/dashboard');

    expect($response)
        ->status()->toBe(200)
        ->assertInertia(fn(Assert $page) => $page->component('Dashboard'));
});
```
