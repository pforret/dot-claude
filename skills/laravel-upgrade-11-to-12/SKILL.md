---
name: laravel-upgrade-11-to-12
description: >-
  Upgrade a Laravel application from version 11.x to 12.x. Use when the user asks
  to upgrade/migrate Laravel 11 to 12, bump laravel/framework to ^12, or resolve
  Laravel 12 breaking changes (Carbon 3 required, HasUuids/UUIDv7, PHPUnit 11,
  Pest 3, image validation excluding SVG, local disk root path).
---

# Upgrade Laravel 11.x → 12.x

Official guide: https://laravel.com/docs/12.x/upgrade
Estimated time: ~5 minutes. This is a small release with few breaking changes.

## How to work through an upgrade

1. Start on a clean git branch with a passing test suite.
2. Update `composer.json`, run `composer update`, then walk the changes below, testing as you go.
3. Run the test suite and boot the app at the end.

Laravel Shift (https://laravelshift.com/) can automate much of this.

## Step 1 — Update dependencies (High impact)

In `composer.json`, set:

- `laravel/framework` → `^12.0`
- `phpunit/phpunit` → `^11.0`
- `pestphp/pest` → `^3.0` (if used)

Run `composer update`.

If you use the global Laravel installer, run `composer global update laravel/installer`.
If installed via php.new or Herd, re-run the php.new command or update Herd.

## Step 2 — Breaking changes

- **Carbon 3 required (Low):** Carbon 2.x support is removed; all Laravel 12 apps require
  Carbon 3.x. Note `diffIn*` now returns floats and may be negative (direction-aware).
- **HasUuids → UUIDv7 (Medium):** the `HasUuids` trait now generates UUIDv7 (ordered) values.
  To keep ordered UUIDv4, alias the v4 trait:
  ```php
  use Illuminate\Database\Eloquent\Concerns\HasVersion4Uuids as HasUuids;
  ```
  The `HasVersion7Uuids` trait was removed — use `HasUuids` instead (same behavior).
- **Image validation excludes SVG (Low):** the `image` rule no longer allows SVGs. Allow them
  explicitly: `'photo' => 'required|image:allow_svg'` or
  `['required', File::image(allowSvg: true)]`.
- **Local disk root path (Low):** if you don't explicitly define a `local` disk,
  `Storage::disk('local')` now defaults its root to `storage/app/private` (was `storage/app`).
  To restore, define the `local` disk with the old root in `config/filesystems.php`.
- **Concurrency result index mapping (Low):** `Concurrency::run()` with an associative array
  now returns results keyed by the same keys.
- **Container respects nullable class defaults (Low):** resolving a class with a
  `?Type $x = null` constructor property now yields `null` instead of an auto-resolved instance.
- **Nested array request merging (Low):** `$request->mergeIfMissing()` now supports dot-notation
  nested keys instead of creating a literal top-level dotted key.
- **Multi-schema inspecting (Low):** `Schema::getTables()/getViews()/getTypes()` include all
  schemas by default; pass `schema:` to scope. `Schema::getTableListing()` now returns
  schema-qualified names (pass `schemaQualified: false` for old behavior). `db:table`/`db:show`
  now show all schemas on MySQL/MariaDB/SQLite too.
- **Route precedence (Low):** with duplicate route names, uncached routing now matches the
  FIRST registered route (now consistent with cached routing).
- **DatabaseTokenRepository constructor (Very low):** `$expires` is now in seconds, not minutes.
- **Database constructor signatures (Very low — package maintainers):** `Blueprint` and
  `Grammar` constructors now require a `Connection`. `Grammar::setConnection()`,
  `Connection::withTablePrefix()` removed; `Grammar::get/setTablePrefix()`,
  `Blueprint::getPrefix()` deprecated. Get prefix via `$connection->getTablePrefix()`.

## Step 3 — Verify

Run the full test suite (note PHPUnit 11 / Pest 3), run `php artisan about`, boot the app,
and exercise any UUID models, file uploads (SVG), and `local` disk reads/writes.
Optionally diff against laravel/laravel:
https://github.com/laravel/laravel/compare/11.x...12.x
