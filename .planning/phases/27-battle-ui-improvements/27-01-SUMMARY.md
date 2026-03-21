---
phase: 27-battle-ui-improvements
plan: 01
subsystem: ui
tags: [flutter, dispatch, military, carry-capacity, cargo-ship, battle-report]

# Dependency graph
requires:
  - phase: 05-battle-engine
    provides: pillage SQL formula (v_cargo_cap := v_surviving_cs * 500)
  - phase: 14-military-dispatch
    provides: dispatch_screen.dart with _dispatchControllers and roster
provides:
  - cargoCapacityPerShip = 500 constant in unit_constants.dart
  - _CargoCapacityRow widget in dispatch_screen.dart (live carry capacity indicator)
  - Wave 0 test stubs for BTUI-01 (PillageResultCard) and BTUI-02 (carry capacity)
affects: [28-battle-ui-improvements]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "_CargoCapacityRow StatelessWidget reads from parent _dispatchControllers map — no new state management needed"
    - "Wave 0 skip:true test stubs document expected widget behavior before full implementation"

key-files:
  created:
    - test/widget/pillage_result_card_test.dart
    - test/widget/dispatch_capacity_test.dart
  modified:
    - lib/core/constants/unit_constants.dart
    - lib/features/military/screens/dispatch_screen.dart
    - test/unit/unit_constants_test.dart

key-decisions:
  - "cargoCapacityPerShip = 500 constant placed in unit_constants.dart after baseMinutesPerGridUnit — same pattern as existing travel time constant"
  - "_CargoCapacityRow hides entirely (SizedBox.shrink) when maxShips == 0, avoiding unnecessary UI noise"
  - "Orange warning text shown when 0 cargo ships selected but ships exist in roster — distinct from hidden state"
  - "Capacity format is 'X / Y' (selected * 500 / max * 500) for immediate clarity"

patterns-established:
  - "Cargo capacity constant synced comment: 'Keep in sync with v_cargo_cap := v_surviving_cs * 500 in pillage SQL'"
  - "Wave 0 test stub pattern: skip:true stubs with TODO comments document expected behavior before full widget test implementation"

requirements-completed: [BTUI-01, BTUI-02]

# Metrics
duration: 15min
completed: 2026-03-21
---

# Phase 27 Plan 01: Battle UI Improvements Summary

**cargoCapacityPerShip=500 constant plus live _CargoCapacityRow widget in dispatch screen showing X/Y carry capacity with orange zero-ship warning**

## Performance

- **Duration:** 15 min
- **Started:** 2026-03-21T12:12:00Z
- **Completed:** 2026-03-21T12:27:04Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Added `cargoCapacityPerShip = 500` constant to unit_constants.dart, synced with SQL pillage formula
- Added `_CargoCapacityRow` widget to dispatch_screen.dart showing live "X / Y" capacity between unit list and dispatch button
- Widget hides when roster has no cargo ships, shows orange italic warning when 0 ships selected but ships are available
- Created Wave 0 skip:true test stubs for BTUI-01 (PillageResultCard) and BTUI-02 (dispatch carry capacity)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add cargoCapacityPerShip constant and _CargoCapacityRow widget** - `f6d21f4` (feat)
2. **Task 2: Create Wave 0 test stubs for BTUI-01 and BTUI-02 widget verification** - `84a2e79` (test)

**Plan metadata:** _(docs commit — pending)_

## Files Created/Modified
- `lib/core/constants/unit_constants.dart` - Added `cargoCapacityPerShip = 500` constant after `baseMinutesPerGridUnit`
- `lib/features/military/screens/dispatch_screen.dart` - Added `_CargoCapacityRow` widget class and insertion in build method
- `test/unit/unit_constants_test.dart` - Added `cargo capacity` group with 2 new tests
- `test/widget/pillage_result_card_test.dart` - New Wave 0 stub test file (4 skipped tests, BTUI-01)
- `test/widget/dispatch_capacity_test.dart` - New Wave 0 stub test file (3 skipped tests, BTUI-02)

## Decisions Made
- `cargoCapacityPerShip = 500` placed alongside `baseMinutesPerGridUnit` in unit_constants.dart — same pattern for game balance constants
- `_CargoCapacityRow` uses `SizedBox.shrink()` when maxShips == 0 — no cargo ship section renders at all when player has no ships
- Orange italic warning text displayed when ships exist but none are selected (0 selected != no ships available)
- No new state management added — widget reads from existing `_dispatchControllers` map passed from parent

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- BTUI-01 and BTUI-02 requirements fulfilled; Wave 0 stub tests ready for future full implementation
- Full test suite passes (166 tests, 44 skipped) — no regressions
- Wave 1 plans in Phase 27 can build on this carry capacity foundation

---
*Phase: 27-battle-ui-improvements*
*Completed: 2026-03-21*
