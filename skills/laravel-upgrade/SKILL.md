---
name: laravel-upgrade
description: >-
  Upgrade a Laravel application across major versions (9 → 10 → 11 → 12 → 13) and/or
  Laravel Nova from 4 to 5, one hop at a time with tests and a commit checkpoint per hop.
  Use when the user asks to upgrade/migrate Laravel (e.g. "upgrade Laravel 10 to 11",
  "go to Laravel 13"), bump laravel/framework or laravel/nova, upgrade Nova 4 to 5, or
  resolve breaking changes such as PHP 8.1/8.2 requirements, Monolog 3, removed $dates,
  dispatchNow, modifying columns, float/double types, Sanctum 4, published package
  migrations, Carbon 3, per-second rate limiting, HasUuids/UUIDv7, PHPUnit 10/11/12,
  Pest 3/4, image rule excluding SVG, PreventRequestForgery (CSRF rename), cache
  serializable_classes, Nova Inertia 2, Fortify replacing laravel/ui, removed Place field.
---

# Upgrade Laravel (9 → 13) and Laravel Nova (4 → 5)

This skill routes the upgrade. The breaking changes for each hop live in `references/`;
read only the files for the hops you will actually run.

## 1. Detect versions

Read the **installed** versions (from `composer.lock`), not the `composer.json` constraints:

```bash
composer show laravel/framework laravel/nova 2>/dev/null | grep -E '^(name|versions)'
php -v | head -1
```

- Laravel below 9 or above 13, or Nova below 4: out of scope. Say so and stop.
- **Target**: what the user asked for. If they didn't say, ask: next major only, or latest (13)?
- If the user only asked for Nova, check that Laravel is ≥ 10.34 first. If not, offer the
  Laravel hop(s) first.

## 2. Plan the hops

| Hop | Reference | Official guide | Min PHP |
|-----|-----------|----------------|---------|
| Laravel 9 → 10 | `references/laravel-9-to-10.md` | https://laravel.com/docs/10.x/upgrade | 8.1 |
| Laravel 10 → 11 | `references/laravel-10-to-11.md` | https://laravel.com/docs/11.x/upgrade | 8.2 |
| Laravel 11 → 12 | `references/laravel-11-to-12.md` | https://laravel.com/docs/12.x/upgrade | 8.2 |
| Laravel 12 → 13 | `references/laravel-12-to-13.md` | https://laravel.com/docs/13.x/upgrade | 8.3 ¹ |
| Nova 4 → 5 | `references/nova-4-to-5.md` | https://nova.laravel.com/docs/v5/upgrade | 8.1 |

¹ Not stated in the upgrade guide. Confirm with `composer why-not laravel/framework ^13.0`
(it reports the PHP constraint) before starting.

**Placing Nova 4 → 5** (only when `laravel/nova` ^4 is installed):

- Nova 5 supports Laravel 10.34+ through 13.x. Nova 4's upper bound is believed to be
  Laravel 11, but that is unconfirmed. Check it with
  `composer why-not laravel/framework ^<next-major>.0` before every Laravel hop.
- Run the Nova hop as soon as Laravel is ≥ 10.34. Coming from 9, that means right after the
  9 → 10 hop plus `composer update laravel/framework` to the latest 10.x.
- It must run before any 11 → 12 hop, and before 10 → 11 if `why-not` shows Nova 4 blocks
  Laravel 11.

Show the user the ordered hop list (e.g. `9→10, Nova 4→5, 10→11, 11→12`) before starting,
and check that the PHP version available covers the final target.

## 3. Before starting

- Clean git working tree, ideally on a dedicated branch (`git switch -c upgrade/laravel-<target>`).
- The test suite passes **before** you change anything. Note any pre-existing failures.
- Third-party packages: run `composer outdated --direct` to spot packages that will need a
  major bump along the way.
- Laravel Shift (https://laravelshift.com/) can automate much of a Laravel hop. Mention it
  once; don't depend on it.

## 4. For each hop, in order

1. **Read** the hop's reference file fully.
2. **Prerequisites**: check the PHP and tool versions it lists.
3. **Dependencies**: update the `composer.json` constraints it lists (only packages that are
   installed), then `composer update`. Resolve conflicts by bumping the blocking package,
   never with `--ignore-platform-reqs`.
4. **Breaking changes**: walk them in the reference's order. Grep the codebase for each
   affected API and fix only what actually occurs.
5. **Checkpoint**: run the test suite (`php artisan test`, or `vendor/bin/pest` /
   `vendor/bin/phpunit`) and `php artisan about`. Fix failures before going on.
6. **Commit suggestion**: propose a commit such as `chore: upgrade Laravel 10 → 11`.
   Commit only when the user agrees. Never start the next hop with failing tests.

## 5. Final verification

- Full test suite green, `php artisan about` shows the target versions, app boots, and you
  have clicked through the main routes.
- Run the "Verify" step of each reference that was used (it names the areas to exercise).
- If Nova was upgraded or any Inertia/Vue components changed: `npm install && npm run build`,
  log into Nova and exercise resources, actions, filters, lenses and custom tools.
- Summarise per hop: what changed, what was skipped as not applicable, and anything the
  user still needs to check manually.

## References

- `references/laravel-9-to-10.md`: PHP 8.1, Composer 2.2, PHPUnit 10, Monolog 3, `$dates` → `$casts`, `DB::raw` `getValue`, `dispatchNow` removed
- `references/laravel-10-to-11.md`: PHP 8.2, published package migrations, `->change()` modifiers, float/double, Sanctum 4, Passport 12, Carbon 3, per-second rate limits
- `references/laravel-11-to-12.md`: Carbon 3 required, `HasUuids` → UUIDv7, PHPUnit 11 / Pest 3, `image` rule excludes SVG, `local` disk root
- `references/laravel-12-to-13.md`: `PreventRequestForgery`, PHPUnit 12 / Pest 4, Tinker 3, cache `serializable_classes`, `upsert` `uniqueBy`, cache/session prefixes, Laravel Boost
- `references/nova-4-to-5.md`: Inertia 2, Fortify replacing `laravel/ui`, `parent::register()`, `api_middleware`, `form-backend-validation`, Place field removed, republish assets/stubs
