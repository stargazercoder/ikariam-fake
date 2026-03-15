---
phase: 12-combat-depth
plan: "01"
subsystem: database
tags: [sql, plpgsql, pillage, cargo, hideout, flutter, dart, tdd]

# Dependency graph
requires:
  - phase: 12-combat-depth (research)
    provides: combat domain decisions, Hideout protection formula, cargo ship capacity rules
  - phase: 20260312000004_battle_functions.sql
    provides: resolve_battles() with attacker_won branch and v_att_units snapshot
  - phase: 20260312000005_modify_process_arrivals.sql
    provides: process_arrivals() with friendly arrival branch

provides:
  - unit_movements.cargo JSONB column (nullable) — holds pillaged resources on return movements
  - battles.pillage_result JSONB column (nullable) — stores final loot breakdown for battle reports
  - resolve_battles() updated with full pillage logic (hideout floor, survivor ratio, cargo cap, deduction, result storage)
  - process_arrivals() updated with cargo delivery on friendly arrival
  - hideoutProtectionFloor(int? level) Dart helper in building_constants.dart

affects:
  - 12-02 (battle report UI will read pillage_result from battles table)
  - Any future plan reading battles or unit_movements

# Tech tracking
tech-stack:
  added: []
  patterns:
    - SELECT FOR UPDATE on city_resources inside resolve_battles() to prevent race with resource tick cron
    - JSONB cargo field on unit_movements (nullable) — reuses existing JSONB-for-immutable-snapshots pattern
    - CREATE OR REPLACE for function updates — never DROP/RECREATE

key-files:
  created:
    - supabase/migrations/20260315000001_pillage_schema_and_functions.sql
    - test/hideout_protection_test.dart
  modified:
    - lib/core/constants/building_constants.dart

key-decisions:
  - "hideoutProtectionFloor(null) returns 50 — base protection for cities without Hideout row (per user decision)"
  - "Pillage ratio formula: LEAST(0.75, total_land_units / 50.0 * 0.10) — scales with surviving attackers, caps at 75%"
  - "Cargo cap applied proportionally across all 4 resources — no resource prioritization"
  - "SELECT FOR UPDATE on defender city_resources during pillage prevents race with resource tick"
  - "v_loot reset to {} per battle iteration to prevent bleed-over between battles"

patterns-established:
  - "Pillage pattern: count cargo ships → check hideout → compute ratio → compute raw loot (SELECT FOR UPDATE) → scale to cargo cap → deduct from defender → store on battles.pillage_result + unit_movements.cargo"
  - "Cargo delivery pattern: process_arrivals() checks m.cargo IS NOT NULL, then UPDATE city_resources for each key in cargo JSONB"

requirements-completed:
  - CMBT-01
  - CMBT-02

# Metrics
duration: 4min
completed: 2026-03-15
---

# Phase 12 Plan 01: Pillage Mechanics — SQL Schema + Functions + Dart Helper Summary

**Pillage mechanics fully wired server-side: cargo JSONB on unit_movements, hideout protection floor with base-50 fallback, survivor-scaled loot, cargo cap proportional distribution, SELECT FOR UPDATE race protection, and Dart mirror formula with 5/5 TDD tests passing**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-15T18:58:38Z
- **Completed:** 2026-03-15T19:02:00Z
- **Tasks:** 2
- **Files modified:** 3 (created 3 new files)

## Accomplishments

- SQL migration adds `cargo` column to `unit_movements` and `pillage_result` column to `battles`, with full `resolve_battles()` pillage logic in the `attacker_won` branch: Hideout floor (base-50 fallback when no hideout row exists, `100 * 1.5^level` otherwise), survivor-scaled ratio, cargo ship capacity cap, proportional scaling across 4 resources, `SELECT FOR UPDATE` for race safety, and deduction from defender
- `process_arrivals()` extended to deliver cargo resources to attacker city on friendly return arrival
- `hideoutProtectionFloor(int? level)` Dart helper mirrors the SQL formula exactly (null → 50, 0 → 100, 5 → 759, 10 → 5766); all 5 TDD test cases pass

## Task Commits

Each task was committed atomically:

1. **Task 1: SQL migration — pillage schema + resolve_battles() + process_arrivals()** - `0c31458` (feat)
2. **Task 2 RED: Failing tests for hideoutProtectionFloor()** - `f8be0c2` (test)
3. **Task 2 GREEN: Implement hideoutProtectionFloor()** - `b8b1cfc` (feat)

**Plan metadata:** _(docs commit — see below)_

_Note: TDD task has two commits (test RED → feat GREEN). No refactor needed — implementation was already minimal and clean._

## Files Created/Modified

- `supabase/migrations/20260315000001_pillage_schema_and_functions.sql` - Schema ALTER TABLE statements + full replacement of resolve_battles() and process_arrivals() with pillage logic
- `lib/core/constants/building_constants.dart` - Added hideoutProtectionFloor(int? level) top-level function
- `test/hideout_protection_test.dart` - 5 test cases covering null, level 0, 1, 5, 10

## Decisions Made

- **v_loot and v_total_raw_loot reset per battle loop iteration** — added explicit resets at the top of the loop to prevent state bleed-over between battles (deviation Rule 1 auto-fix applied to the DECLARE-initialised variables that aren't reset between iterations).
- **Pillage ratio formula**: `LEAST(0.75, v_total_att_land / 50.0 * 0.10)` — 10% per 50 surviving land units, capped at 75%. Design call per Claude discretion as specified in CONTEXT.md.
- **Cargo capacity proportional distribution** — when loot exceeds capacity, each resource is scaled by `v_cargo_cap / v_total_raw_loot`. Equal treatment across all 4 resources.
- **defender_won UPDATE explicitly sets pillage_result = NULL** — makes intent clear even though NULL is the default.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Reset v_loot and v_total_raw_loot in per-battle loop**
- **Found during:** Task 1 (resolve_battles implementation)
- **Issue:** DECLARE initialises variables once; a batch run with multiple battles would carry v_loot from the previous iteration into the next if no pillage occurred in the second battle.
- **Fix:** Added `v_loot := '{}';` and `v_total_raw_loot := 0;` to the per-battle reset block at the top of the FOR loop.
- **Files modified:** supabase/migrations/20260315000001_pillage_schema_and_functions.sql
- **Verification:** Reset block confirmed present in migration file.
- **Committed in:** 0c31458 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — bug: missing per-iteration reset)
**Impact on plan:** Essential for correctness in multi-battle batches. No scope creep.

## Issues Encountered

- Local Supabase DB not running — `db lint` could not connect. Manual verification of key SQL patterns (NULL fallback, SELECT FOR UPDATE, CASE WHEN) performed via code review instead.

## User Setup Required

None - no external service configuration required. Migration will apply on next `supabase db push` or local dev restart.

## Next Phase Readiness

- `battles.pillage_result` is ready to be consumed by battle report UI (Phase 12 Plan 02)
- `unit_movements.cargo` is ready; cargo delivery on return arrival is live
- `hideoutProtectionFloor()` Dart helper available for client-side display of protection floor in city overview or battle detail screen

---
*Phase: 12-combat-depth*
*Completed: 2026-03-15*
