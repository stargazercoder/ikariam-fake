---
phase: 12-combat-depth
plan: 02
subsystem: ui
tags: [flutter, dart, battle, combat, constants, models, charts]

# Dependency graph
requires:
  - phase: 12-combat-depth plan 01
    provides: pillage schema with pillage_result JSONB column on battles and cargo JSONB on unit_movements
provides:
  - unitTypeColors constant map with 13 distinct Color entries (one per UnitType)
  - orderedLandTypes and orderedNavalTypes canonical lists for stacked chart iteration
  - Battle.pillageResult nullable Map<String,int>? field parsed from pillage_result JSONB
  - UnitMovement.cargo nullable Map<String,int>? field parsed from cargo JSONB
affects:
  - 12-combat-depth plan 03 (battle_loss_chart.dart uses unitTypeColors and orderedLandTypes/orderedNavalTypes)
  - 12-combat-depth plan 03 (battle_detail_screen.dart uses Battle.pillageResult)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - unitTypeColors map for chart color lookup by UnitType enum key
    - Canonical ordered type lists (orderedLandTypes/orderedNavalTypes) ensure stable stacked-bar fromY/toY ordering
    - Nullable JSONB fields with (v as num).toInt() for safe Supabase number parsing
    - TDD workflow with RED commit (test only) then GREEN commit (implementation)

key-files:
  created:
    - test/unit_type_colors_test.dart
  modified:
    - lib/core/constants/unit_constants.dart
    - lib/features/battles/models/battle.dart
    - lib/features/military/models/unit_movement.dart

key-decisions:
  - "Color.toARGB32() used instead of deprecated Color.value for Dart color integer comparisons in tests"
  - "orderedLandTypes/orderedNavalTypes as const List constants — canonical iteration order for chart stacking, prevents randomization from Map.entries"
  - "(v as num).toInt() for JSONB parsing — Supabase JSON decoder returns num not int, hard casting would throw at runtime"

patterns-established:
  - "Canonical ordered unit type lists: always use orderedLandTypes/orderedNavalTypes when building stacked charts — never iterate UnitType.values directly"
  - "Nullable model fields for optional JSONB: oldRows without the column return null cleanly without error"

requirements-completed:
  - CMBT-04

# Metrics
duration: 12min
completed: 2026-03-15
---

# Phase 12 Plan 02: Unit Type Colors & Model Extensions Summary

**13-entry unitTypeColors constant map, ordered unit type lists for chart stacking, and nullable pillageResult/cargo fields on Battle/UnitMovement models with safe JSONB parsing**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-03-15T19:00:00Z
- **Completed:** 2026-03-15T19:12:00Z
- **Tasks:** 2
- **Files modified:** 4 (1 created test file, 3 modified source files)

## Accomplishments

- Added `unitTypeColors` constant map with 13 distinct Material colors, one per UnitType enum value
- Added `orderedLandTypes` (8 entries) and `orderedNavalTypes` (5 entries) canonical lists for consistent stacked bar chart ordering
- Extended `Battle` model with nullable `pillageResult: Map<String, int>?` field from `pillage_result` JSONB
- Extended `UnitMovement` model with nullable `cargo: Map<String, int>?` field from `cargo` JSONB
- All additions backward-compatible — existing code using these models requires no changes

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Failing test for unitTypeColors** - `f4d63ed` (test)
2. **Task 1 GREEN: unitTypeColors map + ordered lists** - `29d698f` (feat)
3. **Task 2: Battle.pillageResult + UnitMovement.cargo** - `6c53e55` (feat)

_Note: Task 1 used TDD workflow — RED commit then GREEN commit_

## Files Created/Modified

- `lib/core/constants/unit_constants.dart` - Added `unitTypeColors` map, `orderedLandTypes`, `orderedNavalTypes`, and `flutter/material.dart` import
- `lib/features/battles/models/battle.dart` - Added nullable `pillageResult` field with fromJson parsing
- `lib/features/military/models/unit_movement.dart` - Added nullable `cargo` field with fromJson parsing
- `test/unit_type_colors_test.dart` - New: 3 tests asserting 13 entries, full coverage, all distinct colors

## Decisions Made

- `Color.toARGB32()` used instead of deprecated `Color.value` — Flutter deprecated the `.value` integer accessor; `toARGB32()` is the modern equivalent
- `orderedLandTypes`/`orderedNavalTypes` stored as `const List` constants rather than deriving from `Map.entries` — stacked bar charts require stable iteration order for consistent fromY/toY calculations
- `(v as num).toInt()` for JSONB number parsing — Supabase's Dart JSON decoder returns `num`, not `int`; hard-casting with `v as int` would throw at runtime on valid data

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed deprecated Color.value usage in test**
- **Found during:** Task 1 (unitTypeColors test — flutter analyze output)
- **Issue:** Test used `c.value` which is deprecated in Flutter; analyze warned `deprecated_member_use`
- **Fix:** Replaced `c.value` with `c.toARGB32()` in the color distinctness assertion
- **Files modified:** test/unit_type_colors_test.dart
- **Verification:** All 3 tests pass, no deprecated usage warnings
- **Committed in:** 6c53e55 (Task 2 commit, batched with model changes)

---

**Total deviations:** 1 auto-fixed (Rule 1 - deprecated API usage)
**Impact on plan:** Minimal fix for correctness. No scope creep.

## Issues Encountered

None — plan executed cleanly. Test infrastructure already set up from prior phases.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `unitTypeColors`, `orderedLandTypes`, `orderedNavalTypes` are ready for import in Plan 03 chart widget
- `Battle.pillageResult` ready for display in Plan 03 battle detail screen
- `UnitMovement.cargo` ready for display in Plan 03 return movement cards
- No blockers for Plan 03

---
*Phase: 12-combat-depth*
*Completed: 2026-03-15*
