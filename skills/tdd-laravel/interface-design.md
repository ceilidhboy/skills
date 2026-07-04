# Interface Design for Testability

Good interfaces make testing natural:

1. **Accept dependencies, don't create them**

   Use constructor injection with property promotion:

   ```php
   // Testable
   class ProcessOrderAction
   {
       public function __construct(private PaymentGateway $gateway) {}

       public function execute(Order $order): PaymentResult
       {
           return $this->gateway->charge($order->total);
       }
   }

   // Hard to test
   class ProcessOrderAction
   {
       public function execute(Order $order): PaymentResult
       {
           $gateway = new StripeGateway(config('stripe.key'));
           return $gateway->charge($order->total);
       }
   }
   ```

2. **Return results, don't produce side effects**

   Return computed values instead of mutating state:

   ```php
   // Testable
   class CalculateDiscountAction
   {
       public function execute(Cart $cart): Discount
       {
           return new Discount($cart->total * 0.1);
       }
   }

   // Hard to test
   class ApplyDiscountAction
   {
       public function execute(Cart $cart): void
       {
           $cart->total -= $cart->total * 0.1;
       }
   }
   ```

3. **Small surface area**
   - Fewer public methods = fewer tests needed
   - Fewer parameters = simpler test setup
   - Single responsibility = focused tests
