---
phase: 03-world-map
plan: 01
subsystem: ui
tags: [flutter, riverpod, go_router, supabase, navigation]

# Dependency graph
requires:
  - phase: 03-00
    provides: Wave 0 test scaffolds for map_models_test.dart with 3 skipped stubs
  - phase: 02-core-economy
    provides: CityScreen, BuildingType enum, Supabase schema with islands/cities tables

provides:
  - Island data model with fromJson parsing grid_x, grid_y, luxury_type, max_city_slots
  - CitySlot data model with isOccupied getter
  - IslandDetail aggregate model with cityCount getter
  - MapRepository with fetchAllIslands() and fetchIslandDetail()
  - allIslandsProvider, islandDetailProvider.family, selectedIslandIdProvider
  - MainShellScreen with NavigationBar 3-tab bottom nav (World/Island/City)
  - StatefulShellRoute with branches at /map, /island, /city
  - seed.sql reduced to 10 islands in 5x2 grid

affects:
  - 03-02 (World Map screens that will replace placeholder widgets at /map and /island)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - StatefulShellRoute.indexedStack with file-level GlobalKey navigator keys
    - FutureProvider.family for parameterized async data
    - StateProvider for cross-tab state (selectedIslandIdProvider)

key-files:
  created:
    - lib/features/map/models/island.dart
    - lib/features/map/models/island_city_slot.dart
    - lib/features/map/data/map_repository.dart
    - lib/features/map/providers/islands_provider.dart
    - lib/features/map/providers/island_detail_provider.dart
    - lib/features/map/screens/main_shell_screen.dart
  modified:
    - lib/core/router/app_router.dart
    - supabase/seed.sql
    - test/unit/map_models_test.dart

key-decisions:
  - "File-level GlobalKey<NavigatorState> variables for StatefulShellBranch — must not be inside build or provider to avoid recreation"
  - "NavigationBar (Material 3) used instead of BottomNavigationBar — app_theme.dart has useMaterial3: true"
  - "Auth Rule 4 redirect changed from '/city' to '/map' — post-login landing is now the world map"
  - "_WorldMapPlaceholder and _IslandPlaceholder widgets are private to app_router.dart — replaced in Plan 03-02"

patterns-established:
  - "Shell navigation: StatefulShellRoute.indexedStack in routes array at same level as auth GoRoutes"
  - "Cross-tab selection state: StateProvider<String?> pattern for selectedIslandIdProvider"

requirements-completed: [MAP-01, MAP-02, MAP-03, MAP-05]

# Metrics
duration: 3min
completed: 2026-03-11
---

# Phase 3 Plan 01: World Map Data Layer Summary

**Island/IslandDetail models with MapRepository, Riverpod providers, StatefulShellRoute 3-tab navigation, and seed reduced to 10 islands in a 5x2 grid**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-11T09:19:39Z
- **Completed:** 2026-03-11T09:22:29Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Island, CitySlot, and IslandDetail models parse Supabase JSON with sensible defaults for missing fields
- MapRepository provides fetchAllIslands() and fetchIslandDetail() with proper ordering and joins
- allIslandsProvider, islandDetailProvider.family, and selectedIslandIdProvider wire the repository into Riverpod
- MainShellScreen with NavigationBar (Material 3) renders 3 tabs and delegates to StatefulNavigationShell
- StatefulShellRoute.indexedStack replaces single /city route with /map, /island, /city branches
- Auth Rule 4 redirect updated to send authenticated users with complete profiles to /map instead of /city
- seed.sql now generates 10 islands (5x2 grid) down from 100 (10x10)

## Task Commits

Each task was committed atomically:

1. **Task 1: Island models, repository, providers, and unit tests** - `fdba5ef` (feat)
2. **Task 2: Seed migration update and StatefulShellRoute navigation shell** - `7c13bd6` (feat)

## Files Created/Modified

- `lib/features/map/models/island.dart` - Island model with fromJson; handles null fields with defaults
- `lib/features/map/models/island_city_slot.dart` - CitySlot (isOccupied getter) and IslandDetail (cityCount getter)
- `lib/features/map/data/map_repository.dart` - MapRepository with fetchAllIslands/fetchIslandDetail + mapRepositoryProvider
- `lib/features/map/providers/islands_provider.dart` - allIslandsProvider (FutureProvider) + selectedIslandIdProvider (StateProvider)
- `lib/features/map/providers/island_detail_provider.dart` - islandDetailProvider (FutureProvider.family)
- `lib/features/map/screens/main_shell_screen.dart` - MainShellScreen with NavigationBar 3-tab bottom nav
- `lib/core/router/app_router.dart` - StatefulShellRoute.indexedStack with 3 branches; Rule 4 → /map
- `supabase/seed.sql` - Changed to 5x2 grid (10 islands total)
- `test/unit/map_models_test.dart` - 3 unit tests un-skipped and implemented (all pass)

## Decisions Made

- File-level `GlobalKey<NavigatorState>` for each branch navigator key — must not live inside `Provider` or `build` callbacks to avoid being recreated on each provider evaluation.
- `NavigationBar` (Material 3) used instead of `BottomNavigationBar` — confirmed `useMaterial3: true` in `app_theme.dart`.
- Auth redirect Rule 4 changed from `'/city'` to `'/map'` — the world map is the correct post-login landing screen for a game with a world map feature.
- Placeholder widgets `_WorldMapPlaceholder` and `_IslandPlaceholder` are private file-level classes in `app_router.dart` — they serve as temporary builders until Plan 03-02 replaces them with actual screen widgets.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 03-02 can immediately begin building WorldMapScreen and IslandScreen — both routes exist at `/map` and `/island` with placeholder builders ready to be replaced
- allIslandsProvider, islandDetailProvider, and selectedIslandIdProvider are available for Plan 03-02 screens
- CityScreen continues to work unchanged in the City tab at `/city`

---
*Phase: 03-world-map*
*Completed: 2026-03-11*
