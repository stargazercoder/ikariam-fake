# Pitfalls Research

**Domain:** Browser-based multiplayer strategy game — v1.1 Economy & Combat Depth additions to existing Supabase/Flutter system
**Stack:** Flutter web + Supabase (Auth/DB/Realtime/Edge Functions/pg_cron) + Riverpod (manual providers)
**Researched:** 2026-03-13
**Confidence:** HIGH (Supabase/PostgreSQL-specific pitfalls verified via official docs and GitHub issues); MEDIUM (game design pitfalls from community sources and original Ikariam mechanics research)

---

## Critical Pitfalls

### Pitfall 1: Happiness/Population Tick Ordering — Wine Consumed Before It Is Available

**What goes wrong:**
The resource production tick runs every 5 minutes and updates `city_resources.amount` for all resource types including wine. A separate happiness tick (or the same tick) reads wine amount to deduct wine consumption and update happiness. If the happiness tick runs in the same cron invocation *before* the resource production portion updates wine, the tick sees last-cycle's wine balance. If it runs *after*, it sees this cycle's wine. The order is undefined unless explicitly controlled. In the worst variant, wine is deducted twice in one tick period (deducted in production tick's cap calculation AND in a separate happiness deduction step) because the two operations use different read timestamps on the same row.

**Why it happens:**
Developers model happiness as a separate concern from resource production and write two independent functions or two loop sections. Both touch `city_resources` wine row but use separate `UPDATE` statements without coordinating. The existing `process_resource_tick()` already iterates city resources; adding happiness logic as a separate pg_cron job running at the same minute causes read-write skew on the wine row.

**How to avoid:**
Extend `process_resource_tick()` to handle happiness and population in a single per-city loop iteration, in this fixed order: (1) produce resources including wine, (2) deduct wine for tavern consumption, (3) calculate new happiness score, (4) calculate population delta, (5) apply population change. This keeps all mutations in one transaction per city. Do not add a separate cron job for happiness — it must be the same job. Add a `city_happiness` table (or columns on cities) that stores `happiness_score`, `population`, `wine_per_tick_rate` so the tick reads and writes from one place.

**Warning signs:**
- Two separate pg_cron jobs touching the same `city_resources` wine row in the same 5-minute window
- `process_resource_tick()` not modified — happiness logic added as a new standalone function scheduled independently
- Negative wine amount appearing in test data (wine deducted but not yet produced)
- Population oscillating rapidly between two values each tick

**Phase to address:**
Happiness/Population phase (Phase 1 of v1.1). Design the extended tick schema before writing any SQL — define all columns needed, then write one unified tick function.

---

### Pitfall 2: Pillage Deducts Resources After Battle Ends — Double Deduct Race on Concurrent Pillage + Ongoing Production Tick

**What goes wrong:**
When `resolve_battles()` sets `status = 'attacker_won'` and proceeds to pillage, it calculates the steal amount by reading `city_resources` at that moment. However, the 5-minute resource production tick may also be running concurrently (pg_cron fires the battle tick every minute, resource tick every 5 minutes — they can overlap). If the resource tick commits an update to the defender's resources *while* the pillage UPDATE is in flight, the pillage reads a pre-tick balance but the resource tick also committed a delta to the same row, resulting in one of the two updates silently winning and the other's delta being lost (last-writer-wins under READ COMMITTED).

**Why it happens:**
`resolve_battles()` uses `SELECT ... FOR UPDATE SKIP LOCKED` on the battles table to prevent concurrent battle processing, but it does not lock the `city_resources` row of the defender before the pillage UPDATE. The resource production tick updates `city_resources` without locking against the battle function. Both functions run as independent transactions with READ COMMITTED isolation (Supabase/Postgres default), so they see each other's committed values but can still race on the write.

**How to avoid:**
Inside the pillage logic of `resolve_battles()`, lock the defender's resource rows before reading them using `SELECT amount FROM city_resources WHERE city_id = v_defender_city_id FOR UPDATE`. This pins the rows until the pillage UPDATE commits. The production tick should use the same `deduct_resource` / atomic update pattern that already exists in the codebase. Cap the pillage amount at a percentage of current balance (e.g., 20-50% of each resource capped by warehouse level) to reduce the impact of any edge-case skew. Non-atomic resource deduction is accepted for v1 (per PROJECT.md), but pillage is a security-sensitive write — it must be atomic.

**Warning signs:**
- Pillage logic reads `city_resources` with a plain `SELECT` before the pillage `UPDATE` (two separate statements, not atomic)
- No `FOR UPDATE` lock on defender resource rows inside `resolve_battles()`
- Test scenario: trigger battle resolution at exactly the same second as a resource tick and observe defender resource balance for inconsistency

**Phase to address:**
Pillage phase. The pillage SQL must be written with the lock pattern from the start; retrofitting is risky because `resolve_battles()` is a long function with multiple failure modes.

---

### Pitfall 3: Marketplace Order Matching — Partial Fill Leaving Orphaned Orders

**What goes wrong:**
A player places a buy order for 500 wood at 2 gold each. A seller places a sell order for 300 wood at 2 gold each. The match function fills 300 wood, removes the sell order, and reduces the buy order to 200 remaining. A concurrent second seller places a sell order for 400 wood at 2 gold. The match function tries to fill the remaining 200 from the buy order but concurrently another function (e.g., a cancellation or expiry job) has already marked the buy order as cancelled. Both functions read the buy order as "open" (READ COMMITTED snapshot before the cancellation committed) and both attempt to fill it — the second seller deducts 200 from their inventory and expects 400 gold, but the order state after concurrent cancellation is inconsistent.

**Why it happens:**
Order matching engines require serializable semantics for correctness but most developers reach for SELECT + UPDATE (non-atomic check-then-modify) because it is simpler to write. Without `SELECT ... FOR UPDATE` on the matched order row, two concurrent transactions can read the same partially-filled order and both conclude it has remaining quantity.

**How to avoid:**
Use `SELECT ... FOR UPDATE` on the specific order row being matched at the start of the match function — before reading its remaining quantity. Use a PostgreSQL `SECURITY DEFINER` function for all order book operations (place-order, cancel-order, match-order). Resource escrow: deduct the buyer's gold (or seller's resource) at order placement time, not at match time. This eliminates the window where both a match and a cancellation attempt to act on the same balance. Cap order quantity to prevent enormous orders that lock rows for long periods.

**Warning signs:**
- Order matching SQL reads `remaining_quantity` in one statement and updates it in a separate statement without a row lock between them
- No escrow: buyer's gold is only deducted when matched, not when order is placed
- `marketplace_orders` table has no `FOR UPDATE` lock in the match function
- Test: place buy and sell orders and fire two concurrent match calls; check for negative `remaining_quantity`

**Phase to address:**
Marketplace phase. Write the match function as a single PostgreSQL stored procedure with row-level locking from day one. Do not write it in TypeScript Edge Function logic with multiple sequential Supabase calls.

---

### Pitfall 4: Shared Island Upgrade — Concurrent City Owners Trigger Multiple Upgrades

**What goes wrong:**
Island resource upgrades (wood_level and luxury_level on the `islands` table) are shared among all cities on the island. Multiple players on the same island all see "Upgrade available" and click simultaneously. The upgrade Edge Function checks `islands.wood_level < max_allowed_level`, sees it as upgradeable, deducts wood from each contributing city, and increments `wood_level`. Because multiple requests pass the level check before any of them commit, the island level is incremented multiple times — exceeding the max level or draining resources from players who did not intend to pay for an already-in-progress upgrade.

**Why it happens:**
The `islands` row is shared state with no per-upgrade lock. The upgrade function reads `wood_level`, checks it, deducts resources, and increments — all as separate SQL statements in a TypeScript Edge Function rather than inside one atomic PostgreSQL transaction. Two concurrent Edge Function invocations pass the check before either increments the level.

**How to avoid:**
Implement island upgrades as a `SECURITY DEFINER` PostgreSQL function. Inside the function, use `SELECT wood_level FROM islands WHERE id = p_island_id FOR UPDATE` to lock the island row for the duration of the upgrade transaction. Validate max-level constraint inside the same transaction after acquiring the lock. Add `CHECK (wood_level BETWEEN 1 AND 10)` constraint on the islands table so any over-increment fails at the DB level. Introduce an `island_upgrade_in_progress` boolean or a separate `island_upgrades` queue table (analogous to the existing `construction_queue`) to gate concurrent upgrade attempts.

**Warning signs:**
- Island upgrade logic split across multiple Edge Function `.from().update()` calls without a wrapping DB function
- No `FOR UPDATE` lock on the `islands` row in the upgrade path
- Two players on the same island can both click "Upgrade" within milliseconds — test this scenario before release
- No `CHECK` constraint preventing `wood_level` exceeding its maximum

**Phase to address:**
Island Upgrades phase. The shared-row pattern is the core architectural challenge here — get the locking right before adding UI.

---

### Pitfall 5: Wine Escrow — Tavern Consumes From Global Wine Pool, Not Per-City Escrow

**What goes wrong:**
Wine is produced on islands (shared resource). Cities on the same island all draw from the island wine pool (or each city's personal wine storage). If the happiness tick deducts wine from the city's warehouse without checking whether the city's trading port has committed wine to outbound trade, the same wine units can be both "consumed by the tavern" and "in transit as a trade cargo" simultaneously — the city goes into negative wine, happiness drops unexpectedly, and the incoming trade shipment then pushes resources above warehouse capacity (wasted production).

**Why it happens:**
Resource trading and happiness consumption are implemented in different phases without coordinating on a shared "reserved" concept. The city's wine `amount` in `city_resources` represents all wine — the tick deducts from it regardless of whether some of it is already escrowed for an outbound trade.

**How to avoid:**
Escrow trade resources at dispatch time, not at arrival time. When a trade cargo ship departs, deduct the traded wine from `city_resources.amount` immediately (reducing the visible balance). The tavern tick then only consumes from the remaining available balance. This is consistent with how other strategy games handle resource-in-transit (Ikariam itself deducts resources on departure). Add a `UNIQUE` constraint check: `city_resources.amount >= 0` (already present in v0.1.0 schema via `CHECK (amount >= 0)`) — enforce that the escrow deduction itself cannot push amount negative.

**Warning signs:**
- Trade dispatch function creates the `unit_movements`-style cargo row but does NOT deduct resources from `city_resources` at departure
- Wine in transit still appears in the city's resource display
- Tavern consumes wine in the tick and the cargo also delivers wine — city ends up with more wine than warehouse capacity

**Phase to address:**
Trading/Cargo phase (before happiness phase if possible, or coordinated in the same phase). Clarify the resource-in-transit model in the schema design step.

---

### Pitfall 6: Battle Report Visualization — Realtime Subscription on `battle_turns` Floods Client During Multi-Turn Battles

**What goes wrong:**
The existing `battle_turns` table is in the `supabase_realtime` publication. The `BattleDetailScreen` subscribes via `battleTurnsProvider(battleId)` which streams all turns for a battle. During a long battle (10+ turns), each new turn INSERT triggers a Realtime event that re-emits the entire list from the StreamProvider (or appends an item). If the battle report widget rebuilds on every new turn and each rebuild re-renders all previous turn cards, the Flutter frame budget (16ms) is easily blown on a long battle with complex card layouts. A 20-turn battle re-renders 20 cards on every new turn arrival.

**Why it happens:**
The `StreamProvider` for turns appends to a growing list each time a Realtime INSERT arrives. The `ListView` or `Column` in `BattleDetailScreen` re-renders all children on state change because there is no key-based diffing or `ListView.builder` with item caching. The current implementation uses a `Column` with `.map()` to build turn cards — every state update rebuilds all cards.

**How to avoid:**
Switch the turns list widget from `Column(children: reversed.map(...).toList())` to `ListView.builder` with `itemCount` and `itemBuilder` — Flutter only builds visible items. Assign a `ValueKey(turn.id)` to each `BattleTurnCard` widget so Flutter's diffing algorithm can skip unchanged cards. The `battleTurnsProvider` stream should append new turns rather than replacing the whole list (check whether the repository uses `.stream()` which re-emits full snapshots or `.on('INSERT')` which emits only new rows). For visualization, consider rendering unit casualty counts as simple `Row`/`Text` widgets rather than a charting library — charting libraries add ~1-2MB to WASM bundle and excessive repaint cost for what is essentially a table of numbers.

**Warning signs:**
- `BattleDetailScreen` uses `Column(children: turns.map(...))` instead of `ListView.builder`
- Turn cards have no `key:` argument
- `battleTurnsProvider` receives full list snapshots on each new turn (Supabase `.stream()` re-emits all rows for a filter match on INSERT)
- Frame render time exceeds 16ms when viewing a battle with 5+ turns (measure in Flutter DevTools)

**Phase to address:**
Battle Report Visualization phase. Switch to `ListView.builder` at the point the visualization is built — do not add it as a post-ship optimization.

---

### Pitfall 7: Population as an Integer — Growth Accumulation Lost Between Ticks

**What goes wrong:**
Population growth rate is `happiness_score / 34.65` citizens per hour (Ikariam formula). At a 5-minute tick interval, the per-tick delta is approximately `happiness_score / 34.65 / 12`. For a small city with happiness = 50, that is `50 / 34.65 / 12 ≈ 0.12` citizens per tick. If population is stored as `INTEGER` and the tick does `population = population + 0.12`, PostgreSQL floor-truncates to 0. The city's population never grows even though it should gain ~1.44 citizens per hour.

**Why it happens:**
Population feels like a whole-number concept and developers use `INTEGER` column type. The per-tick fractional accumulation is discarded silently. This is exactly the same trap that affects any "slow accumulation" mechanic — the existing `city_resources.amount` correctly uses `NUMERIC` to avoid this, but population is a new column and developers may reach for `INTEGER` reflexively.

**How to avoid:**
Store population as `NUMERIC` (not `INTEGER`) in the database. The display layer in Flutter can `floor()` the value for display purposes. Alternatively, store `population` as `INTEGER` and `population_growth_accum NUMERIC` — the tick adds to the accumulation, and when it crosses 1.0 it increments the integer and resets the fractional part. This is the more common "fixed-point growth" pattern in browser strategy games and avoids displaying fractional citizens to the user while still accumulating correctly.

**Warning signs:**
- `population` column defined as `INTEGER` in the migration
- Tick formula uses `FLOOR()` or integer arithmetic on a fractional growth rate
- Test: set happiness = 50, run 50 ticks, check if population has increased by at least 6 citizens (expected ~6 over 50 ticks × 0.12/tick)

**Phase to address:**
Happiness/Population schema design — column type decision must be made in the migration, not fixed later (changing `INTEGER` to `NUMERIC` requires a migration with a `ALTER COLUMN ... TYPE` that can lock the table).

---

### Pitfall 8: Marketplace Orders Not Expired / Cleaned Up — Order Book Grows Without Bound

**What goes wrong:**
Players place buy/sell orders and forget about them. Orders that are never matched accumulate indefinitely. After a few weeks of play with a small community, the `marketplace_orders` table has hundreds of stale orders. Every call to the match function must scan all open orders to find matches — query time grows linearly with the number of open orders. Players also see a flooded order book UI showing 3-gold wood offers from players who quit 2 weeks ago.

**Why it happens:**
Order expiry is not part of the "minimum viable" order book feature and gets deferred. There is no pg_cron job to expire old orders and no UI to show order age.

**How to avoid:**
Add `expires_at TIMESTAMPTZ NOT NULL` to `marketplace_orders` at schema creation time (default 48 hours from placement). Add a partial index: `CREATE INDEX marketplace_orders_open ON marketplace_orders (resource_type, price) WHERE status = 'open' AND expires_at > NOW()`. The match function's WHERE clause filters on `status = 'open' AND expires_at > NOW()` — expired orders are invisible to matching without needing cleanup. Add a pg_cron job (weekly is fine for a small community) that sets `status = 'expired'` on orders past their expiry and refunds escrowed resources.

**Warning signs:**
- `marketplace_orders` table has no `expires_at` column
- The match function's WHERE clause only filters on `status = 'open'` without expiry check
- No pg_cron job for order expiry and refund
- Order book UI shows orders with no "placed X hours ago" timestamp

**Phase to address:**
Marketplace/Order Book phase. The `expires_at` column and expiry index must be in the initial marketplace migration.

---

### Pitfall 9: Trade Cargo Ship — No Interception Mechanic But Attacks Are Possible During Transit

**What goes wrong:**
v1.1 adds player-to-player resource trading via cargo ships. Cargo ships travel using the same `unit_movements` table and `process_arrivals()` function as military units. An attacker can dispatch military units to arrive at the defender's city at approximately the same time as a cargo ship arrives. The arrival processor triggers both: cargo resources are added to the city, then the battle begins with the city's post-delivery resource balance. The cargo delivery and battle arrival processing are sequential in one tick, but if cargo arrives at `T` and the attacker arrives at `T+1 minute`, the defender benefits from the resources before the battle. This may be intentional, but needs explicit design decision. Worse: there is no interception mechanic (attack cargo in transit), and if the feature is not defined, players will ask for it and the schema has no way to express "intercepted cargo movement."

**Why it happens:**
Trading and military movement share the `unit_movements` table (`movement_type` discriminator already exists as `'attack'` / `'return'`). A new `'trade'` movement type is added but no thought is given to whether military movement can target a trade movement.

**How to avoid:**
Explicitly decide: "cargo interception is out of scope for v1.1." Document this in code comments on the trade dispatch Edge Function and in the cargo movement handler. Add `'trade'` and optionally `'trade_return'` to the `movement_type` CHECK constraint. In `process_arrivals()`, branch on movement type — trade arrivals add resources to the destination city, military arrivals start a battle. Ensure these branches are mutually exclusive and do not attempt to battle a cargo movement. Deferred: interception can be added in v1.2 by adding an `intercepted_by` foreign key to `unit_movements`.

**Warning signs:**
- `movement_type` CHECK constraint not updated to include `'trade'`
- `process_arrivals()` treats all arrivals the same (tries to start a battle for a cargo movement)
- No code comment explicitly deferring interception mechanic
- Two cargo ships dispatched simultaneously to the same city — test whether both resources are credited correctly

**Phase to address:**
Trading/Cargo phase. Update `process_arrivals()` and `movement_type` constraint before writing the trade Edge Function.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Separate pg_cron job for happiness (instead of extending existing tick) | Easier to develop in isolation | Wine consumed twice in same tick window; ordering bugs; harder to reason about state | Never — extend the existing tick function |
| Store population as `INTEGER` | Simpler schema, intuitive | Fractional growth silently truncated to 0; small cities never grow | Never — use `NUMERIC` with display-layer flooring |
| Marketplace match logic in TypeScript Edge Function (multiple `.from().select().update()` calls) | Familiar syntax, easy to prototype | No atomicity between read and update; partial fills leave inconsistent state under concurrent load | Never for order matching — must be a single PostgreSQL stored procedure |
| Pillage: read defender resources in separate SELECT then UPDATE | Simple to write | Race with resource production tick; potential double-deduct | Never — use `SELECT ... FOR UPDATE` within the battle resolution function |
| Trade resources escrowed on arrival (not departure) | No upfront deduction | Wine shows as available for tavern consumption even though it is in transit; city can over-commit | Never — escrow at dispatch time |
| Order book with no `expires_at` | Simpler schema initially | Table grows unbounded; query times increase; stale orders pollute the UI | Never — `expires_at` belongs in the initial migration |
| Battle turns rendered in `Column.map()` instead of `ListView.builder` | One less refactor | Full list rebuild on every new Realtime event; frame drops on long battles | OK for 1-5 turns (MVP test); unacceptable for production with 10+ turn battles |
| Island upgrade as sequential Edge Function calls (no DB-level lock) | Faster to write | Concurrent upgrades from multiple island neighbors bypass level cap | Never — use a PostgreSQL function with `FOR UPDATE` on the island row |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Supabase Realtime + `battle_turns` | `.stream()` re-emits the full list on each INSERT — grows quadratically with turn count | Use `.on('INSERT', ...)` to append only new rows; or switch to polling after battle ends |
| Supabase pg_cron + happiness tick | Scheduling a separate happiness cron job at the same minute as resource tick causes concurrent writes to wine row | Use a single pg_cron job; order sub-steps within one function |
| Supabase Edge Function + island upgrade | Multiple `.from('islands').update()` calls from different players' requests race on the same row | Wrap in a `SECURITY DEFINER` PostgreSQL function with `SELECT ... FOR UPDATE` |
| Supabase Edge Function + marketplace match | Writing match logic as sequential `.select()` + `.update()` in TypeScript | Write the entire match as one `CALL match_order(...)` to a stored procedure |
| Flutter Realtime + `marketplace_orders` table | Subscribing to all open orders for a resource type sends updates for every other player's orders too | Subscribe only to own orders (`eq('owner_id', userId)`) for own-order status; use a separate RPC for the public order book display |
| Flutter Riverpod + population/happiness display | `StreamProvider` for `city_happiness` triggers full widget rebuild on each tick update | Use `select:` parameter or a derived provider to expose only the fields the widget needs, preventing unnecessary rebuilds of unrelated widgets |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| `process_resource_tick()` extended with happiness loop — now iterates all cities twice (once for resources, once for happiness) | Tick duration doubles; may exceed pg_cron timeout | Keep single loop: produce resources AND compute happiness in same per-city iteration | ~100 cities (each with 2 passes instead of 1) |
| Marketplace match function scans all open orders without index | Order matching slows as order book grows; players notice delayed fill confirmation | Partial index on `(resource_type, price) WHERE status = 'open' AND expires_at > NOW()` | ~500 open orders |
| Battle turns `Column.map()` rebuilds all cards on each new Realtime event | Flutter frame drops from 60fps to 20fps on 10+ turn battle | `ListView.builder` with `ValueKey` per turn card | 8+ turns visible simultaneously |
| Population tick adds ~0.1 citizens per tick using `NUMERIC` — triggers Realtime `UPDATE` on `cities` table every 5 minutes for every city | Supabase Realtime broadcasts city row updates to all subscribers every tick; unnecessary UI re-renders | Do not put population on the `cities` table if it is realtime-published; use a separate `city_population` table not in the realtime publication, or batch population updates hourly | 50+ concurrent players watching city screen |
| Trade order book UI subscribes to full `marketplace_orders` for a resource type | Every order placed or matched by any player triggers a UI re-render for all players viewing the same resource | Use a server-rendered RPC to fetch the order book snapshot; only subscribe to own orders via Realtime | 10+ concurrent players trading same resource |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Pillage amount computed client-side and sent in Edge Function body | Attacker sets steal amount to 999999 regardless of actual resources | Pillage calculation must be entirely inside `resolve_battles()` PostgreSQL function — client never sends a steal amount |
| Marketplace order placed without resource escrow validation | Player places sell order for 1000 wood but only has 500; creates order that can never fill but occupies order book | Deduct escrowed resources atomically in the same DB transaction that creates the order row |
| Island upgrade Edge Function trusts client-supplied `contribution_amount` | Player sends 0 contribution but claims upgrade credit | Server calculates required contribution from the upgrade formula; client sends only `{ island_id, upgrade_type }` |
| `marketplace_orders` table has `SELECT authenticated` policy with no filter | Any player can read all orders including cancellation history revealing another player's trade strategy | Fine for the public order book view; but if orders contain private notes or the buyer's identity should be hidden, restrict SELECT to `owner_id = auth.uid()` for private fields |
| Happiness configuration (wine spending rate) accepted from client without server-side bounds check | Player sets wine rate to 0.0001 (near-zero) to bypass wine consumption while keeping happiness benefit | Clamp wine spending rate server-side: minimum = tavern_level * base_consumption; maximum = current_wine_stock |
| Trade cargo ship arrival adds resources without RLS-aware check | Cargo arrives at a city not owned by the recipient player (city transferred or wrong ID) | In `process_arrivals()` for trade movements, verify `destination_city_id` owner matches the trade order recipient before crediting resources |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Happiness score displayed as a raw number (e.g., "247") with no context | Player does not know if 247 is good or bad; cannot make decisions | Show happiness as "247 / 310 population" or a color-coded sentiment label ("Happy", "Neutral", "Unhappy") with a tooltip explaining the formula |
| Production rate displayed per-tick (every 5 min) instead of per-hour | "You produce 3.2 wood" is meaningless; Ikariam displays per-hour rates | Multiply tick production by 12 for the displayed hourly rate: `workers * level * 12` |
| Marketplace order book shows all orders in creation order (not price order) | Players cannot find best-price offers without scrolling through old orders | Sort sell orders ascending by price, buy orders descending by price — standard order book display |
| Battle report shows raw casualty numbers but no "who won this turn" summary | Players spend time adding up numbers to figure out which side is winning | Add a per-turn outcome badge (green "Defender advantage" / red "Attacker advantage") derived from `land_outcome` and `naval_outcome` fields already stored in `battle_turns` |
| Island upgrade UI shows upgrade cost without showing who else on the island has already contributed | Players over-contribute; later contributors see the upgrade succeed without knowing their resources were wasted | Show total required vs. total contributed by all island cities; make contribution a partial-payment model like original Ikariam |
| Wine rate slider in Tavern configuration snaps to preset levels (0, 25%, 50%, 75%, 100%) but the server stores an arbitrary rate | The Flutter UI creates a false impression of finer control; rate mismatches cause confusion | Store wine rate as one of {0, 0.25, 0.5, 0.75, 1.0} in DB to match the UI options; validate server-side that submitted rate is one of the allowed values |

---

## "Looks Done But Isn't" Checklist

- [ ] **Happiness system:** Tavern building exists and tavern level is stored — verify wine is *actually deducted* from `city_resources` each tick and that deduction runs *after* wine production (not before) in the same tick iteration.
- [ ] **Population growth:** Population value increments visibly over time in test — verify it still increments for a city with happiness = 50 (fractional growth); it likely does not if column is `INTEGER`.
- [ ] **Tax income (gold):** Gold is produced each tick based on `population * tax_rate` — verify this does NOT double-count the Town Hall production that already exists in v0.1.0 (Town Hall already generates gold via `process_resource_tick()`; adding a population-tax gold source on top creates two gold production streams for the same city).
- [ ] **Island upgrades:** Upgrade button works for one player — verify that a second player on the same island clicking within 500ms does NOT trigger a second upgrade (concurrent lock test).
- [ ] **Marketplace order placement:** Order appears in the order book — verify the seller's resources were *immediately deducted* from `city_resources` at placement (not at match time); check `city_resources` in Supabase dashboard immediately after placing a sell order.
- [ ] **Trade cargo dispatch:** Cargo ship departs and resources appear to be in transit — verify sender's resource balance *decreased immediately* on dispatch (escrow), not after arrival.
- [ ] **Pillage on battle win:** Battle report shows "resources stolen" — verify (a) the defender's `city_resources` decreased by the stolen amount server-side, (b) the attacker's resources increased by the stolen amount after the return travel, and (c) the steal happened in `resolve_battles()` not in a client-triggered Edge Function.
- [ ] **Battle turn visualization:** Turn-by-turn cards render for a 3-turn battle — verify they also render without layout overflow or performance degradation for a 15-turn battle (simulate by seeding 15 battle_turns rows in dev).

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Wine double-deducted (separate happiness cron + resource tick both touch wine) | MEDIUM | Disable the separate happiness cron job immediately; audit `city_resources` wine balances; add a one-time correction script adding back the over-deducted amounts; merge happiness logic into the resource tick function |
| Pillage race condition found in production (defender's resources went negative) | HIGH | Run integrity check: `SELECT * FROM city_resources WHERE amount < 0` (should be impossible with CHECK constraint — if found, constraint was never added); restore from backup for affected rows; add `FOR UPDATE` lock in `resolve_battles()` |
| Marketplace partial-fill inconsistency (buyer's gold deducted but seller's resources not credited) | HIGH | Freeze marketplace (disable place-order and match endpoints); audit order book for orders with `status = 'matched'` but no corresponding resource transfer log; implement compensating transactions or restore from backup; rewrite match function as atomic stored procedure |
| Island over-upgraded (level exceeds max due to concurrent requests) | LOW | Run: `UPDATE islands SET wood_level = 10 WHERE wood_level > 10`; add CHECK constraint; add FOR UPDATE lock in upgrade function |
| Population never grows (INTEGER truncation) | MEDIUM | Migrate column: `ALTER TABLE city_population ALTER COLUMN population TYPE NUMERIC`; no data loss, but requires downtime window; alternatively keep INTEGER and add `population_growth_accum NUMERIC` column |
| Battle report UI freezing on long battles | LOW | Switch `Column.map()` to `ListView.builder` in `BattleDetailScreen`; no schema changes needed; hot-reload compatible |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Happiness/wine tick ordering | Phase: Happiness/Population (first v1.1 phase) | Run 10 ticks with wine at borderline capacity; verify wine not double-deducted |
| Pillage race with production tick | Phase: Pillage mechanic | Integration test: trigger resolve_battles() and process_resource_tick() simultaneously; check defender resources |
| Marketplace partial fill orphans | Phase: Marketplace order book | Concurrent test: two sell orders arrive at same time for one buy order; verify only one fills |
| Island upgrade concurrent over-upgrade | Phase: Island Upgrades | Two simultaneous upgrade requests from different players; verify level incremented exactly once |
| Wine escrow (trade vs. tavern consumption) | Phase: Trading/Cargo ships | Dispatch cargo, immediately check city_resources; wine must be deducted at departure |
| Battle turns Realtime flood | Phase: Battle Report Visualization | Profile Realtime events during a 10-turn battle; verify rebuild count per turn arrival |
| Population INTEGER truncation | Phase: Happiness/Population schema | Seed test: happiness = 50, run 100 ticks, assert population > 0 |
| Marketplace order expiry | Phase: Marketplace order book | Check marketplace_orders migration for expires_at column and expiry index |
| Trade cargo collision with military arrival | Phase: Trading/Cargo ships | Verify process_arrivals() branches on movement_type; cargo arrival does not trigger battle |
| Gold double-production (Town Hall + tax) | Phase: Population tax | Check process_resource_tick() after tax income is added; gold production should be one source only |

---

## Sources

- [Ikariam Happiness Wiki (Fandom)](https://ikariam.fandom.com/wiki/Happiness) — population formula, wine consumption rate, happiness decay
- [Ikariam Tavern Wiki (Fandom)](https://ikariam.fandom.com/wiki/Building:Tavern) — wine-per-level bonus, happiness per load
- [Ikariam Forum: Happiness calculation in Tavern slider](https://forum.ikariam.gameforge.com/forum/thread/96997-fixed-happiness-calculation-in-tavern-slider-does-not-account-for-corruption/) — edge case: happiness preview not matching server reality
- [PostgreSQL Explicit Locking Documentation](https://www.postgresql.org/docs/current/explicit-locking.html) — `SELECT ... FOR UPDATE`, `SKIP LOCKED` semantics
- [The Unreasonable Effectiveness of SKIP LOCKED in PostgreSQL (Inferable.ai)](https://www.inferable.ai/blog/posts/postgres-skip-locked) — SKIP LOCKED gives inconsistent view; not suitable for order book matching
- [PostgreSQL Row-Level Locks Guide (ScalableArchitect)](https://scalablearchitect.com/postgresql-row-level-locks-a-complete-guide-to-for-update-for-share-skip-locked-and-nowait/) — join locking pitfalls, same-row contention under concurrency
- [Order Matching Engine in PostgreSQL Stored Procedures (GitHub: anders94)](https://github.com/anders94/order-matching-engine) — reference for atomic order matching patterns
- [Order Matching Engine: Everything You Need to Know (DEV Community)](https://dev.to/devexperts/order-matching-engine-everything-you-need-to-know-638) — partial fill mechanics, price/time priority
- [Supabase Realtime Client-Side Memory Leak (drdroid.io)](https://drdroid.io/stack-diagnosis/supabase-realtime-client-side-memory-leak) — subscription lifecycle management
- [Supabase Realtime Channel Already Subscribed (drdroid.io)](https://drdroid.io/stack-diagnosis/supabase-realtime-channel-already-subscribed) — duplicate subscription pitfall
- [Flutter ListView Optimization with Riverpod (Medium)](https://saqlainalishah.medium.com/flutter-listview-optimization-with-riverpod-avoiding-unnecessary-rebuilds-3bdf49a86ad3) — key-based diffing, scoped providers for list items
- [Preventing Race Conditions with SERIALIZABLE Isolation in Supabase (GitHub Discussion #30334)](https://github.com/orgs/supabase/discussions/30334) — serializable isolation trade-offs for concurrent updates
- [Grand Strategy Games: Simulating population growth (Roblox Dev Forum)](https://devforum.roblox.com/t/grand-strategy-games-simulating-population-growth-workforce-etc/4041693) — fractional growth accumulation pattern for integer population display
- [Web Race Conditions: PortSwigger Research](https://portswigger.net/research/smashing-the-state-machine) — concurrent request exploitation patterns applicable to order book and pillage

---
*Pitfalls research for: Ikariam-style browser strategy game — v1.1 Economy & Combat Depth (adding happiness, marketplace, pillage, battle visualization to existing Supabase system)*
*Stack: Flutter web + Supabase + pg_cron + Riverpod (manual providers)*
*Researched: 2026-03-13*
