# Phase 2: Core Economy - Research

**Researched:** 2026-03-11
**Domain:** PostgreSQL pg_cron + Supabase Realtime + Flutter Riverpod Economy Loop
**Confidence:** HIGH

## Summary

Phase 2 implements the core idle loop: server-side resource production every 5 minutes, warehouse capacity enforcement, and a single-slot construction queue for building upgrades. Everything runs through PostgreSQL and Supabase, with Flutter displaying the state reactively via Realtime streams and local countdowns computed from server UTC timestamps.

The architecture has two server-side heartbeats managed by pg_cron: a resource tick (every 5 minutes) that calls a SECURITY DEFINER function to add production to all city resources (capped at warehouse capacity), and a construction tick (also every 5 minutes, or every minute) that completes any building upgrade whose `finish_at` has passed. The Flutter client never writes resource amounts or completes buildings — it only reads and subscribes to Realtime changes. The build queue mutation goes through a Supabase Edge Function that validates the one-upgrade-at-a-time constraint server-side.

The biggest implementation risk for this phase is the pg_cron + pg_cron local development gap: the `cron` schema does not exist by default in `supabase db reset` unless pg_cron is explicitly created in a migration (not seed.sql). The project decision from STATE.md confirms "pg_cron jobs must be created via raw SQL (not dashboard UI)" — this means migrations must install the extension AND create the cron job in the same SQL block.

**Primary recommendation:** Use pg_cron to run a single `process_resource_tick()` PL/pgSQL function every 5 minutes that updates all city_resources rows in one transaction. Use a second pg_cron job (every minute) to run `complete_building_upgrades()` which sets buildings to their new level when `finish_at <= NOW()`. The Flutter client subscribes to city_resources and city_buildings table changes via `supabase.from().stream()` and Riverpod StreamProviders for live UI updates.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| RSRC-01 | Cities produce 5 resource types: Wood, Marble, Crystal, Sulfur, Gold | `city_resources` table with one row per (city_id, resource_type); pg_cron tick inserts/updates all rows |
| RSRC-02 | Resource production runs server-side via pg_cron every 5 minutes | `cron.schedule('resource-tick', '*/5 * * * *', 'SELECT process_resource_tick()')` in migration; extension enabled via `CREATE EXTENSION pg_cron` |
| RSRC-03 | Production rate calculated as workers x building_level x research_bonus | `process_resource_tick()` reads `city_buildings.level` for the relevant building type, uses worker count from `city_buildings.assigned_workers`, research_bonus=1.0 for v1 (v2 research not in scope) |
| RSRC-04 | Resources capped by Warehouse building capacity | `process_resource_tick()` reads `city_buildings` for Warehouse level, computes capacity = `base_capacity x 1.5^level`, does `LEAST(current + production, capacity)` |
| BLDG-01 | City supports 10 building types | `city_buildings` table with `building_type` enum; seed function inserts Town Hall level 1 for each city at creation |
| BLDG-02 | Buildings can be upgraded with cost formula (base_cost x 1.5^level) | Edge Function `upgrade-building` validates cost, deducts resources, inserts into `construction_queue`; cost computed server-side using base costs per building type |
| BLDG-03 | Building upgrade takes time calculated as base_time x 1.2^level (minutes) | `finish_at = NOW() + (base_time_minutes * POWER(1.2, current_level))::int * interval '1 minute'` |
| BLDG-04 | Only one construction can run at a time per city | Edge Function `upgrade-building` checks `SELECT 1 FROM construction_queue WHERE city_id = $1 AND finish_at > NOW()` before inserting |
| BLDG-05 | Construction completion detected and applied by pg_cron tick | `cron.schedule('construction-tick', '* * * * *', 'SELECT complete_building_upgrades()')` — runs every minute, updates `city_buildings.level` where finish_at has passed |
</phase_requirements>

---

## Standard Stack

### Core (unchanged from Phase 1)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| supabase_flutter | ^2.12.0 | Supabase client: Auth, DB, Realtime | Already installed; `.stream()` and `.onPostgresChanges()` handle realtime |
| flutter_riverpod | ^3.3.1 | State management | Already installed; StreamProvider wraps Supabase streams |
| go_router | ^17.1.0 | Routing | Already installed; no changes needed |

### New: PostgreSQL Backend
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| pg_cron | 1.6.4 (Supabase bundled) | Scheduled SQL jobs at cron intervals | Project decision: server-side ticks via pg_cron; no alternatives |
| Supabase Edge Functions | Deno 2.x | Validate + execute building upgrades | Project decision: all mutations via Edge Functions |
| PL/pgSQL functions | PostgreSQL 17 | resource tick, construction completion logic | Runs in same DB transaction; no network latency; SECURITY DEFINER bypasses RLS |

### No New Flutter Dependencies
Phase 2 does not add new pub.dev packages. All functionality uses:
- `supabase_flutter` `.stream()` for realtime resource/building display
- `dart:async` `Timer.periodic` for client-side countdown display
- Riverpod `StreamProvider` for reactive state from Supabase streams

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| pg_cron SQL function for resource tick | Edge Function called via pg_net | pg_net adds HTTP overhead; pure SQL is faster, atomic, no cold start |
| pg_cron SQL function for construction tick | DB trigger on INSERT into construction_queue | Trigger fires on insert but cannot fire on time elapsed; pg_cron is correct tool |
| Single `*/5 * * * *` tick for both | Two separate schedules | Separate schedules are clearer and independently adjustable |
| Supabase `.stream()` for resource display | Polling with `Future.delayed` + `ref.invalidate` | Realtime stream is lower latency and more efficient |

---

## Architecture Patterns

### Recommended Project Structure Extension
```
lib/
├── features/
│   ├── city/
│   │   ├── data/
│   │   │   ├── city_repository.dart          # existing (SELECT-only)
│   │   │   ├── resources_repository.dart     # NEW: stream city_resources
│   │   │   └── buildings_repository.dart     # NEW: stream city_buildings + queue
│   │   ├── providers/
│   │   │   ├── city_provider.dart            # existing
│   │   │   ├── resources_provider.dart       # NEW: StreamProvider<List<CityResource>>
│   │   │   ├── buildings_provider.dart       # NEW: StreamProvider<List<CityBuilding>>
│   │   │   └── construction_provider.dart    # NEW: AsyncNotifier for upgrade action
│   │   ├── models/
│   │   │   ├── city_resource.dart            # NEW: typed model
│   │   │   └── city_building.dart            # NEW: typed model
│   │   └── screens/
│   │       ├── city_screen.dart              # extended: shows resources + buildings
│   │       └── building_upgrade_sheet.dart   # NEW: bottom sheet with upgrade details
│   └── ...
├── core/
│   └── constants/
│       ├── building_constants.dart           # NEW: base_cost, base_time per type
│       └── resource_constants.dart           # NEW: resource type enum, base capacities

supabase/
├── migrations/
│   ├── 20260311000004_create_city_resources.sql
│   ├── 20260311000005_create_city_buildings.sql
│   ├── 20260311000006_create_construction_queue.sql
│   ├── 20260311000007_resource_production_functions.sql
│   ├── 20260311000008_construction_functions.sql
│   └── 20260311000009_pg_cron_jobs.sql
└── functions/
    └── upgrade-building/
        └── index.ts                          # NEW: Edge Function
```

### Pattern 1: pg_cron Resource Tick Function
**What:** A PL/pgSQL SECURITY DEFINER function called by pg_cron every 5 minutes. Iterates all cities, computes production for each resource type, applies warehouse cap, updates city_resources.
**When to use:** The ONLY way resource totals change. Never updated by client or Edge Function directly.
**Example:**
```sql
-- Migration: 20260311000007_resource_production_functions.sql
-- Source: Supabase pg_cron docs + pg_cron GitHub

CREATE OR REPLACE FUNCTION public.process_resource_tick()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  rec RECORD;
  v_production   numeric;
  v_capacity     numeric;
  v_base_cap     constant numeric := 500;   -- warehouse base capacity
  v_cap_factor   constant numeric := 1.5;   -- capacity growth per level
BEGIN
  -- For every city x resource type combination
  FOR rec IN
    SELECT
      cr.id            AS resource_id,
      cr.city_id,
      cr.resource_type,
      cr.amount,
      COALESCE(prod_b.level, 0)  AS prod_level,
      COALESCE(prod_b.assigned_workers, 0) AS workers,
      COALESCE(wh.level, 0)  AS warehouse_level
    FROM public.city_resources cr
    -- Join the relevant production building per resource type
    LEFT JOIN public.city_buildings prod_b
      ON prod_b.city_id = cr.city_id
      AND prod_b.building_type = CASE cr.resource_type
        WHEN 'wood'    THEN 'sawmill'
        WHEN 'marble'  THEN 'quarry'
        WHEN 'crystal' THEN 'glassblower'
        WHEN 'sulfur'  THEN 'sulfur_pit'
        WHEN 'gold'    THEN 'town_hall'
        ELSE NULL
      END
    LEFT JOIN public.city_buildings wh
      ON wh.city_id = cr.city_id AND wh.building_type = 'warehouse'
  LOOP
    -- Production formula: workers x building_level x research_bonus (1.0 for v1)
    v_production := rec.workers * rec.prod_level * 1.0;

    -- Warehouse capacity: base_cap * 1.5^warehouse_level
    v_capacity := v_base_cap * POWER(v_cap_factor, rec.warehouse_level);

    -- Update: cap to warehouse capacity
    UPDATE public.city_resources
    SET
      amount     = LEAST(rec.amount + v_production, v_capacity),
      updated_at = NOW()
    WHERE id = rec.resource_id;
  END LOOP;
END;
$$;
```

### Pattern 2: pg_cron Construction Completion Function
**What:** A PL/pgSQL SECURITY DEFINER function called every minute. Finds all queue entries where `finish_at <= NOW()`, increments building level, removes the queue entry.
**When to use:** Only mechanism that advances a building level. Client reads the result via Realtime.
**Example:**
```sql
-- Migration: 20260311000008_construction_functions.sql

CREATE OR REPLACE FUNCTION public.complete_building_upgrades()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    SELECT cq.id AS queue_id, cq.city_id, cq.building_type, cq.target_level
    FROM public.construction_queue cq
    WHERE cq.finish_at <= NOW()
  LOOP
    -- Advance the building level
    UPDATE public.city_buildings
    SET level = rec.target_level, updated_at = NOW()
    WHERE city_id = rec.city_id AND building_type = rec.building_type;

    -- Remove from queue
    DELETE FROM public.construction_queue WHERE id = rec.queue_id;
  END LOOP;
END;
$$;
```

### Pattern 3: pg_cron Job Registration (migration, not seed.sql)
**What:** The two pg_cron jobs created via a dedicated migration. The extension must be enabled BEFORE the cron.schedule() calls. The project decision states jobs must be created via raw SQL, not dashboard.
**Critical:** pg_cron installed in a migration file (not seed.sql) to avoid the "schema cron does not exist" error that occurs when seed.sql creates the extension and immediately tries to use it.
**Example:**
```sql
-- Migration: 20260311000009_pg_cron_jobs.sql
-- Source: https://github.com/citusdata/pg_cron
-- Source: https://github.com/supabase/supabase/issues/28966 (seed.sql timing bug)

-- 1. Enable the extension (idempotent)
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;

GRANT USAGE ON SCHEMA cron TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA cron TO postgres;

-- 2. Resource production tick: every 5 minutes
SELECT cron.schedule(
  'resource-tick',
  '*/5 * * * *',
  'SELECT public.process_resource_tick()'
);

-- 3. Construction completion tick: every minute
SELECT cron.schedule(
  'construction-tick',
  '* * * * *',
  'SELECT public.complete_building_upgrades()'
);
```

### Pattern 4: Edge Function — upgrade-building
**What:** The ONLY way a client can queue a building upgrade. Validates: player owns city, building exists, no active construction, sufficient resources. Deducts resources, inserts into construction_queue.
**When to use:** Called from Flutter via `supabaseClient.functions.invoke('upgrade-building', body: {...})`.
**Example:**
```typescript
// supabase/functions/upgrade-building/index.ts
// Source: https://supabase.com/docs/guides/functions/quickstart

import { createClient } from 'jsr:@supabase/supabase-js@2'

const BASE_COSTS: Record<string, Record<string, number>> = {
  // building_type -> { resource_type -> base_amount }
  'town_hall':    { gold: 100, wood: 200 },
  'warehouse':    { wood: 100, marble: 50 },
  'sawmill':      { wood: 50,  gold: 50 },
  // ... etc
}

const BASE_TIMES: Record<string, number> = {
  // building_type -> base_time in minutes
  'town_hall': 10,
  'warehouse': 5,
  'sawmill':   3,
  // ... etc
}

Deno.serve(async (req) => {
  const { city_id, building_type } = await req.json()

  const authHeader = req.headers.get('Authorization')!
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } }
  )

  // Verify the caller owns this city
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })

  const { data: city } = await supabase
    .from('cities')
    .select('id')
    .eq('id', city_id)
    .eq('owner_id', user.id)
    .maybeSingle()
  if (!city) return new Response(JSON.stringify({ error: 'City not found or not owned by you' }), { status: 403 })

  // Use service role for mutations (bypasses RLS)
  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  // Check no active construction
  const { data: activeQueue } = await admin
    .from('construction_queue')
    .select('id')
    .eq('city_id', city_id)
    .gt('finish_at', new Date().toISOString())
    .maybeSingle()

  if (activeQueue) {
    return new Response(JSON.stringify({ error: 'Construction queue is busy' }), { status: 409 })
  }

  // Get current building level
  const { data: building } = await admin
    .from('city_buildings')
    .select('level')
    .eq('city_id', city_id)
    .eq('building_type', building_type)
    .maybeSingle()

  const currentLevel = building?.level ?? 0
  const targetLevel = currentLevel + 1
  const baseCosts = BASE_COSTS[building_type] ?? {}

  // Calculate upgrade cost: base_cost * 1.5^current_level
  const costs: Record<string, number> = {}
  for (const [resource, baseCost] of Object.entries(baseCosts)) {
    costs[resource] = Math.ceil(baseCost * Math.pow(1.5, currentLevel))
  }

  // Deduct resources (will fail if insufficient — checked via DB constraint or explicit check)
  for (const [resourceType, amount] of Object.entries(costs)) {
    const { error } = await admin.rpc('deduct_resource', {
      p_city_id: city_id,
      p_resource_type: resourceType,
      p_amount: amount,
    })
    if (error) {
      return new Response(JSON.stringify({ error: `Insufficient ${resourceType}` }), { status: 400 })
    }
  }

  // Calculate finish time: base_time * 1.2^current_level minutes
  const baseMinutes = BASE_TIMES[building_type] ?? 5
  const durationMinutes = Math.ceil(baseMinutes * Math.pow(1.2, currentLevel))
  const finishAt = new Date(Date.now() + durationMinutes * 60 * 1000).toISOString()

  // Insert into construction queue
  const { error: insertError } = await admin
    .from('construction_queue')
    .insert({
      city_id,
      building_type,
      target_level: targetLevel,
      finish_at: finishAt,
    })

  if (insertError) {
    return new Response(JSON.stringify({ error: insertError.message }), { status: 500 })
  }

  return new Response(JSON.stringify({ success: true, finish_at: finishAt, duration_minutes: durationMinutes }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
```

### Pattern 5: Flutter Realtime Resource Stream (Riverpod StreamProvider)
**What:** `supabase.from('city_resources').stream()` filtered to the current city. Wrapped in a Riverpod `StreamProvider` so the UI rebuilds automatically when pg_cron updates the DB.
**When to use:** City screen resource panel; replaces polling entirely.
**Example:**
```dart
// lib/features/city/providers/resources_provider.dart
// Source: https://supabase.com/docs/reference/dart/stream

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Real-time stream of all city_resources rows for the current player's city.
/// Emits a new list every time pg_cron updates any resource amount.
///
/// Important: store the Stream in a field, not in build(), to prevent
/// the subscription from being cancelled on each rebuild.
final resourcesProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, cityId) {
  return Supabase.instance.client
      .from('city_resources')
      .stream(primaryKey: ['id'])
      .eq('city_id', cityId)
      .order('resource_type');
});
```

### Pattern 6: Client-Side Construction Countdown
**What:** The construction `finish_at` timestamp is stored in UTC. The Flutter client computes the remaining duration locally using `Timer.periodic` — this is display-only, never authoritative.
**When to use:** Building upgrade progress bar / countdown on city screen.
**Example:**
```dart
// lib/features/city/providers/construction_provider.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Streams the active construction queue entry for a given city.
/// Client uses finish_at to compute display countdown — server applies
/// the actual completion via pg_cron.
final constructionQueueProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, cityId) {
  return Supabase.instance.client
      .from('construction_queue')
      .stream(primaryKey: ['id'])
      .eq('city_id', cityId)
      .map((rows) => rows.isEmpty ? null : rows.first);
});

/// Countdown in seconds computed from server UTC finish_at.
/// Updates every second. Pure display logic — never triggers completion.
///
/// Usage in widget:
///   final finishAt = DateTime.parse(queueRow['finish_at']);
///   final remaining = finishAt.toLocal().difference(DateTime.now());
///   // Display remaining.inMinutes, remaining.inSeconds % 60
```

### Anti-Patterns to Avoid
- **Computing resource production in Flutter:** The client never adds resources — it only reads. Production happens server-side in `process_resource_tick()`.
- **Completing buildings in Flutter:** The client never calls an API to complete a building. pg_cron does it. The client detects completion via the Realtime stream when the `city_buildings` row is updated.
- **Storing resource amounts in `cities` table:** Resources have their own `city_resources` table with one row per (city_id, resource_type) — not a JSONB blob in cities.
- **Using `seed.sql` for pg_cron setup:** GitHub issue #28966 confirmed that `cron` schema is not available immediately in seed.sql. Use a migration file instead.
- **Calling `cron.schedule()` before `CREATE EXTENSION pg_cron`:** The extension must be created in the same migration block before any `cron.schedule()` calls.
- **Resource deduction in Flutter before Edge Function returns:** The UI must wait for the Edge Function response before reflecting resource deductions.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Scheduled server tick | Custom HTTP polling from Flutter | pg_cron `*/5 * * * *` job | pg_cron runs in DB even when no clients connected; atomic; no network |
| Resource cap enforcement | Flutter-side `min(amount, capacity)` | `LEAST(amount + prod, capacity)` in SQL tick function | Client-side cap has race conditions with concurrent city views |
| Construction queue uniqueness | Application-level lock | DB `UNIQUE (city_id)` on active construction, or Edge Function pre-check | DB constraint is atomic; client check has TOCTOU |
| Building level tracking | JSONB in cities table | Separate `city_buildings` table with FK to cities | Normalized table is queryable, indexable, streamable via Realtime |
| Countdown timer display | Server polling every second | `Timer.periodic` + client `DateTime.now() - finishAt` | Local timer for display; server timestamp is authoritative |
| Real-time resource display | Polling endpoint every 5 minutes | `supabase.from('city_resources').stream()` | Supabase Realtime pushes updates instantly after pg_cron tick |

**Key insight:** The idle loop only needs two server-side mechanisms — a pg_cron tick and an Edge Function. Everything else is display logic in Flutter.

---

## Common Pitfalls

### Pitfall 1: pg_cron Extension in seed.sql vs Migration
**What goes wrong:** `SELECT cron.schedule(...)` throws `ERROR: schema "cron" does not exist` when the CREATE EXTENSION and schedule() call are both in seed.sql.
**Why it happens:** The cron schema initializes asynchronously during the seed pass; the schedule call runs before the schema is ready.
**How to avoid:** Put `CREATE EXTENSION IF NOT EXISTS pg_cron` and the `cron.schedule()` calls in a dedicated migration file (e.g., `20260311000009_pg_cron_jobs.sql`). Migrations run in order and wait for each to commit before proceeding.
**Warning signs:** `supabase db reset` fails with "schema cron does not exist".
**Source:** https://github.com/supabase/supabase/issues/28966

### Pitfall 2: pg_cron Runs as `postgres` User — RLS Blocks It
**What goes wrong:** pg_cron calls the function but the function fails silently because it cannot UPDATE city_resources (RLS blocks the `postgres` role if policies are misconfigured).
**Why it happens:** SECURITY DEFINER functions run as the function owner. If the owner is `postgres` and RLS does not have a `USING (true)` or bypasses for service role, updates silently fail.
**How to avoid:** Use `SECURITY DEFINER SET search_path = ''` on all tick functions. Verify with `SELECT * FROM cron.job_run_details WHERE status <> 'succeeded'` after the first tick.
**Warning signs:** Resources never increase even though pg_cron shows "succeeded" status; check for 0-row UPDATE.

### Pitfall 3: No `city_resources` Rows at City Creation
**What goes wrong:** The resource tick function loops over city_resources rows. If a new city has no rows in city_resources, no resources are produced.
**Why it happens:** Phase 1's `handle_new_user` trigger only creates the `cities` row. Phase 2 must extend it (or add a separate trigger/function) to also INSERT the initial 5 resource rows for every new city.
**How to avoid:** Extend `handle_new_user` OR create a separate `on_city_created` trigger on the cities table that inserts the 5 resource rows and the 10 building rows with starting values.
**Warning signs:** New player sees 0 for all resources and they never increase after 5 minutes.

### Pitfall 4: construction_queue Realtime Not Enabled
**What goes wrong:** Flutter's `construction_queue` stream provider never fires — the building upgrade appears to do nothing until the next full page refresh.
**Why it happens:** Supabase Realtime requires tables to be added to the `supabase_realtime` publication. New tables are NOT added automatically.
**How to avoid:** In the migration that creates `city_resources`, `city_buildings`, and `construction_queue`, include: `ALTER PUBLICATION supabase_realtime ADD TABLE public.city_resources, public.city_buildings, public.construction_queue;`
**Warning signs:** Stream provider never emits a new value after a DB update, even though the DB row changed.

### Pitfall 5: Edge Function Called Without Service Role Key for Mutations
**What goes wrong:** Edge Function uses the anon key client to INSERT into construction_queue or UPDATE city_resources — RLS blocks it.
**Why it happens:** The anon/authenticated role has no INSERT/UPDATE policies on game-state tables (by design, INFR-02). Only SECURITY DEFINER functions or service role can mutate.
**How to avoid:** Inside the Edge Function, create TWO clients: one with the auth header (anon key, for `getUser()` identity verification) and one with `SUPABASE_SERVICE_ROLE_KEY` for actual mutations. The service role bypasses RLS.
**Warning signs:** Edge Function returns a 500 with "new row violates row-level security policy".

### Pitfall 6: Clock Skew Between Client and Server
**What goes wrong:** Client countdown timer shows "0 seconds" but the building is not yet complete server-side, or vice versa.
**Why it happens:** Client `DateTime.now()` is local time; `finish_at` from DB is UTC. If the client clock is skewed or the timezone conversion is wrong, countdown displays incorrectly.
**How to avoid:** Always parse `finish_at` as UTC (`DateTime.parse(finishAt).toUtc()`) and compare against `DateTime.now().toUtc()`. The countdown is display-only — the pg_cron tick is authoritative.
**Warning signs:** Countdown shows negative or jumps unexpectedly.

### Pitfall 7: Forgetting `replica identity full` for Realtime
**What goes wrong:** Supabase Realtime only sends the primary key in the UPDATE payload (not the new column values) — Flutter displays stale resource amounts.
**Why it happens:** Default replica identity only includes PK columns in change events.
**How to avoid:** Add to migrations: `ALTER TABLE public.city_resources REPLICA IDENTITY FULL;` (and same for city_buildings, construction_queue).
**Warning signs:** Realtime fires but the `newRecord` payload has only `id` and no other columns.

---

## Code Examples

Verified patterns from official sources and established project patterns:

### DB Schema: city_resources
```sql
-- Migration: 20260311000004_create_city_resources.sql
-- Source: Phase 1 pattern (RLS in same migration)

CREATE TABLE public.city_resources (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  city_id       uuid NOT NULL REFERENCES public.cities(id) ON DELETE CASCADE,
  resource_type text NOT NULL CHECK (resource_type IN ('wood','marble','crystal','sulfur','gold')),
  amount        numeric NOT NULL DEFAULT 0 CHECK (amount >= 0),
  updated_at    timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (city_id, resource_type)
);

ALTER TABLE public.city_resources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.city_resources REPLICA IDENTITY FULL;

-- Players can read their own city's resources
CREATE POLICY "city_resources_select_own"
  ON public.city_resources FOR SELECT
  TO authenticated
  USING (
    city_id IN (
      SELECT id FROM public.cities WHERE owner_id = auth.uid()
    )
  );

-- No INSERT/UPDATE/DELETE from client — pg_cron tick (SECURITY DEFINER) writes
ALTER PUBLICATION supabase_realtime ADD TABLE public.city_resources;
```

### DB Schema: city_buildings
```sql
-- Migration: 20260311000005_create_city_buildings.sql

CREATE TABLE public.city_buildings (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  city_id          uuid NOT NULL REFERENCES public.cities(id) ON DELETE CASCADE,
  building_type    text NOT NULL CHECK (building_type IN (
    'town_hall','warehouse','barracks','shipyard','academy',
    'embassy','trading_port','town_wall','hideout','tavern'
  )),
  level            integer NOT NULL DEFAULT 0 CHECK (level >= 0),
  assigned_workers integer NOT NULL DEFAULT 0 CHECK (assigned_workers >= 0),
  updated_at       timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (city_id, building_type)
);

ALTER TABLE public.city_buildings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.city_buildings REPLICA IDENTITY FULL;

CREATE POLICY "city_buildings_select_own"
  ON public.city_buildings FOR SELECT
  TO authenticated
  USING (
    city_id IN (
      SELECT id FROM public.cities WHERE owner_id = auth.uid()
    )
  );

ALTER PUBLICATION supabase_realtime ADD TABLE public.city_buildings;
```

### DB Schema: construction_queue
```sql
-- Migration: 20260311000006_create_construction_queue.sql

CREATE TABLE public.construction_queue (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  city_id       uuid NOT NULL REFERENCES public.cities(id) ON DELETE CASCADE,
  building_type text NOT NULL,
  target_level  integer NOT NULL,
  finish_at     timestamptz NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (city_id)    -- enforces one-at-a-time per city at DB level
);

ALTER TABLE public.construction_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.construction_queue REPLICA IDENTITY FULL;

CREATE POLICY "construction_queue_select_own"
  ON public.construction_queue FOR SELECT
  TO authenticated
  USING (
    city_id IN (
      SELECT id FROM public.cities WHERE owner_id = auth.uid()
    )
  );

ALTER PUBLICATION supabase_realtime ADD TABLE public.construction_queue;
```

### DB: Extend handle_new_user to seed city resources and buildings
```sql
-- Migration: amend handle_new_user (or create new trigger on cities)
-- Strategy: Add a separate AFTER INSERT trigger on cities table so
-- handle_new_user does not grow unboundedly.

CREATE OR REPLACE FUNCTION public.on_city_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  -- Insert starting resources
  INSERT INTO public.city_resources (city_id, resource_type, amount)
  VALUES
    (NEW.id, 'wood',    500),
    (NEW.id, 'marble',    0),
    (NEW.id, 'crystal',   0),
    (NEW.id, 'sulfur',    0),
    (NEW.id, 'gold',    500);

  -- Insert all 10 buildings at level 0, except town_hall at level 1
  INSERT INTO public.city_buildings (city_id, building_type, level, assigned_workers)
  VALUES
    (NEW.id, 'town_hall',      1, 0),
    (NEW.id, 'warehouse',      0, 0),
    (NEW.id, 'barracks',       0, 0),
    (NEW.id, 'shipyard',       0, 0),
    (NEW.id, 'academy',        0, 0),
    (NEW.id, 'embassy',        0, 0),
    (NEW.id, 'trading_port',   0, 0),
    (NEW.id, 'town_wall',      0, 0),
    (NEW.id, 'hideout',        0, 0),
    (NEW.id, 'tavern',         0, 0);

  RETURN NEW;
END;
$$;

CREATE TRIGGER on_city_created
  AFTER INSERT ON public.cities
  FOR EACH ROW EXECUTE PROCEDURE public.on_city_created();
```

### Flutter: StreamProvider wrapping Supabase .stream()
```dart
// lib/features/city/providers/resources_provider.dart
// Source: https://supabase.com/docs/reference/dart/stream

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Real-time resource amounts for a given city.
/// Updates automatically when pg_cron tick modifies city_resources.
final resourcesStreamProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, cityId) {
  // Store stream in local variable — do NOT create inline in build()
  // to prevent subscription cancellation on rebuild.
  return Supabase.instance.client
      .from('city_resources')
      .stream(primaryKey: ['id'])
      .eq('city_id', cityId)
      .order('resource_type');
});
```

### Flutter: Invoke Edge Function for building upgrade
```dart
// lib/features/city/data/buildings_repository.dart
// Source: https://supabase.com/docs/reference/dart/functions-invoke

import 'package:supabase_flutter/supabase_flutter.dart';

class BuildingsRepository {
  const BuildingsRepository();

  /// Queues a building upgrade via the upgrade-building Edge Function.
  /// Throws [BuildingUpgradeException] with a reason if the server rejects it.
  Future<void> upgradeBuilding({
    required String cityId,
    required String buildingType,
  }) async {
    final response = await Supabase.instance.client.functions.invoke(
      'upgrade-building',
      body: {'city_id': cityId, 'building_type': buildingType},
    );

    if (response.status != 200) {
      final error = (response.data as Map<String, dynamic>?)?['error']
          ?? 'Unknown error';
      throw BuildingUpgradeException(error);
    }
  }
}

class BuildingUpgradeException implements Exception {
  final String message;
  const BuildingUpgradeException(this.message);

  @override
  String toString() => 'BuildingUpgradeException: $message';
}
```

### Flutter: Construction countdown display
```dart
// In building upgrade sheet widget — display-only, no server authority

Duration _getRemainingDuration(String finishAtIso) {
  final finishAt = DateTime.parse(finishAtIso).toUtc();
  final now = DateTime.now().toUtc();
  final diff = finishAt.difference(now);
  return diff.isNegative ? Duration.zero : diff;
}

String _formatDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
}
// Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}))
// in a StatefulWidget, or use a Riverpod notifier that ticks every second.
```

### Verify pg_cron jobs are running
```sql
-- Run this in Supabase Studio SQL editor or via docker exec psql
SELECT jobname, schedule, command, active
FROM cron.job;

-- Check for failures in last 10 ticks
SELECT jobname, status, start_time, end_time, return_message
FROM cron.job_run_details
WHERE status <> 'succeeded'
ORDER BY start_time DESC
LIMIT 10;
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Supabase pg_cron in seed.sql | pg_cron in dedicated migration (schema timing issue) | Discovered via issue #28966 | Avoids "schema cron does not exist" error |
| `RealtimeChannel.on('UPDATE', ...)` string filter | `onPostgresChanges(filter: PostgresChangeFilter(...))` typed object | supabase_flutter 2.0 | Compile-time type safety for filter parameters |
| `supabase.from().stream()` in `build()` method | Stream stored as field in StatefulWidget or Riverpod StreamProvider | supabase_flutter 2.x guidance | Prevents subscription cancel/restart on every rebuild |
| Edge Function with only anon key client | Edge Function: anon key for auth verification + service role key for mutations | Ongoing best practice | Anon key respects RLS (correct for reading); service role bypasses RLS for server-authority mutations |

**Deprecated/outdated:**
- `supabase.from('table').on('UPDATE', callback)`: replaced by `onPostgresChanges()` in supabase_flutter 2.x
- Storing `cron.schedule()` in `seed.sql`: use migration file (see Pitfall 1)

---

## Open Questions

1. **Worker Assignment Model**
   - What we know: RSRC-03 requires `workers x building_level x research_bonus`. The buildings table has `assigned_workers` column.
   - What's unclear: Phase 2 requirements do not include a UI for worker assignment. Does Phase 2 need a worker-assignment Edge Function, or are workers pre-assigned at default values (e.g., 3 workers per building)?
   - Recommendation: Default `assigned_workers = 3` for all production buildings on city creation. Worker reassignment deferred to a later phase. This satisfies RSRC-03 (the formula runs correctly) without needing additional UI.

2. **Research Bonus Value**
   - What we know: RSRC-03 formula includes `research_bonus`. Research system (RSCH-01 through RSCH-04) is v2, deferred.
   - What's unclear: What value does `research_bonus` hold in v1?
   - Recommendation: Hard-code `research_bonus = 1.0` in the tick function (multiplying by 1.0 is a no-op). Add a comment: `-- v2: read from city_research_bonuses table`.

3. **Building Type to Resource Type Mapping**
   - What we know: The original Ikariam has: Sawmill (Wood), Quarry (Marble/Crystal/Sulfur — island-specific), Town Hall (Gold tax).
   - What's unclear: Phase 2 BLDG-01 lists 10 building types that do not include "Sawmill" or "Quarry" by name. The `process_resource_tick()` CASE statement needs the correct mapping.
   - Recommendation: Map production to building types: `wood -> sawmill` (though not in BLDG-01 list), or re-interpret. Likely the 10 buildings in BLDG-01 are non-production buildings (Town Hall, Warehouse, Barracks, Shipyard, Academy, Embassy, Trading Port, Town Wall, Hideout, Tavern) and production buildings (Sawmill, Quarry variant) are implicit or part of the island resource areas. Needs clarification before coding. Safest approach for Phase 2: Gold from Town Hall, Wood from a "wood resource" implicit to the island, luxury from island type — or simplify to: all production comes from Town Hall level for Gold, and the island's resource buildings for Wood/Luxury. Planner should flag this for discussion.

4. **pg_cron local dev timing**
   - What we know: The 5-minute cron tick is too slow for manual testing.
   - What's unclear: How do developers verify resource production locally?
   - Recommendation: Add a SQL helper function `public.trigger_resource_tick()` (just calls `process_resource_tick()`) that developers can call manually from Supabase Studio or psql during testing. Do not change the cron schedule for dev.

---

## Validation Architecture

> nyquist_validation is enabled (config.json `workflow.nyquist_validation: true`).

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Flutter test (built-in) + integration_test (already installed) |
| Config file | None — `pubspec.yaml` dev_dependencies sufficient |
| Quick run command | `flutter test test/unit/ --reporter compact` |
| Full suite command | `flutter test --reporter compact` |
| DB function tests | `supabase db reset` + manual psql calls or Supabase Studio |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| RSRC-01 | 5 resource rows exist for a new city | DB integration (psql) | `supabase db reset && docker exec supabase_db_ikariam psql -U postgres -c "SELECT COUNT(*) FROM public.city_resources WHERE city_id = (SELECT id FROM cities LIMIT 1)"` | ❌ Wave 0 |
| RSRC-02 | pg_cron job named 'resource-tick' is active | DB integration (psql) | `docker exec supabase_db_ikariam psql -U postgres -c "SELECT jobname FROM cron.job WHERE jobname='resource-tick'"` | ❌ Wave 0 |
| RSRC-03 | process_resource_tick() increases resource amounts correctly | Unit test (SQL function call) | `docker exec supabase_db_ikariam psql -U postgres -c "SELECT public.process_resource_tick(); SELECT amount FROM city_resources LIMIT 5"` | ❌ Wave 0 |
| RSRC-04 | Resources do not exceed warehouse capacity | Unit test (SQL) | manual psql: set amount near cap, call tick, verify LEAST cap applied | ❌ Wave 0 |
| BLDG-01 | 10 city_buildings rows exist for a new city | DB integration | psql `SELECT COUNT(*) FROM city_buildings WHERE city_id = (SELECT id FROM cities LIMIT 1)` = 10 | ❌ Wave 0 |
| BLDG-02 | upgrade-building Edge Function deducts resources and inserts queue | Integration test (Flutter) | `flutter test integration_test/building_upgrade_test.dart -d chrome` | ❌ Wave 0 |
| BLDG-03 | finish_at is correctly computed (base_time * 1.2^level) | Unit test (Dart) | `flutter test test/unit/building_time_test.dart` | ❌ Wave 0 |
| BLDG-04 | Second upgrade request while queue active returns 409 | Integration test (Flutter) | `flutter test integration_test/building_upgrade_test.dart -d chrome` (duplicate-upgrade test case) | ❌ Wave 0 |
| BLDG-05 | complete_building_upgrades() advances building level | DB integration (psql) | manually insert past finish_at row, call function, verify level incremented | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/unit/ --reporter compact`
- **Per wave merge:** `flutter test --reporter compact`
- **Phase gate:** Full suite + `supabase db reset` (clean migration run) green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/unit/building_time_test.dart` — covers BLDG-03: finish_at duration formula in Dart
- [ ] `integration_test/building_upgrade_test.dart` — covers BLDG-02, BLDG-04 (upgrade + duplicate rejection)
- [ ] `integration_test/resource_production_test.dart` — covers RSRC-01, RSRC-03, RSRC-04 (with manual tick call)
- [ ] No additional framework install needed — integration_test already in dev_dependencies

---

## Sources

### Primary (HIGH confidence)
- [pg_cron GitHub — citusdata/pg_cron](https://github.com/citusdata/pg_cron) — cron.schedule() API, syntax, sub-minute intervals
- [Supabase Cron Quickstart](https://supabase.com/docs/guides/cron/quickstart) — `SELECT cron.schedule()` exact SQL syntax
- [Supabase Cron Install](https://supabase.com/docs/guides/cron/install) — `CREATE EXTENSION pg_cron` SQL
- [supabase_flutter pub.dev v2.12.0](https://pub.dev/packages/supabase_flutter) — `.stream()` API, `.onPostgresChanges()` API
- [Supabase pg_cron debugging guide](https://supabase.com/docs/guides/troubleshooting/pgcron-debugging-guide-n1KTaz) — silent failure detection, connection limits
- Phase 1 RESEARCH.md — established patterns: SECURITY DEFINER, RLS, migration structure, Riverpod manual AsyncNotifier

### Secondary (MEDIUM confidence)
- [Supabase Realtime Postgres Changes docs](https://supabase.com/docs/guides/realtime/postgres-changes) — onPostgresChanges typed filter API
- [Supabase Realtime Flutter guide](https://supabase.com/docs/guides/realtime/realtime-listening-flutter) — stream() usage patterns
- [Supabase issue #28966 — pg_cron schema in seed.sql](https://github.com/supabase/supabase/issues/28966) — confirmed: create extension in migration, not seed.sql
- [Supabase Cron blog post](https://supabase.com/blog/supabase-cron) — max 8 concurrent jobs, 10-minute execution limit

### Tertiary (LOW confidence)
- Community Medium articles on Riverpod + Supabase stream patterns — useful for pattern confirmation but not authoritative on versions

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — same stack as Phase 1, no new packages; pg_cron API verified from official GitHub + Supabase docs
- pg_cron job creation pattern: HIGH — verified from Supabase quickstart + GitHub issue confirming migration vs seed.sql approach
- Architecture (DB schema): HIGH — follows Phase 1 RLS pattern exactly; REPLICA IDENTITY requirement from official Realtime docs
- Edge Function pattern: HIGH — anon + service role dual-client pattern from Supabase docs
- Building type mapping (Open Question 3): LOW — requires domain clarification; production building names not fully resolved from requirements
- Worker assignment model: MEDIUM — reasonable default (3 workers) but not specified in requirements

**Research date:** 2026-03-11
**Valid until:** 2026-04-11 (30 days — stable ecosystem; no breaking changes expected in supabase_flutter 2.x or pg_cron 1.6.4 in this window)
