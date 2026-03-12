---
phase: 04-military
plan: 01
subsystem: database
tags: [postgresql, supabase, pg_cron, rls, realtime, jsonb, migrations]

# Dependency graph
requires:
  - phase: 02-core-economy
    provides: construction_queue pattern, deduct_resource() function, pg_cron extension
  - phase: 04-military (plan 00)
    provides: wave 0 test scaffolds for military feature

provides:
  - city_units table: army roster per city with UNIQUE(city_id, unit_type) for upsert
  - training_queue table: one-active-per-city training with UNIQUE(city_id) constraint
  - unit_movements table: in-transit armies as JSONB snapshot with cross-city RLS
  - complete_training() function: upserts trained units into city_units, removes queue entry
  - deduct_units() function: atomically deducts units, raises insufficient_resources error
  - process_arrivals() function: delivers in-transit armies to destination city_units
  - training-tick cron job: fires every minute to process complete_training()
  - arrivals-tick cron job: fires every minute to process process_arrivals()
affects: [04-military plans 02+, 05-combat]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Training queue as mirror of construction_queue: UNIQUE(city_id), pg_cron completion, Realtime"
    - "JSONB snapshot for unit movements: immutable at departure, avoids Phase 5 join complexity"
    - "deduct_units() mirrors deduct_resource(): atomic UPDATE with ROW_COUNT guard"
    - "process_arrivals() with jsonb_each_text() for iterating JSONB unit type/quantity entries"

key-files:
  created:
    - supabase/migrations/20260311000011_create_city_units.sql
    - supabase/migrations/20260311000012_create_training_queue.sql
    - supabase/migrations/20260311000013_create_unit_movements.sql
    - supabase/migrations/20260311000014_training_functions.sql
    - supabase/migrations/20260311000015_movement_functions.sql
    - supabase/migrations/20260311000016_military_cron_jobs.sql
  modified: []

key-decisions:
  - "unit_movements uses JSONB snapshot (not join table): immutable army at departure, simpler Phase 5 combat resolution"
  - "training_queue UNIQUE(city_id) enforces one-at-a-time at DB level — same as construction_queue"
  - "city_units has no pre-population trigger: complete_training() uses INSERT ON CONFLICT for first training"
  - "process_arrivals() uses jsonb_each_text() to iterate JSONB unit type/quantity pairs"

patterns-established:
  - "Pattern: JSONB unit snapshot in unit_movements — object format {unit_type: qty}, iterate with jsonb_each_text()"
  - "Pattern: military pg functions follow SECURITY DEFINER SET search_path = '' convention"
  - "Pattern: military cron jobs registered in dedicated migration (not added to existing pg_cron migration)"

requirements-completed: [MIL-01, MIL-02, MIL-04, MIL-05]

# Metrics
duration: 3min
completed: 2026-03-11
---

# Phase 04 Plan 01: Military Database Layer Summary

**3 Supabase tables (city_units, training_queue, unit_movements) + 3 pg functions (complete_training, deduct_units, process_arrivals) + 2 pg_cron jobs, giving the server-side foundation for unit training and cross-city dispatch**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-03-11T07:16:52Z
- **Completed:** 2026-03-11T07:20:00Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- city_units army roster table with UNIQUE(city_id, unit_type) for simple upsert on training completion
- training_queue with UNIQUE(city_id) one-active-per-city constraint, mirroring construction_queue exactly
- unit_movements with JSONB unit snapshot (immutable at departure) and cross-city RLS for Phase 5 combat visibility
- complete_training() and deduct_units() functions for training lifecycle
- process_arrivals() function iterating JSONB units with jsonb_each_text() to deliver armies at destination
- training-tick and arrivals-tick cron jobs registered; all 4 cron jobs confirmed in cron.job table

## Task Commits

Each task was committed atomically:

1. **Task 1: Create city_units, training_queue, and unit_movements tables** - `777b993` (feat)
2. **Task 2: Create pg functions and register military cron jobs** - `3c5807c` (feat)

**Plan metadata:** (docs commit below)

## Files Created/Modified
- `supabase/migrations/20260311000011_create_city_units.sql` - Army roster table with RLS, Realtime, 13-value unit_type CHECK
- `supabase/migrations/20260311000012_create_training_queue.sql` - Training queue, UNIQUE(city_id), mirrors construction_queue
- `supabase/migrations/20260311000013_create_unit_movements.sql` - Unit movements JSONB table, cross-city RLS (owner + defender)
- `supabase/migrations/20260311000014_training_functions.sql` - complete_training() upsert + deduct_units() atomic deduction
- `supabase/migrations/20260311000015_movement_functions.sql` - process_arrivals() JSONB iteration + city_units upsert
- `supabase/migrations/20260311000016_military_cron_jobs.sql` - training-tick + arrivals-tick cron registration

## Decisions Made
- JSONB snapshot for unit_movements (not a join table): army is immutable at departure time, simplifies Phase 5 battle resolution without cascading deletes or joins
- process_arrivals() uses `jsonb_each_text()` to iterate JSONB object keys — object format `{"hoplite": 10}` preferred over array for readability and `->>`  operator compatibility
- Military cron jobs placed in a new dedicated migration file rather than modifying existing 20260311000010 — keeps each migration atomic and idempotent

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. All 6 migrations applied cleanly on first `supabase db reset`. All 4 cron jobs confirmed in `cron.job`. All 3 functions confirmed in `pg_proc`.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- DB foundation complete for Plan 02 (train-units Edge Function) and Plan 03 (dispatch-units Edge Function)
- complete_training() and process_arrivals() are callable — Edge Functions can trigger via RPC if needed
- deduct_units() ready for dispatch-units Edge Function to call before inserting unit_movements row

---
*Phase: 04-military*
*Completed: 2026-03-11*

## Self-Check: PASSED

- All 6 migration files exist on disk
- Commits 777b993 and 3c5807c confirmed in git log
- supabase db reset completed without errors
- All 3 tables present with RLS enabled (rowsecurity = t)
- All 3 functions present in pg_proc
- All 4 cron jobs (arrivals-tick, construction-tick, resource-tick, training-tick) confirmed in cron.job
