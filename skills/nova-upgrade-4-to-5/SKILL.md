---
name: nova-upgrade-4-to-5
description: >-
  Upgrade Laravel Nova from version 4 to 5. Use when the user asks to upgrade/migrate
  Nova 4 to 5, bump laravel/nova to ^5, or resolve Nova 5 breaking changes (Inertia 2,
  Fortify replacing laravel/ui, parent::register, api_middleware config, removed Place
  field, form-backend-validation removal, republishing assets/stubs).
---

# Upgrade Laravel Nova 4 → 5

Official guide: https://nova.laravel.com/docs/v5/upgrade

## Dependency baseline (Nova 5)

- PHP 8.1+
- Laravel Framework 10.34+ or 11.0+
- Inertia Laravel 1.3+ or 2.0+
- `laravel/ui` replaced by `laravel/fortify` v1.21+
- `doctrine/dbal` removed
- Client: Inertia Vue3 v2, Heroicons v2, Trix v2; removed `form-backend-validation` and
  `places.js`

## How to work through an upgrade

Start on a clean git branch with a passing test suite. Work the steps in order, then boot
Nova and click through your resources, lenses, actions, and custom tools.

## Step 1 — Update the Composer dependency

In `composer.json` set `laravel/nova` from `^4.0` to `^5.0`, then:

```bash
composer update mirrors
composer update
```

## Step 2 — Republish assets and translations

**Back up your current Nova translation file first** so you can port custom translations back.

```bash
php artisan vendor:publish --tag=nova-assets --force
php artisan vendor:publish --tag=nova-lang --force
```

Also update any third-party Nova tools/packages — they may need maintainer updates for Nova 5.

## Step 3 — Update authentication config & provider

In `config/nova.php`, ensure `api_middleware` reads:

```php
'api_middleware' => [
    'nova',
    \Laravel\Nova\Http\Middleware\Authenticate::class,
    // \Laravel\Nova\Http\Middleware\EnsureEmailIsVerified::class,
    \Laravel\Nova\Http\Middleware\Authorize::class,
],
```

In `app/Providers/NovaServiceProvider.php`, call the parent `register()` **first**:

```php
public function register(): void
{
    parent::register();

    //
}
```

(Nova 5 uses Fortify instead of `laravel/ui` for auth scaffolding.)

## Step 4 — Update custom components (tools, cards, fields, filters)

### Inertia 2
Nova's frontend now uses Inertia.js 2.x. Update imports in custom Vue components/packages:

```diff
-import { usePage } from '@inertiajs/inertia-vue3'
-import { Inertia } from '@inertiajs/inertia'
+import { router as Inertia, usePage } from '@inertiajs/vue3'
```
See Inertia's upgrade guide: https://inertiajs.com/upgrade-guide

### Replace `form-backend-validation`
It's archived. Import `Errors` from `laravel-nova` instead, then remove the package:

```diff
-import { Errors } from 'form-backend-validation'
+import { Errors } from 'laravel-nova'
```
```bash
npm remove form-backend-validation
```

## Step 5 — Other changes

- **Form abandonment warnings removed (Medium):** Inertia 2 no longer warns on browser
  back-button navigation away from a dirty form.
- **Algolia `Place` field removed (Medium):** the Algolia Places API was retired (2022); the
  deprecated `Place` field is gone in Nova 5. Replace with another field/geocoding approach.
- **Republish stubs (Low):** if you previously published Nova stubs, re-publish them:
  ```bash
  php artisan nova:stubs --force
  ```

## Step 6 — Verify

Boot the app, log into Nova, and exercise resource index/detail/forms, actions, filters,
lenses, and every custom tool/card/field. Confirm assets load (no stale Nova JS/CSS) and
that authentication still works under Fortify.
