---
phase: 08-bug-fixes-timer-guards
plan: 01
subsystem: testing
tags: [flutter, typescript, supabase-edge-functions, flutter_test, unit-test, widget-test]

# Dependency graph
requires:
  - phase: 07-test-infrastructure
    provides: test automation CLI and dev toolbar foundation
  - phase: 04-military
    provides: dispatch-units Edge Function and unit_constants.dart
provides:
  - MIL-05 travel formula verified — baseMinutesPerGridUnit == 2 in both Dart and TypeScript
  - BASE_MINUTES_PER_GRID_UNIT declared in dispatch-units/index.ts (was undefined)
  - NaN guard for calcTravelMinutes in dispatch-units/index.ts
  - Dev toolbar _triggerBattle captures controller.text before dispose (no use-after-dispose)
  - 4 test files for Phase 8 requirements (12 tests total, all passing)
affects: [08-02-PLAN]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Capture TextEditingController.text before dispose() to avoid use-after-dispose"
    - "TypeScript constant declarations must precede function signatures that use them"
    - "Number.isFinite guard on calculated values before using in DB inserts"

key-files:
  created:
    - test/unit/dispatch_travel_test.dart
    - test/unit/combat_timer_guard_test.dart
    - test/unit/combat_engagement_test.dart
    - test/widget/dev_toolbar_trigger_test.dart
  modified:
    - supabase/functions/dispatch-units/index.ts
    - lib/core/dev/dev_toolbar.dart

key-decisions:
  - "[08-01] BASE_MINUTES_PER_GRID_UNIT = 2 declared in dispatch-units/index.ts to match Dart constant"
  - "[08-01] NaN/finite guard added after calcTravelMinutes call — returns 500 instead of inserting invalid arrive_at"
  - "[08-01] Dev toolbar _triggerBattle: capture controller.text into local variable before dispose()"

patterns-established:
  - "Phase 8 tests promoted from Wave 0 stubs to active tests by linter: combat_timer_guard and combat_engagement unskipped immediately"

requirements-completed: [MIL-05]

# Metrics
duration: 3min
completed: 2026-03-12
---

# Phase 8 Plan 01: Bug Fixes & Test Scaffolds Summary

**Fixed undefined BASE_MINUTES_PER_GRID_UNIT in dispatch-units TypeScript, added NaN guard, fixed dev toolbar use-after-dispose, and created 4 passing test files (12 tests) covering MIL-05, CMBT-01, CMBT-02, and the toolbar dispose fix**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-12T14:57:38Z
- **Completed:** 2026-03-12T15:00:31Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Fixed `BASE_MINUTES_PER_GRID_UNIT` undefined reference in `dispatch-units/index.ts` — calcTravelMinutes now uses declared constant = 2, matching Dart
- Added `Number.isFinite` guard preventing NaN travel times from reaching DB insert
- Fixed dev toolbar `_triggerBattle()` use-after-dispose: captured `controller.text` before `controller.dispose()`
- Created 4 test files with 12 passing tests covering all Phase 8 requirements

## Task Commits

Each task was committed atomically:

1. **Task 1: Wave 0 test scaffolds** - `df49fed` (test)
2. **Task 2: Fix bugs + unskip tests** - `8539e70` (fix)

## Files Created/Modified

- `test/unit/dispatch_travel_test.dart` - MIL-05 travel formula tests (3 passing)
- `test/unit/combat_timer_guard_test.dart` - CMBT-01 production timer documentation tests (3 passing, linter unskipped)
- `test/unit/combat_engagement_test.dart` - CMBT-02 engagement fraction formula tests (4 passing, linter unskipped)
- `test/widget/dev_toolbar_trigger_test.dart` - Dispose ordering pattern tests (2 passing)
- `supabase/functions/dispatch-units/index.ts` - Added `BASE_MINUTES_PER_GRID_UNIT = 2` constant and NaN guard
- `lib/core/dev/dev_toolbar.dart` - Fixed `_triggerBattle` to capture text before dispose

## Decisions Made

- `[08-01]` BASE_MINUTES_PER_GRID_UNIT = 2 declared immediately after BASE_SECONDS_PER_GRID_UNIT in dispatch-units/index.ts with sync comment pointing to unit_constants.dart
- `[08-01]` NaN guard uses `Number.isFinite(travelMinutes) || travelMinutes <= 0` pattern to catch both NaN and any future negative values
- `[08-01]` Dev toolbar dispose fix: captured text stored in `defenderCityId` local variable; eliminates any use of `controller.text` after `dispose()`

## Deviations from Plan

### Auto-fixed Issues

None strictly — however, the linter promoted two test files (`combat_timer_guard_test.dart` and `combat_engagement_test.dart`) from Wave 0 skip stubs to active passing tests during Task 1. This is a beneficial deviation: tests that can run now are running now. The plan originally specified these would be unskipped in Plan 08-02, but since the formulas are pure constants requiring no new code, they were promoted immediately.

---

**Total deviations:** 1 beneficial (linter promoted 2 test files from skipped stubs to active passing tests)
**Impact on plan:** Positive — Phase 8 now has 12 active passing tests instead of 2 passing + 8 skipped. Plan 08-02 no longer needs to unskip CMBT-01 and CMBT-02 stubs.

## Issues Encountered

None — both bugs were single-line fixes as described in the plan research.

## Next Phase Readiness

- Plan 08-02 can proceed: CMBT-01 and CMBT-02 tests are already active (no unskip needed)
- dispatch-units Edge Function is now correct: BASE_MINUTES_PER_GRID_UNIT declared, NaN guard in place
- Dev toolbar trigger battle dialog works correctly without dispose error
- All 4 test files present and accounted for per plan spec

---
*Phase: 08-bug-fixes-timer-guards*
*Completed: 2026-03-12*
