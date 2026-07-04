# Pest 4 Features

| Feature              | Purpose                                 |
| -------------------- | --------------------------------------- |
| Browser Testing      | Full integration tests in real browsers |
| Smoke Testing        | Validate multiple pages quickly         |
| Visual Regression    | Compare screenshots for visual changes  |
| Test Sharding        | Parallel CI runs                        |
| Architecture Testing | Enforce code conventions                |

## Browser Testing

Browser tests run in real browsers for full integration testing:

- Browser tests live in `tests/Browser/`
- Use Laravel features like `Event::fake()`, `assertAuthenticated()`, and model factories
- Use `RefreshDatabase` for clean database state per test
- Interact with page: click, type, scroll, select, submit, drag-and-drop, touch gestures
- Test on multiple browsers (Chrome, Firefox, Safari) if requested
- Test on different devices/viewports (iPhone 14 Pro, tablets) if requested
- Switch color schemes (light/dark mode) when appropriate
- Take screenshots or pause tests for debugging

## Smoke Testing

Quickly validate multiple pages have no JavaScript errors:

```php
$pages = visit(['/', '/about', '/contact']);

$pages->assertNoJavaScriptErrors()->assertNoConsoleLogs();
```

## Visual Regression Testing

Capture and compare screenshots to detect visual changes.

## Test Sharding

Split tests across parallel processes for faster CI runs.

## Architecture Testing

Pest 4 includes architecture testing (from Pest 3):

```php
arch('controllers')
    ->expect('App\Http\Controllers')
    ->toExtendNothing()
    ->toHaveSuffix('Controller');
```
