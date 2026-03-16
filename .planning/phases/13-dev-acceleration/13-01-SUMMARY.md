---
phase: 13
plan: "01"
subsystem: dev-acceleration
tags: [dev-tools, rpc, edge-functions, speed-multiplier]
dependency_graph:
  requires: []
  provides: [dev_bulk_spawn_units RPC, dev_instant_complete RPC, DEV_SPEED_MULTIPLIER in train-units, DEV_SPEED_MULTIPLIER in dispatch-units]
  affects: [train-units edge function, dispatch-units edge function, city_units table, training_queue table, construction_queue table]
tech_stack:
  added: []
  patterns: [SECURITY DEFINER RPC with jsonb_each_text iteration, env-gated speed multiplier via APP_ENVIRONMENT]
key_files:
  created:
    - supabase/migrations/20260316000001_dev_bulk_spawn_and_instant_complete.sql
  modified:
    - supabase/functions/train-units/index.ts
    - supabase/functions/dispatch-units/index.ts
decisions:
  - "construction_queue instant-complete sets finish_at = NOW() - 1 second so existing complete_construction() cron handles level-up logic unchanged"
  - "dispatch-units renames travelMinutes to rawTravelMinutes and applies Math.max(1, ceil(raw * multiplier)) to preserve 1-minute floor"
metrics:
  duration_seconds: 91
  completed_date: "2026-03-16T08:05:34Z"
  tasks_completed: 2
  files_created: 1
  files_modified: 2
---

# Phase 13 Plan 01: Dev Acceleration — Server-Side Infrastructure Summary

**One-liner:** Two SECURITY DEFINER RPC functions for bulk unit spawning and instant queue completion, plus 1/5 speed multipliers in train-units and dispatch-units Edge Functions gated by APP_ENVIRONMENT.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create SQL migration with dev_bulk_spawn_units and dev_instant_complete | f132bfe | supabase/migrations/20260316000001_dev_bulk_spawn_and_instant_complete.sql |
| 2 | Add 1/5 dev speed multiplier to train-units and dispatch-units Edge Functions | e788726 | supabase/functions/train-units/index.ts, supabase/functions/dispatch-units/index.ts |

## What Was Built

### SQL Migration (Task 1)

`supabase/migrations/20260316000001_dev_bulk_spawn_and_instant_complete.sql` adds two SECURITY DEFINER functions:

**`dev_bulk_spawn_units(p_city_id uuid, p_units jsonb)`**
- Iterates the JSONB map with `jsonb_each_text` and upserts each unit type into `city_units`
- Uses `ON CONFLICT (city_id, unit_type) DO UPDATE SET quantity = existing + excluded` — additive, never overwrites
- Follows the exact pattern from `dev_rpc_helpers.sql` (same header, same upsert logic)

**`dev_instant_complete(p_city_id uuid)`**
- Training queue: FOR loop over `training_queue WHERE city_id = p_city_id` — upserts awarded units, then deletes the queue row
- Construction queue: sets `finish_at = NOW() - INTERVAL '1 second'` so the existing `complete_construction()` cron handles level-up logic on its next tick (no duplication of upgrade logic)

### Edge Function Patches (Task 2)

Both Edge Functions now read `APP_ENVIRONMENT` from Deno env at module scope:

```typescript
const APP_ENV = Deno.env.get('APP_ENVIRONMENT') ?? 'development';
const IS_PRODUCTION = APP_ENV === 'production';
const DEV_SPEED_MULTIPLIER = IS_PRODUCTION ? 1.0 : 0.2;
```

**train-units:** `durationMinutes = UNIT_BASE_TIMES[unit_type] * quantity * DEV_SPEED_MULTIPLIER`
- 10 hoplites: 10 min × 0.2 = 2 min in dev; 10 min in production

**dispatch-units:** `rawTravelMinutes = calcTravelMinutes(...)` then `travelMinutes = Math.max(1, Math.ceil(rawTravelMinutes * DEV_SPEED_MULTIPLIER))`
- `calcTravelMinutes` function signature is unchanged
- `Math.max(1, ...)` floor preserved — minimum 1 minute even in dev mode

## Decisions Made

1. **Construction queue completion strategy:** Set `finish_at` to the past rather than calling upgrade logic inline. This avoids duplicating the `complete_construction()` cron function's level-up logic and ensures the same code path runs whether triggered by cron or dev toolbar.

2. **`rawTravelMinutes` rename in dispatch-units:** The original `travelMinutes` variable was used in both the `arriveAt` calculation and the success response body. Renaming to `rawTravelMinutes` and computing `travelMinutes` after the multiplier ensures the rest of the function (response body, arrive_at) uses the dev-adjusted value automatically.

## Deviations from Plan

None — plan executed exactly as written.

## Success Criteria Verification

- Two new SECURITY DEFINER RPC functions callable via Supabase client: PASS
- Training time is 1/5 in dev mode: PASS (DEV_SPEED_MULTIPLIER = 0.2)
- Travel time is 1/5 in dev mode with minimum 1 minute floor: PASS (Math.max(1, ceil(...)))
- All changes are inert when APP_ENVIRONMENT = 'production': PASS (multiplier = 1.0)

## Self-Check: PASSED

Files verified to exist:
- FOUND: supabase/migrations/20260316000001_dev_bulk_spawn_and_instant_complete.sql
- FOUND: supabase/functions/train-units/index.ts (modified)
- FOUND: supabase/functions/dispatch-units/index.ts (modified)

Commits verified:
- FOUND: f132bfe — feat(13-01): add dev_bulk_spawn_units and dev_instant_complete RPC functions
- FOUND: e788726 — feat(13-01): add 1/5 dev speed multiplier to train-units and dispatch-units
