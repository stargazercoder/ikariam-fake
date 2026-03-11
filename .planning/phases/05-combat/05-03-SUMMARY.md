---
phase: 05-combat
plan: "03"
subsystem: ui
tags: [flutter, riverpod, go_router, realtime, battles, navigation]

# Dependency graph
requires:
  - phase: 05-combat/05-02
    provides: allMyBattlesProvider, battleTurnsProvider, Battle/BattleTurn models, BattleRepository with Realtime streams

provides:
  - BattlesScreen: 4th navigation tab listing active battles (with countdown) and past battles
  - BattleDetailScreen: per-battle view with status header, army counts, reverse-chronological turn cards
  - BattleTurnCard: widget showing naval phase before land phase, gate-keeper blocked message, survivors
  - /battles and /battle-detail GoRouter routes in 4th StatefulShellBranch
  - 4th NavigationDestination (Battles) in MainShellScreen

affects: [05-combat, future phases using combat UI]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - ConsumerWidget pattern for read-only battle screens watching Riverpod providers
    - BattleTurnCard stateless widget accepts turn + isAttacker bool for role-aware display
    - NavalPhase rendered before LandPhase (CMBT-03 compliance)
    - Blocked land phase shows anchor icon + descriptive message instead of casualty rows

key-files:
  created:
    - lib/features/battles/screens/battles_screen.dart
    - lib/features/battles/screens/battle_detail_screen.dart
    - lib/features/battles/screens/widgets/battle_turn_card.dart
  modified:
    - lib/core/router/app_router.dart
    - lib/features/map/screens/main_shell_screen.dart

key-decisions:
  - "Icons.sword_outlined not in Material Icons — used Icons.gps_fixed_outlined for attacker role icon"
  - "Missing unit_constants import in battle_detail_screen caused compile error — added as auto-fix (Rule 3)"

patterns-established:
  - "BattleTurnCard: naval phase shown before land phase (CMBT-03); skipped phases hidden, blocked land shows gate-keeper message"
  - "BattlesScreen uses allMyBattlesProvider (returns List<Battle>) directly — no AsyncValue wrapping needed"

requirements-completed: [CMBT-01, CMBT-03, CMBT-04]

# Metrics
duration: 5min
completed: 2026-03-12
---

# Phase 5 Plan 03: Battle UI Layer Summary

**Flutter battle UI: BattlesScreen (4th nav tab with Realtime countdown), BattleDetailScreen (turn cards with naval-before-land phases), BattleTurnCard widget, wired into GoRouter and NavigationBar**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-11T21:50:57Z
- **Completed:** 2026-03-12T21:55:00Z
- **Tasks:** 2 of 3 (Task 3 is human verification checkpoint)
- **Files modified:** 5

## Accomplishments
- BattlesScreen lists active battles (with CountdownTimerWidget) then past battles, links to detail
- BattleDetailScreen shows status header, army count comparison, reverse-chronological BattleTurnCard list
- BattleTurnCard displays Naval phase before Land phase (CMBT-03), blocked message for naval gate-keeper
- 4th StatefulShellBranch added with battlesNav key, /battles and /battle-detail routes
- 4th NavigationDestination (shield icon, "Battles" label) added to MainShellScreen

## Task Commits

Each task was committed atomically:

1. **Task 1: Create BattlesScreen, BattleDetailScreen, BattleTurnCard widget** - `56ff433` (feat)
2. **Task 2: Integrate 4th Battles tab into router and navigation shell** - `fc76900` (feat)

_Task 3 is a human verification checkpoint — not yet committed._

## Files Created/Modified
- `lib/features/battles/screens/battles_screen.dart` - 4th tab listing active/past battles with CountdownTimerWidget
- `lib/features/battles/screens/battle_detail_screen.dart` - Battle detail: header, army counts, turn cards
- `lib/features/battles/screens/widgets/battle_turn_card.dart` - Card for single turn: naval then land phases
- `lib/core/router/app_router.dart` - Added _battlesNavigatorKey, 4th StatefulShellBranch with /battles and /battle-detail
- `lib/features/map/screens/main_shell_screen.dart` - Added 4th NavigationDestination for Battles tab

## Decisions Made
- `Icons.sword_outlined` does not exist in Material Icons — used `Icons.gps_fixed_outlined` for attacker role icon in battle tile
- `allMyBattlesProvider` returns `List<Battle>` (not `AsyncValue<List<Battle>>`): no loading/error states needed in BattlesScreen, empty list is shown until stream warms up

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Missing unit_constants import in battle_detail_screen.dart**
- **Found during:** Task 2 (build verification)
- **Issue:** `_ArmyColumn._displayName()` calls `unitTypeFromDbName()` but unit_constants was not imported
- **Fix:** Added `import '../../../core/constants/unit_constants.dart';` to battle_detail_screen.dart
- **Files modified:** lib/features/battles/screens/battle_detail_screen.dart
- **Verification:** `flutter build web --no-pub` succeeds
- **Committed in:** fc76900 (Task 2 commit)

**2. [Rule 1 - Bug] Icons.sword_outlined does not exist**
- **Found during:** Task 2 (build verification)
- **Issue:** `Icons.sword_outlined` is not a valid Material Icon, causing compile error
- **Fix:** Changed to `Icons.gps_fixed_outlined` (crosshair/target icon for attacker role)
- **Files modified:** lib/features/battles/screens/battles_screen.dart
- **Verification:** `flutter build web --no-pub` succeeds
- **Committed in:** fc76900 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 missing import, 1 invalid icon)
**Impact on plan:** Both auto-fixes necessary for compilation. No scope creep.

## Issues Encountered
None beyond the two auto-fixed compile errors above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Full combat UI layer is complete pending human verification (Task 3)
- BattlesScreen, BattleDetailScreen, BattleTurnCard all ready for end-to-end testing
- 4th nav tab visible in app, /battles and /battle-detail routes registered
- Human verifier should test: Battles tab appears, BattlesScreen loads, BattleDetailScreen navigates, turn cards show naval-before-land ordering

## Self-Check: PASSED

All files and commits verified present.

---
*Phase: 05-combat*
*Completed: 2026-03-12*
