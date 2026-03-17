# Phase 21: GodMode Backend - Research

**Researched:** 2026-03-17
**Domain:** PostgreSQL SECURITY DEFINER RPCs, Supabase admin access pattern, GoRouter redirect guards
**Confidence:** HIGH

## Summary

This phase delivers the backend API layer for GodMode: five SECURITY DEFINER RPCs gated by `is_admin` at the Postgres layer, plus a Flutter GoRouter `/godmode` route guard. No new tables are required — all RPCs query existing tables (`profiles`, `cities`, `city_resources`, `city_buildings`, `city_units`, `bot_schedules`, `battles`, `unit_movements`, `spy_reports`). The `is_admin` column on `profiles` and `bot_schedules.is_paused` both exist from Phase 18.

The security model is simple and proven: SECURITY DEFINER bypasses RLS so the function can read any player's data, but the function itself enforces the `is_admin` check on `auth.uid()` as the very first statement. Non-admin callers get `RAISE EXCEPTION` with SQLSTATE `insufficient_privilege`. This is identical to how `dev_*` functions are already structured, except those lack the `is_admin` guard.

The GoRouter extension is mechanical: add a GoRoute for `/godmode` outside the `StatefulShellRoute`, and add one rule to the existing `_redirect()` function. The `ProfileNotifier.isAdmin` getter already exists and is ready to use.

**Primary recommendation:** Follow the exact `SECURITY DEFINER SET search_path = ''` + `is_admin` guard pattern, mirror the `run_bot_decisions()` loop structure for `godmode_force_action`, and add the `/godmode` route as a top-level sibling of `/city-view`.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**RPC Response Shape**
- `godmode_get_world_state()` returns a single JSONB aggregate with a players array — each entry contains resources, army counts (land total / naval total), building levels, bot status (`is_bot`, `is_paused`), and active battles summary
- Single RPC for entire world state — simpler for Phase 22 dashboard consumption; split later only if performance requires it
- Army sizes represented as total land unit count and total naval unit count (summary, not per-unit-type breakdown)
- Active battles include battle ID, attacker/defender names, and current turn number only
- All RPCs are `SECURITY DEFINER SET search_path = ''` with an explicit `is_admin` check on `auth.uid()` at the top — return error/empty if non-admin

**Admin Route Guard**
- `/godmode` route is a top-level GoRoute outside the StatefulShellRoute — GodMode is a separate full-page experience, not part of the game shell with bottom nav
- Non-admin users hitting `/godmode` are redirected to `/map` via the existing `_redirect()` function in app_router.dart
- Defense in depth: client-side route guard is UX-only; every RPC independently rejects non-admin callers at the Postgres layer
- Route guard reads `isAdmin` from the `ProfileNotifier` getter (already implemented in Phase 18)

**Bot Control RPCs**
- `godmode_set_bot_paused(p_bot_id UUID, p_paused BOOLEAN)` — sets `is_paused` on `bot_schedules` row; the next bot-think-tick skips that bot
- `godmode_force_action(p_bot_id UUID)` — triggers one immediate `run_bot_decisions()` cycle for the specified bot only, without waiting for the cron schedule
- Pause only prevents NEW decisions — in-flight movements and ongoing battles continue unaffected
- Speed adjustment (manipulating `next_action_at`) deferred to Phase 22 UI implementation

**Resource Modification RPC**
- `admin_set_resources(p_player_id UUID, p_wood NUMERIC, p_marble NUMERIC, p_crystal NUMERIC, p_sulfur NUMERIC, p_gold NUMERIC)` — sets any player's resource balances
- Values clamped to 0 minimum — no negative resources allowed
- Non-admin callers rejected at Postgres layer (same `is_admin` check pattern)

**Event Feed RPC**
- `godmode_get_events(p_limit INTEGER DEFAULT 50, p_event_type TEXT DEFAULT NULL)` returns JSONB array of recent events
- Queries `battles`, `trade_routes`, and `spy_reports` tables, unions them sorted by timestamp
- Each event includes: event type, timestamp, involved player names, and a one-line summary
- Optional `p_event_type` filter: 'battle', 'trade', 'espionage', or NULL for all types

### Claude's Discretion
- Exact JSONB structure and key naming within RPC responses
- Whether to use CTE vs subquery for the event feed union
- Index strategy on event tables for the feed query (likely not needed at current scale)
- Error message wording for non-admin rejection
- Whether godmode_force_action should return void or a result summary

### Deferred Ideas (OUT OF SCOPE)
- Bot speed adjustment UI — Phase 22 (GodMode Flutter Dashboard)
- GodMode world map overlay — v1.3+ future requirement (GOD-F01)
- Time-travel replay — v1.3+ future requirement (GOD-F02)
- Economy analytics dashboard — v1.3+ future requirement (GOD-F03)
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| GOD-05 | GodMode access is secured via is_admin check at Postgres layer — service_role key never reaches Flutter client | All five RPCs use SECURITY DEFINER + is_admin guard. Route guard reads isAdmin from ProfileNotifier (no service_role in Flutter). |
</phase_requirements>

---

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|---------------|---------|---------|--------------|
| PL/pgSQL SECURITY DEFINER | PostgreSQL 15 (Supabase) | Admin RPCs that bypass RLS while enforcing own auth check | Established project pattern — used in resource_production_functions, construction_functions, all cron tick functions |
| Supabase `rpc()` client | supabase_flutter ^2.x | Flutter call site for all admin RPCs | All server operations already use `.rpc()` in this project |
| go_router | ^14.x (already in pubspec) | `/godmode` route declaration and redirect guard | Existing routing infrastructure |
| flutter_riverpod | ^2.x (already in project) | Reading `profileProvider.notifier.isAdmin` in redirect | Existing state management layer |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| PostgreSQL `jsonb_agg` / `json_build_object` | built-in | Build JSONB response shapes in `godmode_get_world_state()` | Any RPC returning aggregated multi-row data |
| PostgreSQL CTE (`WITH`) | built-in | Composing multi-table queries in event feed | Cleaner than nested subqueries for the UNION of battles + trade movements + spy_reports |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SECURITY DEFINER RPC | Edge Function with service_role key | Edge Function would require service_role key in Flutter — explicitly forbidden by STATE.md and GOD-05 |
| Single `godmode_get_world_state()` RPC | Multiple per-entity RPCs | Multiple RPCs add round-trip overhead and complexity; decided in CONTEXT.md to keep single RPC |
| GoRouter redirect in `_redirect()` | Separate router config | Project uses a single `_redirect()` function — extending it keeps the redirect logic centralized |

**Installation:** No new packages required — all dependencies already present.

---

## Architecture Patterns

### Recommended Project Structure

New files for this phase:
```
supabase/migrations/
└── 20260317000005_godmode_rpcs.sql     # All five GodMode RPCs in one migration

lib/core/router/
└── app_router.dart                      # Modified: add /godmode route + redirect rule

lib/features/godmode/
└── screens/
    └── godmode_placeholder_screen.dart  # Minimal placeholder — Phase 22 builds real UI
```

### Pattern 1: SECURITY DEFINER Admin Guard

**What:** Every GodMode RPC starts with an `is_admin` check that raises an exception for non-admins before touching any data.

**When to use:** Every RPC in this phase, without exception.

```sql
-- Source: project pattern from 20260311000008_resource_production_functions.sql
-- Extended with is_admin guard for GodMode RPCs

CREATE OR REPLACE FUNCTION public.godmode_get_world_state()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_caller_id uuid;
  v_is_admin  boolean;
BEGIN
  -- Admin guard: must be the FIRST statement
  v_caller_id := auth.uid();
  SELECT is_admin INTO v_is_admin
  FROM public.profiles
  WHERE id = v_caller_id;

  IF NOT FOUND OR v_is_admin IS NOT TRUE THEN
    RAISE EXCEPTION 'permission denied: admin access required'
      USING ERRCODE = 'insufficient_privilege';  -- SQLSTATE 42501
  END IF;

  -- ... data query follows
END;
$$;
```

**SQLSTATE `42501` (`insufficient_privilege`):** Supabase client surfaces this as a `PostgrestException` with code `"42501"`. Flutter can catch and display appropriately.

### Pattern 2: Single-Bot Decision Run (godmode_force_action)

**What:** `godmode_force_action` runs the same priority chain as `run_bot_decisions()` but for exactly one bot, ignoring `is_paused` and `next_action_at`.

**When to use:** Implementing `godmode_force_action(p_bot_id UUID)`.

```sql
-- Source: derived from 20260317000004_bot_run_decisions_and_cron.sql

-- The full run_bot_decisions() loop:
--   FOR bot IN SELECT ... WHERE is_paused = false AND next_action_at <= NOW() LOOP
--     IF NOT bot_decide_upgrade(...) THEN
--       IF NOT bot_decide_train(...) THEN
--         IF bot.aggression > 0 THEN PERFORM bot_decide_attack(...); END IF;
--       END IF;
--     END IF;
--   END LOOP;
--
-- godmode_force_action replaces the loop with a direct fetch of the single bot,
-- skipping is_paused and next_action_at checks.
```

### Pattern 3: JSONB Aggregation for World State

**What:** Use `jsonb_agg(json_build_object(...))` with JOINs across profiles, cities, city_resources, city_buildings, city_units, bot_schedules, and battles.

**When to use:** Implementing `godmode_get_world_state()`.

```sql
-- Source: PostgreSQL built-ins; pattern consistent with existing jsonb usage in battles table

-- Army count approach — land vs naval split matches city_units unit_type CHECK:
-- Land units: hoplite, phalanx, archer, cavalry, catapult, mortar, medic, cook
-- Naval units: cargo_ship, ram_ship, catapult_ship, mortar_ship, diving_boat

SELECT
  COALESCE(SUM(CASE WHEN unit_type IN (
    'hoplite','phalanx','archer','cavalry','catapult','mortar','medic','cook'
  ) THEN quantity ELSE 0 END), 0) AS land_count,
  COALESCE(SUM(CASE WHEN unit_type IN (
    'cargo_ship','ram_ship','catapult_ship','mortar_ship','diving_boat'
  ) THEN quantity ELSE 0 END), 0) AS naval_count
FROM public.city_units WHERE city_id = c.id
```

### Pattern 4: Event Feed via CTE UNION

**What:** `godmode_get_events` unions three event sources using CTEs, then aggregates to JSONB.

**When to use:** Implementing the event feed RPC.

**Key insight on "trade_routes" in CONTEXT.md:** There is no separate `trade_routes` table. Trade events are rows in `unit_movements` where `movement_type = 'trade'` (added in migration `20260316000002`). The event feed should query `unit_movements WHERE movement_type = 'trade'` for trade events.

```sql
-- Event sources:
-- 1. battles (created_at, battle ID, attacker/defender player names, turn_number)
-- 2. unit_movements WHERE movement_type = 'trade' (created_at, owner, destination city owner)
-- 3. spy_reports (created_at, player_id, target_city_id)
--
-- Join profiles for display names on all three sources.
```

### Pattern 5: GoRouter Redirect Extension

**What:** Add `/godmode` rule to existing `_redirect()` function and add a top-level `GoRoute`.

**When to use:** Adding the admin route guard in `app_router.dart`.

```dart
// Source: lib/core/router/app_router.dart existing _redirect() pattern

// Add after Rule 4 (Session + complete profile but still on auth screen),
// before Rule 5 (no redirect):

// Rule 4b: Non-admin user attempting to access /godmode → redirect to /map
if (location == '/godmode' && !profileNotifier.isAdmin) {
  return '/map';
}

// In GoRouter routes list — add as top-level sibling of /city-view GoRoute:
GoRoute(
  path: '/godmode',
  builder: (context, state) => const GodModePlaceholderScreen(),
),
```

### Anti-Patterns to Avoid

- **Admin check after data query:** The `is_admin` guard MUST be the first statement in every RPC — checking after querying data is a data leak even if the result is discarded.
- **Using `auth.uid()` in RLS policy for admin tables:** `bot_schedules` has deny-all RLS. GodMode RPCs use SECURITY DEFINER to bypass this — do NOT add admin RLS policies to `bot_schedules`.
- **Returning `NULL` for non-admin callers:** `RAISE EXCEPTION` is required (not `RETURN NULL`) so the Flutter client gets an explicit error, not silent empty data.
- **Setting `search_path` without `''`:** All SECURITY DEFINER functions MUST use `SET search_path = ''` and fully qualify all table references as `public.tablename` — this prevents search_path injection attacks.
- **Wine resource omission:** `city_resources` includes `wine` (added Phase 10 migration `20260313000001`). The world state resource snapshot must include wine alongside wood/marble/crystal/sulfur/gold.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Bot single-decision trigger | New bot AI execution code | Call existing `bot_decide_upgrade()`, `bot_decide_train()`, `bot_decide_attack()` directly | These functions are already SECURITY DEFINER with all edge cases handled |
| Admin identity check | Custom auth tables or JWT claims | `SELECT is_admin FROM public.profiles WHERE id = auth.uid()` | `is_admin` column exists from Phase 18 with REVOKE on client UPDATE |
| Resource modification validation | Custom range/type checks | `GREATEST(p_wood, 0)` clamp + existing `city_resources` CHECK constraint | Table already enforces `amount >= 0` |

**Key insight:** `godmode_force_action` is NOT a new bot engine — it is a single-bot variant of the existing `run_bot_decisions()` body. Copy the inner loop body, replace the `FOR bot IN SELECT...WHERE is_paused=false` with a direct lookup of `p_bot_id`.

---

## Common Pitfalls

### Pitfall 1: Missing `public.` Prefix in SECURITY DEFINER Function

**What goes wrong:** `search_path = ''` means PostgreSQL cannot resolve unqualified table names like `profiles` — the query throws `ERROR: relation "profiles" does not exist`.

**Why it happens:** SECURITY DEFINER with empty search_path is intentional security hardening. Every existing function in the project uses `public.tablename`.

**How to avoid:** Every table reference in GodMode RPCs must use `public.` prefix. Verify by searching the migration for any bare table name without schema prefix.

**Warning signs:** Migration applies but calling the RPC throws a relation-not-found error.

### Pitfall 2: Route Guard Race Condition (Profile Loading)

**What goes wrong:** User navigates to `/godmode` before profile loads — `isAdmin` returns `false` (default when `AsyncLoading`) — user gets redirected to `/map` even if they are admin.

**Why it happens:** `ProfileNotifier.isAdmin` returns `false` during `AsyncLoading` state (see `state.whenOrNull` with `?? false` fallback).

**How to avoid:** In `_redirect()`, check `profileState.isLoading` before checking `isAdmin` — the existing Rule 2 already holds authenticated users during loading. The `/godmode` admin check must be placed AFTER Rule 2 so loading state is resolved first.

**Warning signs:** Admin user gets redirected to `/map` on first navigation to `/godmode`, but succeeds after a page refresh.

### Pitfall 3: Wine Resource Omitted from World State

**What goes wrong:** `admin_set_resources` and `godmode_get_world_state` only handle 5 resource types (wood/marble/crystal/sulfur/gold) but the schema has 6 (`wine` added in Phase 10).

**Why it happens:** Phase 21 CONTEXT.md specifies the 5 "core" resources by name — wine may be forgotten because it was added later.

**How to avoid:** `admin_set_resources` signature has 5 params as decided in CONTEXT.md (wine excluded from admin control is an acceptable v1.3 scope decision). But `godmode_get_world_state` resource snapshot should aggregate ALL `city_resources` rows, not hardcode specific types — use `jsonb_object_agg(resource_type, amount)` to capture all 6 types automatically.

**Warning signs:** World state resource map shows only 5 entries per player when queried.

### Pitfall 4: godmode_force_action Updates next_action_at

**What goes wrong:** Force-triggering a bot accidentally resets its `next_action_at`, causing it to skip its next scheduled tick.

**Why it happens:** Copying `run_bot_decisions()` body includes the `UPDATE bot_schedules SET next_action_at = ...` at the end of the loop.

**How to avoid:** `godmode_force_action` should NOT update `next_action_at` — the forced action is out-of-band and should not interfere with the regular schedule.

**Warning signs:** After force-action, the bot does not take its next scheduled action for 15+ minutes.

### Pitfall 5: Event Feed "trade_routes" Table Does Not Exist

**What goes wrong:** CONTEXT.md mentions querying `trade_routes` table — no such table exists in the schema.

**Why it happens:** Trade in this project uses `unit_movements` with `movement_type = 'trade'` (migration `20260316000002`).

**How to avoid:** Query `public.unit_movements WHERE movement_type = 'trade'` for trade events. Use `created_at` as the timestamp. Join `public.profiles` via `owner_id` for the sender display name, and via city owner for the receiver display name.

**Warning signs:** Migration fails with `relation "trade_routes" does not exist`.

---

## Code Examples

Verified patterns from project source:

### Admin Guard Pattern (used in every GodMode RPC)

```sql
-- Source: project SECURITY DEFINER convention from 20260311000008_resource_production_functions.sql
-- Extended with is_admin guard pattern decided in CONTEXT.md

DECLARE
  v_caller_id uuid;
  v_is_admin  boolean;
BEGIN
  v_caller_id := auth.uid();

  SELECT is_admin INTO v_is_admin
  FROM public.profiles
  WHERE id = v_caller_id;

  IF NOT FOUND OR v_is_admin IS NOT TRUE THEN
    RAISE EXCEPTION 'permission denied: admin access required'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  -- ... rest of function body
```

### bot_schedules is_paused Update

```sql
-- Source: bot_schedules schema from 20260317000001_bot_schema.sql
-- bot_id is PK, is_paused is boolean NOT NULL DEFAULT false

UPDATE public.bot_schedules
  SET is_paused = p_paused
  WHERE bot_id = p_bot_id;

IF NOT FOUND THEN
  RAISE EXCEPTION 'bot not found: %', p_bot_id
    USING ERRCODE = 'no_data_found';
END IF;
```

### Resource SET with 0 clamp

```sql
-- Source: pattern derived from dev_inject_resources in 20260312000008_dev_rpc_helpers.sql
-- city_resources has UNIQUE(city_id, resource_type) — use UPDATE not upsert

UPDATE public.city_resources
  SET amount = GREATEST(p_wood, 0),
      updated_at = NOW()
  WHERE city_id = v_city_id AND resource_type = 'wood';
-- Repeat for marble, crystal, sulfur, gold (wine excluded per CONTEXT.md)
```

### GoRoute for /godmode (top-level, outside StatefulShellRoute)

```dart
// Source: app_router.dart — add as sibling of existing /city-view GoRoute
// (outside StatefulShellRoute.indexedStack)

GoRoute(
  path: '/godmode',
  builder: (context, state) => const GodModePlaceholderScreen(),
),
```

### Redirect rule for /godmode

```dart
// Source: app_router.dart _redirect() — insert as Rule 4b
// Must come AFTER the profileState.isLoading check (Rule 2) to avoid race condition

// Rule 4b: Non-admin accessing /godmode
if (location == '/godmode' && !profileNotifier.isAdmin) {
  return '/map';
}
```

### JSONB resource aggregation (all types, future-proof)

```sql
-- Source: PostgreSQL built-ins; avoids hardcoding resource type list
-- Captures all 6 resource types (including wine) automatically

SELECT jsonb_object_agg(resource_type, amount)
FROM public.city_resources
WHERE city_id = c.id
-- Result: {"wood": 1200, "marble": 800, "crystal": 400, "sulfur": 200, "gold": 3000, "wine": 500}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| service_role key in Flutter for admin ops | SECURITY DEFINER RPC with is_admin Postgres check | STATE.md v1.3 decision | Service_role key never touches the Flutter client |
| Separate cron jobs per bot behavior | Single `run_bot_decisions()` consolidated tick | Phase 19 | `godmode_force_action` calls the same function body |

---

## Open Questions

1. **godmode_force_action return type**
   - What we know: CONTEXT.md leaves this to Claude's discretion
   - What's unclear: `void` vs `jsonb` summary of what action was taken
   - Recommendation: Return `text` (e.g., `'upgrade'`, `'train'`, `'attack'`, `'none'`) so Phase 22 UI can display what action was forced. Costs nothing, makes debugging easier.

2. **admin_set_resources: single-city or all-cities for a player**
   - What we know: Signature takes `p_player_id` — but resources live on `city_resources` (per city). A player could have multiple cities in future versions.
   - What's unclear: Should the RPC set resources on ALL cities for the player, or require a city_id?
   - Recommendation: Since v1.3 has one city per player (confirmed by seed data and Phase 20 bot setup), look up the player's city via `SELECT id FROM public.cities WHERE owner_id = p_player_id LIMIT 1`. Document the one-city assumption in a TODO comment.

3. **Event feed timestamp field for unit_movements**
   - What we know: `unit_movements` has `created_at` but no `completed_at`
   - What's unclear: Should trade events use `created_at` (departure) or `arrive_at` (completion)?
   - Recommendation: Use `created_at` for consistency with battles and spy_reports which also use `created_at`. The event feed shows when the action was initiated.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Not yet established (Phase 23 = TEST-01/TEST-02) |
| Config file | None — see Wave 0 |
| Quick run command | `supabase db reset && supabase db dump` (schema validation) |
| Full suite command | Phase 23 will define |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| GOD-05 | Non-admin caller to any GodMode RPC gets SQLSTATE 42501 | manual-only (SQL) | `supabase db reset` then `SELECT public.godmode_get_world_state()` as non-admin user | ❌ Wave 0 |
| GOD-05 | Admin caller gets valid JSONB data | manual-only (SQL) | Call RPC as a1111111 (is_admin=true) via Supabase Studio | ❌ Wave 0 |
| GOD-05 | /godmode route redirects non-admin to /map | manual (Flutter) | Run app, login as non-admin, navigate to /godmode | ❌ Wave 0 |
| GOD-05 | service_role key does not appear in any Flutter file | static analysis | `grep -r "service_role" lib/` returns no results | ❌ Wave 0 |

> Formal automated tests are deferred to Phase 23. Phase 21 validation is manual SQL execution and grep check.

### Sampling Rate

- **Per task commit:** `supabase db reset` to verify migration applies cleanly
- **Per wave merge:** Manual SQL test of each RPC as admin and non-admin user
- **Phase gate:** All 5 RPCs callable; non-admin rejection verified; route guard working

### Wave 0 Gaps

- [ ] Migration file `supabase/migrations/20260317000005_godmode_rpcs.sql` — covers GOD-05
- [ ] `lib/features/godmode/screens/godmode_placeholder_screen.dart` — minimal screen for route
- [ ] Grep check: `grep -r "service_role" lib/` must return empty

---

## Sources

### Primary (HIGH confidence)

- Project migrations `20260317000001_bot_schema.sql` — `is_admin`, `is_bot`, `bot_schedules` schema verified
- Project migrations `20260317000004_bot_run_decisions_and_cron.sql` — `run_bot_decisions()` body verified
- Project migrations `20260311000008_resource_production_functions.sql` — SECURITY DEFINER SET search_path pattern verified
- Project `lib/core/router/app_router.dart` — GoRouter `_redirect()` function and route structure verified
- Project `lib/features/profile/providers/profile_provider.dart` — `ProfileNotifier.isAdmin` getter verified
- Project migrations `20260316000002_trade_movement_type_and_deduct_resources.sql` — confirmed trade uses `unit_movements.movement_type='trade'`, no separate `trade_routes` table

### Secondary (MEDIUM confidence)

- Supabase SECURITY DEFINER documentation pattern: `USING ERRCODE = 'insufficient_privilege'` is SQLSTATE 42501, standard PostgreSQL
- GoRouter redirect pattern for role-based guards: consistent with existing `_redirect()` logic in the project

### Tertiary (LOW confidence)

- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries/tools are already in the project with verified usage
- Architecture: HIGH — patterns copied directly from existing migrations and router code
- Pitfalls: HIGH — identified by direct inspection of schema and existing code (not guesswork)

**Research date:** 2026-03-17
**Valid until:** 2026-04-17 (30 days — stable Supabase + Flutter stack)
