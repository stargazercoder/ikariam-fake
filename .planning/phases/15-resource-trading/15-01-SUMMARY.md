---
phase: 15-resource-trading
plan: "01"
subsystem: backend
tags: [trading, migration, edge-function, rpc, movement]
dependency_graph:
  requires:
    - "20260312000001_add_movement_type_to_unit_movements.sql (movement_type column)"
    - "20260315000001_pillage_schema_and_functions.sql (cargo column, deduct_units pattern)"
  provides:
    - "deduct_resources RPC"
    - "send-trade Edge Function"
    - "movement_type='trade' accepted by DB"
  affects:
    - "unit_movements table (CHECK constraint extended)"
    - "process_arrivals() delivers cargo on friendly arrival (already handles cargo JSONB)"
tech_stack:
  added: []
  patterns:
    - "deduct_resources mirrors deduct_units (SECURITY DEFINER, IF NOT FOUND RAISE)"
    - "send-trade mirrors dispatch-units (anon auth + service role admin, calcTravelMinutes)"
key_files:
  created:
    - supabase/migrations/20260316000002_trade_movement_type_and_deduct_resources.sql
    - supabase/functions/send-trade/index.ts
  modified: []
decisions:
  - "Migration renamed from 20260316000001 to 20260316000002 due to timestamp conflict with existing dev migration"
  - "Self-trade (origin == destination) allowed — no rejection added, per plan spec"
  - "Warehouse capacity check uses formula 500 * pow(1.5, warehouseLevel) to match Dart client"
metrics:
  duration: "4 minutes"
  completed_date: "2026-03-16"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 0
---

# Phase 15 Plan 01: Trade Infrastructure Summary

DB migration and Edge Function providing server-side resource trading: extended movement_type CHECK to include 'trade', atomic deduct_resources RPC, and send-trade Edge Function that validates ownership/cargo/warehouse capacity before deducting and inserting a trade movement.

## Tasks Completed

| # | Name | Commit | Files |
|---|------|--------|-------|
| 1 | DB migration — extend movement_type CHECK and create deduct_resources RPC | 560ecea | supabase/migrations/20260316000002_trade_movement_type_and_deduct_resources.sql |
| 2 | send-trade Edge Function | 3555816 | supabase/functions/send-trade/index.ts |

## What Was Built

**DB Migration (`20260316000002`):**
- Drops the existing `unit_movements_movement_type_check` constraint and re-adds it with `'trade'` alongside `'attack'` and `'return'`
- Creates `deduct_resources(p_city_id, p_resource_type, p_amount)` SECURITY DEFINER function that atomically deducts a resource and raises `EXCEPTION 'Insufficient %'` when balance is insufficient

**send-trade Edge Function:**
- POST endpoint following the same auth pattern as `dispatch-units` (anon client for getUser, service role admin for mutations)
- Validates: origin ownership, destination existence, non-empty cargo, only tradeable types (`['wood', 'marble', 'crystal', 'sulfur']`), positive integer amounts
- Server-side balance pre-check before deduction (defense-in-depth)
- Warehouse capacity check: `500 * Math.pow(1.5, warehouseLevel)` per resource type
- Deducts each resource atomically via `deduct_resources` RPC
- Inserts `unit_movements` row with `movement_type='trade'`, `units={}`, `cargo=<JSONB>`
- Returns `{ success, arrive_at, travel_minutes }`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Migration timestamp conflict**
- **Found during:** Task 1
- **Issue:** `20260316000001_dev_bulk_spawn_and_instant_complete.sql` already exists with the same timestamp as specified in the plan
- **Fix:** Renamed migration to `20260316000002_trade_movement_type_and_deduct_resources.sql`
- **Files modified:** File renamed before creation
- **Commit:** 560ecea

## Verification Results

- CHECK constraint verified via `pg_get_constraintdef`: includes `'attack'`, `'return'`, `'trade'`
- `deduct_resources` function verified via `pg_proc` with `prosecdef=true` (SECURITY DEFINER)
- Migration applied cleanly via `supabase db reset`
- send-trade file confirmed: all acceptance criteria patterns present

## Self-Check: PASSED

- [x] `supabase/migrations/20260316000002_trade_movement_type_and_deduct_resources.sql` exists
- [x] `supabase/functions/send-trade/index.ts` exists
- [x] Commit 560ecea exists (migration)
- [x] Commit 3555816 exists (edge function)
- [x] CHECK constraint includes 'trade' (verified via psql)
- [x] deduct_resources function exists (verified via psql)
