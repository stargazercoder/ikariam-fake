---
phase: 19-bot-behavior-engine
plan: "01"
subsystem: bot-behavior
tags: [plpgsql, bot, migration, security-definer, construction-queue, training-queue]
dependency_graph:
  requires:
    - "20260317000001_bot_schema.sql (bot_schedules, profiles.is_bot)"
    - "20260311000009_construction_functions.sql (construction_queue schema)"
    - "20260311000014_training_functions.sql (training_queue schema, deduct_units)"
    - "deduct_resource() RPC (migration 20260311000008)"
  provides:
    - "public.bot_decide_upgrade(p_city_id uuid) RETURNS boolean"
    - "public.bot_decide_train(p_city_id uuid) RETURNS boolean"
  affects:
    - "construction_queue (INSERT)"
    - "training_queue (INSERT)"
    - "city_resources (deductions via deduct_resource)"
    - "islands.resource_level (UPDATE for donation fallback)"
tech_stack:
  added: []
  patterns:
    - "SECURITY DEFINER SET search_path = '' (matching all existing cron functions)"
    - "EXCEPTION WHEN unique_violation to handle race conditions on UNIQUE(city_id) queues"
    - "GET DIAGNOSTICS v_rows = ROW_COUNT for conditional island UPDATE check"
key_files:
  created:
    - supabase/migrations/20260317000002_bot_helper_functions.sql
  modified: []
decisions:
  - "Bot builds cheapest building by level ASC (not total cost) — matches CONTEXT.md spec"
  - "Island donation fallback fires when no building is affordable (not after all buildings maxed)"
  - "Dev speed multiplier hardcoded to 0.2 in PL/pgSQL — pg_cron has no APP_ENVIRONMENT env var access"
  - "Island donation race condition accepted as v1 edge case (mirrors donate-island-wood Edge Function decision)"
  - "Building base times all 1 minute (same as upgrade-building/index.ts BASE_TIMES)"
metrics:
  duration_minutes: 3
  completed_date: "2026-03-17"
  tasks_completed: 1
  tasks_total: 1
  files_created: 1
  files_modified: 0
---

# Phase 19 Plan 01: Bot Helper Functions Summary

**One-liner:** PL/pgSQL SECURITY DEFINER functions bot_decide_upgrade and bot_decide_train that write directly to construction_queue/training_queue with island donation fallback and race condition handling.

## What Was Built

Single migration file `supabase/migrations/20260317000002_bot_helper_functions.sql` containing two helper functions used by the bot behavior engine:

### `bot_decide_upgrade(p_city_id uuid) RETURNS boolean`

Attempts to queue the cheapest building upgrade for a bot city. Logic:

1. Returns false immediately if construction_queue already has an entry for the city
2. Loads city resources in one query (all 5 resource types)
3. Iterates city buildings ordered by level ASC; for each, computes upgrade cost using `CEIL(base_cost * 1.5^current_level)` — the same formula as `upgrade-building/index.ts`
4. If affordable: deducts each non-zero resource via `deduct_resource()`, calculates `finish_at` using `CEIL(1.0 * 1.2^current_level)` minutes, INSERTs to construction_queue
5. Island donation fallback: if no building is affordable, computes `CEIL(300 * 1.5^island_level)` wood cost; if affordable, deducts wood and conditionally UPDATEs `islands.resource_level = resource_level + 1` with race-condition guard
6. Catches `unique_violation` (SQLSTATE 23505) on queue INSERT to handle concurrent player/bot race

### `bot_decide_train(p_city_id uuid) RETURNS boolean`

Attempts to queue land unit training for a bot city. Logic:

1. Returns false immediately if training_queue already has an entry for the city
2. Returns false if barracks not found or level = 0
3. Loads city resources in one query
4. Iterates land units ordered by total cost ASC — only units the barracks level unlocks
5. First affordable unit is selected; quantity = `LEAST(50, FLOOR(min_resource / unit_cost))` across all resources
6. Deducts resources for `unit_cost * quantity` via `deduct_resource()`
7. Calculates `finish_at` as `GREATEST(1, CEIL(1.0 * quantity * 0.2))` minutes (0.2 = dev speed multiplier)
8. INSERTs to training_queue; catches `unique_violation` for race condition

## Commits

| Hash | Message |
|------|---------|
| 514daef | feat(19-01): add bot_decide_upgrade and bot_decide_train helper functions |

## Tasks

| # | Name | Status | Commit |
|---|------|--------|--------|
| 1 | Create bot_decide_upgrade and bot_decide_train helper functions | Done | 514daef |

## Decisions Made

1. **Building selection order:** Level ASC (not total upgrade cost) — cheapest in terms of which building has the most room to grow, consistent with CONTEXT.md "lowest-level building" spec.

2. **Island donation trigger:** Falls back when no building is affordable (city has too few resources), not when all buildings are at max level. This matches the spec's "if all buildings are queued or unaffordable" intent.

3. **Dev speed multiplier (0.2):** Hardcoded in PL/pgSQL since pg_cron functions cannot read `APP_ENVIRONMENT` env var. Matches the `DEV_SPEED_MULTIPLIER = 0.2` in `train-units/index.ts`. TODO comment added for future game_config parameterization.

4. **Building base time = 1 minute:** All buildings use base time of 1 minute, matching `upgrade-building/index.ts BASE_TIMES`. Duration formula: `CEIL(1.0 * 1.2^current_level)`.

5. **Island donation race condition:** Accepted v1 edge case — wood may be deducted but level not incremented if two bots donate simultaneously. Mirrors the documented behavior in `donate-island-wood/index.ts`.

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- [x] `supabase/migrations/20260317000002_bot_helper_functions.sql` exists (16508 bytes)
- [x] Contains `CREATE OR REPLACE FUNCTION public.bot_decide_upgrade(p_city_id uuid)`
- [x] Contains `CREATE OR REPLACE FUNCTION public.bot_decide_train(p_city_id uuid)`
- [x] Both functions return `boolean`
- [x] Both functions use `SECURITY DEFINER SET search_path = ''`
- [x] Contains `PERFORM public.deduct_resource(` (multiple occurrences)
- [x] Contains `INSERT INTO public.construction_queue`
- [x] Contains `INSERT INTO public.training_queue`
- [x] Contains `UPDATE public.islands SET resource_level = resource_level + 1`
- [x] Contains `unique_violation` (in both EXCEPTION blocks)
- [x] Building costs match: town_hall wood=200 gold=100; barracks wood=150 gold=100
- [x] Unit costs match: cook wood=20 gold=20; hoplite wood=40 gold=30
- [x] Unit unlock levels match: cook barracks >= 1; mortar barracks >= 5
- [x] Contains `-- TODO: parameterize via game_config table` comment
- [x] Commit 514daef exists in git log
- [ ] `supabase db reset` — Docker Desktop not running in this environment; static verification passed all criteria
