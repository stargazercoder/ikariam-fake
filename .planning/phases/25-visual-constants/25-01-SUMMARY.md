---
phase: 25-visual-constants
plan: "01"
subsystem: UI / constants
tags: [visual-constants, resource-badge, icon-system, refactor]
dependency_graph:
  requires: []
  provides: [visual_constants.dart, ResourceBadge widget]
  affects:
    - lib/features/city/screens/city_screen.dart
    - lib/features/map/screens/city_grid_screen.dart
    - lib/features/city/screens/building_upgrade_sheet.dart
    - lib/features/trade/screens/trade_dialog.dart
    - lib/features/battles/screens/widgets/pillage_result_card.dart
    - lib/features/espionage/screens/spy_report_dialog.dart
tech_stack:
  added: []
  patterns:
    - Map<EnumType, Color> and Map<EnumType, IconData> constant maps (matching unit_constants.dart pattern)
    - ResourceBadge StatelessWidget using CircleAvatar + letter for production, Icon for wine
key_files:
  created:
    - lib/core/constants/visual_constants.dart
    - lib/shared/widgets/resource_badge.dart
    - test/constants/visual_constants_test.dart
    - test/widgets/resource_badge_test.dart
  modified:
    - lib/features/city/screens/city_screen.dart
    - lib/features/map/screens/city_grid_screen.dart
    - lib/features/city/screens/building_upgrade_sheet.dart
    - lib/features/trade/screens/trade_dialog.dart
    - lib/features/battles/screens/widgets/pillage_result_card.dart
    - lib/features/espionage/screens/spy_report_dialog.dart
decisions:
  - "Wine uses Icon(Icons.wine_bar) not CircleAvatar+letter — per locked PROJECT.md decision"
  - "Wine letter is 'V' (Vinum/Latin) to avoid clash with Wood's 'W'"
  - "Wine color is Color(0xFF8E24AA) = purple.shade600 — matches locked PROJECT.md decision"
  - "ResourceBadge wraps both circle-letter and wine-icon patterns in single widget"
  - "String-keyed resource data (pillage, trade, spy report) converts via resourceTypeFromDbName() before badge lookup"
metrics:
  duration_minutes: 25
  completed_date: "2026-03-19"
  tasks_completed: 2
  files_created: 4
  files_modified: 6
---

# Phase 25 Plan 01: Visual Constants Summary

**One-liner:** Canonical `Map<ResourceType, Color/IconData/String>` and `Map<BuildingType, Color/IconData>` maps in `visual_constants.dart` plus a shared `ResourceBadge` widget eliminate 5 duplicate resource switch methods and 3 binary building icon conditionals across 6 UI files.

## Tasks Completed

| # | Name | Commit | Files |
|---|------|--------|-------|
| 1 | Create visual_constants.dart, ResourceBadge, and tests | 7c6e9c5 | visual_constants.dart, resource_badge.dart, 2 test files |
| 2 | Replace all ad-hoc resource/building icon logic in 6 files | 21b3c68 | 6 consumer files updated |

## What Was Built

### visual_constants.dart
- `resourceTypeColor`: Map<ResourceType, Color> — 6 entries (wood, marble, crystal, sulfur, gold, wine)
- `resourceTypeLetter`: Map<ResourceType, String> — W, M, C, S, G, V (wine='V' to avoid clash with Wood)
- `resourceTypeIcon`: Map<ResourceType, IconData> — 6 entries
- `buildingTypeColor`: Map<BuildingType, Color> — 14 entries with semantically distinct colors per building
- `buildingTypeIcon`: Map<BuildingType, IconData> — 14 entries replacing binary factory/home logic

### resource_badge.dart
- `ResourceBadge` widget — `CircleAvatar + letter` for production resources (wood, marble, crystal, sulfur, gold)
- Wine renders `Icon(Icons.wine_bar)` instead of circle+letter — per locked user decision

### 6 Consumer Files Updated
- `city_screen.dart`: `_ResourceChip._icon()/_color()` removed; `ResourceBadge` used; `_ProductionBreakdownSheet._resourceIcon()` removed; `resourceTypeIcon` map used
- `city_grid_screen.dart`: `_ResourceChip._icon()/_color()` removed (local duplicate copy); `ResourceBadge` used; `isProduction ? Icons.factory : Icons.home` replaced with `buildingTypeIcon` map; binary color replaced with `buildingTypeColor` map
- `building_upgrade_sheet.dart`: `_resourceIcon()` method removed; `ResourceBadge` used in cost rows; `isProductionBuilding ? Icons.factory : Icons.home` header icon replaced with `buildingTypeIcon` map
- `trade_dialog.dart`: top-level `_resourceIcon(String)` function removed; `_tradeResourceBadge()` helper added using `ResourceBadge` with `resourceTypeFromDbName()` conversion
- `pillage_result_card.dart`: `_iconForResource()` and `_colorForResource()` removed; `_resourceBadge()` helper using `ResourceBadge` with `resourceTypeFromDbName()` conversion and `Icons.help_outline` fallback
- `spy_report_dialog.dart`: `_resourceIcon()`, `_resourceColor()`, `_buildingIcon()` methods removed; new `_ResourceBadgeRow` widget added; `buildingTypeIcon` map used via `buildingTypeFromDbName()` with fallback

## Deviations from Plan

### Auto-fixed Issues

None. Plan executed exactly as written.

The plan anticipated `_SpyReportDialogContent._resourceRows()` needed refactoring — however, `_InfoRow` widget uses `IconData` not a `Widget`, so a new `_ResourceBadgeRow` widget was added alongside `_InfoRow` to handle resource rows with `ResourceBadge`. This is a minor structural choice (not an architectural deviation) — `_InfoRow` is kept for building rows which still use `IconData`.

## Test Results

- `test/constants/visual_constants_test.dart`: 18 tests — all pass
- `test/widgets/resource_badge_test.dart`: 7 tests — all pass
- `flutter analyze` on all 6 modified files: No issues found

## Self-Check: PASSED

Files confirmed present:
- lib/core/constants/visual_constants.dart — FOUND
- lib/shared/widgets/resource_badge.dart — FOUND
- test/constants/visual_constants_test.dart — FOUND
- test/widgets/resource_badge_test.dart — FOUND

Commits confirmed:
- 7c6e9c5 (Task 1) — FOUND
- 21b3c68 (Task 2) — FOUND
