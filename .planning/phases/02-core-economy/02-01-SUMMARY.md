---
phase: 02-core-economy
plan: 01
subsystem: database
tags: [postgres, supabase, plpgsql, pg_cron, rls, realtime, game-loop]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: cities table (FK target for city_resources, city_buildings, construction_queue)

provides:
  - city_resources table with RLS, REPLICA IDENTITY FULL, and Realtime publication
  - city_buildings table with 14-type CHECK constraint (10 city + 4 production), RLS, REPLICA IDENTITY FULL, Realtime
  - construction_queue table with UNIQUE(city_id) one-at-a-time constraint, RLS, REPLICA IDENTITY FULL, Realtime
  - on_city_created trigger: seeds 5 resources + 14 buildings on city INSERT
  - process_resource_tick(): SECURITY DEFINER function updating all city resources on 5-min cron
  - deduct_resource(): atomic resource spend function for Edge Function use
  - complete_building_upgrades(): finishes queued builds when finish_at passes
  - pg_cron jobs: resource-tick (every 5 min) and construction-tick (every 1 min)

affects:
  - 02-02 (upgrade-building Edge Function calls deduct_resource and inserts into construction_queue)
  - 02-03 (Flutter city screen subscribes to city_resources and city_buildings via Realtime)

# Tech tracking
tech-stack:
  added: [pg_cron]
  patterns:
    - SECURITY DEFINER SET search_path = '' for all server-side functions
    - RLS enabled in same migration that creates the table (never added later)
    - REPLICA IDENTITY FULL on all tables that use Supabase Realtime
    - Production building mapping: wood->sawmill, marble->quarry, crystal->glassblower, sulfur->sulfur_pit, gold->town_hall
    - pg_cron registered via migration file (not seed.sql) to avoid "schema cron does not exist" error

key-files:
  created:
    - supabase/migrations/20260311000004_create_city_resources.sql
    - supabase/migrations/20260311000005_create_city_buildings.sql
    - supabase/migrations/20260311000006_create_construction_queue.sql
    - supabase/migrations/20260311000007_on_city_created_trigger.sql
    - supabase/migrations/20260311000008_resource_production_functions.sql
    - supabase/migrations/20260311000009_construction_functions.sql
    - supabase/migrations/20260311000010_pg_cron_jobs.sql
  modified: []

key-decisions:
  - "Production buildings (sawmill, quarry, glassblower, sulfur_pit) added to city_buildings CHECK constraint alongside 10 city buildings — required so process_resource_tick() can find a matching production building for all 5 resource types"
  - "Production buildings seeded at level=1 assigned_workers=3 by on_city_created so all 5 resources produce from day one"
  - "pg_cron extension created via migration file (not seed.sql or dashboard) to avoid schema-does-not-exist error on supabase db reset"
  - "process_resource_tick() uses CONTINUE WHEN to skip resources with no production building (defensive guard against missing rows)"
  - "deduct_resource() raises SQLSTATE insufficient_resources exception on failure to allow Edge Function transaction auto-rollback"

patterns-established:
  - "SECURITY DEFINER SET search_path = '' for all PL/pgSQL functions that write game state"
  - "pg_cron registered via migration, not seed.sql, to ensure idempotent supabase db reset"
  - "REPLICA IDENTITY FULL required on all tables published to supabase_realtime"

requirements-completed: [RSRC-01, RSRC-02, RSRC-03, RSRC-04, BLDG-01, BLDG-05]

# Metrics
duration: 3min
completed: 2026-03-11
---

# Phase 2 Plan 01: Core Economy Tables and Server-Side Game Loop Summary

**7 Supabase migrations establishing city_resources, city_buildings, construction_queue tables with pg_cron-driven resource production tick and construction completion — all 5 resources produce automatically every 5 minutes from day one**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-11T01:51:06Z
- **Completed:** 2026-03-11T01:54:49Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Three economy tables (city_resources, city_buildings, construction_queue) with RLS, REPLICA IDENTITY FULL, and Realtime publication — fully server-write-only from client perspective
- on_city_created trigger seeds 5 resource rows (wood=500, gold=500, others=0) and 14 building rows; production buildings start at level=1 assigned_workers=3 so all 5 resources immediately produce
- Server-side game loop: process_resource_tick() updates every city's resources using production formula (workers * level * 1.0) capped at warehouse capacity; complete_building_upgrades() completes builds when finish_at passes; deduct_resource() atomically spends resources for Edge Functions
- pg_cron jobs registered via migration: resource-tick every 5 min and construction-tick every 1 min, both active

## Task Commits

Each task was committed atomically:

1. **Task 1: Create economy tables and on_city_created trigger** - `2d9e46f` (feat)
2. **Task 2: Create server-side functions and pg_cron jobs** - `0d39617` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified

- `supabase/migrations/20260311000004_create_city_resources.sql` - city_resources table: RLS, REPLICA IDENTITY FULL, Realtime, SELECT-only RLS for owner
- `supabase/migrations/20260311000005_create_city_buildings.sql` - city_buildings table: 14-type CHECK constraint, RLS, REPLICA IDENTITY FULL, Realtime
- `supabase/migrations/20260311000006_create_construction_queue.sql` - construction_queue table: UNIQUE(city_id), RLS, REPLICA IDENTITY FULL, Realtime
- `supabase/migrations/20260311000007_on_city_created_trigger.sql` - AFTER INSERT trigger on cities: seeds 5 resources + 14 buildings with production buildings at level=1 workers=3
- `supabase/migrations/20260311000008_resource_production_functions.sql` - process_resource_tick() and deduct_resource() SECURITY DEFINER functions
- `supabase/migrations/20260311000009_construction_functions.sql` - complete_building_upgrades() SECURITY DEFINER function
- `supabase/migrations/20260311000010_pg_cron_jobs.sql` - pg_cron extension + resource-tick + construction-tick job registration

## Decisions Made

- **Production buildings in city_buildings:** The CHECK constraint includes 14 building types (10 city + 4 production: sawmill, quarry, glassblower, sulfur_pit). Without the production buildings, process_resource_tick() would only produce gold (via town_hall). All 5 production buildings are seeded at level=1 assigned_workers=3 by on_city_created.
- **pg_cron via migration:** The extension must be in a migration file, not seed.sql, to avoid the "schema cron does not exist" error during `supabase db reset`. The extension is created with `CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog` (idempotent).
- **deduct_resource SQLSTATE:** Uses custom error code `insufficient_resources` so Edge Functions can catch specific exception types and return structured error responses.
- **process_resource_tick defensive guard:** `CONTINUE WHEN r.workers = 0 OR r.prod_level = 0` skips any resource where the production building is missing or at level 0, preventing division or incorrect updates.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required. pg_cron is bundled with Supabase local dev and registered via migration.

## Next Phase Readiness

- All economy tables and functions ready for Plan 02-02 (upgrade-building Edge Function)
- deduct_resource() signature: `(p_city_id uuid, p_resource_type text, p_amount numeric)` — Edge Function calls this for each resource cost
- construction_queue UNIQUE(city_id) enforces one-build-at-a-time at DB level
- Realtime subscriptions on city_resources and city_buildings ready for Flutter UI (Plan 02-03)

---
*Phase: 02-core-economy*
*Completed: 2026-03-11*
