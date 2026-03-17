---
phase: 20-seed-data
plan: 01
subsystem: seed-data
tags: [seed, bots, database, idempotency]
dependency_graph:
  requires:
    - "18-01: is_bot/is_admin columns in profiles table"
    - "18-01: bot_schedules table"
    - "Phase 10+: city_units, city_buildings, city_resources tables"
  provides:
    - "20 bot accounts with diverse game states for gameplay testing"
    - "Admin flag on Leonidas for GodMode testing in Phases 21-22"
  affects:
    - "supabase/seed.sql (extended with 1042 lines of bot seed data)"
tech_stack:
  added: []
  patterns:
    - "ON CONFLICT (id) DO NOTHING for auth.users/auth.identities idempotency"
    - "ON CONFLICT (bot_id) DO UPDATE for bot_schedules refresh-on-reseed"
    - "ON CONFLICT (city_id, unit_type) DO UPDATE for city_units idempotency"
    - "UPDATE for profiles/city_buildings/city_resources (naturally idempotent)"
key_files:
  created: []
  modified:
    - supabase/seed.sql
decisions:
  - "Bot UUIDs use deterministic pattern b{NN}00000-0000-0000-0000-000000000000 for easy identification and ON CONFLICT correctness"
  - "Low-tier bots (1-7) get only barracks=1 units (hoplite/cook) to enforce unlock gate correctness"
  - "20 bots placed by trigger random slot assignment — result: each on a distinct island (20 distinct islands observed)"
  - "Aggression distribution: 5x0 (bots 1,2,5,6,13), 5x1 (bots 3,4,7,8,9), 5x2 (bots 10,11,12,14,18), 5x3 (bots 15,16,17,19,20)"
metrics:
  duration: "10 minutes"
  completed_date: "2026-03-17"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 1
requirements:
  - SEED-01
  - SEED-02
---

# Phase 20 Plan 01: Seed Bot Accounts Summary

**One-liner:** 20 tiered bot accounts seeded via idempotent SQL with Greek hero names, diverse building/army/resource profiles, and even aggression distribution 0-3.

## What Was Built

Extended `supabase/seed.sql` with 1042 lines appended after the existing 7 human test accounts. The bot seed data covers 8 sections:

1. **Admin flag** — Leonidas (a1111111) set `is_admin=true` for GodMode testing
2. **auth.users** — 20 bot accounts in a single batch INSERT with `ON CONFLICT (id) DO NOTHING`
3. **auth.identities** — 20 identity rows, same idempotency pattern
4. **Profile UPDATEs** — display_name + `is_bot=true` for all 20 bots
5. **city_buildings UPDATEs** — Per-bot, only overriding trigger defaults; barracks levels sized to match assigned units
6. **city_resources UPDATEs** — All 5 resource types (wood/marble/crystal/sulfur/gold) at tier-appropriate amounts
7. **city_units UPSERTs** — `ON CONFLICT (city_id, unit_type) DO UPDATE`; unit type variety increases by tier
8. **bot_schedules** — 20 rows with 45-second stagger, `ON CONFLICT (bot_id) DO UPDATE`

## Verification Results

| Check | Expected | Actual | Pass |
|-------|----------|--------|------|
| Double db reset (idempotency) | Both exit 0 | Both exit 0 | Yes |
| Bot count | 20 | 20 | Yes |
| Leonidas is_admin | true | true | Yes |
| Tier distribution | 7 low / 7 mid / 6 high | 7 low / 7 mid / 6 high | Yes |
| Island spread | >= 8 | 20 (each bot on distinct island) | Yes |
| Aggression distribution | 5x0, 5x1, 5x2, 5x3 | 5x0, 5x1, 5x2, 5x3 | Yes |
| bot_schedules count | 20 | 20 | Yes |
| Barracks-unit consistency | All bots unlocked | Verified all 20 | Yes |

## Tier Details

**Low tier (bots 1-7):** barracks=1, hoplite + cook only, resources 500-1500
**Mid tier (bots 8-14):** barracks=2-3, adds archer/phalanx/cavalry, resources 2000-5000
**High tier (bots 15-20):** barracks=4-5, full unit mix including catapult/mortar, resources 5000-15000

## Commits

- `ca5568f` — feat(20-01): add 20 bot accounts with tiered game states to seed.sql

## Deviations from Plan

None — plan executed exactly as written. Docker Desktop was not running at the start of Task 2 but was started automatically (not a seed script issue).

## Self-Check: PASSED

- `supabase/seed.sql` exists and contains 1487 lines: FOUND
- Commit `ca5568f` exists: FOUND
- All verification queries returned expected results
