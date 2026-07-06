# Test Organization

## Directory Structure

- Unit/Feature tests: `tests/Feature` and `tests/Unit` directories
- Browser tests: `tests/Browser/` directory
- Do NOT remove tests without approval - these are core application code

## ⚠️ CRITICAL: Feature Tests Required for Laravel Application Code

**Any test that depends on Eloquent models, facades, or the Laravel application container MUST be a Feature test, not a Unit test.**

The Laravel application is not loaded in Unit tests. Therefore:

- ❌ **Unit tests cannot use**: Eloquent models, facades (Mail, Storage, Queue, etc.), the service container, or any Laravel features
- ✅ **Feature tests can use**: Everything in the application, including models, facades, and the container

**Rule**: If your test uses `Property::factory()`, `app()`, `Storage::`, `Mail::`, or any other Laravel feature, it must be in `tests/Feature/`, not `tests/Unit/`.

The `tests/Pest.php` configuration automatically applies `RefreshDatabase` to all Feature tests, ensuring a clean database state for each test.
