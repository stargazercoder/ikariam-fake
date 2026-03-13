---
phase: 11-island-upgrades-resource-rate-ui
plan: "02"
subsystem: economy-ui
tags: [flutter, riverpod, production-rates, island-upgrades, ui]
dependency_graph:
  requires: ["11-01"]
  provides: ["island-resource-level-ui", "production-rate-display", "donate-wood-ui"]
  affects: ["city-screen", "island-screen"]
tech_stack:
  added: []
  patterns: ["ConsumerWidget for rate display", "showModalBottomSheet for breakdown", "showDialog for donate flow"]
key_files:
  created:
    - lib/core/constants/island_constants.dart
    - lib/features/city/providers/production_rate_provider.dart
  modified:
    - lib/features/map/models/island.dart
    - lib/features/city/screens/city_screen.dart
    - lib/features/map/screens/island_screen.dart
decisions:
  - "productionRateProvider uses Provider.autoDispose.family (not StreamProvider) — rates are derived from existing streams, not a new stream"
  - "productionBreakdownProvider takes (String, String) record tuple as family param — cityId + resourceTypeName"
  - "_ResourcePanel converted from StatelessWidget to ConsumerWidget to watch productionRateProvider inline"
  - "_DonateWoodDialog is StatefulWidget to manage donating spinner state"
  - "buildingBonus clamped to 0.0 minimum to avoid negative display when building level is 0"
metrics:
  duration: "~25 min"
  completed_date: "2026-03-14"
  tasks_completed: 3
  tasks_total: 4
  files_modified: 5
---

# Phase 11 Plan 02: Island Upgrade + Resource Rate UI Summary

One-liner: Flutter UI for island wood donation with donate dialog calling Edge Function, and +X/hr production rate labels on city screen resource chips with tappable 4-row breakdown sheet.

## What Was Built

### Task 1 — Island model extension + constants + production rate provider (c218b40)

Extended `Island.fromJson` to parse `resource_level` from Supabase JSON (default 0 if null).

Created `lib/core/constants/island_constants.dart` with:
- `islandDonationCost(int currentLevel)` — formula: `ceil(300 * 1.5^level)`, mirrors Edge Function
- `islandMultiplier(int resourceLevel)` — 1.0 + level * 0.10 (Level 0 = 1.0x, Level 10 = 2.0x)
- `maxIslandResourceLevel = 10`

Created `lib/features/city/providers/production_rate_provider.dart`:
- `productionRateProvider(cityId)` — `Provider.autoDispose.family<Map<String, double>, String>` computing hourly rates for wood/marble/crystal/sulfur
- `productionBreakdownProvider((cityId, resourceTypeName))` — returns `ProductionBreakdown` with base/building/island/research components
- Formula: `workers * level * 5.0 * productionMult * islandMult * 12` (12 ticks/hr at 5-min intervals)
- Happiness < 0 applies 0.5 production multiplier

### Task 2 — City screen resource rate display + breakdown sheet (89c10d8)

Modified `city_screen.dart`:
- `_ResourcePanel` converted to `ConsumerWidget` with `cityId` parameter
- Watches `productionRateProvider(cityId)` inline
- `_ResourceChip` extended with optional `hourlyRate` (shows `+X/hr` label in green below amount) and `onTap` callback
- Wood/marble/crystal/sulfur chips show rate label and open `_ProductionBreakdownSheet` on tap
- Gold/wine chips unchanged (no rate, not tappable)
- `_ProductionBreakdownSheet` — ConsumerWidget bottom sheet showing 4-row breakdown: Base Rate, Building Level Bonus, Island Level Bonus (0.0 when level 0), Research Bonus (always 0.0), plus Total row
- `_BreakdownRow` helper widget for consistent label + value rows

### Task 3 — Island screen donate wood UI (76bcf9c)

Modified `island_screen.dart`:
- Island header card shows `Resource Level: X / 10` row with `Icons.upgrade`
- `_ResourceCell` extended with optional `onTap` callback and tap indicator icon
- Wood resource cell is tappable (luxury cell is not)
- `_DonateWoodDialog` StatefulWidget:
  - Shows cost (`islandDonationCost`), current/next multiplier, and cancel/donate buttons
  - Calls `Supabase.instance.client.functions.invoke('donate-island-wood', body: {'city_id': cityId})`
  - On success: closes dialog, calls `ref.invalidate(islandDetailProvider(islandId))`
  - On error: shows SnackBar with error message
  - At max level 10: shows "at maximum level" message instead of donate form

### Task 4 — Checkpoint: human-verify (PENDING)

Awaiting human verification of end-to-end flows.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing error handling] _DonateWoodDialog uses StatefulWidget for loading state**
- **Found during:** Task 3
- **Issue:** Plan called for StatelessWidget but donate button needs a loading state to prevent double-taps and show spinner
- **Fix:** Used StatefulWidget with `_donating` bool; disables buttons and shows CircularProgressIndicator during async call
- **Files modified:** lib/features/map/screens/island_screen.dart

**2. [Rule 2 - UX enhancement] _ResourceCell tap indicator icon**
- **Found during:** Task 3
- **Issue:** Tappable cells with no visual affordance would confuse players
- **Fix:** Added small `Icons.touch_app` in top-right corner of tappable cells only
- **Files modified:** lib/features/map/screens/island_screen.dart

## Self-Check: PARTIAL (checkpoint pending)

Tasks 1-3 complete with commits verified:
- c218b40 found: FOUND
- 89c10d8 found: FOUND
- 76bcf9c found: FOUND

Files created/modified:
- lib/core/constants/island_constants.dart: FOUND
- lib/features/city/providers/production_rate_provider.dart: FOUND
- lib/features/map/models/island.dart: FOUND (modified)
- lib/features/city/screens/city_screen.dart: FOUND (modified)
- lib/features/map/screens/island_screen.dart: FOUND (modified)

Flutter analyze: No errors (6 pre-existing info/warning in unrelated files).
