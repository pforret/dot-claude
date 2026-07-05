---
name: laravel-upgrade-12-to-13
description: >-
  Upgrade a Laravel application from version 12.x to 13.x. Use when the user asks
  to upgrade/migrate Laravel 12 to 13, bump laravel/framework to ^13, or resolve
  Laravel 13 breaking changes (PreventRequestForgery/CSRF rename, PHPUnit 12,
  Pest 4, Tinker 3, cache serializable_classes, UUIDv7, cache/session prefixes).
---

# Upgrade Laravel 12.x → 13.x

Official guide: https://laravel.com/docs/13.x/upgrade
Estimated time: ~10 minutes.

## How to work through an upgrade

1. Start on a clean git branch with a passing test suite.
2. Update `composer.json`, run `composer update`, then walk the changes below, testing as you go.
3. Run the test suite and boot the app at the end.

### Optional: automate with Laravel Boost (AI)
Laravel Boost (`^2.0`) is a first-party MCP server. Once installed in a Laravel 12 app, run
the `/upgrade-laravel-v13` slash command in Claude Code (or Cursor/VS Code/etc.) for a guided
upgrade. Laravel Shift (https://laravelshift.com/) is another option.

## Step 1 — Update dependencies (High impact)

In `composer.json`, set:

- `laravel/framework` → `^13.0`
- `laravel/boost` → `^2.0`
- `laravel/tinker` → `^3.0`
- `phpunit/phpunit` → `^12.0`
- `pestphp/pest` → `^4.0` (if used)

Run `composer update`. Update the global installer with `composer global update laravel/installer`
(or update Herd).

## Step 2 — High-impact breaking changes

- **CSRF middleware renamed → `PreventRequestForgery` (High):** `VerifyCsrfToken` is now
  `Illuminate\Foundation\Http\Middleware\PreventRequestForgery`, which also verifies request
  origin via the `Sec-Fetch-Site` header. `VerifyCsrfToken`/`ValidateCsrfToken` remain as
  deprecated aliases, but update direct references — especially middleware exclusions in tests
  and routes:
  ```php
  use Illuminate\Foundation\Http\Middleware\PreventRequestForgery;
  ->withoutMiddleware([PreventRequestForgery::class]);
  ```
  The config API also exposes `preventRequestForgery(...)`.

## Step 3 — Medium-impact changes

- **Cache `serializable_classes` (Medium):** the default `cache` config now sets
  `serializable_classes => false` to harden unserialization against gadget-chain attacks. If
  you cache PHP objects, allow-list the classes:
  ```php
  'serializable_classes' => [App\Data\CachedDashboardStats::class],
  ```
  Otherwise migrate object payloads to arrays.
- **`upsert` with MySQL/MariaDB (Medium):** an empty `uniqueBy` now throws
  `InvalidArgumentException` (even though MySQL/MariaDB ignore the value). Always pass a
  non-empty `uniqueBy`.

## Step 4 — Low-impact changes

- **Cache/session prefix defaults (Low):** framework-level fallback prefixes now use hyphens
  (`-cache-`, `-database-`, `-session`) and no longer slug with `_`. If you rely on generated
  defaults, set `CACHE_PREFIX`, `REDIS_PREFIX`, `SESSION_COOKIE` explicitly to keep old keys.
- **Collection model serialization (Low):** deserialized model collections now restore
  eager-loaded relations (e.g. in queued jobs).
- **`Container::call` nullable defaults (Low):** now returns `null` for unbound
  `?Type $x = null` params, matching constructor injection.
- **Domain route precedence (Low):** routes with an explicit domain now match before
  non-domain routes.
- **`JobAttempted` event (Low):** `$exceptionOccurred` (bool) replaced by `$exception`
  (object or `null`).
- **`QueueBusy` event (Low):** `$connection` renamed to `$connectionName`.
- **Manager `extend` binding (Low):** custom driver closures are now bound to the manager
  instance; capture other objects via `use (...)`.
- **MySQL `DELETE` with JOIN+ORDER BY+LIMIT (Low):** these clauses are now compiled and may
  throw `QueryException` on engines that don't support the syntax (previously silently ignored).
- **Pagination Bootstrap view names (Low):** `pagination::default` →
  `pagination::bootstrap-3`, `pagination::simple-default` → `pagination::simple-bootstrap-3`.
- **Polymorphic pivot table names (Low):** custom morph pivot classes now infer pluralized
  table names; set `$table` explicitly on the pivot if you relied on singular names.
- **`Str` factories reset between tests (Low):** custom UUID/ULID/random factories no longer
  persist across tests — set them per test/setup.
- **Symfony PHP 8.5 polyfill (Low):** adds global `array_first()`/`array_last()` on PHP < 8.5,
  which can conflict with `laravel/helpers` or custom helpers. Prefer `Arr::first()`/`Arr::last()`.

## Step 5 — Very-low-impact / contracts

If you implement these contracts, add the new methods: `Cache\Store::touch($key,$seconds)`,
`Bus\Dispatcher::dispatchAfterResponse`, `Routing\ResponseFactory::eventStream`,
`Auth\MustVerifyEmail::markEmailAsUnverified`, `Queue\Queue::{pendingSize, delayedSize,
reservedSize, creationTimeOfOldestPendingJob}`. Also: HTTP `Response::throw/throwIf` signatures
now declare `$callback`; default password-reset subject is now "Reset your password"; queued
notifications respect `#[DeleteWhenMissingModels]`; instantiating a model during its own
booting throws `LogicException`; `Js::from` uses `JSON_UNESCAPED_UNICODE`;
`withScheduling()` registration is deferred until `Schedule` resolves.

## Step 6 — Verify

Run the full test suite (PHPUnit 12 / Pest 4), run `php artisan about`, boot the app, and
test CSRF-protected forms/POST routes, cached objects, and any `upsert` calls. Optionally diff
against laravel/laravel: https://github.com/laravel/laravel/compare/12.x...13.x
