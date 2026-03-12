# Phase 4: Military - Research

**Researched:** 2026-03-11
**Domain:** Training queue (land + naval units), pg_cron completion, army dispatch with travel time, Flutter UI for training panels
**Confidence:** HIGH

## Summary

Phase 4 adds two distinct but structurally parallel systems: a **training queue** (mirroring the existing construction queue pattern) and an **army dispatch** system (new domain — moving units across the map with travel time). Both systems follow the established project rule that all game mutations go through Edge Functions with service-role DB writes, pg_cron for timed completion, and Supabase Realtime for live UI updates.

The training queue for Barracks/Shipyard is an almost exact analogue of `construction_queue`: a new `training_queue` table with `city_id`, `unit_type`, `quantity`, `finish_at`; a pg_cron job calls `complete_training()` every minute; an Edge Function `train-units` validates ownership, checks building level, deducts resources, and inserts the queue row. A new `city_units` table stores the army roster per city. Unit type → required building level mapping is a constant table that lives both in Edge Function TypeScript and Dart constants (same dual-location pattern as `BASE_COSTS` in `upgrade-building`).

The dispatch system introduces the first cross-city operation in the game. A `unit_movements` table records `origin_city_id`, `destination_city_id`, `unit_snapshot` (jsonb), `depart_at`, `arrive_at`. Travel time is calculated from the Euclidean distance between the two cities' island grid coordinates (islands.grid_x/grid_y). A pg_cron job fires every minute to process arrivals. An Edge Function `dispatch-units` validates the move, deducts units from the roster, and inserts the movement row.

**Primary recommendation:** Model training queue identically to construction queue (one active training at a time per city to keep v1 simple). For dispatch, store units as a JSONB snapshot in `unit_movements` — this avoids complex joins during combat in Phase 5 and cleanly snapshots the army at departure time.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| MIL-01 | 8 land unit types trainable from Barracks (Hoplite, Phalanx, Archer, Cavalry, Catapult, Mortar, Medic, Cook) | `training_queue` table + `city_units` table; `train-units` Edge Function; unit type enum with `minBarracksLevel` constants |
| MIL-02 | 5 naval unit types buildable from Shipyard (Cargo Ship, Ram Ship, Catapult Ship, Mortar Ship, Diving Boat) | Same `training_queue` + `city_units` tables; same Edge Function handles both building types; unit type enum with `minShipyardLevel` constants |
| MIL-03 | Each unit type requires specific building level to unlock | `UNIT_UNLOCK_LEVELS` constant map in Edge Function + Dart; Edge Function validates barracks/shipyard level before inserting queue entry |
| MIL-04 | Training queue with time-based completion via pg_cron | `training_queue` table + `complete_training()` pg function + new `training-tick` cron job every minute; mirrors `construction_queue` pattern exactly |
| MIL-05 | Troops can be dispatched to other cities with travel time based on distance | `unit_movements` table; `dispatch-units` Edge Function; distance formula from island grid coordinates; `process_arrivals()` pg function called by pg_cron |
</phase_requirements>

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Supabase PostgreSQL | (hosted) | `training_queue`, `city_units`, `unit_movements` tables with RLS | All DB tables follow this pattern; already established |
| Supabase Edge Functions (Deno) | (hosted) | `train-units`, `dispatch-units` mutations | INFR-02: all game mutations via Edge Functions; matches `upgrade-building` structure |
| pg_cron | already enabled (migration 20260311000010) | `complete_training()` and `process_arrivals()` called every minute | Already used for resource tick and construction tick; extension already enabled |
| Supabase Realtime | already enabled | Live updates to `training_queue` and `city_units` when pg_cron completes training | Already used for `city_buildings` and `construction_queue`; `REPLICA IDENTITY FULL` + `ADD TABLE` pattern |
| flutter_riverpod ^3.3.1 | already in pubspec | `StreamProvider` for training queue and army roster; `AsyncNotifier` for train/dispatch actions | Consistent with all existing providers in the project |
| supabase_flutter ^2.12.0 | already in pubspec | DB queries and Realtime subscriptions | Already connected and in use |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Dart `math.sqrt` | SDK | Euclidean distance calculation (display only in Flutter) | Client-side distance display; authoritative calculation is in Edge Function |
| Flutter `CountdownTimerWidget` | existing widget | Show training time remaining | Reuse exactly — same pattern as construction countdown |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Single `training_queue` (one active per city) | Multi-slot queue (queue multiple units) | Multi-slot is complex for v1; one-at-a-time matches construction pattern; simpler Edge Function |
| JSONB unit snapshot in `unit_movements` | Separate `movement_units` join table | JSONB snapshot is simpler, avoids Phase 5 join complexity, immutable at departure time |
| pg_cron every minute for training | pg_cron every 5 minutes | Training times can be short (small units); minute granularity matches construction tick already running |

**Installation:** No new packages needed. All required libraries are already in `pubspec.yaml` or are Supabase-side.

---

## Architecture Patterns

### Recommended Project Structure
```
supabase/
├── migrations/
│   ├── 20260311000011_create_city_units.sql          # Army roster table
│   ├── 20260311000012_create_training_queue.sql      # Training queue table
│   ├── 20260311000013_create_unit_movements.sql      # Dispatch/transit table
│   ├── 20260311000014_training_functions.sql         # complete_training() pg function
│   ├── 20260311000015_movement_functions.sql         # process_arrivals() pg function
│   └── 20260311000016_military_cron_jobs.sql         # Register training-tick + arrivals-tick
└── functions/
    ├── train-units/
    │   └── index.ts                                  # Validate + deduct + enqueue training
    └── dispatch-units/
        └── index.ts                                  # Validate + deduct units + enqueue movement

lib/
├── core/
│   └── constants/
│       └── unit_constants.dart                       # UnitType enum, unlock levels, costs, times
├── features/
│   └── military/
│       ├── data/
│       │   └── military_repository.dart              # watchTrainingQueue, watchArmyRoster, streamMovements
│       ├── models/
│       │   ├── unit_type.dart                        # UnitType enum (mirrors building_constants pattern)
│       │   ├── training_queue_entry.dart             # TrainingQueueEntry.fromJson
│       │   ├── city_unit.dart                        # CityUnit.fromJson (army roster row)
│       │   └── unit_movement.dart                    # UnitMovement.fromJson (in-transit entry)
│       ├── providers/
│       │   ├── training_queue_provider.dart          # StreamProvider for active training
│       │   ├── army_roster_provider.dart             # StreamProvider for city_units
│       │   └── unit_movements_provider.dart          # StreamProvider for in-transit units
│       └── screens/
│           ├── barracks_screen.dart                  # Land unit training UI
│           ├── shipyard_screen.dart                  # Naval unit training UI
│           └── dispatch_screen.dart                  # Select units + target city + dispatch
```

### Pattern 1: Training Queue — Mirror of Construction Queue

**What:** `training_queue` table with one-active-per-city constraint. `train-units` Edge Function validates building level, deducts resources, inserts row. `complete_training()` pg function moves units to `city_units`. pg_cron calls it every minute.

**When to use:** Any timed server-side completion that must not be cheated.

**DB schema:**
```sql
-- Source: mirrors construction_queue pattern (migration 20260311000006)
CREATE TABLE public.training_queue (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  city_id      uuid NOT NULL REFERENCES public.cities(id) ON DELETE CASCADE,
  unit_type    text NOT NULL,  -- CHECK constraint on all 13 unit types
  quantity     integer NOT NULL CHECK (quantity > 0),
  finish_at    timestamptz NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (city_id)  -- one active training per city at a time (v1 simplicity)
);

ALTER TABLE public.training_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_queue REPLICA IDENTITY FULL;

CREATE POLICY "training_queue_select_owner"
  ON public.training_queue FOR SELECT TO authenticated
  USING (city_id IN (SELECT id FROM public.cities WHERE owner_id = auth.uid()));

ALTER PUBLICATION supabase_realtime ADD TABLE public.training_queue;
```

### Pattern 2: Army Roster — city_units Table

**What:** Each row represents a stack of one unit type in a city. UNIQUE(city_id, unit_type) allows simple upsert when training completes.

**DB schema:**
```sql
CREATE TABLE public.city_units (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  city_id      uuid NOT NULL REFERENCES public.cities(id) ON DELETE CASCADE,
  unit_type    text NOT NULL,
  quantity     integer NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  updated_at   timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (city_id, unit_type)
);

ALTER TABLE public.city_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.city_units REPLICA IDENTITY FULL;

-- Owner reads own units; others cannot read (army composition is private)
CREATE POLICY "city_units_select_owner"
  ON public.city_units FOR SELECT TO authenticated
  USING (city_id IN (SELECT id FROM public.cities WHERE owner_id = auth.uid()));

ALTER PUBLICATION supabase_realtime ADD TABLE public.city_units;
```

### Pattern 3: complete_training() — pg Function Analogous to complete_building_upgrades()

**What:** Called by pg_cron every minute. Finds `training_queue` rows where `finish_at <= NOW()`, upserts into `city_units`, then deletes the queue entry.

```sql
-- Source: mirrors complete_building_upgrades() pattern (migration 20260311000009)
CREATE OR REPLACE FUNCTION public.complete_training()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  q RECORD;
BEGIN
  FOR q IN
    SELECT id, city_id, unit_type, quantity
    FROM public.training_queue
    WHERE finish_at <= NOW()
  LOOP
    -- Upsert into city_units: add quantity to existing stack or create new row
    INSERT INTO public.city_units (city_id, unit_type, quantity, updated_at)
    VALUES (q.city_id, q.unit_type, q.quantity, NOW())
    ON CONFLICT (city_id, unit_type)
    DO UPDATE SET
      quantity   = public.city_units.quantity + EXCLUDED.quantity,
      updated_at = NOW();

    -- Remove completed training entry
    DELETE FROM public.training_queue WHERE id = q.id;
  END LOOP;
END;
$$;
```

### Pattern 4: Unit Movements — Dispatch with Travel Time

**What:** `unit_movements` stores in-transit armies as a JSONB snapshot. Travel time uses Euclidean distance between island grid coordinates. `process_arrivals()` handles arrival by adding units to the destination city's roster.

**DB schema:**
```sql
CREATE TABLE public.unit_movements (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  origin_city_id      uuid NOT NULL REFERENCES public.cities(id),
  destination_city_id uuid NOT NULL REFERENCES public.cities(id),
  owner_id            uuid NOT NULL REFERENCES auth.users(id),
  -- Snapshot of units at departure time: {"hoplite": 10, "archer": 5}
  units               jsonb NOT NULL,
  depart_at           timestamptz NOT NULL DEFAULT NOW(),
  arrive_at           timestamptz NOT NULL,
  created_at          timestamptz NOT NULL DEFAULT NOW()
);

ALTER TABLE public.unit_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.unit_movements REPLICA IDENTITY FULL;

-- Owner can see their movements; defenders can see incoming (needed for Phase 5)
CREATE POLICY "unit_movements_select_owner"
  ON public.unit_movements FOR SELECT TO authenticated
  USING (owner_id = auth.uid()
      OR destination_city_id IN (SELECT id FROM public.cities WHERE owner_id = auth.uid()));

ALTER PUBLICATION supabase_realtime ADD TABLE public.unit_movements;
```

**Travel time formula (in Edge Function):**
```typescript
// Distance between two cities via their island grid coordinates
// islands table has grid_x and grid_y
// Base travel speed: 1 grid unit = 10 minutes (Claude's discretion — adjustable)
function calcTravelMinutes(
  originIsland: { grid_x: number; grid_y: number },
  destIsland: { grid_x: number; grid_y: number },
  baseMinutesPerUnit = 10
): number {
  const dx = destIsland.grid_x - originIsland.grid_x;
  const dy = destIsland.grid_y - originIsland.grid_y;
  const distance = Math.sqrt(dx * dx + dy * dy);
  return Math.max(1, Math.ceil(distance * baseMinutesPerUnit));
}
// Same-island dispatch: distance = 0, result = 1 minute minimum
```

### Pattern 5: train-units Edge Function Structure

**What:** Mirror of `upgrade-building/index.ts`. Key differences: validates barracks/shipyard level against `UNIT_UNLOCK_LEVELS`, checks training queue vacancy, calculates training duration per unit × quantity.

```typescript
// Source: mirrors upgrade-building/index.ts pattern
// supabase/functions/train-units/index.ts

// Unit type to required building level mapping
// NOTE: Must stay in sync with lib/core/constants/unit_constants.dart unitUnlockLevels
const UNIT_UNLOCK_LEVELS: Record<string, { building: string; minLevel: number }> = {
  // Land units (Barracks)
  hoplite:  { building: 'barracks', minLevel: 1 },
  phalanx:  { building: 'barracks', minLevel: 2 },
  archer:   { building: 'barracks', minLevel: 2 },
  cavalry:  { building: 'barracks', minLevel: 3 },
  catapult: { building: 'barracks', minLevel: 4 },
  mortar:   { building: 'barracks', minLevel: 5 },
  medic:    { building: 'barracks', minLevel: 3 },
  cook:     { building: 'barracks', minLevel: 1 },
  // Naval units (Shipyard)
  cargo_ship:    { building: 'shipyard', minLevel: 1 },
  ram_ship:      { building: 'shipyard', minLevel: 2 },
  catapult_ship: { building: 'shipyard', minLevel: 3 },
  mortar_ship:   { building: 'shipyard', minLevel: 4 },
  diving_boat:   { building: 'shipyard', minLevel: 3 },
};

// Base training cost per unit (resources deducted = base_cost * quantity)
// NOTE: Must stay in sync with lib/core/constants/unit_constants.dart unitBaseCosts
const UNIT_BASE_COSTS: Record<string, Record<string, number>> = {
  hoplite:       { wood: 40, gold: 30 },
  phalanx:       { wood: 60, marble: 20, gold: 50 },
  archer:        { wood: 50, crystal: 20, gold: 40 },
  cavalry:       { wood: 80, gold: 100 },
  catapult:      { wood: 120, sulfur: 30, gold: 80 },
  mortar:        { wood: 100, sulfur: 50, gold: 120 },
  medic:         { wood: 30, crystal: 30, gold: 60 },
  cook:          { wood: 20, gold: 20 },
  cargo_ship:    { wood: 200, gold: 100 },
  ram_ship:      { wood: 250, marble: 100, gold: 150 },
  catapult_ship: { wood: 300, sulfur: 50, gold: 200 },
  mortar_ship:   { wood: 350, sulfur: 80, gold: 250 },
  diving_boat:   { wood: 200, crystal: 80, gold: 180 },
};

// Base training time in minutes per unit
// NOTE: Must stay in sync with lib/core/constants/unit_constants.dart unitBaseTimes
const UNIT_BASE_TIMES: Record<string, number> = {
  hoplite: 3, phalanx: 5, archer: 4, cavalry: 8,
  catapult: 12, mortar: 15, medic: 5, cook: 2,
  cargo_ship: 10, ram_ship: 15, catapult_ship: 20,
  mortar_ship: 25, diving_boat: 18,
};
```

**Edge Function validation flow:**
1. Parse `{ city_id, unit_type, quantity }` from request body
2. Authenticate user (same as upgrade-building)
3. Verify city ownership
4. Validate `unit_type` in `UNIT_UNLOCK_LEVELS`
5. Fetch required building level; verify current level >= `minLevel`
6. Check `training_queue` vacancy (UNIQUE constraint — maybeSingle() check)
7. Calculate total cost = `UNIT_BASE_COSTS[unit_type]` × quantity
8. Deduct resources via `rpc('deduct_resource', ...)` per resource
9. Calculate `finish_at` = NOW() + `UNIT_BASE_TIMES[unit_type]` × quantity minutes
10. Insert into `training_queue`
11. Return `{ success: true, finish_at, unit_type, quantity }`

### Pattern 6: Dart UnitType Enum (mirrors BuildingType pattern)

```dart
// lib/core/constants/unit_constants.dart
// Mirrors building_constants.dart pattern exactly

enum UnitType {
  hoplite, phalanx, archer, cavalry, catapult, mortar, medic, cook,
  cargoShip, ramShip, catapultShip, mortarShip, divingBoat;

  String get dbName {
    switch (this) {
      case UnitType.hoplite:       return 'hoplite';
      case UnitType.phalanx:       return 'phalanx';
      case UnitType.archer:        return 'archer';
      case UnitType.cavalry:       return 'cavalry';
      case UnitType.catapult:      return 'catapult';
      case UnitType.mortar:        return 'mortar';
      case UnitType.medic:         return 'medic';
      case UnitType.cook:          return 'cook';
      case UnitType.cargoShip:     return 'cargo_ship';
      case UnitType.ramShip:       return 'ram_ship';
      case UnitType.catapultShip:  return 'catapult_ship';
      case UnitType.mortarShip:    return 'mortar_ship';
      case UnitType.divingBoat:    return 'diving_boat';
    }
  }

  bool get isNaval => this == UnitType.cargoShip ||
      this == UnitType.ramShip || this == UnitType.catapultShip ||
      this == UnitType.mortarShip || this == UnitType.divingBoat;
}

// Unlock level per unit type — must match UNIT_UNLOCK_LEVELS in train-units/index.ts
const Map<UnitType, int> unitUnlockLevels = {
  UnitType.hoplite:      1,
  UnitType.phalanx:      2,
  UnitType.archer:       2,
  UnitType.cavalry:      3,
  UnitType.catapult:     4,
  UnitType.mortar:       5,
  UnitType.medic:        3,
  UnitType.cook:         1,
  UnitType.cargoShip:    1,
  UnitType.ramShip:      2,
  UnitType.catapultShip: 3,
  UnitType.mortarShip:   4,
  UnitType.divingBoat:   3,
};
```

### Anti-Patterns to Avoid

- **Storing unit stats (attack/defense) in the DB:** Stats are game-balance constants. Keep them in code only (unit_constants.dart / TypeScript constants). DB stores counts, not stats — stats are looked up at battle resolution time in Phase 5.
- **Client-side training completion:** Never check `finish_at` on the client to trigger completion. pg_cron handles it; the client only shows a countdown (same as construction pattern).
- **Allowing dispatch before units are trained:** Dispatch Edge Function must verify `city_units.quantity >= requested_amount` before deducting. Race conditions possible if checked in Dart.
- **Allowing dispatch to self (same city_id):** Edge Function must reject `origin_city_id == destination_city_id`.
- **Floating point distance causing non-deterministic travel times:** Use `ceil()` on the computed minutes. Both Dart display and Edge Function calculation must use the same formula — document it as a constant.
- **Multiple training queue rows per city:** The `UNIQUE(city_id)` constraint on `training_queue` prevents this at DB level, same as `construction_queue`. The Edge Function must still check and return a 409 before attempting insert.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Training completion timer | Custom Dart timer that fires an Edge Function | pg_cron `complete_training()` every minute | Same reason as construction: client may be offline; server must be authoritative |
| Arrival detection | Polling the DB from Flutter every N seconds | pg_cron `process_arrivals()` + Supabase Realtime on `unit_movements` DELETE | Realtime DELETE event fires when pg_cron removes the arrival row, informing the UI instantly |
| Travel time calculation (display) | Custom distance formula in Dart | Reuse the same formula as in the Edge Function, documented in `unit_constants.dart` | Both must agree; document the formula once, implement in both places with sync comment |
| Resource cost × quantity | Separate cost table in DB | Constants in Edge Function TypeScript (same as `BASE_COSTS` in `upgrade-building`) | Server-authoritative; Dart constants are display-only |

**Key insight:** The training system is almost a copy of the construction system. The dispatch system is the only genuinely new pattern. Treat both as instances of the same "timed server-side operation with Realtime notification" pattern.

---

## Common Pitfalls

### Pitfall 1: Training queue UNIQUE(city_id) race condition on concurrent requests

**What goes wrong:** Two simultaneous train-units calls both pass the vacancy check before either inserts, resulting in two queue rows violating the UNIQUE constraint. One insert fails with a DB unique violation error, which surfaces as an unhandled 500.

**Why it happens:** The vacancy check (`maybeSingle()` then insert) is not atomic in the Edge Function.

**How to avoid:** Catch the Supabase error code `23505` (unique_violation) in the Edge Function and return a 409 "Training queue is busy" — the same pattern already used in `upgrade-building`. The UNIQUE constraint is the real guard; the pre-check is just a friendly early error.

**Warning signs:** Occasionally getting a 500 instead of 409 when rapidly tapping "Train."

### Pitfall 2: Dispatch deducts units but movement insertion fails — units vanish

**What goes wrong:** Edge Function deducts units from `city_units` then fails to insert the `unit_movements` row (e.g., city not found). Units are lost with no movement created.

**Why it happens:** Non-atomic sequence, same issue as the construction resource deduction noted in the project decisions ("Non-atomic resource deduction in upgrade-building: acceptable for v1").

**How to avoid:** Follow the v1 decision: acceptable for now. Document in Edge Function comments. Order the operations: validate fully first, deduct units last (right before insert), so failure modes are minimized. For v1 this is acceptable per established project precedent.

**Warning signs:** User reports losing units without them appearing in transit.

### Pitfall 3: pg_cron `complete_training` not registered — training never completes

**What goes wrong:** Training queue entries exist but never get processed. Players see countdown expire but units never appear.

**Why it happens:** pg_cron job not added to the migration file, or migration not applied.

**How to avoid:** Add `training-tick` and `arrivals-tick` in a dedicated migration file (e.g., `20260311000016_military_cron_jobs.sql`). Run `supabase db reset` locally to verify both jobs appear in `SELECT * FROM cron.job;`.

**Warning signs:** `SELECT * FROM cron.job;` shows only `resource-tick` and `construction-tick`, not the new military jobs.

### Pitfall 4: Dispatch distance calculation mismatch between Dart display and Edge Function

**What goes wrong:** Flutter shows "5 minutes" but server computes a different value, causing UI confusion.

**Why it happens:** Dart uses `double` arithmetic and the Edge Function uses `Math.ceil` differently, or they use different `baseMinutesPerUnit` values.

**How to avoid:** Define the `BASE_MINUTES_PER_GRID_UNIT` constant in both Dart (`unit_constants.dart`) and TypeScript with an explicit sync comment. Use identical formulas: `max(1, ceil(sqrt(dx²+dy²) * BASE_MINUTES_PER_GRID_UNIT))`. Test both with the same input values.

**Warning signs:** Travel time shown in Flutter differs from `arrive_at - depart_at` in the DB.

### Pitfall 5: `city_units` row not created on first training completion — INSERT/upsert fails

**What goes wrong:** `complete_training()` tries to upsert into `city_units` but the row doesn't exist, and the function was written as UPDATE-only instead of INSERT-ON-CONFLICT.

**Why it happens:** Forgetting that a city starts with no `city_units` rows (unlike `city_resources` and `city_buildings` which are pre-populated by the `on_city_created` trigger).

**How to avoid:** Use `INSERT ... ON CONFLICT (city_id, unit_type) DO UPDATE` pattern in `complete_training()`. Never assume a city_units row pre-exists. No trigger needs to pre-create these rows.

**Warning signs:** `complete_training()` runs but `city_units` table remains empty; error in pg_cron logs about missing rows.

### Pitfall 6: Same-island dispatch has distance = 0 → travel time = 0 → immediate arrival bypass

**What goes wrong:** Two cities on the same island (grid_x/grid_y identical) produce distance = 0, travel time = 0. Units could arrive instantly, which may be undesirable.

**Why it happens:** Pure geometric distance gives 0 for same-island movement.

**How to avoid:** Apply a minimum travel time of 1 minute regardless of distance (the `Math.max(1, ...)` in the formula). Same-island dispatch still goes through the movement system; it just arrives in 1 minute.

**Warning signs:** `arrive_at` equals `depart_at` in unit_movements rows for same-island cities.

---

## Code Examples

Verified patterns from official sources and existing project code:

### Supabase upsert with ON CONFLICT (for complete_training)
```sql
-- Source: PostgreSQL docs + mirrors complete_building_upgrades() structure
INSERT INTO public.city_units (city_id, unit_type, quantity, updated_at)
VALUES (q.city_id, q.unit_type, q.quantity, NOW())
ON CONFLICT (city_id, unit_type)
DO UPDATE SET
  quantity   = public.city_units.quantity + EXCLUDED.quantity,
  updated_at = NOW();
```

### StreamProvider for training queue (mirrors buildingsStreamProvider)
```dart
// Source: mirrors lib/features/city/providers/buildings_provider.dart pattern
final trainingQueueProvider =
    StreamProvider.autoDispose.family<TrainingQueueEntry?, String>(
  (ref, cityId) {
    return ref.read(militaryRepositoryProvider).watchTrainingQueue(cityId);
  },
);

final armyRosterProvider =
    StreamProvider.autoDispose.family<List<CityUnit>, String>(
  (ref, cityId) {
    return ref.read(militaryRepositoryProvider).watchArmyRoster(cityId);
  },
);

final unitMovementsProvider =
    StreamProvider.autoDispose.family<List<UnitMovement>, String>(
  (ref, cityId) {
    return ref.read(militaryRepositoryProvider).watchOutgoingMovements(cityId);
  },
);
```

### Supabase Realtime subscription in Repository (mirrors BuildingsRepository)
```dart
// Source: mirrors lib/features/city/data/buildings_repository.dart
Stream<TrainingQueueEntry?> watchTrainingQueue(String cityId) {
  return supabaseClient
      .from('training_queue')
      .stream(primaryKey: ['id'])
      .eq('city_id', cityId)
      .map((rows) => rows.isEmpty ? null : TrainingQueueEntry.fromJson(rows.first));
}

Stream<List<CityUnit>> watchArmyRoster(String cityId) {
  return supabaseClient
      .from('city_units')
      .stream(primaryKey: ['id'])
      .eq('city_id', cityId)
      .map((rows) => rows.map(CityUnit.fromJson).toList());
}
```

### Edge Function: deduct units before dispatch
```typescript
// Source: mirrors deduct_resource pattern in upgrade-building/index.ts
// Atomically deducts units from city_units
async function deductUnits(
  admin: SupabaseClient,
  cityId: string,
  units: Record<string, number>
): Promise<string | null> {
  for (const [unitType, qty] of Object.entries(units)) {
    const { error } = await admin.rpc('deduct_units', {
      p_city_id: cityId,
      p_unit_type: unitType,
      p_quantity: qty,
    });
    if (error) return `Insufficient ${unitType}`;
  }
  return null; // success
}
```

### pg function: deduct_units (mirrors deduct_resource)
```sql
-- Source: mirrors deduct_resource() in 20260311000008_resource_production_functions.sql
CREATE OR REPLACE FUNCTION public.deduct_units(
  p_city_id  uuid,
  p_unit_type text,
  p_quantity  integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_rows integer;
BEGIN
  UPDATE public.city_units
  SET quantity   = quantity - p_quantity,
      updated_at = NOW()
  WHERE city_id   = p_city_id
    AND unit_type = p_unit_type
    AND quantity  >= p_quantity;

  GET DIAGNOSTICS v_rows = ROW_COUNT;

  IF v_rows = 0 THEN
    RAISE EXCEPTION 'Insufficient %', p_unit_type
      USING ERRCODE = 'insufficient_resources';
  END IF;
END;
$$;
```

### Flutter: TrainingQueueEntry model (mirrors ConstructionQueueEntry)
```dart
// Source: mirrors lib/features/city/models/construction_queue_entry.dart
class TrainingQueueEntry {
  const TrainingQueueEntry({
    required this.id,
    required this.cityId,
    required this.unitType,   // String, not UnitType enum — same decision as ConstructionQueueEntry
    required this.quantity,
    required this.finishAt,
    required this.createdAt,
  });

  final String id;
  final String cityId;
  final String unitType;
  final int quantity;
  final DateTime finishAt;
  final DateTime createdAt;

  bool get isComplete => DateTime.now().toUtc().isAfter(finishAt);

  factory TrainingQueueEntry.fromJson(Map<String, dynamic> json) {
    return TrainingQueueEntry(
      id:        json['id'] as String,
      cityId:    json['city_id'] as String,
      unitType:  json['unit_type'] as String,
      quantity:  json['quantity'] as int,
      finishAt:  DateTime.parse(json['finish_at'] as String).toUtc(),
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    );
  }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Storing unit stats (atk/def) in DB | Constants in code only; DB stores counts | Project decision from start | Stats can be rebalanced without DB migrations; Phase 5 battle resolution reads constants |
| Polling for training completion | pg_cron + Supabase Realtime | Established in Phase 2 | Zero client polling; server completes authoritatively; UI updates via push |
| Separate movement_units join table | JSONB snapshot in unit_movements | Decision for this phase | Simpler Phase 5 combat: army snapshot is immutable at departure; no cascading deletes |

**Deprecated/outdated:**
- Client-side timed completion: all project decisions confirm pg_cron is the authority; client countdown is display-only.

---

## Open Questions

1. **Unit stats for Phase 5 combat — where do they live?**
   - What we know: Phase 5 (Combat) is the next phase. Unit attack/defense/HP values are needed there.
   - What's unclear: Should Phase 4 define unit stats in `unit_constants.dart`, or defer to Phase 5?
   - Recommendation: Define unit stats (attack, defense, HP, speed) as Dart + TypeScript constants in Phase 4. They are needed for balance display in the training UI ("Hoplite: 30 attack / 20 defense"). Phase 5 simply reads the same constants. This avoids a two-phase constant split.

2. **Unit movement JSONB format — should it be `{"hoplite": 10}` or an array?**
   - What we know: Phase 5 needs to iterate over dispatched units for battle calculation.
   - What's unclear: Which format is easier to query/update in PostgreSQL.
   - Recommendation: Use object format `{"hoplite": 10, "archer": 5}` — simpler to read in TypeScript/Dart, and PostgreSQL jsonb `->>` operator can extract values. Iteration in pg function uses `jsonb_each_text()`.

3. **Training time formula — flat (baseTime × quantity) or diminishing?**
   - What we know: No game design decision locked. Ikariam classic uses flat multiplication.
   - What's unclear: Whether a large quantity (e.g., 100 hoplites) should train faster per unit than 1.
   - Recommendation: Use flat: `totalMinutes = baseTimePerUnit * quantity`. Simplest; matches classic Ikariam; can be changed post-launch by adjusting constants.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK, Dart 3.10.1) |
| Config file | none (uses default flutter test runner) |
| Quick run command | `flutter test test/unit/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MIL-01 | UnitType enum has 8 land unit types with correct dbName values | unit | `flutter test test/unit/unit_constants_test.dart` | ❌ Wave 0 |
| MIL-02 | UnitType enum has 5 naval unit types; isNaval returns true for naval only | unit | `flutter test test/unit/unit_constants_test.dart` | ❌ Wave 0 |
| MIL-03 | unitUnlockLevels map covers all 13 unit types; levels match expected values | unit | `flutter test test/unit/unit_constants_test.dart` | ❌ Wave 0 |
| MIL-04 | TrainingQueueEntry.fromJson parses correctly; isComplete returns correct bool | unit | `flutter test test/unit/military_models_test.dart` | ❌ Wave 0 |
| MIL-04 | CityUnit.fromJson parses correctly from Supabase JSON row | unit | `flutter test test/unit/military_models_test.dart` | ❌ Wave 0 |
| MIL-05 | UnitMovement.fromJson parses JSONB units field correctly | unit | `flutter test test/unit/military_models_test.dart` | ❌ Wave 0 |
| MIL-05 | Travel time formula: calcTravelMinutes(same coords) returns 1 (minimum) | unit | `flutter test test/unit/unit_constants_test.dart` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/unit/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/unit/unit_constants_test.dart` — covers MIL-01, MIL-02, MIL-03, MIL-05 (UnitType enum, unlock levels, travel time formula)
- [ ] `test/unit/military_models_test.dart` — covers MIL-04, MIL-05 (TrainingQueueEntry, CityUnit, UnitMovement fromJson + isComplete)

---

## Sources

### Primary (HIGH confidence)
- Project codebase (directly read): `supabase/functions/upgrade-building/index.ts`, `supabase/migrations/20260311000006_create_construction_queue.sql`, `supabase/migrations/20260311000009_construction_functions.sql`, `supabase/migrations/20260311000010_pg_cron_jobs.sql`, `lib/core/constants/building_constants.dart`, `lib/features/city/models/city_building.dart`, `lib/features/city/providers/buildings_provider.dart`
- PostgreSQL docs: `INSERT ... ON CONFLICT DO UPDATE` (upsert pattern)
- Supabase docs: `REPLICA IDENTITY FULL` + `ALTER PUBLICATION` Realtime pattern (already applied to all existing tables)

### Secondary (MEDIUM confidence)
- Original Ikariam unit types and unlock levels — derived from game knowledge (unlock levels are Claude's discretion per requirements; MIL-03 states "specific building level" but does not specify which levels)
- pg_cron multi-job registration pattern — verified against existing migration 20260311000010

### Tertiary (LOW confidence — verify in implementation)
- Unit base costs (wood/gold/marble/sulfur/crystal per unit type) — defined as Claude's discretion; not locked in requirements; values above are reasonable starting estimates requiring game balance testing post-launch
- `BASE_MINUTES_PER_GRID_UNIT = 10` — arbitrary starting value; should be tuned post-launch based on actual grid size (current world map is 5x5)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all technologies are already in use in the project; no new libraries required
- Architecture (training queue): HIGH — direct pattern match to construction queue, which is implemented and working
- Architecture (dispatch/movements): HIGH — JSONB snapshot + pg_cron pattern is well-established; travel distance formula is straightforward Euclidean geometry
- Unit types and unlock levels: HIGH for type names (requirements specify them exactly); MEDIUM for unlock level values (Claude's discretion)
- Unit costs/times: LOW — game balance values; reasonable estimates, need iteration post-launch
- Pitfalls: HIGH — derived from existing project decisions (non-atomic deduction, pg_cron registration, UNIQUE constraint race conditions all documented in STATE.md)

**Research date:** 2026-03-11
**Valid until:** 2026-04-10 (all technologies stable; Supabase and Flutter APIs unchanged)
