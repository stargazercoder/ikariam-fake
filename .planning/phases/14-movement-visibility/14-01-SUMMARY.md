---
phase: 14-movement-visibility
plan: 01
subsystem: military-data
tags: [movements, riverpod, supabase-realtime, data-layer]
dependency_graph:
  requires: []
  provides:
    - allMovementsStreamProvider
    - allMovementsProvider
    - cityNameProvider
    - watchAllMovements
    - UnitMovement.movementType
  affects:
    - lib/features/movements/screens (Plan 02 UI consumer)
tech_stack:
  added: []
  patterns:
    - Provider.autoDispose mirrors allMyBattlesProvider pattern from battles_provider.dart
    - Stream.empty() guard when userId is null (matches watchOutgoingMovements pattern)
    - Cascade sort ..sort() on mapped list before returning from stream
key_files:
  created:
    - lib/features/movements/providers/movements_provider.dart
  modified:
    - lib/features/military/models/unit_movement.dart
    - lib/features/military/data/military_repository.dart
decisions:
  - movementType uses String with 'attack' default (not enum) for DB compatibility and null-safety on legacy rows
  - watchAllMovements streams ALL owner movements without per-city filter; filtering is UI responsibility
  - cityNameProvider uses FutureProvider.family (single fetch) not StreamProvider (no realtime needed for city names)
metrics:
  duration_seconds: 134
  completed_date: "2026-03-16T09:07:30Z"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 2
  files_created: 1
requirements_satisfied: [MOVE-01, MOVE-02]
---

# Phase 14 Plan 01: Movement Data Layer Summary

**One-liner:** Added movementType field to UnitMovement model, global watchAllMovements() stream to MilitaryRepository, and three Riverpod providers (allMovementsStreamProvider, allMovementsProvider, cityNameProvider) ready for Plan 02 UI consumption.

## What Was Built

### Task 1: UnitMovement.movementType field
- Added `movementType` constructor parameter with default `'attack'` — existing callers unbroken
- Added `final String movementType; // 'attack' | 'return'` field
- Added `movementType: json['movement_type'] as String? ?? 'attack'` in `fromJson` factory
- Updated `toString()` to include movementType

### Task 2: watchAllMovements() + movement providers
- Added `Stream<List<UnitMovement>> watchAllMovements()` to `MilitaryRepository`
  - Streams all movements owned by the current user without any per-city filter
  - Sorted by arriveAt ascending (soonest ETA first) via cascade `..sort()`
  - Returns `const Stream.empty()` when userId is null (matches existing pattern)
- Created `lib/features/movements/providers/movements_provider.dart` with:
  - `allMovementsStreamProvider` — StreamProvider.autoDispose wrapping watchAllMovements()
  - `allMovementsProvider` — Provider.autoDispose returning empty list when user null
  - `cityNameProvider` — FutureProvider.autoDispose.family fetching city name from cities table

## Deviations from Plan

None — plan executed exactly as written.

## Verification

- `flutter analyze lib/features/military/data/military_repository.dart lib/features/movements/providers/movements_provider.dart` — no issues
- `flutter analyze lib/features/military/models/unit_movement.dart` — 2 pre-existing info-level doc comment angle bracket warnings (unintended_html_in_doc_comment at line 44, existing before this plan)
- All acceptance criteria met for both tasks

## Commits

| Hash    | Type | Description                                          |
| ------- | ---- | ---------------------------------------------------- |
| 98cbddc | feat | add movementType field to UnitMovement model         |
| 3629b21 | feat | add watchAllMovements() and create movement providers |

## Self-Check: PASSED

| Check | Result |
| ----- | ------ |
| lib/features/military/models/unit_movement.dart | FOUND |
| lib/features/military/data/military_repository.dart | FOUND |
| lib/features/movements/providers/movements_provider.dart | FOUND |
| Commit 98cbddc | FOUND |
| Commit 3629b21 | FOUND |
