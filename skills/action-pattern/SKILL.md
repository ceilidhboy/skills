---
name: action-pattern
description: Creating and using action classes to encapsulate business logic. Actions replace traditional Service classes with reusable, composable, single-responsibility classes that follow a consistent `execute()` convention.
---

# Action Pattern

## Overview

The Action pattern encapsulates business logic into reusable, composable, single-responsibility classes. Actions replace traditional "Service" classes and provide a clean, testable way to organize application behavior.

## Core Principles

### 1. Single Responsibility Principle (SRP)

Each action should have **one reason to change**. If a class is doing multiple things, it should be split into multiple actions, not multiple methods within the same class.

**Key Question**: Does this action have more than one responsibility? If yes, split it into separate actions.

**Note**: This same principle applies to **tasks** in the task list. See [single-task-responsibility](../single-task-responsibility/SKILL.md) skill for guidance on recognizing when task implementation violates SRP and requires stopping to consult the user.

### 2. The `execute()` Method

Every action **must** have a public `execute()` method. This is the convention and must not be flexible.

- **Method signature**: Parameters and return type depend entirely on the action's functionality
- **Naming**: Always `execute()` — never `handle()`, `__invoke()`, or other alternatives
- **Statelessness**: The method should be callable multiple times with different parameters without side effects

### 3. Fixed Dependencies vs. Variable Parameters

Actions have two types of inputs:

**Fixed Dependencies** (Constructor Injection):

- Dependencies that don't change across calls
- Injected via the constructor
- Resolved automatically by Laravel's container
- Examples: other actions, services

**Variable Parameters** (Execute Method):

- Data that changes between calls
- Passed to the `execute()` method
- Enable the same action instance to be reused with different inputs
- Example: `BuildOpportunities` receives `$priceBreaks` as a parameter

```php
class BuildOpportunities
{
    // Fixed dependency: injected in constructor
    public function __construct(
        private FetchPropertiesForPriceBreak $fetchProperties,
        private MapPropertiesToOpportunities $mapToOpportunities,
    ) {}

    // Variable parameter: passed to execute()
    public function execute(array $priceBreaks): array
    {
        // Use both fixed dependencies and variable parameters
    }
}
```

### 4. Composability and Container Resolution

Actions are composable — they can depend on other actions:

- All fixed dependencies must be resolvable from Laravel's container by type alone
- Actions can depend on other actions via constructor injection
- **Avoid circular dependencies** — actions should form a directed acyclic graph
- The container automatically resolves dependencies; explicit instantiation is rarely needed

### 5. Statelessness and Readonly Classes

Actions must be **stateless**. They should not maintain instance properties that affect behavior across multiple `execute()` calls.

**Why**: If you create an action and call `execute()` twice with different parameters, the second call should not be affected by the first.

**Implementation**: Action classes should be declared as `readonly` since they are stateless and only hold immutable dependencies:

```php
final readonly class BuildOpportunities
{
    public function __construct(
        private FetchPropertiesForPriceBreak $fetchProperties,
        private MapPropertiesToOpportunities $mapToOpportunities,
    ) {}

    public function execute(array $priceBreaks): array
    {
        // ...
    }
}
```

The `readonly` keyword enforces immutability at the class level and makes the stateless nature explicit.

## When to Use the Action Pattern

Activate this skill when:

- **Extracting logic from controllers**: Business logic belongs in actions, not controllers
- **Creating new actions**: Ensure they follow the pattern correctly
- **Refactoring code that violates SRP**: If a class is doing multiple things, consider splitting it into multiple actions
- **Code is required by multiple parts of the application**: If behavior is needed in multiple places, extract it into an action

## Controller Integration

Controllers should delegate business logic to actions. Actions are injected into controller **methods**, not constructors, unless the action is used by **every** public method in the controller.

**Rule**: Only inject an action into the constructor if it's used by all public methods. Otherwise, inject it into the specific methods that need it.

```php
class HomeController extends Controller
{
    // ✅ Correct: Inject into the method that needs it
    public function index(BuildOpportunities $buildOpportunities)
    {
        $opportunities = $buildOpportunities->execute($priceBreaks);
        return Inertia::render('Home', ['opportunities' => $opportunities]);
    }

    // ❌ Incorrect: Don't inject into constructor unless used by ALL methods
    public function __construct(private BuildOpportunities $buildOpportunities) {}
}
```

## Anti-Patterns

### Anti-Pattern 1: Business Logic in Controllers

**Problem**: Controllers become fat, hard to test, and logic can't be reused.

```php
// ❌ Bad: Business logic in controller
public function index()
{
    $priceBreaks = [
        ['label' => 'Budget', 'breakPoint' => 100000],
        ['label' => 'Mid-Range', 'breakPoint' => 500000],
    ];

    // ... lots of business logic here ...
    $opportunities = [];
    foreach ($priceBreaks as $break) {
        $properties = Property::where('price', '>=', $break['breakPoint'] * 100)
                              ->orderBy('price')
                              ->take(3)
                              ->get();
        // ... more logic ...
        $opportunities[] = new OpportunityData(...);
    }

    return Inertia::render('Home', ['opportunities' => $opportunities]);
}

// ✅ Good: Delegate to action
public function index(BuildOpportunities $buildOpportunities)
{
    $priceBreaks = [
        ['label' => 'Budget', 'breakPoint' => 100000],
        ['label' => 'Mid-Range', 'breakPoint' => 500000],
    ];

    $opportunities = $buildOpportunities->execute($priceBreaks);
    return Inertia::render('Home', ['opportunities' => $opportunities]);
}
```

**Why it matters**: Testability, reusability, maintainability, and clean code aesthetics.

### Anti-Pattern 2: Classes Violating Single Responsibility Principle

**Problem**: A single class doing multiple unrelated things becomes hard to test, maintain, and extend.

```php
// ❌ Bad: Multiple responsibilities in one action
class BuildOpportunities
{
    public function execute(array $priceBreaks): array
    {
        // Responsibility 1: Fetch properties from database
        $properties = Property::where('price', '>=', $priceBreak['breakPoint'] * 100)
                              ->orderBy('price')
                              ->take(3)
                              ->get();

        // Responsibility 2: Map properties to DTOs
        return $properties->map(fn($p) => PropertyListingData::from($p))->all();
    }
}

// ✅ Good: Split into focused actions
class FetchPropertiesForPriceBreak
{
    public function execute(int $minPrice): Collection
    {
        return Property::where('price', '>=', $minPrice)
                       ->orderBy('price')
                       ->take(3)
                       ->get();
    }
}

class MapPropertiesToOpportunities
{
    public function execute(array $properties, string $label, int $minPrice): OpportunityData
    {
        return new OpportunityData(
            label: $label,
            minPrice: $minPrice,
            properties: array_map(fn($p) => PropertyListingData::from($p), $properties),
        );
    }
}

class BuildOpportunities
{
    public function __construct(
        private FetchPropertiesForPriceBreak $fetchProperties,
        private MapPropertiesToOpportunities $mapToOpportunities,
    ) {}

    public function execute(array $priceBreaks): array
    {
        return array_map(
            fn($break) => $this->mapToOpportunities->execute(
                $this->fetchProperties->execute($break['breakPoint'] * 100)->all(),
                $break['label'],
                $break['breakPoint'],
            ),
            $priceBreaks,
        );
    }
}
```

**Why it matters**: Extensibility, testability, and reusability. If another part of the application needs to fetch properties or map them to DTOs, those behaviors are now available as separate actions.

## Refactoring Journey

Action refactoring often happens in stages:

1. **Extract from controller**: Move business logic into an action (solves the "fat controller" problem)
2. **Identify multiple responsibilities**: Recognize that the action is doing more than one thing
3. **Split into focused actions**: Create separate actions for each responsibility
4. **Compose**: Have the original action depend on the new, focused actions

This approach allows you to improve code quality incrementally without requiring a complete rewrite.

## Testing Actions

Actions must be instantiated from the container in a `beforeEach` and assigned to `$this->action`:

```php
beforeEach(function () {
    $this->action = app(BuildOpportunities::class);
});

test('builds opportunities from price breaks', function () {
    $result = $this->action->execute($priceBreaks);
    // ...
});
```

Never use `new` on an action in a test, even if it has zero constructor dependencies — the test should match production usage, and a dependency may be added later. Per-test `app()` calls are reserved for rare cases where the test needs multiple distinct instances or injected mocks.

## Naming Conventions

Actions should be named with **verb or verb clauses** that describe what they do:

- `BuildOpportunities` — builds a list of opportunities
- `FetchPropertiesForPriceBreak` — fetches properties matching a price range
- `MapPropertiesToOpportunities` — maps property data to opportunity DTOs
- `SendWelcomeEmail` — sends a welcome email

While not a hard rule, this convention makes code intent immediately clear.
