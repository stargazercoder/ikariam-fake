# Architecture Research

**Domain:** Ikariam Clone — v1.1 Economy & Combat Depth Integration
**Researched:** 2026-03-13
**Confidence:** HIGH

> This document supersedes the v0.1.0 architecture research for the purposes of
> v1.1 planning. It focuses exclusively on how the eight new features integrate
> with the existing Supabase + Flutter architecture. Existing patterns (dumb
> client, server authority, Realtime subscriptions, pg_cron ticks) are
> established and not re-researched here — only additions and modifications are
> detailed.

---

## Existing Architecture Baseline

The v0.1.0 system uses a strict server-authority model:

```
┌────────────────────────────────────────────────────────────────────────┐
│  Flutter Web Client (read-only game-state consumer)                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │  Screen  │  │  Screen  │  │  Screen  │  │  Screen  │              │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘              │
│  ┌────┴──────────────┴──────────────┴──────────────┴────────────────┐  │
│  │          Riverpod Providers (StreamProvider / AsyncNotifier)      │  │
│  │     city · resources · buildings · military · battles · map      │  │
│  └────────────────────────────┬──────────────────────────────────────┘  │
│                               │ Supabase SDK                           │
└───────────────────────────────┼────────────────────────────────────────┘
                                │
              ┌─────────────────┼────────────────────────┐
              │         Supabase Platform                 │
              │   ┌─────────────┴─────────────────────┐  │
              │   │  Edge Functions (Deno/TypeScript)  │  │
              │   │  upgrade-building                  │  │
              │   │  dispatch-units · train-units      │  │
              │   └─────────────┬─────────────────────┘  │
              │                 │ service role (bypasses RLS)
              │   ┌─────────────┴─────────────────────┐  │
              │   │  PostgreSQL (single source of truth)│  │
              │   │  + RLS on every table               │  │
              │   │  + REPLICA IDENTITY FULL            │  │
              │   │    (Realtime push on UPDATE)        │  │
              │   └─────────────┬─────────────────────┘  │
              │   ┌─────────────┴─────────────────────┐  │
              │   │  pg_cron jobs (every 1 / 5 min)    │  │
              │   │  resource-tick · construction-tick  │  │
              │   │  training-tick · movement-tick      │  │
              │   │  battle-tick                        │  │
              │   └─────────────────────────────────────┘  │
              └───────────────────────────────────────────┘
```

### Existing Tables

| Table | Key Columns | Realtime |
|-------|-------------|----------|
| `islands` | `id, grid_x, grid_y, wood_level, luxury_type, luxury_level` | No |
| `cities` | `id, owner_id, island_id, slot_number, name` | No (v0.1.0) |
| `city_resources` | `city_id, resource_type, amount` | Yes — FULL |
| `city_buildings` | `city_id, building_type, level, assigned_workers` | Yes — FULL |
| `construction_queue` | `city_id, building_type, target_level, finish_at` | No |
| `city_units` | `city_id, unit_type, quantity` | No |
| `unit_movements` | `owner_id, origin_city_id, destination_city_id, units (jsonb), arrive_at, movement_type` | Yes — FULL |
| `battles` | `defender_city_id, attacker_city_id, attacker_units (jsonb), defender_units (jsonb), status, turn_number, next_turn_at` | Yes — FULL |
| `battle_turns` | `battle_id, turn_number, naval/land casualties (jsonb), survivors (jsonb)` | No |
| `profiles` | `id, display_name, avatar_id` | No |

### Existing pg_cron Schedule

| Job Name | Schedule | Function |
|----------|----------|----------|
| `resource-tick` | `*/5 * * * *` | `process_resource_tick()` |
| `construction-tick` | `* * * * *` | `complete_building_upgrades()` |
| `training-tick` | `* * * * *` | `complete_training()` |
| `movement-tick` | `* * * * *` | `process_arrivals()` |
| `battle-tick` | `* * * * *` | `resolve_battles()` |

### Existing Edge Functions

| Function | Purpose |
|----------|---------|
| `upgrade-building` | Validate ownership, deduct resources, queue construction |
| `train-units` | Validate, deduct resources, queue training |
| `dispatch-units` | Validate, deduct from garrison, create unit_movement |

---

## New Feature Integration Map

### Feature 1: Happiness System

**What it adds:** Tavern building consumes the island's luxury resource every tick.
Net consumption rate sets `happiness` (0–100) on the city. Happiness affects
population growth rate.

**Schema changes — MODIFY `cities`:**

```sql
ALTER TABLE public.cities ADD COLUMN population        integer NOT NULL DEFAULT 50;
ALTER TABLE public.cities ADD COLUMN happiness         integer NOT NULL DEFAULT 50
  CHECK (happiness BETWEEN 0 AND 100);
ALTER TABLE public.cities ADD COLUMN tavern_wine_rate  integer NOT NULL DEFAULT 0;
  -- units consumed per hour from the island's luxury resource; 0 = tavern off
```

`cities` needs Realtime enabled (currently absent):

```sql
ALTER TABLE public.cities REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.cities;
```

**No new table.** Tavern configuration is a column on `cities`.

**MODIFY `process_resource_tick()` — add happiness sub-loop:**

After the existing production loop, for each city with `tavern_wine_rate > 0`:
1. `wine_per_tick = tavern_wine_rate / 12.0` (12 five-minute ticks per hour)
2. Attempt deduction from `city_resources` WHERE `resource_type = island.luxury_type`
3. If deduction succeeds: `happiness = LEAST(100, happiness + 2)`
4. If insufficient wine: `happiness = GREATEST(0, happiness - 5)`
5. `population = population + FLOOR(population * 0.01 * (happiness / 100.0))`

The happiness and population update is a single `UPDATE cities SET happiness = ..., population = ... WHERE id = ...` appended inside the existing loop. No new pg_cron job.

**New Edge Function — `configure-tavern`:**

```
POST /functions/v1/configure-tavern
Body: { city_id, wine_rate }   // wine_rate in units/hour; 0 = tavern off
```

Validates: city ownership, tavern building level >= 1, wine_rate non-negative.
Writes: `UPDATE cities SET tavern_wine_rate = $wine_rate WHERE id = $city_id`.

**Flutter integration:**

- `cityProvider` already streams `cities` via PostgREST. Add `population`,
  `happiness`, `tavernWineRate` to the select fields.
- New `City` model fields. New `TavernScreen` with wine-rate slider and live
  happiness display.
- Realtime: `cities` is now in the publication — `cityProvider` stream fires on
  city row UPDATE (population, happiness changes from pg_cron tick).

---

### Feature 2: Population-Based Tax Income

**What it adds:** Gold production each tick equals `population * tax_rate / 12`.
High tax depresses happiness.

**Schema changes — MODIFY `cities`:**

```sql
ALTER TABLE public.cities ADD COLUMN tax_rate numeric NOT NULL DEFAULT 0.10
  CHECK (tax_rate BETWEEN 0 AND 1);
```

**MODIFY `process_resource_tick()` — add tax gold sub-loop:**

After the happiness/population update for each city:
```sql
gold_per_tick = FLOOR(population * tax_rate / 12.0)
-- ADD to city_resources WHERE resource_type = 'gold', LEAST-capped by warehouse
-- happiness_penalty: if tax_rate > 0.30, happiness -= FLOOR((tax_rate - 0.30) * 20)
```

Bundled into the same function modification as happiness — one migration file
replaces `process_resource_tick()`.

**New Edge Function — `set-tax-rate`:**

```
POST /functions/v1/set-tax-rate
Body: { city_id, tax_rate }   // 0.0 to 1.0 inclusive
```

**Flutter integration:**

- `TavernScreen` (or a new `GovernorScreen`) adds a tax slider beneath the wine
  slider. Shows estimated gold-per-hour as a derived display value:
  `(population * tax_rate).floor()` gold/hour. Display only; actual production
  is server-authoritative.

---

### Feature 3: Island Resource Upgrades

**What it adds:** Players on an island can upgrade `islands.wood_level` or
`islands.luxury_level`. All cities on the island multiply their matching
resource production by the island level.

**Existing schema handles storage:** `islands.wood_level` and `islands.luxury_level`
already exist. Only the upgrade path and the production multiplier are new.

**MODIFY `process_resource_tick()` — island multiplier:**

The current production formula is:
```
workers * prod_level * 1.0
```
Replace with:
```
workers * prod_level * island_resource_level
```

This requires joining `islands` in the resource tick loop:

```sql
LEFT JOIN public.islands isl
  ON isl.id = (SELECT island_id FROM public.cities WHERE id = cr.city_id)
```

Then multiply by `COALESCE(isl.wood_level, 1)` for wood, and
`COALESCE(isl.luxury_level, 1)` for the island's luxury type. Gold production
(town_hall) is unaffected by island levels.

**New Edge Function — `upgrade-island-resource`:**

```
POST /functions/v1/upgrade-island-resource
Body: { island_id, resource_type }  // 'wood' | 'luxury'
```

Logic:
1. Verify `EXISTS (SELECT 1 FROM cities WHERE island_id = $island_id AND owner_id = $user_id)`.
2. Cost formula: `base_cost * 1.5^current_level` in wood + gold.
3. `deduct_resource(caller_city_id, ...)` using the existing atomic SQL function.
4. `UPDATE islands SET wood_level = wood_level + 1` (or luxury_level).

RLS: `islands` has SELECT-all policy. The Edge Function uses service role for
the UPDATE — no RLS change needed.

**Flutter integration:**

- `IslandScreen` adds an "Upgrade Resources" section showing current wood/luxury
  level, upgrade cost, and an upgrade button.
- No new provider: `islandDetailProvider` already streams island data. The
  button calls the new Edge Function and the stream reflects the change.

---

### Feature 4: Resource UI — Hourly Production Rate Display

**What it adds:** The resource bar and building screens show `+N/hour` alongside
the current resource amount. Pure client-side derivation from existing streams.

**Backend changes:** None.

**New Riverpod provider — `resourceRatesProvider`:**

```dart
// Combines resourcesStreamProvider + buildingsStreamProvider + islandProvider
// Returns Map<ResourceType, double> of gross hourly production rates.
// Formula: workers * building_level * island_level * 12 ticks_per_hour
final resourceRatesProvider = Provider.autoDispose.family<Map<ResourceType, double>, String>(
  (ref, cityId) {
    final buildings = ref.watch(buildingsStreamProvider(cityId)).valueOrNull ?? [];
    final island = ref.watch(islandDetailProvider(cityId)).valueOrNull;
    // ... derive per-resource rate
  },
);
```

For gold, rate also includes tax: `population * tax_rate` per hour (from `cityProvider`).

The formula on the client **must stay in sync** with the server formula in
`process_resource_tick()`. Document the sync requirement with a comment in both
files. Any formula change requires updating both.

**Flutter integration:**

- `_ResourceChip` in `city_screen.dart` gains a subtitle `+N/h` in green.
- `BuildingUpgradeSheet` shows current vs. post-upgrade production rate.
- Keep to gross rate display for v1.1; net rate (minus training costs) is
  deferred to avoid complexity.

---

### Feature 5: Player-to-Player Resource Trading via Cargo Ships

**What it adds:** A player selects a target city, picks resource type and
quantity, dispatches a cargo ship. Resources are deducted immediately
(escrowed). On arrival, the recipient's city gains the resources.

**New table — `resource_shipments`:**

```sql
CREATE TABLE public.resource_shipments (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id           uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  origin_city_id      uuid NOT NULL REFERENCES public.cities(id),
  destination_city_id uuid NOT NULL REFERENCES public.cities(id),
  resource_type       text NOT NULL,
  amount              numeric NOT NULL CHECK (amount > 0),
  arrive_at           timestamptz NOT NULL,
  status              text NOT NULL DEFAULT 'in_transit'
                      CHECK (status IN ('in_transit', 'delivered', 'returned')),
  created_at          timestamptz NOT NULL DEFAULT NOW(),
  CHECK (origin_city_id <> destination_city_id)
);

ALTER TABLE public.resource_shipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.resource_shipments REPLICA IDENTITY FULL;

CREATE POLICY "resource_shipments_select"
  ON public.resource_shipments FOR SELECT TO authenticated
  USING (
    sender_id = auth.uid()
    OR destination_city_id IN (SELECT id FROM public.cities WHERE owner_id = auth.uid())
  );

ALTER PUBLICATION supabase_realtime ADD TABLE public.resource_shipments;
```

**New Edge Function — `send-resources`:**

```
POST /functions/v1/send-resources
Body: { origin_city_id, destination_city_id, resource_type, amount }
```

Logic:
1. Verify caller owns `origin_city_id`.
2. Verify `trading_port` building level >= 1 at origin.
3. Calculate travel time: `max(1, ceil(sqrt(dx² + dy²) * 2))` minutes — same
   formula used in `dispatch-units`.
4. `deduct_resource(origin_city_id, resource_type, amount)` — atomic; rolls back
   on INSERT failure.
5. INSERT into `resource_shipments`.

**New pg_cron job — `deliver-resources`:**

```sql
SELECT cron.schedule('deliver-resources', '* * * * *',
  'SELECT public.deliver_resource_shipments()');
```

New SQL function `deliver_resource_shipments()`:

```sql
-- FOR each resource_shipment WHERE arrive_at <= NOW() AND status = 'in_transit'
-- FOR UPDATE SKIP LOCKED:
--   warehouse_cap = 500 * POWER(1.5, warehouse_level)
--   UPDATE city_resources SET amount = LEAST(amount + shipment.amount, warehouse_cap)
--     WHERE city_id = destination_city_id AND resource_type = shipment.resource_type
--   UPDATE resource_shipments SET status = 'delivered'
```

**Flutter integration:**

- New `TradeScreen`: select target city from a list/map, pick resource + amount,
  confirm send.
- New `ResourceShipmentsProvider` (StreamProvider.family on city_id): streams
  `resource_shipments` for outgoing and incoming shipments.
- Arrival countdown uses existing `CountdownTimerWidget`.

---

### Feature 6: Marketplace with Buy/Sell Order Book

**What it adds:** Global order book where players post buy or sell offers for
resources. Fulfillment is a player-triggered action.

**New table — `marketplace_orders`:**

```sql
CREATE TABLE public.marketplace_orders (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id       uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  city_id         uuid NOT NULL REFERENCES public.cities(id),
  order_type      text NOT NULL CHECK (order_type IN ('buy', 'sell')),
  resource_type   text NOT NULL,
  quantity        numeric NOT NULL CHECK (quantity > 0),
  price_gold      numeric NOT NULL CHECK (price_gold > 0),
  status          text NOT NULL DEFAULT 'open'
                  CHECK (status IN ('open', 'filled', 'cancelled')),
  created_at      timestamptz NOT NULL DEFAULT NOW(),
  updated_at      timestamptz NOT NULL DEFAULT NOW()
);

ALTER TABLE public.marketplace_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_orders REPLICA IDENTITY FULL;

-- All players can read open orders (public order book)
CREATE POLICY "marketplace_orders_select"
  ON public.marketplace_orders FOR SELECT TO authenticated USING (true);

-- Partial index for efficient order book queries
CREATE INDEX ON public.marketplace_orders (resource_type, price_gold)
  WHERE status = 'open';

ALTER PUBLICATION supabase_realtime ADD TABLE public.marketplace_orders;
```

**New Edge Functions:**

`post-sell-order`:
1. Verify city ownership + `trading_port` level >= 1.
2. `deduct_resource(city_id, resource_type, quantity)` — escrows resources.
3. INSERT order `order_type = 'sell'`.

`post-buy-order`:
1. Verify city ownership + `trading_port` level >= 1.
2. `deduct_resource(city_id, 'gold', quantity * price_gold)` — escrows gold.
3. INSERT order `order_type = 'buy'`.

`fulfill-order`:
1. Verify caller's city owns the other side of the trade.
2. Return escrowed gold to seller's `city_resources`.
3. INSERT into `resource_shipments` for the resource delivery to buyer (same
   travel time calculation as `send-resources`).
4. `UPDATE marketplace_orders SET status = 'filled'` for both matched orders.

`cancel-order`:
1. Verify caller owns the order.
2. Return escrowed resource or gold to `city_resources` atomically.
3. `UPDATE marketplace_orders SET status = 'cancelled'`.

**No pg_cron job needed** for the marketplace — fulfillment is event-driven.

**Flutter integration:**

- New `MarketplaceScreen`: order book table (filterable by resource, sortable by
  price), "Post Order" form, "My Orders" tab.
- `MarketplaceOrdersProvider` (global StreamProvider, no city_id): streams
  `marketplace_orders WHERE status = 'open'`.
- Fulfillment triggers a `resource_shipment`, which the existing
  `ResourceShipmentsProvider` picks up automatically.

---

### Feature 7: Pillage (Steal Resources on Battle Victory)

**What it adds:** When `resolve_battles()` resolves an `attacker_won` outcome,
a fraction of the defender's unprotected resources is transferred to the
attacker via the return movement's cargo.

**Schema changes — MODIFY `unit_movements`:**

```sql
ALTER TABLE public.unit_movements ADD COLUMN cargo jsonb;
-- {"wood": 120, "gold": 50} — resources carried by returning army
-- NULL for non-pillage movements
```

**MODIFY `resolve_battles()` — add pillage in the `attacker_won` branch:**

```sql
-- Before INSERT of the return unit_movement:
DECLARE
  v_hideout_level  integer;
  v_protected      numeric;
  v_stealable      numeric;
  v_stolen         numeric;
  v_cargo          jsonb := '{}';
  v_res_type       text;
  v_def_amount     numeric;
BEGIN
  SELECT COALESCE(level, 0) INTO v_hideout_level
  FROM city_buildings WHERE city_id = b.defender_city_id AND building_type = 'hideout';

  v_protected := 100 * v_hideout_level;  -- resources immune to pillage per hideout level

  FOREACH v_res_type IN ARRAY ARRAY['wood','marble','crystal','sulfur','gold'] LOOP
    SELECT amount INTO v_def_amount
    FROM city_resources
    WHERE city_id = b.defender_city_id AND resource_type = v_res_type;

    v_stealable := GREATEST(0, v_def_amount - v_protected);
    v_stolen    := FLOOR(v_stealable * 0.30);  -- 30% pillage rate

    IF v_stolen > 0 THEN
      UPDATE city_resources SET amount = amount - v_stolen
      WHERE city_id = b.defender_city_id AND resource_type = v_res_type;
      v_cargo := v_cargo || jsonb_build_object(v_res_type, v_stolen);
    END IF;
  END LOOP;
END;

-- Then INSERT return movement WITH cargo:
INSERT INTO unit_movements (..., cargo) VALUES (...,
  CASE WHEN v_cargo = '{}' THEN NULL ELSE v_cargo END);
```

**MODIFY `process_arrivals()` — cargo delivery on return movements:**

```sql
-- After existing unit return-to-garrison logic:
IF v_movement.movement_type = 'return' AND v_movement.cargo IS NOT NULL THEN
  FOR v_kv IN SELECT key, value FROM jsonb_each_text(v_movement.cargo) LOOP
    UPDATE city_resources
    SET amount = LEAST(amount + v_kv.value::numeric, warehouse_cap)
    WHERE city_id = v_movement.destination_city_id
      AND resource_type = v_kv.key;
  END LOOP;
END IF;
```

**Flutter integration:**

- `UnitMovement` Dart model gains `cargo` field (`Map<String, double>?`).
- Movement list widget shows "Returning with pillage: 120 wood, 50 gold" when
  `cargo != null`.
- Battle detail screen final turn card shows pillage summary.

---

### Feature 8: Battle Report — Turn-by-Turn Unit Loss Visualization

**What it adds:** Replaces the existing text-based casualty list in
`BattleTurnCard` with a color-coded visual: unit type icons with loss badges and
survivor counts, color-coded by unit class.

**Backend changes:** None. All required data is already in `battle_turns`
(JSONB casualty maps + survivor maps). The data model is complete.

**Pure Flutter changes:**

New widget — `lib/features/battles/screens/widgets/unit_casualty_bar.dart`:

```dart
// Renders a row of UnitChip widgets.
// Each chip shows:
//   - Unit type display name or icon
//   - Red "-N" badge for losses
//   - Green "N left" subtitle
// Color coding:
//   Naval units: Colors.blue.shade400 accent border
//   Land units:  Colors.green.shade600 accent border
//   Support (medic, cook): Colors.grey accent border
```

New file — `lib/core/constants/unit_visual_constants.dart`:

```dart
// Maps DB unit type string → (Color category, display label)
// Keeps BattleTurnCard free of switch statements
const Map<String, UnitVisualCategory> kUnitVisuals = {
  'hoplite': UnitVisualCategory.land,
  'phalanx': UnitVisualCategory.land,
  // ...
  'cargo_ship': UnitVisualCategory.naval,
  // ...
  'medic': UnitVisualCategory.support,
  'cook': UnitVisualCategory.support,
};
```

**Modified `BattleTurnCard`:**

- Naval Phase section (blue header): attacker + defender `UnitCasualtyBar`
- Land Phase section (green header): attacker + defender `UnitCasualtyBar`
- "Skipped" / "Blocked" phases show a gray muted label
- No changes to providers, repositories, or SQL

---

## Complete v1.1 Component Summary

### New Tables

| Table | Purpose | Realtime |
|-------|---------|----------|
| `resource_shipments` | In-transit resource transfers | Yes — FULL |
| `marketplace_orders` | Buy/sell order book | Yes — FULL |

### Modified Tables

| Table | Change |
|-------|--------|
| `cities` | + `population`, `happiness`, `tavern_wine_rate`, `tax_rate`; + Realtime FULL |
| `unit_movements` | + `cargo jsonb` (nullable) |

### New pg_cron Jobs

| Job Name | Schedule | Function |
|----------|----------|----------|
| `deliver-resources` | `* * * * *` | `deliver_resource_shipments()` |

### Modified SQL Functions

| Function | Change |
|----------|--------|
| `process_resource_tick()` | + happiness tick, + population growth, + tax gold, + island level multiplier |
| `resolve_battles()` | + pillage calculation in `attacker_won` branch; return movement gets `cargo` |
| `process_arrivals()` | + cargo delivery when `movement_type = 'return' AND cargo IS NOT NULL` |

### New Edge Functions

| Function | Body Params | Purpose |
|----------|-------------|---------|
| `configure-tavern` | `city_id, wine_rate` | Set tavern wine consumption rate |
| `set-tax-rate` | `city_id, tax_rate` | Set city tax rate |
| `upgrade-island-resource` | `island_id, resource_type` | Upgrade island resource level |
| `send-resources` | `origin_city_id, destination_city_id, resource_type, amount` | Dispatch resource cargo ship |
| `post-sell-order` | `city_id, resource_type, quantity, price_gold` | Escrow + open sell order |
| `post-buy-order` | `city_id, resource_type, quantity, price_gold` | Escrow gold + open buy order |
| `fulfill-order` | `order_id, fulfiller_city_id` | Match orders, trigger shipment |
| `cancel-order` | `order_id` | Return escrow, close order |

### New Flutter Features

| Module | Files | Purpose |
|--------|-------|---------|
| `features/city/screens/tavern_screen.dart` | NEW | Wine rate + tax rate sliders |
| `features/city/providers/resource_rates_provider.dart` | NEW | Derived hourly production rates |
| `features/trade/` | NEW module | TradeScreen, ResourceShipmentsProvider, resource_shipment model |
| `features/marketplace/` | NEW module | MarketplaceScreen, MarketplaceOrdersProvider, order model |
| `features/battles/screens/widgets/unit_casualty_bar.dart` | NEW | Color-coded unit loss visualization |
| `core/constants/unit_visual_constants.dart` | NEW | Unit-to-color/category mapping |
| `features/battles/screens/widgets/battle_turn_card.dart` | MODIFIED | Uses UnitCasualtyBar |
| `features/city/screens/city_screen.dart` | MODIFIED | Resource panel adds hourly rate |
| `features/map/screens/island_screen.dart` | MODIFIED | Island upgrade UI |
| `features/military/models/unit_movement.dart` | MODIFIED | + `cargo` field |
| `features/city/models/city.dart` | MODIFIED | + `population`, `happiness`, `taxRate`, `tavernWineRate` |

---

## Data Flow Diagrams

### Happiness / Population / Tax Tick

```
pg_cron resource-tick (every 5 min):
  process_resource_tick()
    ├── [EXISTING] Production buildings → city_resources (wood/marble/crystal/sulfur)
    ├── [NEW] Tavern wine consumption:
    │         city_resources (luxury) -= wine_per_tick
    │         cities.happiness ↑ if sufficient wine, ↓ if not
    │         cities.population += floor(population * 0.01 * happiness/100)
    ├── [NEW] Tax income:
    │         city_resources (gold) += floor(population * tax_rate / 12)
    │         cities.happiness -= penalty if tax_rate > 0.30
    └── Realtime push:
          cities row UPDATE → cityProvider stream → TavernScreen + GovernorScreen rebuild
          city_resources row UPDATE → resourcesStreamProvider → resource panel rebuild
```

### Island Upgrade

```
Player taps "Upgrade Sawmill Level":
  upgrade-island-resource Edge Function
    ├── Check city-on-island ownership
    ├── deduct_resource(caller_city_id, 'wood', cost)
    │   deduct_resource(caller_city_id, 'gold', cost)
    └── UPDATE islands SET wood_level = wood_level + 1
          → islandDetailProvider refresh (PostgREST SELECT, no Realtime on islands)

pg_cron resource-tick (next tick):
  process_resource_tick()
    └── wood production = workers * sawmill_level * islands.wood_level
          all cities on island produce more wood from now on
```

### Resource Trading

```
Player sends resources:
  send-resources Edge Function
    ├── deduct_resource(origin, type, amount)   [escrow — immediate]
    └── INSERT resource_shipments (status = 'in_transit', arrive_at = now + travel)
          → ResourceShipmentsProvider receives Realtime INSERT
          → UI shows outgoing shipment with countdown

pg_cron deliver-resources (every minute):
  deliver_resource_shipments()
    └── For arrived shipments (arrive_at <= NOW()):
          UPDATE city_resources (destination) += amount (warehouse capped)
          UPDATE resource_shipments SET status = 'delivered'
            → ResourceShipmentsProvider Realtime UPDATE
            → resourcesStreamProvider Realtime UPDATE (recipient's resources)
```

### Marketplace

```
Seller posts:
  post-sell-order
    ├── deduct_resource(city, resource, qty)    [escrow]
    └── INSERT marketplace_orders (status = 'open')
          → MarketplaceOrdersProvider Realtime INSERT → order appears in book

Buyer fulfills:
  fulfill-order
    ├── credit seller: city_resources (gold) += qty * price
    ├── INSERT resource_shipments (buyer receives resources via travel)
    └── UPDATE both orders SET status = 'filled'
          → MarketplaceOrdersProvider Realtime UPDATE → order removed from book
          → ResourceShipmentsProvider Realtime INSERT → buyer sees incoming shipment
```

### Pillage

```
resolve_battles() (pg_cron battle-tick) — attacker_won branch:
  ├── [EXISTING] Clear defender city_units
  ├── [NEW] Calculate pillage:
  │         hideout_protection = 100 * hideout_level
  │         for each resource: stolen = floor((amount - protection) * 0.30)
  │         UPDATE defender city_resources -= stolen
  │         cargo = {wood: N, gold: M, ...}
  └── INSERT unit_movements (movement_type='return', cargo=cargo_jsonb)
        → unitMovementsProvider Realtime INSERT
        → attacker sees "returning with pillage" in movement list

process_arrivals() (movement-tick) — return with cargo:
  └── UPDATE attacker city_resources += cargo amounts (warehouse capped)
        → resourcesStreamProvider Realtime UPDATE → attacker's resources increase
```

---

## Recommended Project Structure Additions

```
lib/
├── features/
│   ├── city/
│   │   ├── screens/
│   │   │   ├── city_screen.dart              [MODIFIED — hourly rates in resource panel]
│   │   │   └── tavern_screen.dart            [NEW]
│   │   └── providers/
│   │       └── resource_rates_provider.dart  [NEW]
│   ├── trade/                                [NEW feature module]
│   │   ├── data/trade_repository.dart
│   │   ├── models/resource_shipment.dart
│   │   ├── providers/resource_shipments_provider.dart
│   │   └── screens/trade_screen.dart
│   ├── marketplace/                          [NEW feature module]
│   │   ├── data/marketplace_repository.dart
│   │   ├── models/marketplace_order.dart
│   │   ├── providers/marketplace_orders_provider.dart
│   │   └── screens/marketplace_screen.dart
│   ├── battles/
│   │   └── screens/widgets/
│   │       ├── battle_turn_card.dart         [MODIFIED — uses UnitCasualtyBar]
│   │       └── unit_casualty_bar.dart        [NEW]
│   └── map/
│       └── screens/island_screen.dart        [MODIFIED — island upgrade UI]
├── core/constants/
│   └── unit_visual_constants.dart            [NEW]
supabase/
├── functions/
│   ├── configure-tavern/index.ts             [NEW]
│   ├── set-tax-rate/index.ts                 [NEW]
│   ├── upgrade-island-resource/index.ts      [NEW]
│   ├── send-resources/index.ts               [NEW]
│   ├── post-sell-order/index.ts              [NEW]
│   ├── post-buy-order/index.ts               [NEW]
│   ├── fulfill-order/index.ts                [NEW]
│   └── cancel-order/index.ts                 [NEW]
└── migrations/
    ├── 2026XXXX_add_city_economy_columns.sql   [cities: population/happiness/rates]
    ├── 2026XXXX_add_unit_movements_cargo.sql   [unit_movements: cargo jsonb]
    ├── 2026XXXX_create_resource_shipments.sql
    ├── 2026XXXX_create_marketplace_orders.sql
    ├── 2026XXXX_modify_process_resource_tick.sql  [replaces existing function]
    ├── 2026XXXX_modify_resolve_battles.sql        [replaces existing function]
    ├── 2026XXXX_modify_process_arrivals.sql       [replaces existing function]
    └── 2026XXXX_deliver_resources_cron.sql        [new cron job]
```

---

## Architectural Patterns

### Pattern 1: Escrow-on-Dispatch

**What:** Any feature where resources are "in flight" (trading, marketplace sell,
marketplace buy) deducts the resources from the sender atomically at dispatch
time. The `resource_shipments` or `marketplace_orders` row represents the
escrowed value.

**When to use:** All multi-city resource transfers without exception. Prevents
a double-send race condition where a player opens two tabs and sends the same
resources to two destinations.

**Trade-offs:** Player sees resources decrease immediately, which can feel
jarring. Mitigate with a clear "in transit: +120 wood arriving in 4 min"
display. The alternative — deducting on arrival — would allow oversending and
create debt.

**Implementation pattern:** Call `deduct_resource()` inside the Edge Function
before the INSERT. If the INSERT fails for any reason, Supabase auto-rolls back
the function's implicit transaction, returning the resources.

### Pattern 2: Columnar Extension Over New Tables

**What:** Happiness, population, tax rate, and tavern wine rate are added as
columns to `cities` rather than in separate `city_happiness` or `city_economy`
tables.

**When to use:** When data has a strict 1:1 relationship with an existing entity
and is always queried together with it.

**Trade-offs:** The `cities` row grows wider. Postgres handles this efficiently
up to hundreds of columns. The benefit is that one Realtime event covers all
city economy changes — no additional subscriptions.

**Exception:** `marketplace_orders` and `resource_shipments` are separate tables
because they are 1:many with cities and require independent Realtime subscriptions
from any client (not just the city owner).

### Pattern 3: Bundled SQL Function Extension

**What:** New tick behaviors (happiness, population, tax, pillage, cargo
delivery) are added as new sections inside existing SQL functions rather than
as new pg_cron jobs.

**When to use:** When the new behavior is tightly coupled to the existing tick's
timing and must operate on data already loaded in the same loop. Happiness and
tax run at the same 5-minute interval as resource production — co-locating them
avoids ordering ambiguity and reduces cron job count.

**Trade-offs:** Functions grow larger. Mitigate with clear `-- SECTION` comment
blocks inside the function body.

**Exception:** `deliver_resource_shipments` is a separate new job because it
operates on a new independent table (`resource_shipments`) with no logical
coupling to the resource production loop.

### Pattern 4: Client-Side Rate Derivation

**What:** Hourly production rate is not stored in the database. It is derived
client-side from existing Riverpod streams (building levels, workers, island
level) using a combined `Provider`.

**When to use:** Display-only data that changes only when the underlying inputs
change (which already trigger Realtime updates), and where the formula is
simple enough to maintain in sync.

**Critical constraint:** The Dart formula in `resourceRatesProvider` must match
the PostgreSQL formula in `process_resource_tick()` exactly. Add a comment in
both files cross-referencing the other. Any formula change in the SQL migration
must also update the Dart provider.

---

## Scaling Considerations

| Scale | Concern | Approach |
|-------|---------|---------|
| Current (< 50 players) | `process_resource_tick()` growing — happiness + tax + island join added | Fine: single-pass loop; island join adds one subquery per resource row, acceptable |
| 100–500 players | Marketplace Realtime fan-out — all players subscribe to all open orders | Filter channel to `WHERE status = 'open'`; Supabase handles ~1000 concurrent connections |
| 100–500 players | `process_resource_tick()` includes happiness + population + tax per city | Monitor job duration; still single function, should complete in < 5s for 500 cities |
| 500+ players | `resolve_battles()` + `process_resource_tick()` may exceed 1-min window | Add `LIMIT 200 FOR UPDATE SKIP LOCKED` batch processing |
| 500+ players | `resource_shipments` table grows unbounded | Add cleanup: `DELETE FROM resource_shipments WHERE status = 'delivered' AND created_at < NOW() - INTERVAL '7 days'` |
| 500+ players | `marketplace_orders` query performance | Partial index on `(resource_type, price_gold) WHERE status = 'open'` — already included in migration above |

---

## Anti-Patterns

### Anti-Pattern 1: Client-Side Escrow Calculation

**What people do:** Show the resource cost in the Flutter UI and display the
post-deduction balance before calling the Edge Function.

**Why it's wrong:** The displayed balance and the server's actual balance can
diverge between render and Edge Function call (another tab, a pg_cron tick, a
concurrent order). The UI shows "sufficient" but the server rejects with
"insufficient resources".

**Do this instead:** Call the Edge Function immediately on player confirm.
Handle `insufficient_resources` error responses in the UI with an informative
snackbar and refresh the resource provider. Never compute affordability on the
client as authoritative.

### Anti-Pattern 2: Cancellation Without Escrow Return

**What people do:** `UPDATE marketplace_orders SET status = 'cancelled'` without
also returning the escrowed resource or gold to the city.

**Why it's wrong:** Player permanently loses the escrowed resources. Happens
easily if cancellation logic is written as two separate statements without a
transaction.

**Do this instead:** The `cancel-order` Edge Function issues both mutations
(resource return + status update) via the service role client. The Supabase
Deno client wraps them in the same HTTP request to PostgREST which handles
implicit rollback — or call a SECURITY DEFINER SQL function that wraps both
in a `BEGIN/COMMIT` block.

### Anti-Pattern 3: Storing Happiness on `city_buildings.tavern`

**What people do:** Add a `happiness` or `wine_consumed` column to the tavern
row in `city_buildings`.

**Why it's wrong:** Happiness is a city-wide property. Storing it on a building
row means the `city_buildings` Realtime subscription would fire on every building
change (not just tavern), causing unnecessary UI rebuilds in `BuildingsGrid` and
`BuildingUpgradeSheet`.

**Do this instead:** `happiness`, `population`, `tax_rate`, `tavern_wine_rate`
live on `cities`. One Realtime subscription covers all city-level economy data.
Building-level data stays in `city_buildings`.

### Anti-Pattern 4: Island Upgrade Without City-Membership Check

**What people do:** Allow any authenticated player to call
`upgrade-island-resource` on any island by passing an `island_id`.

**Why it's wrong:** A player with no city on the island could upgrade that
island's resources at the cost of their own city's resources, benefiting
strangers.

**Do this instead:** In `upgrade-island-resource`, before any deduction, assert:

```sql
EXISTS (
  SELECT 1 FROM cities
  WHERE island_id = $island_id AND owner_id = $auth_uid
)
```

Fail with 403 if the check fails.

---

## Integration Points

### Modified Existing Boundaries

| Boundary | Change | Notes |
|----------|--------|-------|
| `process_resource_tick()` | Add happiness, population, tax, island multiplier sections | One migration replaces the full function; test under load before deploying |
| `resolve_battles()` | Add pillage block in `attacker_won` branch | Hideout level lookup added; `cargo` JSONB built across resource types |
| `process_arrivals()` | Add cargo delivery for return movements | Null-check on `cargo` before processing; warehouse cap applied |
| `unit_movements` table | + `cargo jsonb` nullable column | Existing rows unaffected (NULL default) |
| `cities` table | + 4 economy columns; Realtime enabled | Requires schema migration + Realtime publication update |
| `UnitMovement` Dart model | + `cargo` field | `Map<String, double>?` — nullable |
| `CityModel` / `cityProvider` | + `population`, `happiness`, `taxRate`, `tavernWineRate` | From updated `cities` SELECT fields |
| `BattleTurnCard` widget | Casualty display replaced with `UnitCasualtyBar` | No provider or API changes |

### New Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `TavernScreen` → `configure-tavern` | HTTP POST + JWT | Optimistic display ok (UI only) |
| `TavernScreen` → `set-tax-rate` | HTTP POST + JWT | Optimistic display ok (UI only) |
| `IslandScreen` → `upgrade-island-resource` | HTTP POST + JWT | Response includes new island level for immediate display |
| `TradeScreen` → `send-resources` | HTTP POST + JWT | Response includes `arrive_at` for countdown |
| `MarketplaceScreen` → `post-/fulfill-/cancel-order` | HTTP POST + JWT | fulfill triggers resource_shipment — both parties notified via Realtime |
| `deliver_resource_shipments()` → `city_resources` | SQL pg_cron | No client involvement; Realtime pushes changes to subscribers automatically |

---

## Suggested Build Order (Dependency-Aware)

Features have internal dependencies. Build in three waves to avoid blocked work:

**Wave 1 — Schema migrations (no Flutter work blocked):**

1. Migration: `cities` economy columns + Realtime enabled
   - Unblocks: happiness system, tax system, `TavernScreen`
2. Migration: `unit_movements.cargo`
   - Unblocks: pillage modification in `resolve_battles()`
3. Migration: `resource_shipments` table + `deliver-resources` cron
   - Unblocks: `send-resources` Edge Function, marketplace `fulfill-order`
4. Migration: `marketplace_orders` table
   - Unblocks: all marketplace Edge Functions

**Wave 2 — Backend (Edge Functions + SQL function modifications):**

5. MODIFY `process_resource_tick()` — happiness + population + tax + island multiplier
   - Depends on: Wave 1 cities columns
   - Unblocks: `TavernScreen` rates are now server-computed
6. MODIFY `resolve_battles()` — pillage block
   - Depends on: `unit_movements.cargo` column
7. MODIFY `process_arrivals()` — cargo delivery
   - Depends on: `unit_movements.cargo` column
8. `configure-tavern` + `set-tax-rate` Edge Functions — simple column setters
9. `upgrade-island-resource` Edge Function
   - Depends on: `process_resource_tick()` updated with island multiplier
10. `send-resources` Edge Function
    - Depends on: `resource_shipments` table
11. `post-sell-order`, `post-buy-order`, `fulfill-order`, `cancel-order`
    - `fulfill-order` depends on `send-resources` pattern (triggers shipment)

**Wave 3 — Flutter (can start once corresponding backend is in Wave 2):**

12. `resource_rates_provider.dart` + hourly rate UI in resource panel
    - Depends on: `process_resource_tick()` updated (island multiplier must match)
13. `TavernScreen` — wine rate + tax sliders
    - Depends on: `configure-tavern` + `set-tax-rate`
14. `IslandScreen` upgrade UI
    - Depends on: `upgrade-island-resource`
15. `TradeScreen` + `ResourceShipmentsProvider`
    - Depends on: `send-resources`
16. `MarketplaceScreen` + `MarketplaceOrdersProvider`
    - Depends on: all marketplace Edge Functions
17. `UnitCasualtyBar` + `BattleTurnCard` update
    - Pure Flutter; no backend dependency (all data already in `battle_turns`)
    - Can be built in parallel with any Wave 2/3 work

---

## Sources

- Existing codebase read directly:
  `supabase/migrations/` (all 22 migration files),
  `supabase/functions/upgrade-building/index.ts`,
  `lib/features/city/`, `lib/features/battles/`, `lib/features/military/`,
  `lib/features/map/` — HIGH confidence
- Supabase Realtime: `REPLICA IDENTITY FULL` requirement for UPDATE events — HIGH confidence (official docs)
- Supabase Edge Function transaction semantics (implicit rollback on exception) — HIGH confidence (existing `deduct_resource` pattern in codebase)
- pg_cron `FOR UPDATE SKIP LOCKED` batching pattern — HIGH confidence (existing `resolve_battles()` in codebase)
- Ikariam game mechanics (hideout protection, happiness system, pillage rates): ikariam.fandom.com/wiki — MEDIUM confidence (use as design intent; balance values subject to playtesting)

---

*Architecture research for: Ikariam Clone v1.1 Economy & Combat Depth*
*Researched: 2026-03-13*
