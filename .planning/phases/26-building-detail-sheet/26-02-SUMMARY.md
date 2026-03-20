---
phase: 26-building-detail-sheet
plan: 02
subsystem: city-ui
tags: [building-sheet, tavern, warehouse, barracks, shipyard, production, downgrade, cleanup]
dependency_graph:
  requires:
    - 26-01 (building_detail_sheet.dart scaffold, BuildingSheetUpgradeActions)
    - plan-01 output: showBuildingDetailSheet, _buildStats switch, BuildingSheetSection
  provides:
    - TavernStats widget with wine spending slider
    - WarehouseStats widget with per-resource fill bars
    - ProductionBuildingStats widget with production breakdown
    - BarracksStats widget with unit training grid + roster
    - ShipyardStats widget with naval training grid + roster
    - downgrade-building Edge Function (50% refund, instant)
    - downgradeBuilding() repository method
    - downgradeRefund() Dart helper
    - Downgrade button with AlertDialog in upgrade actions widget
  affects:
    - building_detail_sheet.dart (switch now fully populated)
    - city_screen.dart (production breakdown sheet removed)
    - app_router.dart (barracks/shipyard routes removed)
tech_stack:
  added: []
  patterns:
    - ConsumerStatefulWidget with Timer debounce (TavernStats)
    - LinearProgressIndicator for fill bars (WarehouseStats)
    - productionBreakdownProvider.family watch (ProductionBuildingStats)
    - TextEditingController map for unit quantity inputs (Barracks/ShipyardStats)
    - Deno Edge Function with negative deduct_resource for credit (downgrade-building)
key_files:
  created:
    - lib/features/city/widgets/building_stats/tavern_stats.dart
    - lib/features/city/widgets/building_stats/warehouse_stats.dart
    - lib/features/city/widgets/building_stats/production_building_stats.dart
    - lib/features/city/widgets/building_stats/barracks_stats.dart
    - lib/features/city/widgets/building_stats/shipyard_stats.dart
    - supabase/functions/downgrade-building/index.ts
  modified:
    - lib/features/city/screens/building_detail_sheet.dart
    - lib/features/city/widgets/building_sheet_upgrade_actions.dart
    - lib/features/city/data/buildings_repository.dart
    - lib/core/constants/building_constants.dart
    - lib/features/city/screens/city_screen.dart
    - lib/core/router/app_router.dart
  deleted:
    - lib/features/military/screens/barracks_screen.dart
    - lib/features/military/screens/shipyard_screen.dart
    - lib/features/military/widgets/building_upgrade_card.dart
decisions:
  - downgradeRefund uses floor(50%) not ceil — player loses fractional resources on downgrade
  - Downgrade not gated by construction queue (instant, per locked plan decision)
  - Refund via negative p_amount to deduct_resource (SQL does amount - p_amount; negative adds)
  - Refund errors are non-fatal in Edge Function — building level already decremented
  - TavernStats reuses the exact _TavernWineSlider logic from building_upgrade_sheet.dart (not extracted from there; building_upgrade_sheet.dart still shows the old widget for dialog mode)
  - visual_constants.dart import removed from city_screen.dart after _ProductionBreakdownSheet deletion
metrics:
  duration: 9m
  completed: 2026-03-20
  tasks: 2
  files: 15
---

# Phase 26 Plan 02: Complex Stats Widgets + Downgrade Feature Summary

**One-liner:** Full per-building dynamic content (tavern wine slider, warehouse fill bars, production breakdown, barracks/shipyard training grids) plus instant downgrade with 50% refund and complete deprecated-screen cleanup.

## What Was Built

### Task 1: Complex Stats Widgets

Five stats widgets were created to replace placeholder text in the building detail sheet's `_buildStats()` switch:

1. **TavernStats** — Wine spending slider with 300ms debounced `setWineRate()` calls. Shows happiness contribution (`rate * level`), wine consumption per tick (`rate * level * 5`), and wine stock from the resources stream. Reads initial rate from `cityEconomyStreamProvider`.

2. **WarehouseStats** — For each of wood/marble/crystal/sulfur: a row with `ResourceBadge` + amount/capacity text + `LinearProgressIndicator`. Capacity calculated as `floor(500 * 1.5^level)` matching `warehouseCapacity()` from resource_constants.dart.

3. **ProductionBuildingStats** — Watches `productionBreakdownProvider((cityId, resourceTypeName))` and displays base/building/island/research breakdown rows plus a bold total. Replaces the old `_ProductionBreakdownSheet` in `city_screen.dart`.

4. **BarracksStats** — Full unit training grid for 8 land units with lock gating, TextEditingControllers for quantities, active training banner with `CountdownTimerWidget`, and army roster. Extracted from `barracks_screen.dart`.

5. **ShipyardStats** — Identical structure for 5 naval units. Extracted from `shipyard_screen.dart`.

`building_detail_sheet.dart` switch updated with all 5 real widget instances.

### Task 2: Downgrade Feature + Cleanup

**Backend:** `supabase/functions/downgrade-building/index.ts` — Deno Edge Function following the same auth/ownership pattern as `upgrade-building`. Validates level > 1, computes 50% refund via `calcUpgradeCost(type, currentLevel-1)`, decrements level, credits resources via `deduct_resource(-refundAmount)`.

**Dart helpers:** `downgradeRefund()` in `building_constants.dart` provides the refund map for UI display. `downgradeBuilding()` in `buildings_repository.dart` invokes the Edge Function.

**UI:** `BuildingSheetUpgradeActions` extended with `_isDowngrading` state, `_startDowngrade()` method showing an `AlertDialog` with the refund details, and an `OutlinedButton` visible only when `level > 1`.

**Cleanup:**
- `_ProductionBreakdownSheet` and `_BreakdownRow` classes removed from `city_screen.dart`
- The `showModalBottomSheet` onTap on production resource chips removed
- `/barracks` and `/shipyard` routes removed from `app_router.dart`
- `barracks_screen.dart`, `shipyard_screen.dart`, `building_upgrade_card.dart` deleted

## Deviations from Plan

None — plan executed exactly as written.

## Verification

- `flutter analyze --no-fatal-infos` passes with 0 errors (8 pre-existing warnings/infos unchanged)
- All 14 building types now show dynamic content in the detail sheet
- `downgrade-building/index.ts` exists and implements all required logic
- No `/barracks` or `/shipyard` routes remain in the codebase
- `_ProductionBreakdownSheet` class no longer exists in `city_screen.dart`
- `barracks_screen.dart`, `shipyard_screen.dart`, `building_upgrade_card.dart` deleted

## Self-Check: PASSED

Files created/exist:
- lib/features/city/widgets/building_stats/tavern_stats.dart: FOUND
- lib/features/city/widgets/building_stats/warehouse_stats.dart: FOUND
- lib/features/city/widgets/building_stats/production_building_stats.dart: FOUND
- lib/features/city/widgets/building_stats/barracks_stats.dart: FOUND
- lib/features/city/widgets/building_stats/shipyard_stats.dart: FOUND
- supabase/functions/downgrade-building/index.ts: FOUND
- lib/features/military/screens/barracks_screen.dart: NOT FOUND (deleted, correct)
- lib/features/military/screens/shipyard_screen.dart: NOT FOUND (deleted, correct)
- lib/features/military/widgets/building_upgrade_card.dart: NOT FOUND (deleted, correct)

Commits:
- 0f41e82: feat(26-02): create 5 complex stats widgets and update building detail sheet switch
- 9c1fe32: feat(26-02): add downgrade Edge Function, downgrade UI, and clean up deprecated files
