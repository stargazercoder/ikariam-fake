---
phase: 23-unit-tests
plan: 01
subsystem: edge-functions
tags: [unit-tests, deno, formulas, refactoring]
dependency_graph:
  requires: []
  provides: [supabase/functions/_shared/formulas.ts, supabase/functions/tests/]
  affects: [supabase/functions/upgrade-building/index.ts, supabase/functions/train-units/index.ts]
tech_stack:
  added: [jsr:@std/assert, Deno unit tests]
  patterns: [pure-function extraction, shared module, TDD]
key_files:
  created:
    - supabase/functions/_shared/formulas.ts
    - supabase/functions/tests/upgrade_building_test.ts
    - supabase/functions/tests/train_units_test.ts
  modified:
    - supabase/functions/upgrade-building/index.ts
    - supabase/functions/train-units/index.ts
decisions:
  - "calcTrainingDurationMinutes takes devSpeedMultiplier as a parameter (not Deno.env) so it remains pure and testable"
  - "UNIT_BASE_COSTS and UNIT_BASE_TIMES removed from train-units/index.ts imports — only needed internally by calcTrainingCost/calcTrainingDurationMinutes in formulas.ts"
metrics:
  duration: "189 seconds"
  completed_date: "2026-03-18"
  tasks_completed: 2
  files_created: 3
  files_modified: 2
---

# Phase 23 Plan 01: Unit Tests - Formula Extraction Summary

**One-liner:** Extracted 14 building/unit formula constants and 4 pure functions from Edge Functions into `_shared/formulas.ts`, then added 14 Deno unit tests covering all formula behaviors with zero test failures.

## Tasks Completed

| # | Task | Commit | Status |
|---|------|--------|--------|
| 1 | Extract pure functions into _shared/formulas.ts and update index.ts imports | c4b6eeb | Done |
| 2 | Create Deno test files for upgrade-building and train-units formulas | 7308753 | Done |

## What Was Built

### supabase/functions/_shared/formulas.ts

A pure module (no side effects, no Deno.env, no createClient, no Deno.serve) exporting:

- `BASE_COSTS` — 14 building base resource costs
- `BASE_TIMES` — 14 building base upgrade times
- `COST_GROWTH_FACTOR` (1.5), `TIME_GROWTH_FACTOR` (1.2)
- `calcUpgradeCost(buildingType, currentLevel)` — returns ceil(base * 1.5^level) per resource
- `calcUpgradeDurationMinutes(buildingType, currentLevel)` — returns ceil(base_time * 1.2^level)
- `UNIT_UNLOCK_LEVELS` — 13 unit type → building/minLevel mappings
- `UNIT_BASE_COSTS` — 13 unit base resource costs
- `UNIT_BASE_TIMES` — 13 unit base training times
- `calcTrainingCost(unitType, quantity)` — returns base_cost * quantity per resource
- `calcTrainingDurationMinutes(unitType, quantity, devSpeedMultiplier)` — pure, multiplier is a parameter

### Updated Edge Functions

- `upgrade-building/index.ts` now imports BASE_COSTS, calcUpgradeCost, calcUpgradeDurationMinutes from `_shared/formulas.ts`; local declarations removed
- `train-units/index.ts` now imports UNIT_UNLOCK_LEVELS, calcTrainingCost, calcTrainingDurationMinutes from `_shared/formulas.ts`; inline cost/duration calculations replaced with function calls; local constant declarations removed

### Test Files

- `upgrade_building_test.ts`: 7 test cases — calcUpgradeCost at level 0/1/5 for specific buildings, all building types at level 0, calcUpgradeDurationMinutes at level 0/5/20
- `train_units_test.ts`: 7 test cases — calcTrainingCost at qty 1/5, all unit types at qty 1, calcTrainingDurationMinutes with 1.0x and 0.2x multipliers

## Verification Results

```
ok | 14 passed | 0 failed (61ms)
deno check supabase/functions/upgrade-building/index.ts — no errors
deno check supabase/functions/train-units/index.ts — no errors
deno check supabase/functions/_shared/formulas.ts — no errors
```

## Deviations from Plan

None - plan executed exactly as written.

The one minor implementation detail: after replacing the inline cost/duration calculations in `train-units/index.ts` with `calcTrainingCost`/`calcTrainingDurationMinutes` calls, `UNIT_BASE_COSTS` and `UNIT_BASE_TIMES` were no longer directly referenced in the index file. These imports were dropped to avoid unused-import warnings. The plan did not specify importing them in index.ts (only UNIT_UNLOCK_LEVELS plus the two new functions were listed in the import spec).

## Self-Check: PASSED

- [x] supabase/functions/_shared/formulas.ts — exists
- [x] supabase/functions/tests/upgrade_building_test.ts — exists, 7 tests
- [x] supabase/functions/tests/train_units_test.ts — exists, 7 tests
- [x] Commit c4b6eeb — exists (Task 1)
- [x] Commit 7308753 — exists (Task 2)
- [x] deno test exits 0 with 14 passed
