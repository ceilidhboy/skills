# Deep Testing Approach

This project uses **deep testing** with real dependencies wherever possible and reasonable. This means:

- ✅ **Test through real interfaces** - Use actual models, actions, and dependencies
- ✅ **Use factories to create real data** - Don't mock database records
- ✅ **Test observable behavior** - Verify what the system does, not how it does it
- ❌ **Avoid mocking internal dependencies** - Don't mock your own classes or internal collaborators

**Why deep testing?**

- Catches real integration issues early
- Tests survive refactoring because they test behavior, not implementation
- Simpler to write (no complex mock setup)
- More confidence in the code

**When to mock:**

- Only at **system boundaries**: external APIs, time/randomness, file system operations
- Use Laravel's facade faking: `Mail::fake()`, `Storage::fake()`, `Queue::fake()`
- Use Prophecy for external interfaces you don't control

## Mocking

Import mock function before use: `use function Pest\Laravel\mock;`

See the [tdd skill](../../tdd/SKILL.md) for detailed guidance on mocking and deep modules.
