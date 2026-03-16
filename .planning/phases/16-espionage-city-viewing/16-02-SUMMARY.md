---
phase: 16-espionage-city-viewing
plan: "02"
subsystem: espionage-ui
tags: [flutter, ui, espionage, spy, city-view, routing]
dependency_graph:
  requires: [16-01]
  provides: [spy-report-dialog, enemy-city-view-screen, spy-log-screen, island-spy-buttons, router-city-view-spy-log]
  affects: [island_screen, battles_screen, app_router, city_grid_screen]
tech_stack:
  added: []
  patterns: [ConsumerStatefulWidget auto-trigger, readOnly param propagation, GoRouter nested branch for bottom-nav preservation]
key_files:
  created:
    - lib/features/espionage/screens/spy_report_dialog.dart
    - lib/features/espionage/screens/spy_log_screen.dart
    - lib/features/map/screens/enemy_city_view_screen.dart
  modified:
    - lib/features/map/screens/city_grid_screen.dart
    - lib/features/map/screens/island_screen.dart
    - lib/core/router/app_router.dart
    - lib/features/battles/screens/battles_screen.dart
decisions:
  - "valueOrNull not available in Riverpod 3.x — use whenOrNull(data: (v) => v) instead"
  - "/city-view registered as top-level GoRoute (hides bottom nav); /spy-log nested in battles branch (keeps bottom nav)"
  - "Consumer(builder: (_, ref, _)) pattern used for hasSpiedProvider in island dialog (single underscore per lint rule)"
metrics:
  duration_seconds: 289
  completed_date: "2026-03-16"
  tasks_completed: 2
  tasks_total: 3
  files_created: 3
  files_modified: 4
---

# Phase 16 Plan 02: Espionage Flutter UI Summary

**One-liner:** Full espionage UI with auto-trigger spy dialog, read-only enemy city view (red AppBar), spy log screen, island menu integration, and GoRouter routes wired end-to-end.

## Objective

Build all Flutter UI for espionage: spy report dialog, enemy city view screen, spy log screen, and wire into island action menu and router.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add readOnly to BuildingsGrid/BuildingCell, create EnemyCityViewScreen and SpyReportDialog | 3130668 | city_grid_screen.dart, enemy_city_view_screen.dart, spy_report_dialog.dart |
| 2 | Create SpyLogScreen, wire island action dialog, register GoRouter routes | b4c3743 | spy_log_screen.dart, island_screen.dart, app_router.dart, battles_screen.dart |

## What Was Built

### Task 1

**city_grid_screen.dart** — `BuildingsGrid` and `BuildingCell` both gain a `readOnly: bool = false` constructor parameter. When `readOnly=true`, `BuildingCell.onTap` is `null` — no upgrade sheet opens, no barracks/shipyard navigation occurs.

**enemy_city_view_screen.dart** — New `EnemyCityViewScreen` widget:
- Red AppBar (`Colors.red.shade800`) with title `"$cityName ($ownerName)"`
- Red banner: "Viewing enemy city — read only"
- Optional `_EnemyConstructionBanner` (shows building name + countdown timer) if a construction is in progress
- `BuildingsGrid(readOnly: true, currentResources: const [])` — all cell taps suppressed

**spy_report_dialog.dart** — `showSpyReportDialog(context, targetCityId:, targetCityName:)`:
- `ConsumerStatefulWidget` auto-triggers `spyOnCity()` in `initState()` with loading spinner
- On success: shows resources (5 types with icons/amounts), buildings (with levels), army count
- On "gold" error: SnackBar "Not enough gold. You need 100 gold to spy."
- On other error: SnackBar "Spy action failed. Check your connection and try again."
- Actions: `FilledButton` "View City" (navigates to `/city-view` with encoded params) + `OutlinedButton` "Close Report"
- Invalidates `hasSpiedProvider` and `spyReportsProvider` on success

### Task 2

**spy_log_screen.dart** — `SpyLogScreen`:
- Watches `spyReportsProvider` for list of reports
- Empty state with `Icons.visibility_off`, friendly copy
- `_SpyLogTile`: `ListTile` with city name, formatted date ("Mar 16, 2026 · 14:32"), chevron; taps navigate to `/city-view`

**island_screen.dart** — Enemy city action dialog now has 4 buttons (top to bottom): Attack, Trade, Spy (100 gold), View City. The View City button uses `Consumer` + `hasSpiedProvider` — disabled with "(spy first)" text until player has spied.

**app_router.dart** — Two new routes:
- `/city-view` as top-level `GoRoute` (outside `StatefulShellRoute`) — intentionally hides bottom nav as full-screen detail
- `/spy-log` nested inside `_battlesNavigatorKey` `StatefulShellBranch` — bottom nav stays visible (Military tab sub-section, per CONTEXT.md locked decision)

**battles_screen.dart** — `AppBar` gains an `IconButton(Icons.visibility, tooltip: 'Spy Log')` that navigates to `/spy-log`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Riverpod 3.x does not expose `valueOrNull` on `AsyncValue`**
- **Found during:** Task 2
- **Issue:** Plan code used `.valueOrNull` on `AsyncValue<bool>` from `hasSpiedProvider`; Riverpod 3.3.x does not define this getter on `AsyncValue`
- **Fix:** Replaced with `.whenOrNull(data: (v) => v) ?? false` which is the correct Riverpod 3 pattern
- **Files modified:** lib/features/map/screens/island_screen.dart
- **Commit:** b4c3743

**2. [Rule 3 - Lint] Dart unnecessary_underscores info**
- **Found during:** Task 2 dart analyze
- **Issue:** `Consumer(builder: (_, ref, __))` triggers `unnecessary_underscores` lint (info level)
- **Fix:** Changed `__` to `_` → `Consumer(builder: (_, ref, _))`
- **Files modified:** lib/features/map/screens/island_screen.dart
- **Commit:** b4c3743

## Decisions Made

1. `valueOrNull` not available in Riverpod 3.x — use `whenOrNull(data: (v) => v)` instead.
2. `/city-view` registered as top-level GoRoute (hides bottom nav) — enemy city is a full-screen detail overlay.
3. `/spy-log` nested inside battles `StatefulShellBranch` (keeps bottom nav visible) per CONTEXT.md locked decision.

## Checkpoint Reached

Task 3 is `checkpoint:human-verify` — requires manual end-to-end verification of the complete espionage flow.

## Self-Check: PASSED

All created files exist on disk. Both task commits (3130668, b4c3743) verified in git log.
