# When to Mock

Mock at **system boundaries** only:

- External APIs (payment, email, etc.)
- Databases (sometimes - prefer test DB)
- Time/randomness
- File system (sometimes)

Don't mock:

- Your own classes/modules
- Internal collaborators
- Anything you control

## Designing for Mockability

At system boundaries, design interfaces that are easy to mock:

**1. Use dependency injection**

Pass external dependencies in rather than creating them internally:

```php
// Easy to mock
class ProcessPaymentAction
{
    public function __construct(private PaymentGateway $gateway) {}

    public function execute(Order $order): PaymentResult
    {
        return $this->gateway->charge($order->total);
    }
}

// Hard to mock
class ProcessPaymentAction
{
    public function execute(Order $order): PaymentResult
    {
        $gateway = new StripeGateway(config('stripe.key'));
        return $gateway->charge($order->total);
    }
}
```

**2. Use Laravel's facade faking at system boundaries**

For external services, use Laravel's built-in faking system instead of mocking:

```php
// GOOD: Use Laravel's facade faking
test('sends confirmation email on order', function () {
    Mail::fake();

    $order = Order::factory()->create();
    (new ProcessOrderAction())->execute($order);

    Mail::assertSent(OrderConfirmation::class, function ($mail) use ($order) {
        return $mail->hasTo($order->customer->email);
    });
});

// GOOD: Queue faking
test('queues pdf generation job', function () {
    Queue::fake();

    $property = Property::factory()->create();
    (new GeneratePropertyPdf())->execute($property, 'en');

    Queue::assertPushed(CreatePdfJob::class);
});
```

**3. Mock external interfaces with Prophecy**

When you need to mock a concrete class or interface, use Prophecy:

```php
// GOOD: Mock external payment gateway
test('processes payment with stripe', function () {
    $gateway = $this->prophesize(PaymentGateway::class);
    $gateway->charge(100)
            ->willReturn(new PaymentResult('success'));

    $action = new ProcessPaymentAction($gateway->reveal());
    $result = $action->execute(Order::factory()->create(['total' => 100]));

    expect($result->status)
        ->toBe('success');
        
    $gateway->charge(100)
            ->shouldHaveBeenCalled();
});
```

**4. Prefer specific interfaces over generic ones**

Create specific interfaces for each external operation instead of one generic interface with conditional logic:

```php
// GOOD: Each interface is independently mockable
interface UserRepository
{
    public function findById(int $id): User|null;
    public function findByEmail(string $email): User|null;
    public function create(array $data): User;
}

// BAD: Mocking requires conditional logic inside the mock
interface Repository
{
    public function query(string $operation, array $params): mixed;
}
```

The specific interface approach means:
- Each mock returns one specific shape
- No conditional logic in test setup
- Easier to see which operations a test exercises
- Type safety per operation
