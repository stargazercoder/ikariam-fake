# Stack Research

**Domain:** Browser-based multiplayer strategy game — v1.1 Economy & Combat Depth additions
**Researched:** 2026-03-13
**Confidence:** HIGH (core additions verified via pub.dev, Ikariam wiki, Supabase docs, fl_chart API docs)

---

## Context: What This Research Covers

v1.1 adds 8 new feature areas to an existing Flutter + Supabase + Riverpod codebase.
This document covers ONLY what is new or changed for v1.1. The base stack
(Flutter 3.29, Supabase 2.12.0, Riverpod 3.3.1, Flame 1.35.1, go_router 17.1.0)
is unchanged and validated — see the v0.1.0 STACK.md for that rationale.

Feature areas and their stack implications:

| Feature | New Stack Needed? | Verdict |
|---------|-------------------|---------|
| Happiness system | No new packages | Pure SQL + Edge Function logic |
| Population-based tax | No new packages | Pure SQL formula in pg_cron tick |
| Island resource upgrades | No new packages | New DB table + Edge Function |
| Resource production UI (hourly rates) | No new packages | Derive from existing DB fields, display in existing Flutter widgets |
| Player-to-player trading | No new packages | Edge Function + Supabase Realtime (already used) |
| Marketplace order book | No new packages | Pure SQL (orders table) + Realtime Postgres Changes |
| Pillage mechanic | No new packages | Edge Function with PostgreSQL atomic transaction (FOR UPDATE) |
| Battle report visualization | **fl_chart 1.1.1** | Stacked bar chart per turn; no other library needed |

**Summary:** Only one new Dart package is justified for v1.1: `fl_chart`. Every other
feature is implemented with existing stack capabilities.

---

## Recommended Stack

### New Library for v1.1

| Library | Version | Purpose | Why Recommended |
|---------|---------|---------|-----------------|
| fl_chart | 1.1.1 | Turn-by-turn battle report visualization — stacked bar chart showing unit losses per turn by unit type, color-coded by unit | The only mature, actively maintained Flutter chart library with `BarChartRodStackItem` stacked bar support. MIT license, 6,200+ GitHub stars, Flutter-native (no WebView). Supports color-per-stack-segment — exactly what color-coded unit type visualization requires. Min Flutter SDK 3.27.4, compatible with our 3.29 environment. |

### Existing Stack — How Each Feature Uses It

| Technology | Version | v1.1 Usage |
|------------|---------|------------|
| PostgreSQL (via Supabase) | — | New tables: `island_resource_levels`, `marketplace_orders`, `trade_routes`. New columns on `cities`: `population`, `happiness`, `tax_rate`. Happiness/tax computed in existing `resource-tick` pg_cron function. |
| pg_cron | — | Extend existing `resource-tick` job to compute: `happiness_delta = tavern_level * wine_rate - population`, `population_growth = f(happiness)`, `gold_income += population * tax_rate`. No new cron jobs needed. |
| Supabase Edge Functions (Deno/TypeScript) | — | New functions: `create-trade-offer`, `accept-trade`, `place-market-order`, `cancel-market-order`, `match-market-orders`, `pillage-city`, `upgrade-island-resource`. Pattern: all use PostgreSQL `FOR UPDATE` or `SECURITY DEFINER` functions for atomicity. |
| Supabase Realtime | — | Subscribe to `marketplace_orders` Postgres Changes to update order book in real-time. Existing `battle_turns` subscription already delivers pillage result. Use Broadcast channel for trade accepted/rejected notifications. |
| flutter_riverpod | 3.3.1 | New `StreamProvider`s for marketplace orders and trade offers. New `FutureProvider`s for happiness/population values. Pattern: matches existing providers in `lib/features/city/providers/`. |
| Flutter Material widgets | SDK | Happiness slider (Tavern wine rate config), order book list view, hourly rate display in resource bar. `DataTable` or `ListView.builder` for order book. No third-party widget packages needed. |

---

## Installation

```bash
# Add to existing Flutter project — only new package for v1.1
flutter pub add fl_chart
```

```bash
# Verify no version conflict after add
flutter pub deps | grep fl_chart
# Expected: fl_chart 1.1.1
```

No Supabase CLI changes needed — new functions follow existing deploy pattern:

```bash
supabase functions deploy create-trade-offer
supabase functions deploy accept-trade
supabase functions deploy place-market-order
supabase functions deploy cancel-market-order
supabase functions deploy match-market-orders
supabase functions deploy pillage-city
supabase functions deploy upgrade-island-resource
```

---

## Feature-by-Feature Implementation Stack

### 1. Happiness System

**Stack:** Pure PostgreSQL + pg_cron. Zero new packages.

**Schema additions:**
- `cities.happiness` (integer, default 196 — matches Ikariam base value)
- `cities.population` (integer, computed from happiness growth)
- `city_resources`: existing `wine` type tracked as consumable (already in schema as `crystal` analogue)

**Logic (pg_cron extension of existing `tick_resources()`):**
```sql
-- Happiness formula (simplified from Ikariam wiki):
-- happiness = tavern_base + wine_bonus - population
-- tavern_base = tavern_level * 12
-- wine_bonus = wine_spent_per_hour * 60  (each unit of wine = +60 happiness)
-- population cost: each citizen = -1 happiness
-- Population growth rate = MAX(0, happiness) / 34.66 (citizens per hour, halving curve)
UPDATE cities SET
  happiness = GREATEST(0,
    (SELECT level FROM city_buildings WHERE city_id = cities.id AND building_type = 'tavern') * 12
    + happiness_wine_bonus  -- from a new cities column storing configured wine/hr
    - population
  ),
  population = population + GREATEST(0, happiness) / 34.66
WHERE ...;
```

**Server authority:** All happiness and population mutations happen server-side in the tick. Client only sends `set-wine-rate` action (new Edge Function or extend tavern upgrade function).

### 2. Population-Based Tax

**Stack:** Pure PostgreSQL in existing pg_cron tick. Zero new packages.

**Formula:**
```sql
-- Gold income from tax = population * tax_rate (gold per tick per citizen)
-- tax_rate is player-configurable (0.0 to 1.0, higher rate = lower happiness)
UPDATE city_resources cr
SET amount = LEAST(cr.amount + (c.population * c.tax_rate * tick_minutes / 60.0), capacity)
FROM cities c
WHERE cr.city_id = c.id AND cr.resource_type = 'gold';
```

**New column:** `cities.tax_rate` (numeric, default 0.1). Client sends `set-tax-rate` via Edge Function (or extend town-hall interaction).

### 3. Island Resource Upgrades (Shared Building Levels)

**Stack:** New PostgreSQL table + new Edge Function. Zero new packages.

**Schema:**
```sql
CREATE TABLE island_resource_levels (
  island_id     uuid REFERENCES islands(id),
  resource_type text NOT NULL,       -- 'wood' or luxury type
  level         integer DEFAULT 1,
  PRIMARY KEY (island_id, resource_type)
);
```

**Logic:** `upgrade-island-resource` Edge Function:
- Charges resources from the triggering player's city
- Increments `island_resource_levels.level` (shared — benefits all cities on island)
- Production formula in tick: `workers * island_level * research_bonus` (already structured this way in v0.1.0, just `island_level` was always 1)

**UI:** Reuse `building_upgrade_sheet.dart` pattern — create `island_resource_upgrade_sheet.dart` with identical structure.

### 4. Resource Production UI (Hourly Rates)

**Stack:** Pure Flutter computation from existing data. Zero new packages.

**Approach:** Compute hourly rate client-side from existing DB fields — no new DB columns needed.

```dart
// HourlyRateService (new utility class, no package needed):
double computeHourlyRate({
  required int workers,
  required int buildingLevel,
  required int islandLevel,
  double researchBonus = 1.0,
}) {
  // Tick is every 5 minutes = 12 ticks/hour
  return workers * buildingLevel * islandLevel * researchBonus * 12;
}
```

**UI:** Extend existing resource bar widget (`lib/features/city/widgets/`) to show "+X/hr" label next to each resource. Flutter `Text` widget with a small `TextStyle`. No charting library needed for this — just formatted numbers.

### 5. Player-to-Player Trading (Cargo Ships)

**Stack:** New Edge Functions + existing Supabase Realtime. Zero new packages.

**Schema:**
```sql
CREATE TABLE trade_offers (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  from_city_id    uuid NOT NULL REFERENCES cities(id),
  to_city_id      uuid NOT NULL REFERENCES cities(id),
  offered_type    text NOT NULL,
  offered_amount  numeric NOT NULL,
  requested_type  text NOT NULL,
  requested_amount numeric NOT NULL,
  status          text DEFAULT 'pending',  -- pending | accepted | rejected | cancelled
  cargo_ships_required integer NOT NULL,
  created_at      timestamptz DEFAULT NOW()
);
```

**Edge Functions:**
- `create-trade-offer` — validates ships available, reserves cargo ships, inserts row
- `accept-trade` — atomic: deduct resources from both parties, release ships, mark accepted
- `cancel-trade` — releases reserved ships

**Realtime:** `to_city_id` player subscribes to `trade_offers` Postgres Changes (`INSERT`) — uses existing `supabase.channel()` pattern.

**Cargo ships:** Use existing `city_units` table `unit_type = 'cargo_ship'` count as capacity limiter (each cargo ship = 500 capacity, matching v0.1.0 constants).

### 6. Marketplace Order Book

**Stack:** New PostgreSQL table + Supabase Realtime Postgres Changes. Zero new packages.

**Schema:**
```sql
CREATE TABLE marketplace_orders (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id       uuid NOT NULL REFERENCES profiles(id),
  city_id         uuid NOT NULL REFERENCES cities(id),
  order_type      text NOT NULL CHECK (order_type IN ('buy', 'sell')),
  resource_type   text NOT NULL,
  quantity        numeric NOT NULL,
  price_per_unit  numeric NOT NULL,  -- in gold
  quantity_filled numeric DEFAULT 0,
  status          text DEFAULT 'open' CHECK (status IN ('open', 'partial', 'filled', 'cancelled')),
  created_at      timestamptz DEFAULT NOW()
);
CREATE INDEX ON marketplace_orders (resource_type, order_type, price_per_unit);
```

**Order matching (server-side SQL function):**
```sql
-- Called by match-market-orders Edge Function (or pg_cron every minute):
-- Simple price-time priority matching:
-- Buy orders matched with lowest sell price <= buy price
-- Transfer resources atomically using FOR UPDATE
```

**UI:** Flutter `DataTable` or custom `ListView.builder` with two columns (buys/sells) sorted by price. Existing `StreamProvider` pattern watches `marketplace_orders` Postgres Changes. No chart library needed — this is a list, not a chart.

**Realtime:** Subscribe to `marketplace_orders` changes filtered by `resource_type`. Existing `supabase_flutter` Realtime API handles this.

### 7. Pillage Mechanic

**Stack:** PostgreSQL atomic transaction in existing `resolve_battles()` or new `process-pillage` Edge Function. Zero new packages.

**Rule (from Ikariam wiki, adapted for our game):**
- Attacker wins battle → pillage phase triggers
- Resources stealable = MAX(0, defender_resource_amount - warehouse_protection)
- Warehouse protection = `warehouse_level * base_protection_per_level`
- Cargo ships determine max loot capacity: `attacker_cargo_ships * 500`
- Gold is NOT pillageable (Ikariam design — only production resources)

**SQL pattern (atomic, no race conditions):**
```sql
-- Inside SECURITY DEFINER function called after battle resolution:
UPDATE city_resources
SET amount = GREATEST(0, amount - pillage_amount)
WHERE city_id = defender_city_id AND resource_type = target_type;

UPDATE city_resources
SET amount = LEAST(amount + pillage_amount, warehouse_capacity)
WHERE city_id = attacker_home_city_id AND resource_type = target_type;
```

**Battle report extension:** `battle_turns` already exists. Add `pillage_result` JSONB column to `battles` table (not `battle_turns` — pillage is a one-time end-of-battle event).

### 8. Battle Report Visualization

**Stack:** `fl_chart 1.1.1` — specifically `BarChart` with `BarChartRodStackItem`.

**Why fl_chart specifically:**
- `BarChartRodStackItem(fromY, toY, color)` maps directly to unit type loss per turn
- Color-coded unit types: each unit type gets a fixed `Color` constant (e.g., hoplite = amber, archer = green, slinger = blue)
- Stacked segments per rod = unit type breakdown; each rod = one battle turn
- Separate `BarChart` for attacker casualties and defender casualties
- No licensing fees (MIT) — Syncfusion requires community license agreement for commercial use

**Implementation pattern:**
```dart
// BattleReportChart widget:
BarChart(
  BarChartData(
    barGroups: turns.map((turn) => BarChartGroupData(
      x: turn.turnNumber,
      barRods: [
        BarChartRodData(
          toY: turn.totalAttackerLosses.toDouble(),
          rodStackItems: turn.attackerCasualties.entries.map((e) =>
            BarChartRodStackItem(
              previousTotal,
              previousTotal + e.value,
              UnitColors.forType(e.key),  // color lookup constant map
            )
          ).toList(),
        ),
      ],
    )).toList(),
  ),
)
```

**Data source:** Existing `battle_turns` table — `land_attacker_casualties` and `land_defender_casualties` JSONB fields already contain per-unit-type counts. No schema changes needed for the chart data.

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| syncfusion_flutter_charts | Requires Syncfusion license agreement even for "free" community tier — adds friction, overkill for one chart type | `fl_chart 1.1.1` (MIT, no license required) |
| charts_flutter (google) | Archived/unmaintained as of 2023; community fork `community_charts_flutter` has lower adoption | `fl_chart 1.1.1` (actively maintained, 6,200+ GitHub stars) |
| Third-party order book widget packages | No mature Flutter order book packages exist on pub.dev; those found are finance-specific and add unnecessary dependency | Implement with `ListView.builder` + existing Riverpod `StreamProvider` pattern |
| Client-side marketplace matching | Race conditions inevitable — two clients can both "win" the same order | Server-side SQL function with `FOR UPDATE` row lock, called via Edge Function |
| Client-side pillage calculation | Attacker could manipulate amount stolen | `SECURITY DEFINER` PostgreSQL function — same pattern as existing battle resolution |
| Separate `pg_cron` job for happiness | Adds a new scheduled job when happiness can be computed in the existing resource tick | Extend `tick_resources()` to compute happiness/population — single tick, single transaction |
| `shared_preferences` for tax/wine rate | Game state must be server-authoritative | Store `tax_rate` and `happiness_wine_rate` columns on `cities` table, mutated via Edge Function |
| Freezed/code-gen for v1.1 models | `riverpod_generator` is still blocked by Dart 3.10.1 analyzer conflict (see PROJECT.md Key Decisions) | Manual model classes matching existing v0.1.0 pattern (handwritten `fromJson`, `==`, `hashCode`) |

---

## Alternatives Considered

| Recommended | Alternative | Why Not |
|-------------|-------------|---------|
| fl_chart 1.1.1 (stacked bar) | Flutter CustomPainter (hand-drawn chart) | CustomPainter is 200+ lines of boilerplate for axis labels, tooltips, animation. fl_chart provides all of that out of box. Use CustomPainter only if chart needs are truly unique — stacked bar is not unique. |
| PostgreSQL SECURITY DEFINER function for pillage | Edge Function (Deno) for pillage | SQL function is faster (no HTTP round-trip), simpler, and can be composed inside `resolve_battles()` existing transaction. Reserve Edge Functions for operations that need external calls or complex TypeScript logic. |
| Extend existing pg_cron tick for happiness | New pg_cron job for happiness | Happiness depends on population which depends on resources (wine). Running in the same tick as resource production ensures consistency — no window where happiness is stale relative to resources. |
| Supabase Realtime Postgres Changes for order book | Polling order book every N seconds | Polling adds latency and wastes bandwidth. Realtime WebSocket subscription already established for battle reports — reuse the same connection mechanism. |
| `marketplace_orders` table with SQL matching | Third-party matching engine / message queue | Overkill for a small-community game. PostgreSQL `FOR UPDATE SKIP LOCKED` is sufficient for order matching at this scale. Adding RabbitMQ or Redis would triple infrastructure complexity. |

---

## Version Compatibility

| Package | Version | Compatible With | Notes |
|---------|---------|-----------------|-------|
| fl_chart | 1.1.1 | Flutter 3.27.4+ (our env: 3.29 — compatible) | Min Flutter SDK 3.27.4 confirmed in changelog. No conflict with existing packages. |
| fl_chart | 1.1.1 | flame 1.35.1 | No dependency conflict — fl_chart does not depend on any game engine packages. Verify with `flutter pub deps` after adding. |
| fl_chart | 1.1.1 | flutter_riverpod 3.3.1 | No conflict — fl_chart has no state management dependency. |

Run after adding fl_chart:
```bash
flutter pub deps
# Confirm no version conflicts in dependency tree
flutter analyze
# Confirm no breaking changes introduced
```

---

## New Database Objects Summary

| Object | Type | Purpose |
|--------|------|---------|
| `cities.happiness` | column (integer) | Current happiness score |
| `cities.population` | column (integer) | Current citizen count |
| `cities.tax_rate` | column (numeric 0-1) | Gold income multiplier on population |
| `cities.happiness_wine_rate` | column (integer) | Wine units per hour sent to tavern |
| `island_resource_levels` | table | Shared island building levels (wood + luxury) |
| `trade_offers` | table | Pending/active P2P trades |
| `marketplace_orders` | table | Global order book (buy + sell orders) |
| `battles.pillage_result` | column (jsonb) | Resources stolen on victory |
| `upgrade-island-resource` | Edge Function | Charges player, increments shared level |
| `create-trade-offer` | Edge Function | Validates ships, creates trade |
| `accept-trade` | Edge Function | Atomic bilateral resource swap |
| `cancel-trade` | Edge Function | Releases reserved ships |
| `place-market-order` | Edge Function | Validates resources/gold, inserts order |
| `cancel-market-order` | Edge Function | Cancels own open order |
| `match-market-orders` | Edge Function | Runs order matching (or SQL function via RPC) |
| `set-wine-rate` | Edge Function | Configures tavern wine spending |
| `set-tax-rate` | Edge Function | Configures city tax rate |

---

## Sources

- [pub.dev/packages/fl_chart](https://pub.dev/packages/fl_chart) — Version 1.1.1, min Flutter SDK 3.27.4, MIT license — HIGH confidence
- [pub.dev/documentation/fl_chart/latest/fl_chart/BarChartRodStackItem-class.html](https://pub.dev/documentation/fl_chart/latest/fl_chart/BarChartRodStackItem-class.html) — `BarChartRodStackItem(fromY, toY, color)` API confirmed — HIGH confidence
- [pub.dev/packages/fl_chart/changelog](https://pub.dev/packages/fl_chart/changelog) — Min Flutter version upgrade to 3.27.4 in v1.0.0 confirmed — HIGH confidence
- [ikariam.fandom.com/wiki/Happiness](https://ikariam.fandom.com/wiki/Happiness) — Happiness formula: base 196 + tavern + wine - population; growth rate formula — MEDIUM confidence (reference wiki, values adapted for our simplified model)
- [ikariam.fandom.com/wiki/Pillaging](https://ikariam.fandom.com/wiki/Pillaging) — Warehouse protects resources; cargo ships determine loot capacity — MEDIUM confidence
- [ikariam.fandom.com/wiki/Saw_mill](https://ikariam.fandom.com/wiki/Saw_mill) — Island resource buildings are shared upgrades donated by all island inhabitants — HIGH confidence
- [marmelab.com/blog/2025/12/08/supabase-edge-function-transaction-rls.html](https://marmelab.com/blog/2025/12/08/supabase-edge-function-transaction-rls.html) — Transactions and RLS in Supabase Edge Functions; SQL SECURITY DEFINER pattern — HIGH confidence
- [supaexplorer.com/best-practices/supabase-postgres/lock-skip-locked/](https://supaexplorer.com/best-practices/supabase-postgres/lock-skip-locked/) — FOR UPDATE SKIP LOCKED for atomic operations in Supabase — HIGH confidence
- [supabase.com/docs/guides/realtime/realtime-listening-flutter](https://supabase.com/docs/guides/realtime/realtime-listening-flutter) — Supabase Realtime Postgres Changes subscription in Flutter — HIGH confidence

---

*Stack research for: Ikariam clone v1.1 — Economy & Combat Depth (happiness, population, tax, trading, marketplace, pillage, battle reports)*
*Researched: 2026-03-13*
