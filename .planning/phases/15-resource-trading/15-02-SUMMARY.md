---
phase: 15-resource-trading
plan: 02
subsystem: trade-ui
tags: [trade, flutter, riverpod, island-screen, movements-screen]
dependency_graph:
  requires: [15-01]
  provides: [trade-ui-flow]
  affects: [island-screen, movements-screen]
tech_stack:
  added: []
  patterns: [ConsumerStatefulWidget, FutureProvider.autoDispose.family, Provider]
key_files:
  created:
    - lib/features/trade/data/trade_repository.dart
    - lib/features/trade/providers/trade_providers.dart
    - lib/features/trade/screens/trade_dialog.dart
  modified:
    - lib/features/map/screens/island_screen.dart
    - lib/features/movements/screens/movements_screen.dart
decisions:
  - "TradeRepository.sendTrade returns Map<String, dynamic> (not void) to surface travel_minutes from Edge Function response for success SnackBar"
  - "RecipientCityInfo._pow uses manual loop to avoid dart:math import duplication"
  - "Removed _showEnemyCityDialog from island_screen (dead code replaced by _showCityActionDialog)"
  - "Removed flutter/services.dart import from island_screen (Clipboard no longer used after removing old enemy dialog)"
metrics:
  duration_seconds: 276
  completed_date: "2026-03-16"
  tasks_completed: 2
  files_created: 3
  files_modified: 2
requirements: [TRAD-01]
---

# Phase 15 Plan 02: Flutter Trade Feature Summary

**One-liner:** TradeRepository + TradeDialog with resource sliders wired into island screen city taps and movements screen trade display.

## What Was Built

Complete Flutter trade UI connecting the send-trade Edge Function (Plan 01) to the player interface:

1. **TradeRepository** (`lib/features/trade/data/trade_repository.dart`) — mirrors `MilitaryRepository.dispatchUnits` pattern; invokes `send-trade` Edge Function with origin city, destination city, and cargo map; throws `TradeException` on non-200; returns response data including `travel_minutes` for the success SnackBar.

2. **Trade providers** (`lib/features/trade/providers/trade_providers.dart`) — `RecipientCityInfo` model with `remainingSpace()` helper; `recipientCityInfoProvider` fetches warehouse level from `city_buildings` and current amounts from `city_resources` for the recipient city.

3. **TradeDialog** (`lib/features/trade/screens/trade_dialog.dart`) — `showTradeDialog()` entry point; `_TradeDialogContent` is a `ConsumerStatefulWidget` with per-resource sliders (wood, marble, crystal, sulfur), live sender amounts via `resourcesStreamProvider`, recipient capacity via `recipientCityInfoProvider`, client-side travel time preview via `calcTravelMinutes`, Send Trade / Discard Trade buttons with loading states, and success/error SnackBars.

4. **Island screen integration** (`lib/features/map/screens/island_screen.dart`) — replaced dual `context.go('/city')` / `_showEnemyCityDialog` branches with a single `_showCityActionDialog` method that handles both cases: own city shows "Go to City" + "Trade"; enemy city shows "Trade" (primary) + "Attack" (error style).

5. **Movements screen patch** (`lib/features/movements/screens/movements_screen.dart`) — added `_movementIcon()` and `_movementColor()` top-level helpers; trade movements now display a green `Icons.local_shipping` icon and "Cargo shipment" label instead of the unit composition string.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Island class not imported in island_screen.dart**
- **Found during:** Task 2 (flutter analyze)
- **Issue:** `_showCityActionDialog` signature takes `Island island` parameter but `Island` was not directly imported; only `island_city_slot.dart` (which imports `island.dart` for its own use) was imported
- **Fix:** Added `import '../models/island.dart';` to island_screen.dart
- **Files modified:** lib/features/map/screens/island_screen.dart
- **Commit:** b3e0cf7

**2. [Rule 1 - Bug] Unused import after removing _showEnemyCityDialog**
- **Found during:** Task 2 (flutter analyze)
- **Issue:** `flutter/services.dart` was only used by `_showEnemyCityDialog` (Clipboard) — removing the old dialog left it unused
- **Fix:** Removed `import 'package:flutter/services.dart';`
- **Files modified:** lib/features/map/screens/island_screen.dart
- **Commit:** b3e0cf7

**3. [Rule 1 - Dead code] _showEnemyCityDialog became unreachable**
- **Found during:** Task 2 (flutter analyze unused_element warning)
- **Issue:** The old `_showEnemyCityDialog` method was no longer called after `_showCityActionDialog` replaced both code paths
- **Fix:** Removed the method entirely (its functionality is subsumed by `_showCityActionDialog`)
- **Files modified:** lib/features/map/screens/island_screen.dart
- **Commit:** b3e0cf7

## Commits

| Hash | Message |
|------|---------|
| 63dad37 | feat(15-02): add TradeRepository, trade providers, and TradeDialog |
| b3e0cf7 | feat(15-02): integrate trade into island screen and patch movements screen |

## Self-Check: PASSED
