---
name: laravel-upgrade-10-to-11
description: >-
  Upgrade a Laravel application from version 10.x to 11.x. Use when the user asks
  to upgrade/migrate Laravel 10 to 11, bump laravel/framework to ^11, or resolve
  Laravel 11 breaking changes (PHP 8.2, modifying columns, float/double types,
  Sanctum 4, published package migrations, Carbon 3, per-second rate limiting).
---

# Upgrade Laravel 10.x → 11.x

Official guide: https://laravel.com/docs/11.x/upgrade
Estimated time: ~15 minutes. Most breaking changes affect only a portion of apps.

## How to work through an upgrade

1. Ensure the project is on a clean git branch and the test suite passes BEFORE starting.
2. Confirm prerequisites, then update `composer.json`, run `composer update`, then walk the
   breaking changes below in order, running tests after each meaningful change.
3. Run `php artisan test` (or `vendor/bin/phpunit`/`pest`) and boot the app at the end.

A community tool, Laravel Shift (https://laravelshift.com/), can automate much of this.

## Prerequisites (High impact)

- **PHP 8.2.0+** is now required. Check `php -v` and `composer.json` `require.php`.
- **curl 7.34.0+** required for the HTTP client.
- **SQLite 3.26.0+** required if using SQLite.

## Step 1 — Update dependencies (High impact)

In `composer.json`, set:

- `laravel/framework` → `^11.0`
- `nunomaduro/collision` → `^8.1`

Update these only if installed:

- `laravel/breeze` → `^2.0`
- `laravel/cashier` → `^15.0`
- `laravel/dusk` → `^8.0`
- `laravel/jetstream` → `^5.0`
- `laravel/octane` → `^2.3`
- `laravel/passport` → `^12.0`
- `laravel/sanctum` → `^4.0`
- `laravel/scout` → `^10.0`
- `laravel/spark-stripe` → `^5.0`
- `laravel/telescope` → `^5.0`
- `livewire/livewire` → `^3.4`
- `inertiajs/inertia-laravel` → `^1.0`

Then run `composer update`.

Remove `doctrine/dbal` if present — Laravel no longer depends on it.
Remove `spatie/once` if present — Laravel 11 ships its own `once()` helper (Medium impact: conflict).

If the Laravel installer is installed globally: `composer global require laravel/installer:^5.6`.

### Published package migrations (High impact)

Cashier Stripe, Passport, Sanctum, Spark Stripe and Telescope **no longer auto-load their
own migrations**. For each installed package, publish migrations:

```bash
php artisan vendor:publish --tag=cashier-migrations
php artisan vendor:publish --tag=passport-migrations
php artisan vendor:publish --tag=sanctum-migrations
php artisan vendor:publish --tag=spark-migrations
php artisan vendor:publish --tag=telescope-migrations
```

## Step 2 — Application structure (do NOT migrate)

Laravel 11 introduces a slimmer skeleton (fewer providers/middleware/config files).
**Do not** convert a Laravel 10 app to the new structure — Laravel 11 fully supports the
Laravel 10 structure. Leave `app/Http/Kernel.php`, `app/Console/Kernel.php`, providers, etc. as-is.

## Step 3 — Database / migrations (High impact)

### Modifying columns
When using `->change()`, you must now re-declare **every** modifier to keep
(`unsigned`, `default`, `comment`, etc.) — missing ones are dropped.

```php
// keep existing attributes AND add nullable:
$table->integer('votes')->unsigned()->default(1)->comment('The vote count')->nullable()->change();
```
`change()` does not touch indexes; add/drop indexes explicitly via index modifiers.
To avoid auditing every old change migration, squash with `php artisan schema:dump`.

### Floating-point types
`double`/`float` rewritten. Drop `$total`/`$places` args:

```php
$table->double('amount');
$table->float('amount', precision: 53);
```
`unsignedDecimal`/`unsignedDouble`/`unsignedFloat` removed — chain `->unsigned()` instead.

### Other (lower impact)
- Spatial types: replace `point`/`lineString`/`polygon`/etc. with `geometry()`/`geography()`.
- MariaDB: optionally switch the connection `driver` to `mariadb`. If you do and used the
  `uuid()` schema method, change it to `char('uuid', 36)` to avoid native-UUID breakage.
- Doctrine DBAL classes/methods removed — use native `Schema::getTables()/getColumns()/
  getIndexes()/getForeignKeys()`. Deprecated `getAllTables/Views/Types` removed.

## Step 4 — Other breaking changes

- **Sanctum 4 (High):** after publishing migrations, update `config/sanctum.php` middleware
  references to `Laravel\Sanctum\Http\Middleware\AuthenticateSession`,
  `Illuminate\Cookie\Middleware\EncryptCookies`,
  `Illuminate\Foundation\Http\Middleware\ValidateCsrfToken`.
- **Passport 12 (High):** password grant is disabled by default. Re-enable via
  `Passport::enablePasswordGrant()` in `AppServiceProvider::boot()` if needed.
- **Carbon 3 (Medium):** Laravel 11 supports Carbon 2 and 3. If upgrading to Carbon 3,
  `diffIn*` methods now return floats and may be negative (direction-aware). Audit date math.
- **Per-second rate limiting (Medium):** `Limit`/`GlobalLimit`/`ThrottlesExceptions[WithRedis]`
  constructors now take seconds, not minutes. `Limit::decayMinutes` → `decaySeconds`.
  Documented static constructors (`Limit::perMinute`, `perSecond`) are unaffected.
- **Password rehashing (Low):** passwords auto-rehash on login when work factor changes. If
  the password column isn't named `password`, set `$authPasswordName` on the User model, or
  disable with `'rehash_on_login' => false` in `config/hashing.php`.
- **Cache prefixes (Very low):** Redis/Memcached/DynamoDB prefixes no longer get a `:` suffix.
  Append `:` manually to preserve old keys.
- **Contracts gained methods (Low/Very low):** if you implement them, add the new methods —
  `UserProvider::rehashPasswordIfRequired`, `Authenticatable::getAuthPasswordName`,
  `Enumerable::dump(...$args)`, `Mailer::sendNow`, `BatchRepository::rollBack`,
  `ConnectionInterface::scalar`.
- **Synchronous jobs (Very low):** `sync` driver jobs now respect `after_commit`.
- **Eloquent `casts` method (Low):** base model now defines a `casts()` method; rename any
  model relation accidentally named `casts`.

## Step 5 — Verify

Run the full test suite, run `php artisan about`, boot the app, exercise auth and any
package (Sanctum/Passport/Cashier/Telescope) touched above. Optionally diff against
laravel/laravel: https://github.com/laravel/laravel/compare/10.x...11.x
