---
name: laravel-upgrade-9-to-10
description: >-
  Upgrade a Laravel application from version 9.x to 10.x. Use when the user asks
  to upgrade/migrate Laravel 9 to 10, bump laravel/framework to ^10, or resolve
  Laravel 10 breaking changes (PHP 8.1, Composer 2.2, Monolog 3, removed $dates
  property, DB expressions getValue, removed dispatchNow, native types).
---

# Upgrade Laravel 9.x → 10.x

Official guide: https://laravel.com/docs/10.x/upgrade
Estimated time: ~10 minutes.

## How to work through an upgrade

1. Start on a clean git branch with a passing test suite.
2. Update `composer.json`, run `composer update`, then walk the changes below, testing as you go.
3. Run the test suite and boot the app at the end.

Laravel Shift (https://laravelshift.com/) can automate much of this.

## Prerequisites (High impact)

- **PHP 8.1.0+** required.
- **Composer 2.2.0+** required.

## Step 1 — Update dependencies (High impact)

In `composer.json`, set:

- `laravel/framework` → `^10.0`
- `laravel/sanctum` → `^3.2` (see Sanctum 3.x upgrade guide if coming from 2.x)
- `doctrine/dbal` → `^3.0` (if used)
- `spatie/laravel-ignition` → `^2.0`
- `laravel/passport` → `^11.0` (if used)
- `laravel/ui` → `^4.0` (if used)

For PHPUnit 10: remove `processUncoveredFiles` from the `<coverage>` section of `phpunit.xml`,
then set `nunomaduro/collision` → `^7.0` and `phpunit/phpunit` → `^10.0`.

Set `minimum-stability` to `stable` (or delete the line — `stable` is the default).

Run `composer update`, then verify all third-party packages support Laravel 10.

## Step 2 — Breaking changes

- **Eloquent `$dates` removed (Medium):** replace the `$dates` property with `$casts`:
  ```php
  protected $casts = ['deployed_at' => 'datetime'];
  ```
- **Monolog 3 (Medium):** Laravel now uses Monolog 3.x. If you interact with Monolog directly,
  review its upgrade guide. Upgrade logging integrations (Bugsnag, Rollbar, etc.) to
  Monolog-3-compatible versions.
- **Database expressions (Medium):** `DB::raw(...)` expressions can no longer be cast with
  `(string)`. Use `$expression->getValue(DB::connection()->getQueryGrammar())`.
- **Service mocking (Medium):** the `MocksApplicationServices` trait is removed
  (`expectsEvents`/`expectsJobs`/`expectsNotifications`). Migrate to `Event::fake()`,
  `Bus::fake()`, `Notification::fake()`.
- **Redis cache tags (Medium):** `Cache::tags()` is recommended only for Memcached. On Redis,
  consider Memcached (or note this was later addressed in Laravel 12.30.0).
- **`registerPolicies` (Low):** now auto-invoked — remove the manual call from
  `AuthServiceProvider::boot()`.
- **`Bus::dispatchNow` / `dispatch_now` removed (Low):** use `Bus::dispatchSync` /
  `dispatch_sync`.
- **`dispatch()` helper return (Low):** dispatching a non-`ShouldQueue` class now returns a
  `PendingBatch` instead of the `handle()` result. Use `dispatch_sync()` for the old behavior.
- **ULID columns (Low):** `$table->ulid()` with no args now creates a column named `ulid`
  (previously erroneously `uuid`). Pass a name explicitly to keep an existing column name.
- **RateLimiter::attempt return (Low):** now returns the closure's return value (or `true` if
  `null`/nothing returned).
- **Public path binding (Low):** replace binding `path.public` with
  `app()->usePublicPath(__DIR__.'/public')`.
- **`Redirect::home` removed (Very low):** use `Redirect::route('home')`.
- **QueryException constructor (Very low):** now takes the connection name as first argument.
- **Closure validation `$fail` (Very low):** calling `$fail` multiple times appends messages;
  `$fail` returns an object; to target another key use `$fail('key', 'message')`.
- **Form request `after` (Very low):** `after` is now reserved — rename custom `after` methods
  or adopt the new after-validation hook.

## Step 3 — Optional / structure

- Middleware aliases: in new apps `App\Http\Kernel::$routeMiddleware` was renamed to
  `$middlewareAliases`. Renaming is optional.
- The `lang` directory is no longer present by default in new apps; publish via
  `php artisan lang:publish` if you want the framework's translation files. Existing apps keep
  their `lang` directory.
- Native types: laravel/laravel adopted PHP native types throughout. These diffs are
  backwards-compatible and adopting them is optional.

## Step 4 — Verify

Run the full test suite (note PHPUnit 10), run `php artisan about`, boot the app, and exercise
logging, queued/dispatched jobs, and any DB::raw usage. Optionally diff against laravel/laravel:
https://github.com/laravel/laravel/compare/9.x...10.x
