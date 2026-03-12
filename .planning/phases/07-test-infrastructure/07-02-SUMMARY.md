---
phase: 07-test-infrastructure
plan: 02
subsystem: testing
tags: [flutter, widget, dev-toolbar, riverpod, supabase-rpc, debug-mode]

requires:
  - phase: 07-01
    provides: "4 SECURITY DEFINER RPC functions: dev_inject_resources, dev_level_up_building, dev_spawn_units, dev_trigger_battle"

provides:
  - "DevToolbarWrapper widget: Stack+Positioned FAB overlay in debug mode, no-op in release"
  - "DevRpcService: 4 methods calling SECURITY DEFINER RPC functions with lazy Supabase client access"
  - "_DevToolbarFab: ConsumerStatefulWidget with 4 action buttons + dialogs for building/unit selection"
  - "MainShellScreen integration: kDebugMode conditional wraps navigationShell body"
  - "test/widget/dev_toolbar_test.dart: 2 widget tests with ProviderScope + NullCityNotifier stub"

affects:
  - phase-07-03: test CLI script can now use toolbar RPC functions programmatically

tech-stack:
  added: []
  patterns:
    - "Lazy Supabase client access via getter property (not constructor field) for test isolation"
    - "CityNotifier subclass override pattern for ProviderScope in widget tests"
    - "kDebugMode double-gate: MainShellScreen ternary + DevToolbarWrapper internal check"
    - "ConsumerStatefulWidget reads cityProvider via whenOrNull(data:) — null-safe, no AsyncValue pattern"

key-files:
  created:
    - lib/core/dev/dev_rpc_service.dart
    - lib/core/dev/dev_toolbar.dart
    - test/widget/dev_toolbar_test.dart
  modified:
    - lib/features/map/screens/main_shell_screen.dart

key-decisions:
  - "[07-02] DevRpcService._client is a lazy getter (not constructor field): avoids Supabase.instance.client call during widget construction in tests"
  - "[07-02] Widget tests use ProviderScope + _NullCityNotifier subclass of CityNotifier: AsyncNotifierProvider.overrideWith requires same notifier type"
  - "[07-02] kDebugMode conditional in MainShellScreen is redundant with DevToolbarWrapper's internal check but makes intent explicit and avoids constructing the wrapper in release builds"

metrics:
  duration: 4min
  completed: 2026-03-12
  tasks: 2
  files: 4
---

# Phase 7 Plan 02: Dev Toolbar Widget Summary

**DevToolbarWrapper with 4 action FABs (inject resources, level up building, spawn units, trigger battle) calling SECURITY DEFINER RPC functions — visible on all game screens in debug mode, tree-shaken in release**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-03-12T11:12:43Z
- **Completed:** 2026-03-12T11:17:22Z
- **Tasks:** 2
- **Files modified/created:** 4

## Accomplishments

- Created `DevRpcService` with lazy Supabase client and 4 RPC methods (injectResources, levelUpBuilding, spawnUnits, triggerBattle)
- Created `DevToolbarWrapper` StatelessWidget: returns child in release, Stack+FAB in debug
- Created `_DevToolbarFab` ConsumerStatefulWidget with expand/collapse toggle and 4 action buttons each with dialogs
- Integrated wrapper into `MainShellScreen` via `kDebugMode` ternary on `body`
- Created 2 passing widget tests using `ProviderScope` + `_NullCityNotifier` override

## Task Commits

1. **Task 1: Create DevRpcService and DevToolbarWrapper widget** - `645c920` (feat)
2. **Task 2: Integrate DevToolbarWrapper into MainShellScreen** - `637ee66` (feat)

## Files Created/Modified

- `lib/core/dev/dev_rpc_service.dart` — 4 RPC methods; client accessed lazily via getter not constructor to support testing without Supabase init
- `lib/core/dev/dev_toolbar.dart` — DevToolbarWrapper, _DevToolbarFab, _ActionButton; FAB reads cityProvider via `whenOrNull(data:)` for null-safe city ID
- `test/widget/dev_toolbar_test.dart` — 2 tests: FAB renders in debug mode, child always rendered; uses ProviderScope with _NullCityNotifier subclass override
- `lib/features/map/screens/main_shell_screen.dart` — Added imports for `foundation.dart` and `dev_toolbar.dart`; body wrapped with kDebugMode conditional

## Decisions Made

- `DevRpcService._client` is a lazy getter (`_clientOverride ?? Supabase.instance.client`) rather than being set in the constructor. This avoids calling `Supabase.instance.client` before Supabase is initialized in test environments where no RPC calls are made.
- Widget tests use `ProviderScope` with `_NullCityNotifier extends CityNotifier` — `AsyncNotifierProvider.overrideWith` requires a factory returning the exact notifier type, so a subclass is required.
- Double kDebugMode gate (MainShellScreen ternary + DevToolbarWrapper's `if (!kDebugMode) return child`) is intentional: the shell gate prevents constructing the wrapper at all in release, the internal gate provides defense-in-depth if the wrapper is ever used elsewhere.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] valueOrNull not available in Riverpod 3.x**
- **Found during:** Task 1 (first test run)
- **Issue:** Plan specified `cityAsync.valueOrNull?['id']` but Riverpod 3.x does not expose `valueOrNull` on `AsyncValue`
- **Fix:** Replaced with `ref.read(cityProvider).whenOrNull(data: (c) => c)` — same pattern used in `island_screen.dart`
- **Files modified:** `lib/core/dev/dev_toolbar.dart`
- **Commit:** 645c920

**2. [Rule 1 - Bug] Eager Supabase.instance.client call crashed widget tests**
- **Found during:** Task 1 (second test run)
- **Issue:** `DevRpcService()` was instantiated at `_DevToolbarFabState` field declaration time, calling `Supabase.instance.client` before Supabase was initialized
- **Fix:** Made `_client` a lazy getter on `DevRpcService`; moved `DevRpcService` instantiation to `initState` (now also fine since it no longer calls Supabase in constructor)
- **Files modified:** `lib/core/dev/dev_rpc_service.dart`, `lib/core/dev/dev_toolbar.dart`
- **Commit:** 645c920

**3. [Rule 1 - Bug] Widget tests failed without ProviderScope**
- **Found during:** Task 1 (third test run)
- **Issue:** Plan's test spec used plain `MaterialApp` but `_DevToolbarFab` is a `ConsumerStatefulWidget` requiring `ProviderScope` in widget tree; also `AsyncNotifierProvider.overrideWith` type mismatch
- **Fix:** Updated test to wrap with `ProviderScope`; added `_NullCityNotifier extends CityNotifier` override; `overrideWith(_NullCityNotifier.new)` satisfies type constraint
- **Files modified:** `test/widget/dev_toolbar_test.dart`
- **Commit:** 645c920

## Out-of-Scope Issues Deferred

Pre-existing test failures in `test/unit/building_formulas_test.dart` (5 failures) caused by uncommitted changes to `lib/core/constants/building_constants.dart` (base times reduced to 1 minute each for faster testing). These are unrelated to Plan 07-02. Logged to deferred-items.

## Self-Check

Files created:
- lib/core/dev/dev_rpc_service.dart: FOUND
- lib/core/dev/dev_toolbar.dart: FOUND
- test/widget/dev_toolbar_test.dart: FOUND

Files modified:
- lib/features/map/screens/main_shell_screen.dart: FOUND (contains DevToolbarWrapper, kDebugMode)

Commits:
- 645c920: FOUND (feat(07-02): create DevRpcService, DevToolbarWrapper widget...)
- 637ee66: FOUND (feat(07-02): integrate DevToolbarWrapper into MainShellScreen)

Tests: flutter test test/widget/dev_toolbar_test.dart — 2/2 PASSED

## Self-Check: PASSED

---
*Phase: 07-test-infrastructure*
*Completed: 2026-03-12*
