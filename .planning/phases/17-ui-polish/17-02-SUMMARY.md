---
phase: 17-ui-polish
plan: "02"
subsystem: map-ui, military-ui
tags: [ui-polish, ownership-colors, unit-icons, circle-avatar, map-screen, military-screens]
one_liner: "Ownership color borders on map screens and CircleAvatar unit icons on all military screens using Plan 01 constants"

dependency_graph:
  requires:
    - "17-01-SUMMARY.md (OwnershipColors, unitTypeIcons, unitTypeColors constants)"
  provides:
    - "UIPL-02: Island screen and world map ownership color borders"
    - "UIPL-03: Military screen CircleAvatar unit icons"
  affects:
    - "lib/features/map/screens/island_screen.dart"
    - "lib/features/map/screens/world_map_screen.dart"
    - "lib/features/map/providers/islands_provider.dart"
    - "lib/features/military/screens/barracks_screen.dart"
    - "lib/features/military/screens/shipyard_screen.dart"
    - "lib/features/military/screens/dispatch_screen.dart"
    - "lib/features/battles/screens/battle_detail_screen.dart"

tech_stack:
  added: []
  patterns:
    - "islandOwnershipProvider: FutureProvider querying cities table for owner_id to derive own/enemy/empty status"
    - "CircleAvatar with unitTypeColors background + unitTypeIcons icon, radius 16 for roster/dispatch, radius 10 for battle detail compact rows"
    - "valueOrNull not available in Riverpod 3.x — use whenOrNull(data: (v) => v) for AsyncValue unwrap"

key_files:
  created: []
  modified:
    - "lib/features/map/screens/island_screen.dart: OwnershipColors.own/enemy/empty borders on _CitySlotCell, radius 8, width 2px"
    - "lib/features/map/providers/islands_provider.dart: Added islandOwnershipProvider (Supabase cities query)"
    - "lib/features/map/screens/world_map_screen.dart: _IslandCell now accepts ownershipStatus, _IslandGrid watches islandOwnershipProvider"
    - "lib/features/military/screens/barracks_screen.dart: CircleAvatar in training banner and roster"
    - "lib/features/military/screens/shipyard_screen.dart: CircleAvatar in training banner and roster"
    - "lib/features/military/screens/dispatch_screen.dart: CircleAvatar in dispatch row, removed _isNaval helper"
    - "lib/features/battles/screens/battle_detail_screen.dart: Compact CircleAvatar (radius 10) in army column unit rows"

decisions:
  - id: "17-02-a"
    summary: "valueOrNull not in Riverpod 3.x — world_map_screen uses whenOrNull(data: (v) => v) instead, consistent with Phase 16 constraint"
  - id: "17-02-b"
    summary: "Removed _isNaval helper from _UnitDispatchRow — no longer needed once CircleAvatar is the primary icon path; fallback uses Icons.help_outline"
  - id: "17-02-c"
    summary: "Training banner icons in barracks/shipyard use CircleAvatar only when unitType parses successfully; falls back to Icons.shield/sailing for unknown entries"

metrics:
  duration_minutes: 4
  completed_date: "2026-03-17"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 7
  commits: 2
---

# Phase 17 Plan 02: UI Polish — Ownership Borders and Unit Icons Summary

Ownership color borders (green/red/grey) on island screen and world map, plus CircleAvatar unit type icons on all four military screens using Plan 01 constants.

## Tasks Completed

| # | Task | Commit | Key Changes |
|---|------|--------|-------------|
| 1 | Ownership color borders on island screen and world map | 3e3ff80 | island_screen.dart, world_map_screen.dart, islands_provider.dart |
| 2 | CircleAvatar unit type icons on all military screens | 7cdbf82 | barracks_screen.dart, shipyard_screen.dart, dispatch_screen.dart, battle_detail_screen.dart |

## What Was Built

**Task 1 — Ownership Color Borders:**
- `island_screen.dart`: `_CitySlotCell` now uses `OwnershipColors.own` (green) for player-owned slots, `OwnershipColors.enemy` (red) for enemy slots, and `OwnershipColors.empty` (grey) for empty slots. Border radius updated from 6 to 8, width to 2px for both empty and occupied states.
- `islands_provider.dart`: New `islandOwnershipProvider` added as `FutureProvider<Map<String, String>>`. Queries the `cities` table selecting `island_id` and `owner_id`, builds a map where own cities take priority. Returns `'own'`, `'enemy'`, or absent key.
- `world_map_screen.dart`: `_IslandGrid` watches `islandOwnershipProvider` and passes `ownershipStatus` to each `_IslandCell`. `_IslandCell` gains an `ownershipStatus` field and `_ownershipBorderColor()` helper that returns `OwnershipColors.own/enemy/empty` — only the border changes, background fill remains luxury-type based.

**Task 2 — CircleAvatar Unit Icons:**
- `barracks_screen.dart` and `shipyard_screen.dart`: Training banner uses `CircleAvatar(radius: 16)` with `unitTypeColors` background and `unitTypeIcons` icon when unit type parses; falls back to `Icons.shield`/`Icons.sailing` for unknown entries. Roster `ListTile.leading` replaced with `CircleAvatar` via `Builder`.
- `dispatch_screen.dart`: `_UnitDispatchRow` leading icon replaced with `CircleAvatar`. The `_isNaval` helper removed as no longer needed. Fallback uses `Icons.help_outline`.
- `battle_detail_screen.dart`: `_ArmyColumn` unit row adds `CircleAvatar(radius: 10)` as a compact leading icon before the unit name text.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Riverpod 3.x does not expose `valueOrNull` on `AsyncValue`**
- **Found during:** Task 1 — world_map_screen.dart
- **Issue:** `ownershipAsync.valueOrNull` caused a compile error (`undefined_getter`) — same constraint documented in Phase 16 decisions.
- **Fix:** Used `ownershipAsync.whenOrNull(data: (v) => v) ?? {}` instead.
- **Files modified:** lib/features/map/screens/world_map_screen.dart
- **Commit:** 3e3ff80

**2. [Rule 1 - Bug] Unused `theme` variable in `_CitySlotCell.build()`**
- **Found during:** Task 1 — island_screen.dart flutter analyze
- **Issue:** After replacing `theme.colorScheme.primary/secondary` with `OwnershipColors`, the `final theme = Theme.of(context)` line became unused.
- **Fix:** Removed the unused variable declaration.
- **Files modified:** lib/features/map/screens/island_screen.dart
- **Commit:** 3e3ff80

**3. [Rule 1 - Bug] Unused `isNaval` variable in dispatch_screen.dart**
- **Found during:** Task 2 — dispatch_screen.dart flutter analyze
- **Issue:** After replacing the `isNaval ? Icons.sailing : Icons.shield` expression with `CircleAvatar`, `final isNaval = _isNaval(unit.unitType)` became unused.
- **Fix:** Removed the variable and the now-unused `_isNaval` helper method.
- **Files modified:** lib/features/military/screens/dispatch_screen.dart
- **Commit:** 7cdbf82

## Verification

```
flutter analyze lib/features/map/screens/island_screen.dart \
  lib/features/map/screens/world_map_screen.dart \
  lib/features/map/providers/islands_provider.dart \
  lib/features/military/screens/barracks_screen.dart \
  lib/features/military/screens/shipyard_screen.dart \
  lib/features/military/screens/dispatch_screen.dart \
  lib/features/battles/screens/battle_detail_screen.dart

No issues found! (7 files analyzed)
```

## Self-Check: PASSED

All 7 modified files confirmed present on disk. Both task commits (3e3ff80, 7cdbf82) confirmed in git log. SUMMARY.md confirmed created.
