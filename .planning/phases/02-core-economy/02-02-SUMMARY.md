---
phase: 02-core-economy
plan: 02
subsystem: api
tags: [flutter, dart, supabase, edge-function, deno, typescript, game-economy, tdd]

# Dependency graph
requires:
  - phase: 02-core-economy plan 01
    provides: city_resources, city_buildings, construction_queue tables; deduct_resource() function

provides:
  - upgrade-building Edge Function: validates ownership, checks queue, deducts resources, inserts construction_queue entry
  - ResourceType enum with DB value getter and warehouseCapacity helper
  - BuildingType enum (14 types: 10 city + 4 production) with dbName, displayName, isProductionBuilding
  - buildingBaseCosts and buildingBaseTimes maps for all 14 building types
  - upgradeCost(type, level) and upgradeDurationMinutes(type, level) formula functions
  - CityResource model: fromJson/toJson for city_resources rows
  - CityBuilding model: fromJson/toJson for city_buildings rows
  - ConstructionQueueEntry model: fromJson/toJson with remainingDuration and isComplete helpers

affects:
  - 02-03 (Flutter city screen uses CityResource, CityBuilding, ConstructionQueueEntry models + calls upgrade-building Edge Function)

# Tech tracking
tech-stack:
  added: [deno, jsr:@supabase/supabase-js@2]
  patterns:
    - Edge Function uses anon client for auth.getUser() and service role admin client for mutations (INFR-02)
    - BASE_COSTS and BASE_TIMES constants in TypeScript must stay in sync with Dart building_constants.dart
    - TDD: write failing test file first (RED), implement (GREEN), verify all pass
    - Dart enums with getter methods for DB name mapping (dbName, value) instead of maps
    - Immutable Dart model classes with fromJson/toJson factory constructors

key-files:
  created:
    - supabase/functions/upgrade-building/index.ts
    - lib/core/constants/resource_constants.dart
    - lib/core/constants/building_constants.dart
    - lib/features/city/models/city_resource.dart
    - lib/features/city/models/city_building.dart
    - lib/features/city/models/construction_queue_entry.dart
    - test/unit/building_formulas_test.dart
  modified:
    - test/unit/building_time_test.dart (deleted — replaced by building_formulas_test.dart)

key-decisions:
  - "BASE_COSTS and BASE_TIMES defined as constants in Edge Function TypeScript — must match Dart building_constants.dart exactly (comment added to enforce this)"
  - "deduct_resource() calls are not atomic across resources in v1 — if wood deducts but marble fails, wood is lost; documented as acceptable for v1 with future improvement note"
  - "ConstructionQueueEntry.buildingType is String (not BuildingType enum) — avoids coupling the construction model to the enum and keeps it generic for any building type"

patterns-established:
  - "Edge Function auth pattern: anonClient for getUser(), adminClient (service role) for all mutations"
  - "Dart enum DB mapping: each enum value has a getter returning the DB snake_case string"
  - "Building formula synchronization: same base costs and times duplicated in TypeScript and Dart with sync comment"

requirements-completed: [BLDG-02, BLDG-03, BLDG-04]

# Metrics
duration: 4min
completed: 2026-03-11
---

# Phase 2 Plan 02: Building Upgrade Logic Summary

**upgrade-building Edge Function (244 lines) with TDD-verified Dart cost/time formulas, 3 typed models (CityResource, CityBuilding, ConstructionQueueEntry), and 2 constants files covering all 14 building types — 20 passing unit tests**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-03-11T01:57:26Z
- **Completed:** 2026-03-11T02:02:05Z
- **Tasks:** 2
- **Files modified:** 8 (7 created, 1 deleted)

## Accomplishments

- upgrade-building Edge Function: full validation chain — auth check, city ownership, queue busy check, resource deduction via deduct_resource() RPC, construction_queue INSERT, CORS headers
- Two Dart constants files with 14 building types + formulas: upgradeCost() (ceil(base * 1.5^level)) and upgradeDurationMinutes() (ceil(base * 1.2^level)) — verified against plan spec values
- Three immutable Dart model classes with fromJson/toJson parsing Supabase JSON rows; ConstructionQueueEntry includes remainingDuration and isComplete helpers
- 20 unit tests covering all formula cases, enum mappings, and model parsing — TDD RED/GREEN cycle confirmed

## Task Commits

Each task was committed atomically:

1. **Task 1: Dart constants, models, and formula unit tests** - `70d3249` (feat + test, TDD)
2. **Task 2: Create upgrade-building Edge Function** - `0b4e1e1` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified

- `supabase/functions/upgrade-building/index.ts` - Edge Function: auth, ownership check, queue check, resource deduction, construction_queue insert
- `lib/core/constants/resource_constants.dart` - ResourceType enum with DB value getter; warehouseCapacity helper function
- `lib/core/constants/building_constants.dart` - BuildingType enum (14 types) with dbName/displayName/isProductionBuilding; buildingBaseCosts, buildingBaseTimes maps; upgradeCost/upgradeDurationMinutes formulas
- `lib/features/city/models/city_resource.dart` - CityResource: id, cityId, ResourceType, amount, updatedAt; fromJson/toJson
- `lib/features/city/models/city_building.dart` - CityBuilding: id, cityId, BuildingType, level, assignedWorkers, updatedAt; fromJson/toJson
- `lib/features/city/models/construction_queue_entry.dart` - ConstructionQueueEntry: id, cityId, buildingType, targetLevel, finishAt, createdAt; remainingDuration, isComplete
- `test/unit/building_formulas_test.dart` - 20 unit tests: cost formula (4), time formula (5), BuildingType enum (3), ResourceType enum (1), CityResource (2), CityBuilding (2), ConstructionQueueEntry (3)
- `test/unit/building_time_test.dart` - DELETED (replaced by building_formulas_test.dart with full coverage)

## Decisions Made

- **BASE_COSTS/BASE_TIMES duplication:** The same base cost and time values are defined in both TypeScript (Edge Function) and Dart (building_constants.dart). A sync comment is added to both files. This duplication is intentional — the Edge Function is the server authority and must not import client-side Dart code. Future improvement: a shared JSON config consumed by both.
- **Non-atomic resource deduction:** deduct_resource() calls are sequential, not wrapped in a single SQL transaction. If wood deducts but marble fails, wood is lost. Documented as acceptable for v1 — a future plan should wrap all deductions in a single SQL transaction or create a batch deduct_resources() function.
- **ConstructionQueueEntry.buildingType as String:** Intentionally kept as String rather than BuildingType enum to keep the construction model decoupled from the building enum and avoid circular dependency issues.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed `pow()` return type in resource_constants.dart**
- **Found during:** Task 1 (GREEN phase — running tests)
- **Issue:** `dart:math` `pow(double, int)` returns `num`, not `double`. The return type annotation `double` caused a compile error.
- **Fix:** Added `.toDouble()` cast: `return (baseWarehouseCapacity * pow(...)).toDouble()`
- **Files modified:** `lib/core/constants/resource_constants.dart`
- **Verification:** All 20 tests pass after fix, `flutter analyze` clean
- **Committed in:** `70d3249` (part of Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - type error)
**Impact on plan:** Necessary correctness fix; no scope changes.

## Issues Encountered

None — one compile-time type error caught during TDD GREEN phase, auto-fixed immediately.

## User Setup Required

None — Edge Function uses environment variables automatically provided by Supabase local dev (SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY).

## Next Phase Readiness

- upgrade-building Edge Function deployable and ready for Plan 02-03 integration testing
- CityResource, CityBuilding, ConstructionQueueEntry models ready for Flutter city screen (Plan 02-03)
- All formula functions tested and verified against spec values
- Plan 02-03 will need to: set up a Riverpod provider that calls the Edge Function and subscribes to Realtime changes on city_resources and city_buildings

---
*Phase: 02-core-economy*
*Completed: 2026-03-11*

## Self-Check: PASSED

All files verified present on disk. All commits verified in git log.

| Check | Result |
|-------|--------|
| lib/core/constants/resource_constants.dart | FOUND |
| lib/core/constants/building_constants.dart | FOUND |
| lib/features/city/models/city_resource.dart | FOUND |
| lib/features/city/models/city_building.dart | FOUND |
| lib/features/city/models/construction_queue_entry.dart | FOUND |
| test/unit/building_formulas_test.dart | FOUND |
| supabase/functions/upgrade-building/index.ts | FOUND |
| Commit 70d3249 (Task 1) | FOUND |
| Commit 0b4e1e1 (Task 2) | FOUND |
