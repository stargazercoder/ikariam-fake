---
phase: 03-world-map
plan: 02
subsystem: ui
tags: [flutter, riverpod, go_router, interactive_viewer, world_map, island_view, city_grid]

# Dependency graph
requires:
  - phase: 03-01
    provides: Island models, MapRepository, providers (allIslandsProvider, selectedIslandIdProvider, islandDetailProvider), StatefulShellRoute navigation shell

provides:
  - WorldMapScreen with InteractiveViewer pan/zoom over 5x5 island grid
  - IslandScreen showing city slots and resource areas per island
  - CityGridScreen with Stack-based spatial building grid
  - kBuildingPositions constant mapping all 14 BuildingType values to (row, col)
  - playerIslandIdProvider for default island on IslandScreen
  - Unit tests for building position completeness and uniqueness
  - Widget smoke test for WorldMapScreen rendering

affects:
  - 04-military (navigation shell and city grid are the base layer for military dispatch UI)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - InteractiveViewer wrapping GridView for pannable/zoomable world map
    - Stack + Positioned for spatial building grid layout
    - context.go('/route') for cross-tab navigation (not goBranch)
    - playerIslandIdProvider as FutureProvider deriving player's island from cityProvider

key-files:
  created:
    - lib/features/map/constants/building_positions.dart
    - lib/features/map/screens/city_grid_screen.dart
  modified:
    - lib/features/map/screens/world_map_screen.dart
    - lib/features/map/screens/island_screen.dart
    - lib/features/map/providers/islands_provider.dart
    - lib/core/router/app_router.dart
    - supabase/seed.sql
    - test/unit/city_grid_test.dart
    - test/widget/world_map_smoke_test.dart

key-decisions:
  - "5x5 world map grid (not 5x2): checkpoint feedback revealed 5x2 was too small; expanded to 5x5 matching seed data"
  - "playerIslandIdProvider added to islands_provider.dart: IslandScreen needs a default island when selectedIslandIdProvider is null; derives island_id from cityProvider"
  - "context.go('/island') used for cross-tab navigation — not goBranch — consistent with research recommendation"
  - "Building upgrade 503 error is an Edge Function deploy issue, out of scope for this plan"

patterns-established:
  - "kBuildingPositions: const Map<BuildingType, ({int row, int col})> — single source of truth for building grid layout"
  - "CityGridScreen wraps city data into spatial Stack grid; resource panel and construction banner stay above the grid"
  - "IslandScreen uses effectiveIslandId = selectedId ?? playerIslandId to handle both direct navigation and tab switch"

requirements-completed: [MAP-01, MAP-02, MAP-03, MAP-04, MAP-05]

# Metrics
duration: ~45min
completed: 2026-03-11
---

# Phase 3 Plan 02: World Map Screens Summary

**WorldMapScreen, IslandScreen, and CityGridScreen implementing full 3-tab spatial navigation with 5x5 interactive grid, island detail view, and Stack-based building grid with kBuildingPositions for all 14 building types**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-03-11 (session)
- **Completed:** 2026-03-11
- **Tasks:** 2 (1 auto + 1 checkpoint:human-verify)
- **Files modified:** 9

## Accomplishments

- WorldMapScreen renders 5x5 island grid wrapped in InteractiveViewer for pan/zoom; tapping any island sets selectedIslandIdProvider and navigates to the Island tab
- IslandScreen shows city slots and resource areas per island with player-owned slots highlighted; defaults to player's own island via playerIslandIdProvider when no island is selected
- CityGridScreen renders all city buildings as positioned tiles on a Stack-based spatial grid using kBuildingPositions; tap-to-upgrade preserved via showBuildingUpgradeSheet
- Building positions constant maps all 14 BuildingType values to unique (row, col) cells in a 6-column x 5-row grid with zero collisions — verified by unit tests

## Task Commits

Each task was committed atomically:

1. **Task 1: Building positions, WorldMap, Island, CityGrid screens** - `4fba1f3` (feat)
2. **Task 2: Human verification fixes (5x5 grid, island loading)** - `2b379e8` (fix)

## Files Created/Modified

- `lib/features/map/constants/building_positions.dart` — const kBuildingPositions map for all 14 BuildingType values
- `lib/features/map/screens/world_map_screen.dart` — InteractiveViewer + GridView 5x5 island grid (replaced placeholder)
- `lib/features/map/screens/island_screen.dart` — city slots + resource areas, effectiveIslandId logic (replaced placeholder)
- `lib/features/map/screens/city_grid_screen.dart` — Stack-based spatial building grid with Positioned tiles (created)
- `lib/features/map/providers/islands_provider.dart` — added playerIslandIdProvider derived from cityProvider
- `lib/core/router/app_router.dart` — updated routes to wire real screen classes
- `supabase/seed.sql` — updated world map layout to 5x5 (was 5x2)
- `test/unit/city_grid_test.dart` — un-skipped and implemented 2 building position tests
- `test/widget/world_map_smoke_test.dart` — un-skipped and implemented WorldMapScreen smoke test

## Decisions Made

- Expanded world map grid from 5x2 to 5x5: checkpoint user feedback identified 5x2 as too small; seed.sql and WorldMapScreen updated together in the fix commit
- Added playerIslandIdProvider to islands_provider.dart: IslandScreen was stuck in a loading loop when no island was selected because it had no fallback; the new provider derives the player's island from cityProvider
- Building upgrade 503 errors are an Edge Function deploy issue (not application code) — deferred as out of scope

## Deviations from Plan

### Auto-fixed Issues (post-checkpoint)

**1. [Rule 1 - Bug] World map 5x2 grid too small — expanded to 5x5**
- **Found during:** Task 2 checkpoint user verification
- **Issue:** WorldMapScreen sized for 5 columns x 2 rows; player feedback indicated the world map should be 5x5
- **Fix:** Updated seed.sql grid layout to 5x5 and WorldMapScreen SizedBox height to match 5 rows
- **Files modified:** supabase/seed.sql, lib/features/map/screens/world_map_screen.dart
- **Verification:** User re-tested and approved visual layout
- **Committed in:** 2b379e8

**2. [Rule 1 - Bug] Island tab stuck in loading on first tap**
- **Found during:** Task 2 checkpoint user verification
- **Issue:** IslandScreen had no fallback island ID when selectedIslandIdProvider was null (fresh session, no tap yet) — infinite loading spinner
- **Fix:** Added playerIslandIdProvider (FutureProvider) that reads cityProvider and extracts island_id; IslandScreen uses effectiveIslandId = selectedId ?? playerIslandId
- **Files modified:** lib/features/map/providers/islands_provider.dart, lib/features/map/screens/island_screen.dart
- **Verification:** Island tab now shows player's own island immediately on tab switch without prior world map tap
- **Committed in:** 2b379e8

---

**Total deviations:** 2 auto-fixed post-checkpoint (2 bugs caught during human verification)
**Impact on plan:** Both fixes essential for correct navigation behavior. Grid size correction aligns with intended 5x5 world. No scope creep.

## Issues Encountered

- Building upgrade Edge Function returning 503 errors during checkpoint testing — this is a deploy/infrastructure issue outside the scope of this plan. The upgrade flow code itself is unchanged from Phase 2. Deferred to a future ops task.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Full 3-tab navigation is operational: World Map -> Island -> City grid
- All MAP requirements (MAP-01 through MAP-05) are satisfied and human-verified
- Phase 4 (Military) can begin: navigation shell, city grid, and building positions are the base layer for military dispatch and unit training UI
- Blocker: Building upgrade 503 Edge Function deploy issue should be investigated before Phase 4 adds more Edge Functions

---
*Phase: 03-world-map*
*Completed: 2026-03-11*
