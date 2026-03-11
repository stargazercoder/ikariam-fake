---
phase: 04-military
plan: "02"
subsystem: military-business-logic
tags: [military, units, edge-functions, dart-constants, models, tdd]
dependency_graph:
  requires: [04-01]
  provides: [train-units-edge-function, dispatch-units-edge-function, unit-constants, military-models]
  affects: [04-03]
tech_stack:
  added: []
  patterns: [tdd-red-green, edge-function-auth-pattern, dart-enum-with-dbname, model-fromjson]
key_files:
  created:
    - lib/core/constants/unit_constants.dart
    - lib/features/military/models/training_queue_entry.dart
    - lib/features/military/models/city_unit.dart
    - lib/features/military/models/unit_movement.dart
    - supabase/functions/train-units/index.ts
    - supabase/functions/dispatch-units/index.ts
  modified:
    - test/unit/unit_constants_test.dart
    - test/unit/military_models_test.dart
decisions:
  - "UnitType.unitType stored as String (not enum) in all models — same decision as ConstructionQueueEntry.buildingType; keeps models decoupled from constants"
  - "Non-atomic unit deduction in dispatch-units: acceptable for v1 per established project precedent (same as upgrade-building resource deduction)"
  - "calcTravelMinutes uses Euclidean distance with max(1, ceil()) — same formula in both Dart and TypeScript with explicit sync comments"
metrics:
  duration_minutes: 4
  completed_date: "2026-03-11"
  tasks_completed: 2
  files_created: 6
  files_modified: 2
---

# Phase 4 Plan 02: Military Business Logic Summary

**One-liner:** UnitType enum (13 types), 3 military models, 2 Edge Functions (train-units + dispatch-units) with full validation chains and travel time formula.

## What Was Built

### Task 1: Dart Unit Constants, Military Models, and Unit Tests (TDD)

**TDD Red phase:** Updated 2 Wave 0 test stub files with real assertions targeting not-yet-existing production files. Tests failed with import errors confirming RED state.

**TDD Green phase:** Created 4 production files — all 14 tests passed immediately after creation.

**lib/core/constants/unit_constants.dart:**
- `UnitType` enum with 13 values: 8 land (hoplite, phalanx, archer, cavalry, catapult, mortar, medic, cook) + 5 naval (cargoShip, ramShip, catapultShip, mortarShip, divingBoat)
- `String get dbName` — snake_case DB names for all 13 types
- `bool get isNaval` — true for 5 naval types
- `String get displayName` — human-readable names
- `String get requiredBuilding` — 'barracks' or 'shipyard'
- `const Map<UnitType, int> unitUnlockLevels` — building level requirements for all 13 types
- `const Map<UnitType, Map<String, int>> unitBaseCosts` — resource costs (wood, gold, marble, crystal, sulfur keys)
- `const Map<UnitType, int> unitBaseTimes` — minutes per unit for training duration
- `const int baseMinutesPerGridUnit = 10` — travel speed constant
- `int calcTravelMinutes(originX, originY, destX, destY)` — Euclidean distance formula: max(1, ceil(sqrt(dx^2+dy^2) * 10))
- Sync comment at top referencing train-units/index.ts

**lib/features/military/models/training_queue_entry.dart:**
- Mirrors ConstructionQueueEntry pattern exactly
- `unitType` stored as String (not enum) — same decision as ConstructionQueueEntry
- `bool get isComplete` — checks if finishAt is in the past
- `Duration get remainingDuration` — clamped to zero, never negative

**lib/features/military/models/city_unit.dart:**
- Army roster row model (one per unit type per city)
- `factory fromJson(Map<String, dynamic> json)` — parses Supabase row

**lib/features/military/models/unit_movement.dart:**
- `units: Map<String, int>` — parsed from JSONB `(json['units'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int))`
- `bool get hasArrived` and `Duration get remainingTravelTime`

### Task 2: Edge Functions

**supabase/functions/train-units/index.ts:**
Validation chain: POST only → parse body → validate quantity (1-50) → validate unit_type in UNIT_UNLOCK_LEVELS → authenticate user → verify city ownership → get required building → check building level >= minLevel → check training queue vacancy → deduct resources via deduct_resource() RPC × quantity → calculate finish_at → INSERT training_queue → catch 23505 unique_violation as 409.

**supabase/functions/dispatch-units/index.ts:**
Validation chain: POST only → parse body → validate origin != destination → validate units object non-empty with positive quantities → authenticate user → verify origin city ownership → verify destination city exists → fetch island grid_x/grid_y for both cities → calcTravelMinutes() → deduct units via deduct_units() RPC per unit type → calculate arrive_at → INSERT unit_movements.

Both functions follow the upgrade-building/index.ts pattern exactly: CORS_HEADERS, anon client for getUser(), admin client (service role) for mutations.

## Verification

All 14 unit tests pass. No skipped tests remain in unit_constants_test.dart or military_models_test.dart. Full unit test suite: 39 pass, 5 skip (pre-existing from earlier phases). Both Edge Function files exist with complete validation chains.

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED

Files verified:
- FOUND: lib/core/constants/unit_constants.dart
- FOUND: lib/features/military/models/training_queue_entry.dart
- FOUND: lib/features/military/models/city_unit.dart
- FOUND: lib/features/military/models/unit_movement.dart
- FOUND: supabase/functions/train-units/index.ts
- FOUND: supabase/functions/dispatch-units/index.ts

Commits verified:
- FOUND: ed2f630 (Task 1 — Dart constants, models, tests)
- FOUND: b36de8e (Task 2 — Edge Functions)
