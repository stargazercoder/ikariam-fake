---
phase: 10-economy-foundation
plan: "01"
subsystem: database
tags: [postgresql, supabase, plpgsql, migrations, economy, realtime]

# Dependency graph
requires: []
provides:
  - "cities table with population (NUMERIC), happiness (NUMERIC), wine_spending_rate (INTEGER 0-100)"
  - "city_resources CHECK constraint includes 'wine' as valid resource_type"
  - "on_city_created seeds wine=500 for new cities"
  - "process_resource_tick() 5-step economy loop: production (no gold), wine consumption, happiness, population growth, tax"
  - "cities table in supabase_realtime publication with REPLICA IDENTITY FULL"
  - "Wave 0 economy formula test stubs (ECON-01/02/03/05)"
affects:
  - 10-02-plan
  - 10-03-plan

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Outer city loop in process_resource_tick() with inner per-resource production sub-loop"
    - "NULLIF guard for division-by-zero in happiness effective_rate calculation"
    - "GREATEST(idle, 0) for idle citizen tax prevents negative values"
    - "Tax proration constant: idle * 0.05 = idle * 3 * (60/3600) at 60s tick"

key-files:
  created:
    - supabase/migrations/20260313000001_economy_schema_and_tick.sql
    - test/unit/economy_formulas_test.dart
  modified: []

key-decisions:
  - "Gold produced ONLY via idle citizen tax (Step 5) — Town Hall worker gold path removed entirely to prevent double income"
  - "Population stored as NUMERIC (not INTEGER) to preserve fractional tick growth"
  - "Negative happiness halts population growth AND applies 50% production penalty (no population loss — anti-death-spiral)"
  - "Wine seeded at 500 for both new cities (on_city_created) and existing cities (backfill INSERT)"
  - "cities table added to supabase_realtime publication for live population/happiness UI updates"
  - "Happiness formula: (effective_rate * wine_spending_rate/100.0 * tavern_level) - (population * 0.02)"
  - "cities table has no updated_at column — removed from UPDATE statements to avoid SQL error"

patterns-established:
  - "process_resource_tick() city-first outer loop pattern: all 5 economy steps per city before moving to next"
  - "Wine consumption: wine_per_tick = (rate/100.0) * tavern_level * 5.0; consumed = LEAST(per_tick, available)"
  - "Population growth rate: population * 0.01 * (happiness / 100.0) per tick when happiness > 0"

requirements-completed: [ECON-01, ECON-02, ECON-03, ECON-05]

# Metrics
duration: 3min
completed: 2026-03-13
---

# Phase 10 Plan 01: Economy Schema and Tick Summary

**PostgreSQL migration adding population/happiness/wine economy columns to cities and rewriting process_resource_tick() with a 5-step city-loop: resource production (50% penalty when unhappy), wine consumption via tavern, happiness formula, fractional NUMERIC population growth, and idle citizen tax at 0.05 gold/tick**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-03-13T19:45:39Z
- **Completed:** 2026-03-13T19:49:00Z
- **Tasks:** 1
- **Files created:** 2

## Accomplishments
- Single atomic migration adds all economy columns (`population NUMERIC`, `happiness NUMERIC`, `wine_spending_rate INTEGER 0-100`) to cities table
- City resources CHECK constraint extended to include 'wine'; existing cities backfilled with 500 wine; on_city_created seeds 500 wine for new cities
- process_resource_tick() fully rewritten with outer city loop — gold via Town Hall removed, 5 ordered steps guaranteed to execute atomically per city
- cities table enabled for Supabase Realtime (REPLICA IDENTITY FULL + publication) for live UI updates
- 16 Wave 0 test stubs created covering happiness formula (ECON-01), population growth (ECON-02), tax proration (ECON-03), wine consumption cap (ECON-05)

## Task Commits

Each task was committed atomically:

1. **Task 1: Schema extension, process_resource_tick() rewrite, Wave 0 test stubs** — `56bfe2c` (feat)

## Files Created/Modified
- `supabase/migrations/20260313000001_economy_schema_and_tick.sql` — Full schema migration: cities columns, wine constraint, on_city_created rewrite, Realtime enable, 5-step process_resource_tick()
- `test/unit/economy_formulas_test.dart` — 16 Wave 0 skipped unit test stubs for economy formula validation (ECON-01/02/03/05)

## Decisions Made
- Removed `updated_at = NOW()` from `UPDATE public.cities` statements because the cities table was created without an `updated_at` column — discovered via schema inspection, fixed before commit
- Wine seeded at 500 (not 0 per RESEARCH open question) per plan specification — gives immediate testability of tavern mechanics
- Production penalty (50%) applies to all 4 production resources (wood, marble, crystal, sulfur) uniformly when happiness < 0 — applied via `v_production_mult` multiplier
- Population growth formula: `population * 0.01 * (happiness / 100.0)` — conservative rate, ~0.5/tick at pop=100, happiness=50

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed updated_at from cities UPDATE statements**
- **Found during:** Task 1 (migration writing)
- **Issue:** The `cities` table (created in 20260311000002_create_cities.sql) has no `updated_at` column. The plan's pseudo-code included `updated_at = NOW()` in city UPDATE statements — this would cause a runtime SQL error on every tick.
- **Fix:** Removed `updated_at = NOW()` from both `UPDATE public.cities SET happiness` and `UPDATE public.cities SET population` statements. City resource updates still correctly set `updated_at` (city_resources table does have the column).
- **Files modified:** `supabase/migrations/20260313000001_economy_schema_and_tick.sql`
- **Verification:** Confirmed city_resources has updated_at (migration 20260311000004), cities does not (migration 20260311000002)
- **Committed in:** 56bfe2c

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Essential fix — without it every tick execution would fail with "column updated_at does not exist". No scope creep.

## Issues Encountered
- Docker Desktop not running — `supabase db reset` could not be executed to verify migration applies. Migration SQL syntax verified by code review against existing migration patterns. Test stubs confirmed via `flutter test` (all 16 skipped, compiles clean).

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- Database schema ready for Plan 02 (set-wine-rate Edge Function) and Plan 03 (Flutter UI)
- `cities.wine_spending_rate` column exists for Edge Function to UPDATE
- `cities.population` and `cities.happiness` in Realtime for Flutter StreamProvider
- Wave 0 test stubs at `test/unit/economy_formulas_test.dart` ready for Plan 03 implementation

---
*Phase: 10-economy-foundation*
*Completed: 2026-03-13*
