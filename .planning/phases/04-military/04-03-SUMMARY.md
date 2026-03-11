---
phase: 04-military
plan: "03"
subsystem: military-ui
tags: [flutter, riverpod, supabase-realtime, military, training, dispatch]
dependency_graph:
  requires: [04-02]
  provides: [military-screens, military-repository, training-ui, dispatch-ui]
  affects: [app-router, city-grid]
tech_stack:
  added: []
  patterns:
    - StreamProvider.autoDispose.family mirroring buildingsStreamProvider pattern
    - ConsumerStatefulWidget with TextEditingController per unit type
    - Edge Function invocation with structured exception types
    - GoRoute with queryParameters for cityId passing
key_files:
  created:
    - lib/features/military/data/military_repository.dart
    - lib/features/military/providers/training_queue_provider.dart
    - lib/features/military/providers/army_roster_provider.dart
    - lib/features/military/providers/unit_movements_provider.dart
    - lib/features/military/screens/barracks_screen.dart
    - lib/features/military/screens/shipyard_screen.dart
    - lib/features/military/screens/dispatch_screen.dart
  modified:
    - lib/core/router/app_router.dart
    - lib/features/map/screens/city_grid_screen.dart
decisions:
  - "[04-03]: TrainingBanner uses dynamic entry type to avoid tight coupling between screen and model import hierarchy"
  - "[04-03]: watchOutgoingMovements filters client-side by originCityId after owner_id stream — Realtime .stream() does not support compound eq filters"
  - "[04-03]: DispatchScreen syncs TextEditingControllers to roster in build() to avoid stale controller state on first render"
  - "[04-03]: Barracks/Shipyard taps in BuildingCell navigate to dedicated screens instead of upgrade sheet — military buildings need specialized UI"
metrics:
  duration_minutes: 4
  completed_date: "2026-03-11"
  tasks_completed: 3
  tasks_total: 3
  files_changed: 9
---

# Phase 4 Plan 3: Military UI Layer Summary

**One-liner:** MilitaryRepository with Realtime streams and Edge Function calls, 3 StreamProviders, BarracksScreen (8 land units with level gating), ShipyardScreen (5 naval units), DispatchScreen (unit selection + travel countdown), and router integration — completing the military vertical slice.

## What Was Built

### MilitaryRepository (`lib/features/military/data/military_repository.dart`)

Mirrors the BuildingsRepository pattern. Provides:
- `watchTrainingQueue(cityId)` — streams `training_queue` table, maps to `TrainingQueueEntry?` (null when queue empty)
- `watchArmyRoster(cityId)` — streams `city_units` table, maps to `List<CityUnit>`
- `watchOutgoingMovements(cityId)` — streams `unit_movements` filtered by `owner_id`, then filters client-side by `originCityId`
- `trainUnits()` — invokes `train-units` Edge Function, throws `TrainingException` on non-200
- `dispatchUnits()` — invokes `dispatch-units` Edge Function, throws `DispatchException` on non-200

### 3 StreamProviders

- `trainingQueueProvider` — `StreamProvider.autoDispose.family<TrainingQueueEntry?, String>`
- `armyRosterProvider` — `StreamProvider.autoDispose.family<List<CityUnit>, String>`
- `unitMovementsProvider` — `StreamProvider.autoDispose.family<List<UnitMovement>, String>`

All follow the `buildingsStreamProvider` / `constructionQueueProvider` pattern exactly.

### BarracksScreen (`lib/features/military/screens/barracks_screen.dart`)

- ConsumerStatefulWidget with `cityId` constructor param
- Watches `buildingsStreamProvider`, `trainingQueueProvider`, `armyRosterProvider`
- Reads barracks level from buildings stream
- Shows 8 land unit types with lock icon and "Requires Barracks Lv.X" when level too low
- Active training: `_TrainingBanner` card with unit name, quantity, and `CountdownTimerWidget`
- Train buttons disabled when queue busy
- `_TrainingException` SnackBar on error
- Dispatch IconButton in AppBar navigates to `/dispatch?cityId=X`
- Army roster at bottom filtered to land units

### ShipyardScreen (`lib/features/military/screens/shipyard_screen.dart`)

- Identical structure to BarracksScreen, showing 5 naval unit types
- Uses `BuildingType.shipyard` to derive shipyard level
- Roster filtered to naval units only

### DispatchScreen (`lib/features/military/screens/dispatch_screen.dart`)

- Target city ID TextField (UUID paste/type, v1 approach)
- Per-unit quantity inputs for each unit with quantity > 0
- `_canDispatch` guard: requires at least 1 unit and a target city ID
- `dispatchUnits()` call with SnackBar success/error feedback
- Active movements section with `CountdownTimerWidget` per movement

### Router Integration (`lib/core/router/app_router.dart`)

Added 3 GoRoutes to the city `StatefulShellBranch`:
- `/barracks?cityId=X` → `BarracksScreen`
- `/shipyard?cityId=X` → `ShipyardScreen`
- `/dispatch?cityId=X` → `DispatchScreen`

### City Grid Integration (`lib/features/map/screens/city_grid_screen.dart`)

`BuildingCell.onTap` now navigates to `/barracks?cityId=X` or `/shipyard?cityId=X` for military buildings instead of opening the upgrade sheet.

## Deviations from Plan

None — plan executed exactly as written.

## Auth Gates

None encountered.

## Checkpoint Status

**Task 3: Human Verification** — APPROVED

End-to-end military system verified: unit training (Barracks + Shipyard), army roster display, unit dispatch with travel countdown, and 409 rejection when queue busy.

## Self-Check

**Files created:**
- [x] lib/features/military/data/military_repository.dart
- [x] lib/features/military/providers/training_queue_provider.dart
- [x] lib/features/military/providers/army_roster_provider.dart
- [x] lib/features/military/providers/unit_movements_provider.dart
- [x] lib/features/military/screens/barracks_screen.dart
- [x] lib/features/military/screens/shipyard_screen.dart
- [x] lib/features/military/screens/dispatch_screen.dart

**Commits:**
- [x] d82b33e — feat(04-03): create MilitaryRepository, 3 StreamProviders, and 3 military screens
- [x] c7f3699 — feat(04-03): integrate military screens into app router and city grid
- [x] 773b3bd — fix(04-03): add building upgrade card to Barracks and Shipyard screens
- [x] 936e352 — fix(04-03): fix infinite width constraint in unit training row layout
- [x] 3029d39 — fix(04-03): wrap unit training row in LayoutBuilder with min-size Row
- [x] 9b033d5 — fix(04-03): give ElevatedButton explicit width to prevent infinite constraint

## Self-Check: PASSED
