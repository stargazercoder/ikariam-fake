---
phase: 02-core-economy
plan: 03
subsystem: ui
tags: [flutter, dart, riverpod, supabase-realtime, streamProvider, economy, city-screen, bottom-sheet]

# Dependency graph
requires:
  - phase: 02-core-economy plan 01
    provides: city_resources, city_buildings, construction_queue tables with Realtime publication
  - phase: 02-core-economy plan 02
    provides: upgrade-building Edge Function; CityResource, CityBuilding, ConstructionQueueEntry models; BuildingType/ResourceType enums

provides:
  - ResourcesRepository: Supabase Realtime stream for city_resources via .stream(primaryKey)
  - BuildingsRepository: Supabase Realtime stream for city_buildings + upgradeBuilding() Edge Function call
  - BuildingUpgradeException: typed exception for server upgrade errors
  - resourcesStreamProvider: StreamProvider.autoDispose.family for real-time resource amounts
  - buildingsStreamProvider: StreamProvider.autoDispose.family for real-time building levels
  - constructionQueueProvider: StreamProvider.autoDispose.family for active construction queue entry or null
  - city_screen.dart: overhauled city screen with resource panel, construction banner, and building list
  - building_upgrade_sheet.dart: modal bottom sheet with upgrade cost/time breakdown and confirm/cancel
  - countdown_timer_widget.dart: standalone countdown timer ticking every second via Timer.periodic

affects:
  - 03-map-screen (may reuse StreamProvider patterns for island data)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - StreamProvider.autoDispose.family with cityId parameter for Supabase Realtime subscriptions
    - stream stored in local variable before returning to prevent Riverpod rebuild cancellation
    - Edge Function calls wrapped in typed BuildingUpgradeException for structured error handling
    - Timer.periodic(Duration(seconds: 1)) for display-only countdown — server handles actual completion
    - Building list grouped into city/production via buildingType.isProductionBuilding

key-files:
  created:
    - lib/features/city/data/resources_repository.dart
    - lib/features/city/data/buildings_repository.dart
    - lib/features/city/providers/resources_provider.dart
    - lib/features/city/providers/buildings_provider.dart
    - lib/features/city/providers/construction_provider.dart
    - lib/features/city/screens/building_upgrade_sheet.dart
    - lib/features/city/widgets/countdown_timer_widget.dart
  modified:
    - lib/features/city/screens/city_screen.dart

key-decisions:
  - "BuildingUpgradeException wraps server error message from Edge Function response JSON — allows UI to show specific messages like 'Construction queue is busy'"
  - "CountdownTimerWidget is display-only: Timer.periodic ticks the display every second but server pg_cron handles actual completion; widget fires optional onComplete callback when countdown hits zero"
  - "showBuildingUpgradeSheet uses standard showModalBottomSheet without ProviderScope.overrideFrom — bottom sheet context is already within the app ProviderScope"
  - "constructionQueueProvider streams construction_queue directly (not via a repository class) — table has no mutation logic client-side, repository abstraction would add no value"

patterns-established:
  - "StreamProvider.autoDispose.family: all real-time economy streams use this pattern with cityId as family param"
  - "Grouped building display: isProductionBuilding getter separates 10 city buildings from 4 production buildings in UI"
  - "Optimistic UI pattern: upgrade sheet disables confirm button client-side before calling Edge Function; server validation is authoritative"

requirements-completed: [RSRC-01, RSRC-02, RSRC-03, RSRC-04, BLDG-01, BLDG-02, BLDG-03, BLDG-04, BLDG-05]

# Metrics
duration: 5min
completed: 2026-03-11
---

# Phase 2 Plan 03: Flutter Economy UI Summary

**Riverpod StreamProvider layer + overhauled city screen showing live resources, 14-building grouped list, construction queue countdown, and modal upgrade sheet calling the Edge Function — full idle loop now playable in Flutter**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-03-11T02:05:22Z
- **Completed:** 2026-03-11T02:13:00Z
- **Tasks:** 2 auto + 1 human-verify checkpoint (pending verification)
- **Files modified:** 8 (7 created, 1 modified)

## Accomplishments

- Three Supabase Realtime StreamProviders (resources, buildings, construction queue) wrapping repository classes — all use `.stream(primaryKey: ['id'])` for live updates without polling
- BuildingsRepository.upgradeBuilding() calls the upgrade-building Edge Function and throws BuildingUpgradeException on server errors, enabling structured error messages in the UI
- City screen overhauled: resource panel (5 types with icons + live amounts), construction queue banner with ticking countdown, and building list (City Buildings / Production Buildings) tappable to upgrade
- BuildingUpgradeSheet shows cost breakdown with availability check (red = insufficient), build duration, confirm/cancel — blocks second upgrade when queue is busy

## Task Commits

Each task was committed atomically:

1. **Task 1: Repositories and Riverpod StreamProviders for economy data** - `7f2502c` (feat)
2. **Task 2: City screen overhaul with resources, buildings, and upgrade sheet** - `420722c` (feat)

**Task 3: Human verification pending (checkpoint:human-verify)**

## Files Created/Modified

- `lib/features/city/data/resources_repository.dart` - ResourcesRepository: watchCityResources() Realtime stream; resourcesRepositoryProvider
- `lib/features/city/data/buildings_repository.dart` - BuildingsRepository: watchCityBuildings() stream + upgradeBuilding() Edge Function invocation; BuildingUpgradeException
- `lib/features/city/providers/resources_provider.dart` - resourcesStreamProvider: StreamProvider.autoDispose.family<List<CityResource>, String>
- `lib/features/city/providers/buildings_provider.dart` - buildingsStreamProvider: StreamProvider.autoDispose.family<List<CityBuilding>, String>
- `lib/features/city/providers/construction_provider.dart` - constructionQueueProvider: StreamProvider.autoDispose.family<ConstructionQueueEntry?, String>
- `lib/features/city/screens/city_screen.dart` - Full overhaul: resource panel, construction banner, building list grouped by type
- `lib/features/city/screens/building_upgrade_sheet.dart` - Modal bottom sheet: cost breakdown, duration, confirm/cancel, upgrade-in-progress view
- `lib/features/city/widgets/countdown_timer_widget.dart` - CountdownTimerWidget: Timer.periodic(1s) countdown display

## Decisions Made

- **BuildingUpgradeException:** Typed exception class wraps the server error message from the Edge Function response JSON. This lets the UI show specific messages ("Construction queue is busy", "Insufficient wood") rather than generic errors.
- **No ProviderScope.overrideFrom in bottom sheet:** The modal bottom sheet builder context is already within the root ProviderScope. Wrapping it would require a non-existent API.
- **constructionQueueProvider uses direct supabaseClient:** The construction_queue table has no client-side mutation logic, so a dedicated ConstructionRepository class would add no value. The stream is built inline in the provider.
- **CountdownTimerWidget display-only:** The countdown is purely cosmetic — it does not trigger any action when it reaches zero. The server-side pg_cron complete_building_upgrades() handles actual completion and the buildingsStreamProvider emits the updated level automatically.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed unused supabase_flutter imports**
- **Found during:** Task 1 (flutter analyze after creating files)
- **Issue:** `supabase_flutter` was imported in resources_repository.dart, buildings_repository.dart, and construction_provider.dart but not used directly — supabaseClient is accessed via supabase_provider.dart
- **Fix:** Removed the three unused import statements
- **Files modified:** `lib/features/city/data/resources_repository.dart`, `lib/features/city/data/buildings_repository.dart`, `lib/features/city/providers/construction_provider.dart`
- **Verification:** `flutter analyze --no-fatal-infos` passes with 0 issues
- **Committed in:** `7f2502c` (part of Task 1 commit)

**2. [Rule 1 - Bug] Removed ProviderScope.overrideFrom call in bottom sheet**
- **Found during:** Task 2 (flutter analyze after creating building_upgrade_sheet.dart)
- **Issue:** `ProviderScope.overrideFrom(context, child: ...)` is not a valid API — method does not exist on ProviderScope
- **Fix:** Changed builder to pass `_BuildingUpgradeSheet(...)` directly without ProviderScope wrapper
- **Files modified:** `lib/features/city/screens/building_upgrade_sheet.dart`
- **Verification:** `flutter analyze --no-fatal-infos` passes with 0 issues
- **Committed in:** `420722c` (part of Task 2 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 — compile errors caught by flutter analyze)
**Impact on plan:** Both fixes were necessary for compilation. No scope changes.

## Issues Encountered

None beyond the two auto-fixed analyze errors above.

## User Setup Required

None — the UI connects to Supabase local dev via the existing supabaseClient global. Prerequisites for human verification (Supabase running + Flutter web running) are documented in the Task 3 checkpoint.

## Next Phase Readiness

- Full idle economy loop is playable: resources tick up via pg_cron, buildings can be upgraded, construction countdown is visible, Realtime pushes updates without page refresh
- Human verification (Task 3) still pending — game loop has not been end-to-end verified yet
- Phase 3 (Map Screen) can proceed once Task 3 verification is approved

---
*Phase: 02-core-economy*
*Completed: 2026-03-11*

## Self-Check: PASSED

All files verified present on disk. All commits verified in git log.

| Check | Result |
|-------|--------|
| lib/features/city/data/resources_repository.dart | FOUND |
| lib/features/city/data/buildings_repository.dart | FOUND |
| lib/features/city/providers/resources_provider.dart | FOUND |
| lib/features/city/providers/buildings_provider.dart | FOUND |
| lib/features/city/providers/construction_provider.dart | FOUND |
| lib/features/city/screens/city_screen.dart | FOUND |
| lib/features/city/screens/building_upgrade_sheet.dart | FOUND |
| lib/features/city/widgets/countdown_timer_widget.dart | FOUND |
| Commit 7f2502c (Task 1) | FOUND |
| Commit 420722c (Task 2) | FOUND |
