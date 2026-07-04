# Good and Bad Tests

## Good Tests

**Integration-style**: Test through real interfaces, not mocks of internal parts.

```php
// GOOD: Tests observable behaviour and uses project's coding style
test('user can checkout with valid cart', function () {
    $cart = Cart::factory()
                ->create();
                
    $cart->addItem(
        Product::factory()
               ->create()
    );

    $result = new CheckoutAction()->execute($cart, PaymentMethod::Stripe);

    expect($result->status)
        ->toBe('confirmed');
});
```

Characteristics:

- Tests behaviour users/callers care about
- Uses public API only
- Survives internal refactors
- Describes WHAT, not HOW
- One logical assertion per test

## Bad Tests

**Implementation-detail tests**: Coupled to internal structure.

```php
// BAD: Tests implementation details, doesn't follow project's coding style
test('checkout calls payment service process', function () {
    $mockPayment = $this->prophesize(PaymentService::class);
    $mockPayment->process(Argument::any())->shouldBeCalled();

    $cart = Cart::factory()->create();
    new (CheckoutAction($mockPayment->reveal()))->execute($cart, PaymentMethod::Stripe);
});
```

Red flags:

- Mocking internal collaborators
- Testing private methods
- Asserting on call counts/order
- Test breaks when refactoring without behavior change
- Test name describes HOW not WHAT
- Verifying through external means instead of interface

```php
// BAD: Bypasses interface to verify, ignores project's coding style
test('create user saves to database', function () {
    (new CreateUserAction())->execute(['name' => 'Alice']);

    $row = DB::table('users')->where('name', 'Alice')->first();
    expect($row)->not->toBeNull();
});

// GOOD: Verifies through interface, uses project's coding style
test('create user makes user retrievable', function () {
    $user = new CreateUserAction()->execute(['name' => 'Alice']);

    $retrieved = new GetUserAction()->execute($user->id);
    expect($retrieved->name)
        ->toBe('Alice');
});
```
