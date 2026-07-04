---
name: refactor-comments-that-are-code-smells
description: Scans code for comments that explain what code does and refactors them using the action pattern or extracting to methods. Use after writing or editing any code.
---

# Refactor Comments That Are Code Smells

## Detection

A comment is a code smell when it:
- Explains what the next code block does (`// Get authenticator...`)
- Is a numbered list (`// 1. Do this, // 2. Do that`)
- Explains complex logic that should be extracted

## Refactoring

### Primary: Split into Actions

Follow the action-pattern skill. Split methods into single-responsibility actions:

```php
// Before: one method with code-smell comments
public function execute(Client $client): array  // Returns Contact
{
    // 1. Search for existing contact
    $connector = ...;
    $response = $connector->send(new GetContactsRequest(...));
    if ($contacts) return $contacts[0];

    // 2. Create new contact
    $response = $connector->send(new CreateContactRequest([...]));
    return $response->json('Contacts')[0];
}

// After: separate actions
final readonly class SearchXeroContactByName
{
    public function __construct(private GetAuthenticatedApiConnector $getConnector) {}
    public function execute(Client $client): ?array  // Returns Contact
    {
        $connector = $this->getConnector->execute();
        $response = $connector->send(new GetContactsRequest(...));
        return $response->json('Contacts')[0] ?? null;
    }
}

final readonly class CreateXeroContact
{
    public function __construct(private GetAuthenticatedApiConnector $getConnector) {}
    public function execute(Client $client): array  // Returns Contact
    {
        $connector = $this->getConnector->execute();
        $response = $connector->send(new CreateContactRequest([...]));
        return $response->json('Contacts')[0];
    }
}

final readonly class FindOrCreateXeroContact
{
    public function __construct(
        private SearchXeroContactByName $search,
        private CreateXeroContact $create,
    ) {}

    public function execute(Client $client): array  // Returns Contact
    {
        return $this->search->execute($client)
            ?? $this->create->execute($client);
    }
}
```

### Secondary: Extract to Methods

If not reusable, extract to private methods with semantic names:

```php
// Before
$discount = $total > 100 ? 0.10 : ($total > 50 ? 0.05 : 0);

// After
private function calculateDiscount(int $total): float { ... }
```

## Workflow

1. Detect code-smell comments
2. Choose approach (actions or methods)
3. Propose refactoring to user — reference the action-pattern skill
4. Get explicit approval before making changes
5. Apply refactoring
6. Verify tests pass

## Action Pattern Reference

This skill works with the action-pattern skill. When refactoring to actions:
- Each action: one responsibility
- Use `final readonly class`
- Constructor injection for dependencies
- Public `execute()` method
- Actions compose via constructor injection

## What NOT to Refactor

- PHPDoc blocks (documentation, not explanation)
- TODO comments (acceptable)
- Test explanations (test intent)
- Config comments (e.g., `// seconds`)
