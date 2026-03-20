---
phase: 26-building-detail-sheet
plan: 01
subsystem: city-ui
tags: [bottom-sheet, building-detail, ui-scaffold, flutter]
dependency_graph:
  requires: []
  provides: [showBuildingDetailSheet, BuildingSheetHeader, BuildingSheetSection, BuildingSheetUpgradeActions]
  affects: [city_grid_screen.dart, building_upgrade_sheet.dart (superseded for most buildings)]
tech_stack:
  added: []
  patterns: [DraggableScrollableSheet, ConsumerStatefulWidget, showModalBottomSheet]
key_files:
  created:
    - lib/features/city/screens/building_detail_sheet.dart
    - lib/features/city/widgets/building_sheet_header.dart
    - lib/features/city/widgets/building_sheet_section.dart
    - lib/features/city/widgets/building_sheet_upgrade_actions.dart
    - lib/features/city/widgets/building_stats/town_hall_stats.dart
    - lib/features/city/widgets/building_stats/town_wall_stats.dart
    - lib/features/city/widgets/building_stats/hideout_stats.dart
    - lib/features/city/widgets/building_stats/trading_port_stats.dart
    - lib/features/city/widgets/building_stats/placeholder_stats.dart
  modified:
    - lib/features/map/screens/city_grid_screen.dart
decisions:
  - "Sheet stays open after upgrade (no Navigator.pop) — SnackBar feedback only; old dialog popped on success"
  - "go_router import removed from city_grid_screen.dart — no longer needed after eliminating barracks/shipyard context.push"
  - "PlaceholderStats used for Academy (Research) and Embassy (Alliance) — Plan 02 will replace with full content"
  - "Complex building types (warehouse, tavern, barracks, shipyard, production) use inline Text placeholder — Plan 02 replaces"
metrics:
  duration: 4m
  completed_date: "2026-03-20T20:15:45Z"
  tasks_completed: 2
  files_created: 9
  files_modified: 1
---

# Phase 26 Plan 01: Building Detail Sheet Scaffold Summary

Unified building detail bottom sheet with DraggableScrollableSheet, type-dispatched stats, and shared upgrade actions widget extracted from the old dialog.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Create shared widgets and building detail sheet scaffold | 85ab307 | 9 new files |
| 2 | Wire BuildingCell.onTap to new sheet for all 14 types | 26d3bee | city_grid_screen.dart |

## What Was Built

**9 new files created:**

- `building_detail_sheet.dart` — `showBuildingDetailSheet()` entry point with `DraggableScrollableSheet` (initialSize 0.85, min 0.5, max 0.95); `_BuildingDetailSheetContent` `ConsumerStatefulWidget` renders header + STATS section + ACTIONS section; `_buildStats()` switch dispatches all 14 `BuildingType` values
- `building_sheet_header.dart` — Row with canonical `buildingTypeIcon`/`buildingTypeColor` icon (size 32), name + level column, close `IconButton`; followed by `Divider`
- `building_sheet_section.dart` — Labeled section widget with uppercase grey title, divider, and child slot
- `building_sheet_upgrade_actions.dart` — Upgrade logic extracted from old `_BuildingUpgradeContent`: cost rows with `ResourceBadge`, build time, queue-busy warning, `Start Upgrade` button; upgrade-in-progress branch shows `CountdownTimerWidget` in `primaryContainer` box; does NOT pop sheet on success
- `town_hall_stats.dart` — Watches `cityEconomyStreamProvider`, shows population / `~(200 + level*50)` max / "Growth: Coming soon"
- `town_wall_stats.dart` — "Defense Bonus: +${level*10}%"
- `hideout_stats.dart` — "Resource Protection: X per resource" via `hideoutProtectionFloor(level)`
- `trading_port_stats.dart` — "Trade Capacity: ${100 + level*50} units"
- `placeholder_stats.dart` — Centered info icon + "[featureName]: Coming soon" for Academy/Embassy

**1 file modified:**

- `city_grid_screen.dart` — `BuildingCell.onTap` now calls `showBuildingDetailSheet` for all 14 types; removed special-cased `context.push('/barracks')` and `context.push('/shipyard')`; removed `building_upgrade_sheet.dart` and `go_router` imports

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

Files created:

- [x] lib/features/city/screens/building_detail_sheet.dart — FOUND
- [x] lib/features/city/widgets/building_sheet_header.dart — FOUND
- [x] lib/features/city/widgets/building_sheet_section.dart — FOUND
- [x] lib/features/city/widgets/building_sheet_upgrade_actions.dart — FOUND
- [x] lib/features/city/widgets/building_stats/town_hall_stats.dart — FOUND
- [x] lib/features/city/widgets/building_stats/town_wall_stats.dart — FOUND
- [x] lib/features/city/widgets/building_stats/hideout_stats.dart — FOUND
- [x] lib/features/city/widgets/building_stats/trading_port_stats.dart — FOUND
- [x] lib/features/city/widgets/building_stats/placeholder_stats.dart — FOUND

Commits exist:
- [x] 85ab307 — feat(26-01): create building detail sheet scaffold and shared widgets
- [x] 26d3bee — feat(26-01): wire BuildingCell.onTap to showBuildingDetailSheet for all 14 types

flutter analyze: 8 pre-existing issues (warnings/infos), 0 new errors from this plan.

## Self-Check: PASSED
