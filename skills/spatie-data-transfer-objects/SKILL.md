---
name: spatie-data-transfer-objects
description: Creating and composing Spatie Laravel Data transfer objects for backend-to-frontend communication with automatic TypeScript type generation.
author: Mike Scott
version: '1.1.0'
updated: '2026-07-11'
---

# ⚠️ CRITICAL: Spatie Data Transfer Objects (DTOs)

## 🚨 FIRST THING: Generate TypeScript Types

**WHENEVER YOU CREATE OR MODIFY A DTO, YOU MUST RUN THIS COMMAND:**

```bash
php artisan typescript:transform
```

This is the **ONLY** correct way to generate TypeScript types from Spatie Data DTOs. Do NOT use npm build commands or other tools. This command must be run after any DTO changes to update `resources/js/types/generated.d.ts`.

---

## When to Activate This Skill

Activate this skill whenever you are:
- Creating or modifying data transfer objects in `app/Data/`
- Composing DTOs using the composition pattern
- Passing data from Laravel backend to Inertia React frontend
- Working with Spatie Laravel Data package
- Ensuring TypeScript types are automatically generated for frontend use

## What Are Data Transfer Objects?

DTOs are simple PHP classes that structure and transfer data from the backend to the frontend. They:
- Define the shape of data being passed to React components
- Automatically generate TypeScript types via the `#[TypeScript]` attribute
- Use composition to build complex data structures from simpler ones
- Provide type safety across the full stack (PHP → TypeScript)

## Directory Structure

Mirror the frontend component structure in the backend:

```
app/Data/
├── Dashboard/                    # Mirrors resources/js/components/dashboard/
│   ├── DashboardData.php
│   ├── JobStatisticsData.php
│   ├── ActionRequiredData.php
│   └── CampaignsData.php
├── Clients/                      # Mirrors resources/js/components/clients/
│   └── ClientData.php
├── AgencyData.php                # Root-level shared DTOs
└── ClientContactData.php
```

## Creating a DTO

### Basic Structure

```php
<?php

declare(strict_types=1);

namespace App\Data\Dashboard;

use Spatie\LaravelData\Data;
use Spatie\TypeScriptTransformer\Attributes\TypeScript;

#[TypeScript]
final class JobStatisticsData extends Data
{
    public function __construct(
        public int $totalJobs,
        public int $newWorkers,
        public int $campaigns,
        public int $overdueInvoices,
    ) {
    }
}
```

### Key Points

- **Namespace**: Organize by feature (e.g., `App\Data\Dashboard`)
- **`#[TypeScript]` Attribute**: Required for automatic TypeScript type generation
- **Constructor Property Promotion**: Use PHP 8 syntax for cleaner code
- **CamelCase Parameters**: Follow casing conventions (parameters use camelCase)
- **Type Hints**: Always include explicit types for all properties

## Composition Pattern

Build complex DTOs by composing simpler ones:

```php
#[TypeScript]
final class DashboardData extends Data
{
    public function __construct(
        public JobStatisticsData $jobStatistics,
        public ActionRequiredData $actionRequired,
        public CampaignsData $campaigns,
    ) {
    }
}
```

### Benefits

- **Modularity**: Each section has its own DTO
- **Reusability**: Smaller DTOs can be used in multiple places
- **Maintainability**: Changes to one section don't affect others
- **Scalability**: Easy to add new sections without modifying existing code

## Naming Conventions

- **Class Names**: PascalCase with "Data" suffix (e.g., `DashboardData`, `JobStatisticsData`)
- **Properties**: CamelCase (e.g., `totalJobs`, `newWorkers`)
- **Database Field Exception**: When properties represent database columns in Eloquent models, use snake_case to match the database (e.g., `first_name`, `email_address`)

## TypeScript Generation

The `#[TypeScript]` attribute marks DTOs for automatic TypeScript type generation. However, you must run the transformer command to generate the actual types:

```bash
php artisan typescript:transform
```

This command scans all DTOs with the `#[TypeScript]` attribute and generates corresponding TypeScript type definitions.

### Generated Types

After running the command, TypeScript types are automatically generated:

```typescript
// Generated automatically from JobStatisticsData.php
export type JobStatisticsData = {
    totalJobs: number;
    newWorkers: number;
    campaigns: number;
    overdueInvoices: number;
};

// Generated automatically from DashboardData.php
export type DashboardData = {
    jobStatistics: JobStatisticsData;
    actionRequired: ActionRequiredData;
    campaigns: CampaignsData;
};
```

These types are available in React components for type-safe data handling.

### Important: Caching and Verification

**Tool Caching Issue**: When viewing `resources/js/types/generated.d.ts` after running `php artisan typescript:transform`, the tool may display a cached version of the file that doesn't reflect the newly generated types. This is a caching issue in the viewing tool, not an actual problem with the generation.

**Verification Strategies**:

1. **Check Command Output**: Always verify that the command output shows your new type was transformed. For example:
   ```
   | App\Data\Dashboard\KeyPerformanceData | App.Data.Dashboard.KeyPerformanceData |
   ```
   If you see your new type in the output, it has been successfully generated.

2. **Ask User to Verify**: If you see the type in the command output but not in the viewed file, ask the user to check the actual file. They will see the correct, non-cached version.

3. **Run TypeScript Compiler**: Alternatively, run `npm run types` which executes `tsc --noEmit`. If your code references the new types and they exist, the compiler will succeed. If the types don't exist, you'll get TypeScript errors. This confirms whether the types were actually generated.

**Rule of Thumb**: Trust the command output over the viewed file. If the transformer output shows your type was transformed, it exists in the file even if the viewing tool shows an older version.

## Custom Factory Methods with `from*` Auto-Discovery

Spatie Laravel Data supports type-based auto-discovery of factory methods. When you call `Data::from($payload)`, the package inspects the payload type and routes to a matching `from*` static method.

### How It Works

Add a static method named `from{Type}()` on your Data class, where `{Type}` matches the PHP type of the payload. When `from()` is called with that type, the method is automatically invoked.

The most common case is `fromArray()` for raw array payloads:

```php
class ScreenData extends Data
{
    public function __construct(
        public string $id,
        public string $label,
        public string|null $name,
        public string $displayType,
        public string|null $dataSource,
        public string|null $videoUrl,
        public ScreenPositionData $position,
        public ScreenDimensionsData|null $dimensions,
    ) {}

    /**
     * Auto-called by `from()` when an array is passed.
     * Handles defaults, nested DTO construction, and nullable fields
     * that may be omitted from the source array.
     */
    public static function fromArray(array $config): self
    {
        return new self(
            id: $config['id'],
            label: $config['label'],
            name: $config['name'] ?? null,
            displayType: $config['displayType'] ?? 'carousel',
            dataSource: $config['dataSource'] ?? 'featured',
            videoUrl: $config['videoUrl'] ?? null,
            position: ScreenPositionData::from($config['position']),
            dimensions: isset($config['dimensions'])
                ? ScreenDimensionsData::from($config['dimensions'])
                : null,
        );
    }
}
```

### Benefits

- **Callers never need to know which factory method to use** — they just call `Data::from($anything)`
- **The Data class encapsulates its own construction logic** — no mapping code scattered across actions
- **Nested DTOs compose naturally** — use `from()` inside the factory for nested objects too
- **Nullable/missing fields are handled in one place** — defaults and null coalescing live on the Data class

### Example Usage

```php
// Caller doesn't need to know about fromArray:
$screen = ScreenData::from($rawConfigArray);

// If the payload is an Eloquent model instead, add fromModel():
$screen = ScreenData::from($eloquentModel);  // auto-routes to fromModel()
```

## Workflow

1. **Identify Data Needs**: Look at the frontend component and determine what data it needs
2. **Create DTOs**: Build DTOs that match the component structure
3. **Compose**: Use composition to build larger DTOs from smaller ones
4. **Generate Types**: The TypeScript transformer automatically creates matching types
5. **Use in Controller**: Return DTO instances from your controller/route
6. **Receive in React**: React components receive fully typed data
