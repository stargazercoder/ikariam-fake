---
phase: 05-combat
plan: "01"
subsystem: combat-engine
tags: [postgresql, pg_cron, battles, combat, migrations, supabase]
dependency_graph:
  requires: [04-01, 04-02]
  provides: [battles-table, battle_turns-table, resolve_battles-fn, battle-tick-cron]
  affects: [process_arrivals, unit_movements, city_units]
tech_stack:
  added: []
  patterns: [pg_cron-tick, SECURITY-DEFINER-function, JSONB-snapshot, ratio-damage-formula, naval-gate-keeper]
key_files:
  created:
    - supabase/migrations/20260312000001_add_movement_type_to_unit_movements.sql
    - supabase/migrations/20260312000002_create_battles.sql
    - supabase/migrations/20260312000003_create_battle_turns.sql
    - supabase/migrations/20260312000004_battle_functions.sql
    - supabase/migrations/20260312000005_modify_process_arrivals.sql
    - supabase/migrations/20260312000006_battle_cron_job.sql
  modified: []
decisions:
  - "Naval gate-keeper: when attacker had naval units but all are wiped this turn, battle ends immediately with defender_won — land units never engage"
  - "Attacker with no naval vs defender with naval: naval phase is skipped (attacker land units can still fight)"
  - "Rejected arriving army (city already in battle): units are lost — delete movement row, no refund"
  - "Return travel formula: max(1, ceil(sqrt(dx^2+dy^2) * 2)) minutes, matching Dart calcTravelMinutes with BASE_MINUTES_PER_GRID_UNIT=2"
  - "Unit stats stored as JSONB constants inside resolve_battles() body — not a DB table — rebalancing needs no schema migration"
  - "Town Wall defense bonus: +5% per level as flat multiplier on defender land defense total"
  - "Empty casualties recorded as NULL in battle_turns (not empty object) to distinguish 'no casualties' from 'phase skipped'"
metrics:
  duration_minutes: 18
  completed_date: "2026-03-12"
  tasks_completed: 2
  files_created: 6
  files_modified: 0
---

# Phase 5 Plan 01: Combat Database Layer Summary

**One-liner:** Turn-based server-side battle engine with two-phase naval/land combat, ratio damage formula, and pg_cron resolution every 5 minutes.

## What Was Built

Six migration files establish the complete server-side combat engine:

1. `movement_type` column on `unit_movements` — defaults to `'attack'`, CHECK constraint allows `'attack'` and `'return'` for victorious attacker return trips.

2. `battles` table — stores active and historical battle state with JSONB unit snapshots, partial unique index preventing two active battles at the same defender city, RLS (participants only), Realtime enabled.

3. `battle_turns` table — per-turn record of naval and land phase outcomes with casualty JSONB per side and survivor snapshots; UNIQUE(battle_id, turn_number), RLS via battles join, Realtime enabled.

4. `resolve_battles()` SECURITY DEFINER function — iterates battles with `next_turn_at <= NOW()` under `FOR UPDATE SKIP LOCKED`, runs naval phase then land phase, applies ratio damage formula, handles naval gate-keeper, writes `battle_turns` record, updates battle status; creates return movement and clears/restores city_units on battle end.

5. `process_arrivals()` (modified) — adds destination city ownership check: friendly arrivals use existing upsert logic; enemy arrivals create a `battles` row or reject the army if a battle is already active.

6. `battle-tick` cron job — fires every minute, calls `resolve_battles()`; 5th cron job alongside resource-tick, construction-tick, training-tick, arrivals-tick.

## Combat Formula

- **Ratio damage:** `loss_ratio = enemy_total_attack / max(own_total_defense, 1)`
- **Per unit casualties:** `min(floor(quantity * loss_ratio), quantity)`
- **Naval gate-keeper:** if attacker had naval units and all are wiped this turn → `defender_won`, land phase `blocked`
- **Town Wall bonus:** `wall_bonus = 1.0 + 0.05 * wall_level`, applied to defender land defense total

## Verification Results

```
battle-tick cron job: FOUND
resolve_battles() function: FOUND
process_arrivals() function: FOUND
battles table RLS: ENABLED
battle_turns table RLS: ENABLED
battles in supabase_realtime: YES
battle_turns in supabase_realtime: YES
Total cron jobs: 5 (resource-tick, construction-tick, training-tick, arrivals-tick, battle-tick)
supabase db reset: CLEAN (no errors)
```

## Deviations from Plan

### Auto-applied Discretion Items

**1. Naval phase skipped (attacker no naval, defender has naval)**
- Plan listed this as Claude's discretion
- Decision: skip naval phase entirely — attacker land units still engage, mirroring the "skip if neither has naval" behavior

**2. Empty battle outcome as NULL**
- `{}` casualties recorded as NULL in battle_turns columns to distinguish "no casualties" from "phase did not occur"

**3. DECLARE block for naval remaining count**
- Used inner `DECLARE` block inside the ELSE branch to scope `v_att_naval_remaining` / `v_def_naval_remaining` — avoids polluting outer scope and keeps the gate-keeper check readable

**4. Land outcome fallback**
- When no land units exist on either side, `land_outcome` is set to `'ongoing'` rather than NULL to satisfy the CHECK constraint

## Self-Check: PASSED
