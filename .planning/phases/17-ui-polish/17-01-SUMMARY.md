---
phase: 17-ui-polish
plan: "01"
subsystem: ui-constants
tags: [ui, constants, appbar, flutter]
dependency_graph:
  requires: []
  provides: [ownership_colors, unitTypeIcons, transparent-appbar-pattern]
  affects: [city_screen, enemy_city_view_screen, future-plan-02-consumers]
tech_stack:
  added: []
  patterns: [transparent-appbar, extendBodyBehindAppBar, drop-shadow-icons]
key_files:
  created:
    - lib/core/constants/ownership_colors.dart
  modified:
    - lib/core/constants/unit_constants.dart
    - lib/features/city/screens/city_screen.dart
    - lib/features/map/screens/enemy_city_view_screen.dart
decisions:
  - "CityScreen city name uses white color + drop shadow instead of primary color — visible over any background with transparent AppBar"
  - "EnemyCityViewScreen banner text updated to include cityName+ownerName since AppBar title is gone"
  - "EnemyCityViewScreen body wrapped in Padding (not SafeArea) so Column expands to fill remaining height correctly"
metrics:
  duration: "3m"
  completed_date: "2026-03-17"
  tasks_completed: 2
  files_changed: 4
requirements: [UIPL-01]
---

# Phase 17 Plan 01: Foundation Constants and Transparent AppBar Summary

Ownership color constants + unit type icon map created; transparent AppBar with drop-shadow icons deployed on CityScreen and EnemyCityViewScreen.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create ownership_colors.dart and add unitTypeIcons | bbb7641 | ownership_colors.dart (new), unit_constants.dart |
| 2 | Transparent AppBar on CityScreen and EnemyCityViewScreen | 25a1427 | city_screen.dart, enemy_city_view_screen.dart |

## What Was Built

### lib/core/constants/ownership_colors.dart (new)
- `class OwnershipColors` with private constructor
- `static const Color own = Color(0xFF43A047)` — green (own city)
- `static const Color enemy = Color(0xFFE53935)` — red (enemy city)
- `static const Color empty = Color(0xFFBDBDBD)` — grey (empty slot)
- Single source of truth for all city/map ownership coloring; Plan 02 imports from here

### lib/core/constants/unit_constants.dart (modified)
- Added `const Map<UnitType, IconData> unitTypeIcons` with 13 entries
- All UnitType values covered: hoplite through divingBoat
- Inserted after `unitTypeColors` map, before `orderedLandTypes` list
- Plan 02 military screen CircleAvatars will use these icons

### lib/features/city/screens/city_screen.dart (modified)
- Added `extendBodyBehindAppBar: true` to Scaffold
- AppBar: `backgroundColor: Colors.transparent`, elevation 0, no title
- AppBar icons (back, sign-out) and action text get `Shadow(blurRadius: 4, color: Colors.black54)` for visibility
- `_CityBody` SingleChildScrollView padding: `top = MediaQuery.padding.top + kToolbarHeight + 8` so city name heading is below status bar + AppBar
- City name heading: `color: Colors.white` with drop shadow (was `colorScheme.primary`)

### lib/features/map/screens/enemy_city_view_screen.dart (modified)
- Added `extendBodyBehindAppBar: true` to Scaffold
- AppBar: `backgroundColor: Colors.transparent`, elevation 0, no title, icon drop shadows
- Removed `backgroundColor: Colors.red.shade800` and `foregroundColor: Colors.white` and `title: Text(...)`
- Read-only banner text updated: `'Viewing $cityName ($ownerName) — read only'`
- Body wrapped in `Padding(top: MediaQuery.padding.top + kToolbarHeight)` to position content below transparent AppBar

## Deviations from Plan

None — plan executed exactly as written.

## Verification

- `flutter analyze` passes on all 4 files with no issues
- `OwnershipColors` has correct hex values (#43A047, #E53935, #BDBDBD)
- `unitTypeIcons` has exactly 13 entries matching all UnitType enum values
- CityScreen: `extendBodyBehindAppBar: true`, `Colors.transparent` AppBar, no `title: cityAsync.when`, has `kToolbarHeight` and `Shadow` in padding/icons
- EnemyCityViewScreen: `extendBodyBehindAppBar: true`, `Colors.transparent` AppBar, `Colors.red.shade800` only in banner (icon/text), banner contains "Viewing" and "read only"

## Self-Check: PASSED
