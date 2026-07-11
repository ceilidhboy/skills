---
name: settings-system
description: Multi-tenant polymorphic settings system with agency-scoped records and global fallback chain. Create, read, update settings records. Use when working with App\Models\Setting, App\Enumerations\SettingType, the settings table migration, the polymorphic settings system, or the fallback chain (agency-specific → global default). Also use when integrating third-party services (Xero, Stripe, etc.) that need per-agency configuration storage.
author: Mike Scott
version: '1.0.0'
updated: '2026-07-11'
---

# Settings System

## Quick Start

```php
use App\Enumerations\SettingType;

// Create a settings record (globally, for the system agency)
Setting::create([
    'agency_id' => Agency::SystemAgencyId,
    'type' => SettingType::XeroIntegration,
    'data' => ['key' => encrypt('value')],
]);

// Read with fallback chain (agency → global)
$setting = Setting::forAgency($agencyId, SettingType::XeroIntegration);
$data = $setting?->data;
```

## Model

`App\Models\Setting` extends `TenantModel`. Key details:

- `data` column is JSON, cast to `array` on read
- `$guarded = []` — all fields mass-assignable
- `TenantModel` auto-populates `agency_id` on create via `AgencyScoping` trait (can override by explicitly setting it)

## Fallback Chain Resolution

Settings resolve in priority order, returning the first match:

1. **Agency-specific** (`agency_id` = current agency)
2. **Global default** (`agency_id` = `Agency::SystemAgencyId`, which is 1)

Use `Setting::forAgency($agencyId, $type)` for this. To query a specific level directly, use `scopeOfType()` and/or `scopeForAgency()`.

## Composite Unique Constraint

The migration enforces `unique(agency_id, type)` — one record per setting type per agency. Use `updateOrCreate()` for upsert scenarios:

```php
Setting::updateOrCreate(
    ['agency_id' => $agencyId, 'type' => SettingType::XeroIntegration],
    ['data' => $payload],
);
```

## Data Payload & Encryption

- Only **secrets** (`access_token`, `refresh_token`, API keys) are encrypted via Laravel's `encrypt()`/`decrypt()`
- Non-sensitive fields (`expires_at`, `connected_at`, tenant IDs) are plaintext
- The `data` JSON column stores everything together

## Adding a New Setting Type

1. Add case to `App\Enumerations\SettingType`
2. Create/update a settings record via the model — no schema changes needed

## Creating Global vs Agency-Specific Records

When creating via `Setting::create()`, the `AgencyScoping` trait auto-sets `agency_id` to the current tenant. To create a global record (agency 1), explicitly set the agency_id:

```php
Setting::create([
    'agency_id' => Agency::SystemAgencyId, // must be explicit
    'type' => SettingType::XeroIntegration,
    'data' => [...],
]);
```

## See Also

- `docs/WIP/Mike/settings-system.md` — detailed human-readable documentation
- `app/Models/Setting.php` — model with scopes and helpers
- `app/Enumerations/SettingType.php` — enum of available setting types
- `database/migrations/2026_05_15_000000_create_settings_table.php` — table schema
