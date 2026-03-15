---
phase: 12-combat-depth
plan: "03"
subsystem: ui
tags: [flutter, fl_chart, bar-chart, battle-report, pillage, widget-test]

# Dependency graph
requires:
  - phase: 12-combat-depth/12-02
    provides: unitTypeColors, orderedLandTypes, orderedNavalTypes, Battle.pillageResult
  - phase: 12-combat-depth/12-01
    provides: pillage schema, BattleTurn model with casualty maps
provides:
  - BattleLossChart widget: stacked bar charts for naval + land unit losses per turn
  - PillageResultCard widget: per-resource loot breakdown for completed battles
  - Updated battle_detail_screen.dart integrating both chart and pillage card
  - Widget tests covering chart rendering and pillage card visibility (7 passing)
affects:
  - battle-detail-screen
  - combat-visualization

# Tech tracking
tech-stack:
  added: [fl_chart ^1.0.0]
  patterns:
    - BarChartRodStackItem for stacking unit type losses within a single rod
    - Side-by-side rods (attacker left, defender right) within each BarChartGroupData
    - orderedNavalTypes/orderedLandTypes for stable iteration order across chart + legend

key-files:
  created:
    - lib/features/battles/screens/widgets/battle_loss_chart.dart
    - lib/features/battles/screens/widgets/pillage_result_card.dart
    - test/battle_loss_chart_test.dart
  modified:
    - lib/features/battles/screens/battle_detail_screen.dart
    - pubspec.yaml

key-decisions:
  - "BattleLossChart takes only List<BattleTurn> (no isAttacker flag) — renders both attacker and defender rods side-by-side for objective view"
  - "Legend shows only unit types that actually had casualties — avoids cluttering chart with all 13 types when only 3 fought"
  - "PillageResultCard returns SizedBox.shrink() on null/empty pillageResult — zero layout cost when no pillage"
  - "fl_chart BarChart wrapped in SizedBox(height:180) to avoid unbounded height error in tests"

patterns-established:
  - "Phase chart separation: _PhaseChart private widget encapsulates naval/land chart logic to avoid duplication"
  - "activeTurns filter: only turns with >0 casualties for the phase contribute bar groups — no zero-height bars"
  - "Resource ordering: canonical order wood > marble > crystal > sulfur enforced via _resourceOrder() helper"

requirements-completed: [CMBT-03, CMBT-04]

# Metrics
duration: 15min
completed: 2026-03-15
---

# Phase 12 Plan 03: Battle Report Visualization Summary

**Stacked bar charts (fl_chart) for turn-by-turn unit losses plus a per-resource PillageResultCard, integrated into BattleDetailScreen with 7 widget tests passing**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-03-15T19:00:00Z
- **Completed:** 2026-03-15T19:22:53Z
- **Tasks:** 2 auto (+ 1 checkpoint reached)
- **Files modified:** 5

## Accomplishments

- Created BattleLossChart with naval + land stacked bar sections, attacker/defender side-by-side rods, unit-type color legend
- Created PillageResultCard showing per-resource breakdown (green for attacker gains, red for defender losses)
- Integrated both widgets into battle_detail_screen.dart between army counts and turn cards
- Added fl_chart dependency and 7 widget tests (all passing)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add fl_chart dep + BattleLossChart + PillageResultCard** - `9ea08b2` (feat)
2. **Task 2 RED: Widget tests for BattleLossChart and PillageResultCard** - `723d29d` (test)
3. **Task 2 GREEN: Integrate chart + pillage into battle_detail_screen.dart** - `d5cb308` (feat)

## Files Created/Modified

- `lib/features/battles/screens/widgets/battle_loss_chart.dart` - BattleLossChart widget (naval + land stacked bar charts)
- `lib/features/battles/screens/widgets/pillage_result_card.dart` - PillageResultCard widget with resource breakdown
- `lib/features/battles/screens/battle_detail_screen.dart` - Updated to include chart and pillage card sections
- `test/battle_loss_chart_test.dart` - 7 widget tests for chart rendering and pillage visibility
- `pubspec.yaml` - fl_chart dependency added

## Decisions Made

- BattleLossChart renders both attacker and defender rods side-by-side (objective view, not per-player) since both players view the same battle report
- Legend shows only unit types with actual casualties — avoids showing all 13 types when only 3 fought
- PillageResultCard uses SizedBox.shrink() on null/empty — zero layout cost when no pillage occurred
- BattleLossChart does not take an `isAttacker` flag (plan suggested it, but chart renders both sides, making the flag unnecessary)

## Deviations from Plan

### Minor Adjustment

**1. [Rule 1 - Bug] Removed isAttacker parameter from BattleLossChart**
- **Found during:** Task 1 (BattleLossChart creation)
- **Issue:** Plan specified `isAttacker` parameter on BattleLossChart, but the chart renders both attacker and defender rods side-by-side — the flag serves no purpose
- **Fix:** Removed `isAttacker` parameter; chart always shows both sides
- **Files modified:** battle_loss_chart.dart, battle_detail_screen.dart
- **Verification:** Tests pass, widget renders both rods correctly
- **Committed in:** `9ea08b2`, `d5cb308`

---

**Total deviations:** 1 minor auto-fix (parameter simplification)
**Impact on plan:** Cleaner API; no functional difference since chart always shows both sides.

## Issues Encountered

None — plan executed cleanly. All 7 tests pass, flutter analyze shows no errors from plan changes.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Battle report visualization complete for CMBT-03 and CMBT-04
- Visual verification checkpoint (Task 3) awaits human confirmation
- All widgets compile and tests pass — ready for human visual sign-off via `flutter run`

---
*Phase: 12-combat-depth*
*Completed: 2026-03-15*
