---
phase: 14-movement-visibility
plan: 02
subsystem: ui
tags: [flutter, riverpod, go_router, realtime, movements]

# Dependency graph
requires:
  - phase: 14-01
    provides: allMovementsStreamProvider, cityNameProvider, UnitMovement.movementType
provides:
  - MovementsScreen with _MovementCard widget at lib/features/movements/screens/movements_screen.dart
  - Fifth StatefulShellBranch for /movements route in app_router.dart
  - Fifth NavigationDestination 'Movements' tab (swap_horiz icon) in main_shell_screen.dart
affects: [future-ui-polish, UIPL phases]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - ConsumerWidget for screen + private ConsumerWidget for card
    - Nested Consumer inside card for per-row city name resolution via FutureProvider.family
    - StreamProvider.autoDispose .when() for loading/error/data states
    - Reuse of CountdownTimerWidget for ETA display

key-files:
  created:
    - lib/features/movements/screens/movements_screen.dart
  modified:
    - lib/core/router/app_router.dart
    - lib/features/map/screens/main_shell_screen.dart

key-decisions:
  - "dart:ui import removed — FontFeature.tabularFigures() is re-exported by package:flutter/material.dart"
  - "Nested Consumer widget per card for cityNameProvider to isolate rebuilds to the city name Text only"

patterns-established:
  - "Movement card: direction icon (call_made/call_received) + city name + units + optional cargo + CountdownTimerWidget"
  - "allMovementsStreamProvider watched at screen level; cityNameProvider watched per-card inside Consumer"

requirements-completed: [MOVE-01, MOVE-02]

# Metrics
duration: 15min
completed: 2026-03-16
---

# Phase 14 Plan 02: Movements Screen UI Summary

**Fifth bottom-nav tab "Movements" with real-time card list showing destination city name, unit composition, cargo, and live ETA countdown for all in-transit armies**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-03-16T09:15:00Z
- **Completed:** 2026-03-16T12:20:00Z
- **Tasks:** 3 of 3 (all complete including human-verify checkpoint)
- **Files modified:** 3

## Accomplishments
- Fifth navigation branch `/movements` wired into GoRouter with `_movementsNavigatorKey`
- `Movements` tab (swap_horiz icon) added as index 4 in bottom NavigationBar
- `MovementsScreen` built with loading/error/empty/data states using `allMovementsStreamProvider`
- `_MovementCard` shows destination city name (resolved from UUID), unit composition, conditional cargo, and live `CountdownTimerWidget` ETA
- `call_made`/`call_received` icons distinguish outgoing attacks from returning movements
- `flutter analyze` passes with zero issues

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Movements route and navigation tab** - `05b7d39` (feat)
2. **Task 2: Create MovementsScreen with _MovementCard** - `7af712e` (feat)
3. **Task 3: Verify Movements screen end-to-end** - checkpoint:human-verify approved by user

## Files Created/Modified
- `lib/features/movements/screens/movements_screen.dart` - MovementsScreen + _MovementCard (183 lines)
- `lib/core/router/app_router.dart` - Added import, _movementsNavigatorKey, fifth StatefulShellBranch
- `lib/features/map/screens/main_shell_screen.dart` - Added fifth NavigationDestination, updated doc comment

## Decisions Made
- Removed `dart:ui` import — `FontFeature.tabularFigures()` is already re-exported by `package:flutter/material.dart`, keeping the import would trigger an `unnecessary_import` lint warning.
- Used nested `Consumer` widget inside `_MovementCard` for `cityNameProvider` to isolate city name rebuilds to only the `Text` widget, not the entire card.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed unnecessary dart:ui import and fixed unnecessary_underscores lint**
- **Found during:** Task 2 (flutter analyze after file creation)
- **Issue:** Plan spec included `import 'dart:ui';` but `FontFeature` is already available via `flutter/material.dart`; also `(_, __)` triggered `unnecessary_underscores` lint
- **Fix:** Removed `dart:ui` import; replaced `(_, __)` with `(e, s)` in error callback
- **Files modified:** lib/features/movements/screens/movements_screen.dart
- **Verification:** `flutter analyze` reports zero issues
- **Committed in:** 7af712e (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - lint/import cleanup)
**Impact on plan:** Minor cleanup. No scope creep, no behavioral change.

## Issues Encountered
None beyond the lint fixes above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 14 is complete — MOVE-01 and MOVE-02 requirements satisfied
- Movements screen verified end-to-end: empty state, real-time card updates, city name resolution, unit composition, ETA countdown, and card disappearance on arrival all confirmed
- Ready for Phase 15: Resource Trading (cargo ship sending from city to player)

---
*Phase: 14-movement-visibility*
*Completed: 2026-03-16*
