---
phase: 10-economy-foundation
plan: "03"
subsystem: ui
tags: [flutter, riverpod, supabase-realtime, dart]

# Dependency graph
requires:
  - phase: 10-economy-foundation/10-01
    provides: cities table columns (population, happiness, wine_spending_rate) + Realtime publication
  - phase: 10-economy-foundation/10-02
    provides: CityRepository.setWineRate() Edge Function integration

provides:
  - ResourceType.wine enum member in resource_constants.dart
  - cityEconomyStreamProvider: StreamProvider.autoDispose.family watching cities table in real-time
  - City screen resource panel with all 6 resources including wine chip
  - City screen happiness indicator (_HappinessChip) with emoji + colored score
  - City screen population summary (_PopulationSummary) with count, growth/tick, tax/hr
  - _TavernWineSlider widget in building_upgrade_sheet.dart with 300ms debounced setWineRate calls
  - Wine icon/color/label cases in city_grid_screen.dart and building_upgrade_card.dart

affects: [10-economy-foundation, Phase 11, Phase 12, any feature using ResourceType]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "cityEconomyStreamProvider: StreamProvider.autoDispose.family pattern wrapping Supabase .stream().eq().map() for cities table"
    - "TavernWineSlider: ConsumerStatefulWidget with local slider state, Timer debounce, and stream-initialized value"
    - "Happiness display: emoji-based indicator with green/grey/red coloring based on sign of value"

key-files:
  created:
    - lib/features/city/providers/city_economy_provider.dart
  modified:
    - lib/core/constants/resource_constants.dart
    - lib/features/city/screens/city_screen.dart
    - lib/features/city/screens/building_upgrade_sheet.dart
    - lib/features/map/screens/city_grid_screen.dart
    - lib/features/military/widgets/building_upgrade_card.dart

key-decisions:
  - "Wine icon: Icons.wine_bar + Colors.purple.shade600 — consistent across all files"
  - "_TavernWineSlider initializes _rate from stream on first emission (not re-syncs) to avoid fighting user interaction"
  - "Happiness chip uses emoji (not Icon) for visual distinctiveness from resource chips"
  - "_PopulationSummary uses unicode escapes for person/coin glyphs to avoid encoding issues"

patterns-established:
  - "All ResourceType switch statements are exhaustive — adding new resource type breaks compile and forces updates"
  - "Economy stream consumed via ref.watch in parent, passed as AsyncValue params to child widgets for testability"

requirements-completed: [ECON-01, ECON-02, ECON-03, ECON-04, ECON-05]

# Metrics
duration: 18min
completed: 2026-03-13
---

# Phase 10 Plan 03: Economy UI Summary

**Flutter economy UI: wine in resource bar, happiness/population indicators on city screen, and debounced wine spending slider in tavern sheet backed by Supabase Realtime**

## Performance

- **Duration:** 18 min
- **Started:** 2026-03-13T20:00:00Z
- **Completed:** 2026-03-13T20:18:00Z
- **Tasks:** 3 of 4 (Task 4 is checkpoint:human-verify — awaiting player verification)
- **Files modified:** 5

## Accomplishments

- Added `wine` to `ResourceType` enum and created `cityEconomyStreamProvider` watching `cities` table via Supabase Realtime
- Extended city screen resource panel with wine chip, happiness indicator, and population/tax summary row
- Added `_TavernWineSlider` to building upgrade sheet with 300ms debounce, displaying happiness contribution, wine/tick, and wine stock

## Task Commits

Each task was committed atomically:

1. **Task 1: Add wine to ResourceType + create cityEconomyStreamProvider** - `a348fba` (feat)
2. **Task 2: Add happiness indicator and population summary to city screen** - `8005e9c` (feat)
3. **Task 3: Add wine spending slider to tavern building upgrade sheet** - `26079c9` (feat)

## Files Created/Modified

- `lib/core/constants/resource_constants.dart` - Added `wine` member to ResourceType enum
- `lib/features/city/providers/city_economy_provider.dart` - New: StreamProvider watching cities table for population/happiness/wine_spending_rate
- `lib/features/city/screens/city_screen.dart` - Updated _ResourcePanel with wine chip, added _HappinessChip and _PopulationSummary widgets
- `lib/features/city/screens/building_upgrade_sheet.dart` - Added _TavernWineSlider with debounce + wine cases in switch statements
- `lib/features/map/screens/city_grid_screen.dart` - Added wine case to icon/color/label switch statements
- `lib/features/military/widgets/building_upgrade_card.dart` - Added wine case to _resourceIcon switch statement

## Decisions Made

- Wine icon uses `Icons.wine_bar` with `Colors.purple.shade600` for visual distinctiveness
- `_TavernWineSlider` only syncs initial value from stream on first emission — avoids fighting user's slider interaction mid-drag
- Happiness chip uses emoji text rather than `Icon` widget for compact display
- `_PopulationSummary` uses unicode escape sequences for person/coin emoji to avoid Windows file encoding issues

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed non-exhaustive switch statements for wine in city_grid_screen.dart**
- **Found during:** Task 3 (post-commit dart analyze of full lib/)
- **Issue:** Adding `wine` to `ResourceType` enum caused 3 exhaustive switch errors in `_icon`, `_color`, `_label` methods of city_grid_screen.dart
- **Fix:** Added `case ResourceType.wine:` returning `Icons.wine_bar`, `Colors.purple.shade600`, and `'Wine'`
- **Files modified:** `lib/features/map/screens/city_grid_screen.dart`
- **Verification:** `dart analyze lib/` — no errors
- **Committed in:** `26079c9` (Task 3 commit)

**2. [Rule 1 - Bug] Fixed non-exhaustive switch in building_upgrade_card.dart**
- **Found during:** Task 3 (post-commit dart analyze of full lib/)
- **Issue:** `_resourceIcon` switch in building_upgrade_card.dart missing wine case
- **Fix:** Added `case ResourceType.wine: return Icons.wine_bar;`
- **Files modified:** `lib/features/military/widgets/building_upgrade_card.dart`
- **Verification:** `dart analyze lib/` — no errors
- **Committed in:** `26079c9` (Task 3 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 - Bug, caused directly by adding wine to ResourceType enum)
**Impact on plan:** Both fixes necessary for compile-time correctness. No scope creep.

## Issues Encountered

None beyond the wine enum exhaustive-switch fixes above.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Economy UI layer complete; Task 4 is a human-verify checkpoint for end-to-end validation
- Player-visible loop requires a running Supabase instance with Phase 10-01 migrations applied and Phase 10-02 Edge Functions deployed
- After Task 4 approval, Phase 10 economy foundation is fully complete and Phase 11 (military) can proceed

---
*Phase: 10-economy-foundation*
*Completed: 2026-03-13*
