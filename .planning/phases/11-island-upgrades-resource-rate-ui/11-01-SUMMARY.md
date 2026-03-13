---
phase: 11-island-upgrades-resource-rate-ui
plan: "01"
subsystem: database
tags: [supabase, postgresql, edge-function, deno, island-upgrade, resource-production]

# Dependency graph
requires:
  - phase: 10-economy-foundation
    provides: "process_resource_tick() 5-step loop, deduct_resource RPC, upgrade-building Edge Function pattern"
provides:
  - "islands.resource_level column (INTEGER 0-10) enabling cooperative island upgrades"
  - "process_resource_tick() extended with island multiplier (1.0 + level * 0.10) in Step 1"
  - "donate-island-wood Edge Function for wood donation with race-safe atomic increment"
affects: [12-combat-and-pillage, phase-11-ui-plans]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Conditional UPDATE optimistic lock: .eq('resource_level', currentLevel) prevents race at max level"
    - "COALESCE(i.resource_level, 0) in LEFT JOIN for NULL-safe island multiplier"
    - "v_island_mult = 1.0 + (island_resource_level * 0.10) in process_resource_tick() Step 1"

key-files:
  created:
    - supabase/migrations/20260314000001_island_resource_level.sql
    - supabase/functions/donate-island-wood/index.ts
  modified: []

key-decisions:
  - "Island multiplier applies to all 4 production resources (wood/marble/crystal/sulfur) uniformly — luxury type distinction deferred to v1.2"
  - "Wood donation cost uses fixed constant table (300 * 1.5^level) defined in Edge Function — no DB lookup needed"
  - "Race condition handled via optimistic lock (.eq resource_level = currentLevel) — deducted wood is not refunded on race (accepted v1 limitation)"
  - "Islands table NOT added to Realtime publication — island screen re-fetches on mount; effect visible at next 5-minute tick"

patterns-established:
  - "Pattern: Optimistic lock on island upgrade — UPDATE with equality check on current level prevents concurrent race to level 11"
  - "Pattern: DONATION_COSTS constant table in Edge Function — mirrors buildingBaseTimes/BASE_COSTS from upgrade-building"

requirements-completed: [RSRC-01, RSRC-02]

# Metrics
duration: 5min
completed: 2026-03-14
---

# Phase 11 Plan 01: Island Resource Level Backend Summary

**Island resource_level column on islands table (0-10) + donate-island-wood Edge Function with race-safe atomic upgrade + process_resource_tick() extended with island production multiplier (1.0 + level * 0.10)**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-03-13T21:41:47Z
- **Completed:** 2026-03-13T21:46:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- SQL migration adds `resource_level INTEGER NOT NULL DEFAULT 0 CHECK (resource_level BETWEEN 0 AND 10)` to `islands` table
- Full rewrite of `process_resource_tick()` with cities aliased as `c`, LEFT JOIN on `islands`, `v_island_mult` applied to Step 1 production formula; Steps 2-5 identical to Phase 10
- `donate-island-wood` Edge Function follows INFR-02 pattern exactly: auth validation, city ownership check, max level 10 enforcement (409), wood deduction via `deduct_resource` RPC, atomic conditional UPDATE with race protection

## Task Commits

Each task was committed atomically:

1. **Task 1: Island resource_level migration + process_resource_tick() extension** - `16bf1a1` (feat)
2. **Task 2: donate-island-wood Edge Function** - `1d7204a` (feat)

**Plan metadata:** (pending docs commit)

## Files Created/Modified

- `supabase/migrations/20260314000001_island_resource_level.sql` — ALTER TABLE adds resource_level to islands; full CREATE OR REPLACE FUNCTION process_resource_tick() with island multiplier in Step 1
- `supabase/functions/donate-island-wood/index.ts` — Deno Edge Function for cooperative island wood donation; DONATION_COSTS table, race-safe optimistic lock, deduct_resource RPC integration

## Decisions Made

- **All 4 resources get island bonus:** Applied multiplier to wood/marble/crystal/sulfur uniformly. Luxury-type-specific bonus is deferred to v1.2 per plan recommendation.
- **DONATION_COSTS constant table:** 300 * 1.5^level rounded up, from level 0 (300 wood) to level 9 (11,537 wood). Defined in Edge Function constant — no DB lookup required.
- **Optimistic lock for race safety:** `.eq('resource_level', currentLevel)` in UPDATE ensures atomicity at max level 10. If race occurs, 409 is returned but deducted wood is NOT refunded — accepted v1 limitation (race is extremely rare given donation cost scale).
- **Islands NOT in Realtime:** Island level changes are infrequent and effect is only visible at the next 5-minute tick. Island screen re-fetches on mount is sufficient for v1.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required. Migration applies via `supabase db push` or local migration runner. Edge Function deploys via `supabase functions deploy donate-island-wood`.

## Next Phase Readiness

- Backend for island upgrades is complete (RSRC-01, RSRC-02 satisfied)
- `donate-island-wood` Edge Function is ready to call from Flutter with `{ city_id }` POST body
- `process_resource_tick()` now applies island multiplier — observable after migrating local DB
- Next plan (11-02 or 11-03) can build Flutter UI: island screen donate button + production rate display in resource bar
- `Island.fromJson` needs `resource_level` field added in the Flutter UI plan (Pitfall 3 from RESEARCH)

---
*Phase: 11-island-upgrades-resource-rate-ui*
*Completed: 2026-03-14*
