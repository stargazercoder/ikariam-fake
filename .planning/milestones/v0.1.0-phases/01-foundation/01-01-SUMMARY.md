---
phase: 01-foundation
plan: 01
subsystem: infra
tags: [flutter, supabase, postgresql, rls, riverpod, go_router, flame, dart]

# Dependency graph
requires: []
provides:
  - Flutter web project with pubspec.yaml (supabase_flutter, flutter_riverpod, riverpod_annotation, go_router, flame)
  - Supabase local dev stack initialized (supabase/config.toml)
  - islands table with RLS (SELECT only for authenticated)
  - profiles table with RLS (SELECT all, UPDATE own; INSERT via trigger)
  - cities table with RLS (SELECT only for authenticated)
  - handle_new_user trigger (SECURITY DEFINER, atomically creates profile + city on signup)
  - 100 islands seeded in 10x10 grid (~33 each of marble, crystal, sulfur)
  - Material 3 theme with ancient Greek navy/gold palette
  - 20 preset avatar entries (Greek deity names + icon placeholders)
  - 50 ancient Greek city names pool
  - supabaseClient convenience getter
  - Feature-first folder structure (auth, profile, city, shared/widgets)
affects: [01-02, 01-03, 02-resources, 03-map, all-phases]

# Tech tracking
tech-stack:
  added:
    - supabase_flutter: ^2.12.0
    - flutter_riverpod: ^3.3.1
    - riverpod_annotation: ^4.0.2
    - go_router: ^17.1.0
    - flame: ^1.35.1
    - build_runner: ^2.4.0
  patterns:
    - SECURITY DEFINER trigger with SET search_path='' for user creation
    - RLS enabled in same migration that creates each table (never deferred)
    - No client INSERT/UPDATE/DELETE on game-state tables (islands, cities)
    - supabaseClient convenience getter (not a Riverpod provider)
    - Feature-first folder structure: lib/features/{feature}/{data,providers,screens}/

key-files:
  created:
    - lib/main.dart
    - lib/core/supabase/supabase_provider.dart
    - lib/core/theme/app_theme.dart
    - lib/core/constants/avatar_constants.dart
    - lib/core/constants/city_name_constants.dart
    - supabase/config.toml
    - supabase/migrations/20260311000000_create_islands.sql
    - supabase/migrations/20260311000001_create_profiles.sql
    - supabase/migrations/20260311000002_create_cities.sql
    - supabase/migrations/20260311000003_handle_new_user_trigger.sql
    - supabase/seed.sql
    - pubspec.yaml
  modified:
    - analysis_options.yaml
    - test/widget_test.dart
    - test/helpers/test_helpers.dart

key-decisions:
  - "riverpod_generator ^4.0.x omitted from pubspec: incompatible with flutter_test pinned deps in Dart 3.10.1 (analyzer ^9.0.0 conflict). Runtime deps (flutter_riverpod, riverpod_annotation) kept; generator to be added when Dart SDK upgrades."
  - "build_runner ^2.4.0 kept for future use; riverpod_lint omitted (same analyzer conflict)"
  - "Supabase DB queries run via docker exec supabase_db_ikariam psql (psql not in PATH on Windows)"

patterns-established:
  - "Pattern: All game-state tables (islands, cities) have RLS with SELECT-only policy — client cannot mutate"
  - "Pattern: profiles.display_name allows NULL (trigger creates stub) — constraint validates format when NOT NULL"
  - "Pattern: handle_new_user uses EXCEPTION block — signup never blocked even if city placement fails"
  - "Pattern: Use docker exec supabase_db_ikariam psql for SQL verification on Windows (no native psql)"

requirements-completed: [INFR-02, INFR-03, AUTH-04]

# Metrics
duration: 17min
completed: 2026-03-11
---

# Phase 1 Plan 01: Foundation Scaffold Summary

**Flutter web project + Supabase local dev with 3 RLS-protected tables, 100 seeded islands, and handle_new_user trigger for atomic city placement on signup**

## Performance

- **Duration:** 17 min
- **Started:** 2026-03-10T23:06:39Z
- **Completed:** 2026-03-10T23:24:32Z
- **Tasks:** 2
- **Files modified:** 13

## Accomplishments

- Flutter web project initialized with all Phase 1 dependencies (supabase_flutter, flutter_riverpod, riverpod_annotation, go_router, flame)
- 4 Supabase migrations applied cleanly via `supabase db reset`: islands, profiles, cities tables with RLS + handle_new_user trigger
- 100 islands seeded in a 10x10 grid with correct luxury distribution (34 marble, 33 crystal, 33 sulfur)
- Material 3 theme with ancient Greek color palette, 20 avatar entries, 50 city name pool, and feature-first folder structure

## Task Commits

Each task was committed atomically:

1. **Task 1: Flutter project scaffold** - `fa3048e` (feat)
2. **Task 2: Database migrations, seed, and trigger** - `7cdd593` (feat)

## Files Created/Modified

- `pubspec.yaml` - Project dependencies: supabase_flutter, flutter_riverpod, riverpod_annotation, go_router, flame, build_runner
- `lib/main.dart` - App entry: Supabase.initialize + ProviderScope + IkariamApp placeholder
- `lib/core/supabase/supabase_provider.dart` - supabaseClient convenience getter
- `lib/core/theme/app_theme.dart` - Material 3, navy (#1A237E) + gold (#FFD700) palette
- `lib/core/constants/avatar_constants.dart` - 20 Greek deity avatar entries with icon placeholders
- `lib/core/constants/city_name_constants.dart` - 50 ancient Greek city names
- `supabase/config.toml` - Supabase local dev config (project_id: ikariam)
- `supabase/migrations/20260311000000_create_islands.sql` - islands table + RLS + SELECT policy
- `supabase/migrations/20260311000001_create_profiles.sql` - profiles table + RLS + SELECT/UPDATE own policies
- `supabase/migrations/20260311000002_create_cities.sql` - cities table + RLS + SELECT policy
- `supabase/migrations/20260311000003_handle_new_user_trigger.sql` - SECURITY DEFINER trigger for atomic profile+city creation
- `supabase/seed.sql` - 100 islands in 10x10 grid via DO $$ block
- `test/widget_test.dart` - Updated to smoke test placeholder (Supabase.initialize blocks widget tests)

## Decisions Made

1. **riverpod_generator omitted from initial pubspec**: `riverpod_generator ^4.0.x` requires `analyzer ^9.0.0` which conflicts with `flutter_test` pinned dependencies in Dart 3.10.1 SDK. Runtime deps kept; generator added when Dart SDK supports it or when first `@riverpod` code-gen is needed.

2. **Supabase DB verified via docker exec**: `psql` is not in PATH on this Windows system. All SQL verification commands ran via `docker exec supabase_db_ikariam psql -U postgres -d postgres`.

3. **profiles.display_name allows NULL**: The trigger creates a stub profile with NULL display_name. The CHECK constraint validates format only when display_name is not NULL. This matches the plan spec.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed CardTheme -> CardThemeData type error**
- **Found during:** Task 1 (flutter analyze)
- **Issue:** `CardTheme(...)` constructor is deprecated in Flutter 3.38.x; `ThemeData.cardTheme` expects `CardThemeData?`
- **Fix:** Changed `CardTheme` to `CardThemeData` in `lib/core/theme/app_theme.dart`
- **Files modified:** lib/core/theme/app_theme.dart
- **Verification:** `flutter analyze` passes with no issues
- **Committed in:** fa3048e (Task 1 commit)

**2. [Rule 1 - Bug] Replaced broken widget_test.dart referencing removed MyApp**
- **Found during:** Task 1 (flutter analyze — error: 'MyApp' isn't a class)
- **Issue:** Flutter project init generates a counter widget_test.dart referencing `MyApp` which was replaced by `IkariamApp`. Also, `Supabase.initialize` cannot run in unit tests.
- **Fix:** Replaced with a placeholder smoke test that passes without calling Supabase
- **Files modified:** test/widget_test.dart
- **Verification:** `flutter test` passes with 1 passing test
- **Committed in:** fa3048e (Task 1 commit)

**3. [Rule 3 - Blocking] Removed riverpod_generator + riverpod_lint from pubspec (dependency conflict)**
- **Found during:** Task 1 (flutter pub add --dev)
- **Issue:** `riverpod_generator ^4.0.x` requires `analyzer ^9.0.0`; `riverpod_lint` has similar conflicts. Both are incompatible with `flutter_test` pinned deps in Dart 3.10.1.
- **Fix:** Omitted `riverpod_generator` and `riverpod_lint`; kept `build_runner ^2.4.0` for future use. Plans 01-02+ that need code-gen can add the generator with a specific version.
- **Files modified:** pubspec.yaml
- **Verification:** `flutter pub get` and `flutter analyze` both succeed
- **Committed in:** fa3048e (Task 1 commit)

---

**Total deviations:** 3 auto-fixed (2 Rule 1 bugs, 1 Rule 3 blocker)
**Impact on plan:** All auto-fixes necessary for correctness and build success. No scope creep. The riverpod_generator omission is a known SDK constraint — it does not affect Phase 1 since no `@riverpod` code-gen is used in this plan.

## Issues Encountered

- `psql` not available in PATH on Windows 11. Resolved by using `docker exec supabase_db_ikariam psql` for all SQL verification queries.
- Supabase images required a full Docker pull (~1.2GB total) on first run — expected for a fresh environment.

## User Setup Required

None - no external service configuration required. Supabase local dev runs entirely in Docker.

## Next Phase Readiness

- Flutter project compiles with zero errors (`flutter analyze --no-fatal-infos` passes)
- `flutter test` passes (1 passing, 5 skipped awaiting future plans)
- Supabase local dev running on port 54321 (API) and 54322 (DB)
- All 3 tables have RLS enabled, verified via `pg_tables` query
- 100 islands seeded with correct luxury distribution
- `on_auth_user_created` trigger verified in `information_schema.triggers`
- Ready for Plan 01-02: Auth screens, login/signup, GoRouter with auth guards

---
*Phase: 01-foundation*
*Completed: 2026-03-11*
