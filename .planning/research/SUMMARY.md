# Project Research Summary

**Project:** Ikariam Clone — v1.1 Economy & Combat Depth
**Domain:** Browser-based multiplayer strategy game (Flutter Web + Supabase)
**Researched:** 2026-03-13
**Confidence:** HIGH

## Executive Summary

v1.1 adds eight tightly interconnected economy and combat features to a validated Flutter + Supabase architecture. The existing codebase already provides the structural backbone — server-authority model, Supabase Realtime, pg_cron resource ticks, Edge Functions with atomic SQL patterns — and every new feature is an extension of these established patterns, not a new paradigm. The only new Dart dependency is `fl_chart 1.1.1` for battle report visualization; all other features are implementable with the existing stack. The research confirms this milestone is achievable with high confidence: the patterns are proven, the data already exists, and the eight features decompose cleanly into schema migrations, backend extensions, and Flutter UI work.

The recommended build approach is a strict three-wave sequence: schema migrations first (unblock parallel backend work), then SQL function modifications and Edge Functions, then Flutter UI. This order is non-negotiable because several SQL functions (`process_resource_tick`, `resolve_battles`, `process_arrivals`) are shared infrastructure that multiple feature clusters depend on. Building UI before backend functions are extended is the most common source of integration rework. The happiness/population system must be built first — it is a dependency of the tax system and is the highest-risk item for subtle tick-ordering bugs.

The primary risks are concurrency-related, not architectural. Five of the nine critical pitfalls share the same root cause: treating shared PostgreSQL rows (city resources, island levels, marketplace orders) without proper row-level locking. Every one has a clear prevention: use `SELECT ... FOR UPDATE` inside `SECURITY DEFINER` PostgreSQL functions rather than sequential TypeScript calls from Edge Functions. A secondary risk is the `cities` table Realtime fan-out — enabling Realtime on `cities` (required for happiness/population push) will broadcast a city row UPDATE every 5 minutes to every subscriber. The mitigation is well-defined in the research and must be addressed at design time, not as a post-ship optimization.

---

## Key Findings

### Recommended Stack

The existing stack (Flutter 3.29, Supabase 2.12.0, Riverpod 3.3.1, Flame 1.35.1, go_router 17.1.0) handles all eight new features without changes. One new package is justified: `fl_chart 1.1.1` (MIT, 6,200+ GitHub stars, min Flutter SDK 3.27.4) for stacked bar charts in battle reports. Its `BarChartRodStackItem` API maps directly onto the per-turn, per-unit-type casualty data already stored in `battle_turns`.

See full details: `.planning/research/STACK.md`

**Core technologies for v1.1:**
- `fl_chart 1.1.1` — battle report turn-by-turn unit loss visualization; only Flutter chart library with native stacked bar support at MIT license
- `PostgreSQL SECURITY DEFINER functions` — atomic order matching, pillage calculation, island upgrades; prevents race conditions that TypeScript Edge Function chains cannot guarantee
- `Supabase Realtime Postgres Changes` — live marketplace order book and resource shipment tracking; reuses established WebSocket connection, no new infrastructure
- `pg_cron (extended existing jobs)` — happiness + population + tax gold added into `process_resource_tick()`; new `deliver-resources` job for cargo shipments
- `flutter_riverpod (manual providers)` — new `StreamProvider` for marketplace orders and resource shipments; new derived `Provider` for hourly production rates; no code generation (riverpod_generator blocked by Dart analyzer conflict per PROJECT.md)

**Critical constraint:** Do NOT introduce `riverpod_generator` or `freezed` for v1.1 models. The Dart 3.10.1 analyzer conflict is still active per PROJECT.md. All new models follow the existing handwritten `fromJson`/`==`/`hashCode` pattern.

### Expected Features

All features in scope are P1 for v1.1 launch. All are table stakes or clear differentiators with no viable deferral.

See full details: `.planning/research/FEATURES.md`

**Must have (table stakes) — users expect these in any Ikariam-like game:**
- Happiness system (tavern + wine consumption) — without it, the Tavern building serves no purpose
- Population growth driven by happiness — closes the core city progression loop
- Population-based tax income — gold must scale with city growth; static gold feels broken
- Configurable wine spending rate slider — genre-standard; players can't manage wine scarcity without it
- Island resource building upgrades — shared island cooperation mechanic; its absence removes the social dynamic
- Resource production rate visible in UI (+X/hr) — players cannot plan without hourly rates
- Pillage resources on battle victory — winning a battle needs tangible economic reward
- Battle report showing unit losses per turn — flat win/loss summary is inadequate post-combat UX

**Should have (differentiators above the original Ikariam):**
- Marketplace order book (global async buy/sell orders) — original Ikariam's radius-limited search is a known weakness; a global order book creates a real economy
- Direct player-to-player resource transfer — faster than marketplace for allied trades; prerequisite for the marketplace cargo ship mechanic
- Color-coded turn-by-turn battle chart (fl_chart) — materially above original Ikariam's text-based reports

**Defer to v1.2+:**
- Corruption mechanic (gold penalty at high city count) — only relevant with 3+ cities
- Auto wine-send standing orders — quality-of-life after wine management is validated
- Museum building for happiness — high complexity, low immediate value
- Population decay from extreme unhappiness — only if players request punishing mechanics

**Anti-features to explicitly reject:**
- Negative happiness causing population loss — death spiral for new players
- Gold-for-gold marketplace trades — original Ikariam prohibits this; enables exploit vectors
- Per-city island resource ownership — removes the island cooperation social dynamic
- Instant pillage without cargo ship travel — breaks balance; travel delay is intentional counterplay
- Real-time happiness ticker (WebSocket every second) — battery drain; happiness changes once per 5-min tick

### Architecture Approach

v1.1 extends the v0.1.0 server-authority architecture through targeted additions: two new tables (`resource_shipments`, `marketplace_orders`), four new columns on `cities`, one new nullable column on `unit_movements` (cargo jsonb), eight new Edge Functions, one new pg_cron job (`deliver-resources`), and modifications to three existing SQL functions. The Flutter client gains two new feature modules (`features/trade/`, `features/marketplace/`), one new screen (`TavernScreen`), and one new provider (`resource_rates_provider`). The core architectural contract is unchanged: all game-state mutations happen server-side; the client is a read-only consumer of Supabase Realtime and PostgREST.

See full details: `.planning/research/ARCHITECTURE.md`

**Major components added:**
1. **Economy tick extension** (`process_resource_tick`) — happiness/wine consumption, population growth, tax gold, island level multiplier bundled into the single existing 5-minute pg_cron job to prevent ordering ambiguity
2. **Escrow-on-dispatch pattern** — resource shipments and marketplace orders deduct resources at creation time, not delivery; prevents double-spend from concurrent operations
3. **Resource shipments subsystem** — `resource_shipments` table + `deliver-resources` pg_cron job handles both P2P trades and marketplace fulfillment via the same cargo ship delivery mechanism
4. **Marketplace order book** — `marketplace_orders` table with Realtime; order matching via PostgreSQL stored procedure with `FOR UPDATE` row locks; escrow deducted at order placement
5. **Pillage integration** — extends `resolve_battles()` attacker_won branch; loot travels home via `unit_movements.cargo` jsonb; delivered by `process_arrivals()` extended with a cargo delivery branch
6. **Battle report visualization** — pure Flutter; `UnitCasualtyBar` widget + `unit_visual_constants.dart` constants; no backend changes needed (all turn data already in `battle_turns`)

**Key patterns to follow:**
- Columnar extension over new tables: happiness/population/tax/wine-rate are columns on `cities`, not separate tables — one Realtime event covers all city economy changes
- Bundled SQL function extension: new tick behaviors co-located with related existing behaviors to avoid ordering ambiguity
- Client-side rate derivation: hourly production rate is NOT stored in DB; derived in `resourceRatesProvider` from existing streams; the Dart formula must stay in sync with the SQL tick formula

### Critical Pitfalls

See full details: `.planning/research/PITFALLS.md`

1. **Happiness/wine tick ordering** — Separate pg_cron job for happiness races with the resource tick on the same wine row (double deduction). Prevention: extend `process_resource_tick()` with happiness sub-steps in fixed order: produce → deduct wine → compute happiness → grow population. Never add a separate cron job for happiness.

2. **Pillage race with production tick** — `resolve_battles()` and `process_resource_tick()` can run concurrently; without row-level locking the pillage reads a stale defender balance. Prevention: `SELECT ... FOR UPDATE` on defender resource rows inside `resolve_battles()` before the pillage UPDATE.

3. **Marketplace partial fill orphans** — Concurrent match + cancel on the same partially-filled order leaves inconsistent state. Prevention: entire order matching logic must be a single PostgreSQL stored procedure with `SELECT ... FOR UPDATE` on matched rows; never write match logic as sequential TypeScript calls.

4. **Island upgrade concurrent over-increment** — Two players on the same island clicking "Upgrade" within milliseconds both pass the level-cap check before either commits. Prevention: `SELECT ... FOR UPDATE` on the `islands` row inside a `SECURITY DEFINER` function; `CHECK (wood_level BETWEEN 1 AND 10)` constraint as DB-level backstop.

5. **Population as INTEGER — fractional growth silently truncated** — At 5-minute tick intervals, population delta is fractional (~0.12 citizens/tick at happiness=50). `INTEGER` means `FLOOR(0.12) = 0` every tick; the city never grows. Prevention: store as `NUMERIC` or use a `population_growth_accum NUMERIC` accumulator column. Must be decided at schema creation — changing column type later requires a locking migration.

6. **Marketplace orders without expiry** — Stale orders accumulate indefinitely; query times grow linearly; order book fills with offers from inactive players. Prevention: `expires_at TIMESTAMPTZ NOT NULL` in the initial migration; partial index filtering on `status = 'open' AND expires_at > NOW()`; weekly pg_cron expiry job returning escrowed resources.

7. **Gold double-production (Town Hall + tax)** — Town Hall already generates gold in `process_resource_tick()`. Adding population-tax gold without auditing the existing formula creates two simultaneous gold income streams. Prevention: audit `process_resource_tick()` before Phase 1 implementation; decide which formula replaces or supplements which.

8. **Realtime fan-out on `cities` updates** — Enabling Realtime on `cities` means every pg_cron tick broadcasts a city UPDATE to all subscribers (every 5 minutes). At 50+ concurrent players this creates unnecessary widget rebuilds. Prevention: use Riverpod `select:` to expose only the fields a specific widget needs; consider population updates on an hourly rather than 5-minute cadence.

9. **Trade cargo not branched in `process_arrivals()`** — Adding a `'trade'` movement type without branching `process_arrivals()` causes cargo movements to attempt to start battles. Prevention: update `movement_type` CHECK constraint and add an explicit branch in `process_arrivals()` for trade arrivals before writing the trade Edge Function.

---

## Implications for Roadmap

Based on the feature dependencies, architecture build order, and pitfall-to-phase mapping from research, a five-phase structure is recommended.

### Phase 1: Economy Foundation — Happiness, Population, Tax

**Rationale:** Happiness is the root dependency for population, which is the root dependency for tax. All three share the `cities` table schema and the `process_resource_tick()` extension. Building these together in one phase means one schema migration, one SQL function replacement, and two Edge Functions (`configure-tavern`, `set-tax-rate`). The `cities` Realtime publication is also enabled here, which is a prerequisite for Phase 3 (trading notifications) and Phase 4 (marketplace). This is the highest-risk phase — the tick ordering pitfall and population INTEGER truncation pitfall both live here and must be solved at schema design time.

**Delivers:** Working happiness/population/tax loop. Tavern building becomes functional. Gold scales with city size. Configurable wine spending rate UI in new `TavernScreen`. Tax rate slider with estimated gold-per-hour display.

**Addresses (from FEATURES.md):** Happiness system, population growth, tax income, configurable wine spending rate — all table stakes.

**Avoids (from PITFALLS.md):** Pitfall 1 (tick ordering — happiness integrated into existing tick), Pitfall 5 (population INTEGER truncation — use NUMERIC from schema creation), Pitfall 7 (gold double-production — audit Town Hall formula before adding tax).

**Research flag:** Standard patterns (pg_cron extension, columnar schema). Skip `/gsd:research-phase`.

---

### Phase 2: Island Upgrades + Resource Rate UI

**Rationale:** Island resource upgrade modifies `process_resource_tick()` to apply the island level multiplier. The resource rate UI (`+X/hr` display) reads from the island level via `resourceRatesProvider`. Both depend on the Phase 1 tick extension being deployed first — the island multiplier formula must be live in the SQL before the client derives rates from it. These two features share no dependencies with the trading or marketplace systems, making this a clean standalone phase with well-bounded scope.

**Delivers:** Island sawmill/luxury building upgrades (shared, all island cities benefit). Hourly production rates visible in resource bar and building upgrade sheet. Upgrade cost formula: `base_cost * 1.5^current_level`.

**Addresses (from FEATURES.md):** Island resource upgrades, resource production rate UI — both table stakes.

**Avoids (from PITFALLS.md):** Pitfall 4 (concurrent island over-upgrade — `FOR UPDATE` lock in `SECURITY DEFINER` function; `CHECK` constraint on wood_level from the start). Client-side rate derivation formula must be documented as synced with the SQL formula.

**Research flag:** Standard patterns. Skip `/gsd:research-phase`.

---

### Phase 3: Trading via Cargo Ships

**Rationale:** Direct P2P resource transfer is a prerequisite for marketplace fulfillment (`fulfill-order` triggers a `resource_shipment`). Building the trade infrastructure first means the marketplace reuses the `resource_shipments` table and `deliver-resources` pg_cron job without reimplementing them. The `movement_type` discriminator and `process_arrivals()` cargo branch must be added here — before the marketplace creates shipments that use the same delivery path. This ordering also validates the cargo delivery mechanic under real conditions before the marketplace depends on it.

**Delivers:** Players can send resources to other cities via cargo ships. `TradeScreen` with target city selection, resource/amount picker, arrival countdown. Incoming/outgoing shipment tracking in `ResourceShipmentsProvider` via Realtime.

**Addresses (from FEATURES.md):** Direct player-to-player resource transfer (differentiator).

**Avoids (from PITFALLS.md):** Pitfall 5 (wine escrow — resources deducted at dispatch, not arrival), Pitfall 9 (cargo collision with military arrival — `process_arrivals()` branched on `movement_type`; interception explicitly deferred to v1.2 with code comment).

**Research flag:** Standard patterns. Skip `/gsd:research-phase`.

---

### Phase 4: Marketplace Order Book

**Rationale:** Depends on Phase 3 cargo ship infrastructure (`fulfill-order` triggers a `resource_shipment` for delivery). Marketplace is the highest-complexity feature — four Edge Functions, atomic SQL matching, Realtime order book, escrow for both buy and sell orders, expiry handling. Deserves its own isolated phase. Building after trading means the `resource_shipments` delivery path is already tested and trusted.

**Delivers:** Global buy/sell order book. Players post orders, browse by resource type (sorted by price), fulfill orders. Resources travel via cargo ships on fulfillment. Orders expire after 48 hours with automatic escrow return. `MarketplaceScreen` with filterable order list, "Post Order" form, and "My Orders" tab.

**Addresses (from FEATURES.md):** Marketplace order book (primary differentiator).

**Avoids (from PITFALLS.md):** Pitfall 3 (partial fill orphans — single stored procedure with `FOR UPDATE`), Pitfall 6 (unbounded order growth — `expires_at` in initial migration), anti-pattern of client-side match logic.

**Research flag:** Needs `/gsd:research-phase`. Specifically: confirm that a Supabase Edge Function calling a PostgreSQL stored procedure via RPC receives full ACID rollback semantics if the stored procedure raises. This must be verified before writing the match function — the entire correctness of order matching depends on it.

---

### Phase 5: Combat Depth — Pillage + Battle Report Visualization

**Rationale:** Pillage modifies `resolve_battles()` and `process_arrivals()`. `process_arrivals()` was also modified in Phase 3 (cargo branch). Building pillage last avoids modifying `process_arrivals()` twice across different phases, which risks merge conflicts and regression. Battle report visualization is pure Flutter (no backend changes), making it safe to build in parallel with or immediately after pillage. Combat features are grouped together because they share the battles domain and the `unit_movements.cargo` schema addition.

**Delivers:** Attackers steal resources on battle victory (transported home via cargo in the return movement). Hideout building protects resources (100 units per hideout level). Turn-by-turn unit loss visualization with color-coded unit types in `BattleTurnCard`. New `UnitCasualtyBar` widget and `unit_visual_constants.dart` constant map.

**Addresses (from FEATURES.md):** Pillage mechanic, battle report visualization — both table stakes.

**Avoids (from PITFALLS.md):** Pitfall 2 (pillage race — `FOR UPDATE` on defender resource rows inside `resolve_battles()`), Pitfall 6 (battle turns Realtime flood — `ListView.builder` with `ValueKey` per turn card, `.on('INSERT')` append pattern instead of `.stream()` full-list re-emit).

**Research flag:** Standard patterns. Skip `/gsd:research-phase` for battle report visualization. Before implementing pillage SQL, read the existing `resolve_battles()` function in full to understand the `attacker_won` branch before modifying it.

---

### Phase Ordering Rationale

- **Economy foundation first:** Population and tax depend on happiness as the root. No other phase can be built in isolation from this tick extension.
- **Island upgrades before trading:** The `resourceRatesProvider` client derivation needs the island multiplier live in the SQL tick to display accurate rates; traders will immediately notice if +X/hr labels don't reflect the island level.
- **Trading before marketplace:** `fulfill-order` in the marketplace triggers a `resource_shipment`; the `resource_shipments` table, RLS, and delivery pg_cron job must exist and be tested before marketplace goes live.
- **Marketplace before pillage:** Pillage modifies `process_arrivals()` which was also modified in Phase 3. Sequencing pillage last avoids a multi-phase migration conflict on the same function. It also means Phase 5 can be an entirely combat-domain phase with no cross-cutting schema risk.
- **Battle visualization in the same phase as pillage:** Both touch the combat domain; `unit_movements.cargo` is needed for pillage; visualization is pure Flutter with no backend risk. Grouping them keeps combat domain changes isolated to one phase and reduces the total phase count.

### Research Flags

Phases needing deeper research during planning:
- **Phase 4 (Marketplace):** Confirm Supabase Edge Function → PostgreSQL stored procedure RPC transaction semantics before writing the match function. The entire correctness guarantee of order matching depends on this.

Phases with standard patterns (skip `/gsd:research-phase`):
- **Phase 1 (Economy Foundation):** pg_cron extension, columnar schema, Edge Functions as column setters — all established patterns in the codebase.
- **Phase 2 (Island Upgrades + Rate UI):** `SECURITY DEFINER` + `FOR UPDATE` is already used in `deduct_resource()`; client-side rate derivation is a pure Riverpod `Provider` combination.
- **Phase 3 (Trading):** `resource_shipments` mirrors existing `unit_movements`; `deliver-resources` mirrors existing `construction-tick` and `training-tick` patterns.
- **Phase 5 (Combat Depth):** `resolve_battles()` pattern is understood from existing codebase; battle visualization is documented fl_chart usage with an established API.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Only one new package (fl_chart 1.1.1); all other capabilities verified in the existing codebase; version compatibility confirmed via pub.dev |
| Features | HIGH | Cross-referenced against Ikariam Fandom wiki, community guides, original game mechanics; all nine features have clear scope boundaries and implementation notes |
| Architecture | HIGH | Research read the actual codebase (22 migration files, existing Edge Functions, existing Flutter features); findings are grounded in real code, not theory |
| Pitfalls | HIGH (technical) / MEDIUM (game design) | PostgreSQL locking pitfalls verified against official docs and GitHub issues; game balance constants (happiness formula, pillage rates) are from Ikariam wiki and subject to playtesting adjustment |

**Overall confidence:** HIGH

### Gaps to Address

- **Gold production formula audit (Phase 1 blocker):** Before Phase 1 implementation, read `process_resource_tick()` in full to confirm the existing Town Hall gold production formula. Adding population-tax gold without auditing will create two simultaneous income streams for the same city. The research flags this but does not resolve which formula survives — this is an implementation decision that must happen before the Phase 1 migration is written.

- **Happiness formula balance values (post-Phase 1 tuning):** The Ikariam wiki formula constants adapted for a 5-minute tick interval are estimates, not production-validated values. Specifically: `population * 0.01 * (happiness/100)` growth rate per tick and `happiness = LEAST(100, happiness + 2)` on successful wine consumption are design estimates. Expect to tune these values in playtesting after Phase 1 ships.

- **Cargo ship availability model (Phase 3 pre-implementation check):** The research assumes `city_units.unit_type = 'cargo_ship'` exists as garrison stock that can be reserved by trade dispatch. Before Phase 3, verify the actual unit model — if cargo ships are only tracked as active movements in `unit_movements` rather than as garrison stock in `city_units`, the reservation logic will differ from the research design.

- **Marketplace partial fills (Phase 4 scope decision):** STACK.md and FEATURES.md both describe partial fills. The ARCHITECTURE.md describes orders as 'open' → 'filled' only. Align on whether v1.1 supports partial fills or only full-quantity matches before Phase 4 planning. Partial fills add significant complexity to the match stored procedure and the order book UI.

- **`cities` Realtime performance at scale (Phase 1 monitoring item):** Enabling `REPLICA IDENTITY FULL` + Realtime publication on `cities` broadcasts a city UPDATE to all subscribers every 5-minute tick. At 50+ concurrent players watching the city screen simultaneously, this may become a bottleneck. Monitor Supabase Realtime message volume after Phase 1 ships; the mitigation (separate population table not in Realtime, hourly population updates) is documented in PITFALLS.md Performance Traps.

---

## Sources

### Primary (HIGH confidence)

- Existing codebase (read directly): `supabase/migrations/` (all 22 files), `supabase/functions/upgrade-building/index.ts`, `lib/features/city/`, `lib/features/battles/`, `lib/features/military/`, `lib/features/map/` — architecture and pattern verification
- [pub.dev/packages/fl_chart](https://pub.dev/packages/fl_chart) — Version 1.1.1, MIT license, min Flutter SDK 3.27.4, `BarChartRodStackItem` API confirmed
- [supabase.com/docs/guides/realtime/realtime-listening-flutter](https://supabase.com/docs/guides/realtime/realtime-listening-flutter) — Realtime Postgres Changes subscription patterns
- [marmelab.com/blog/2025/12/08/supabase-edge-function-transaction-rls.html](https://marmelab.com/blog/2025/12/08/supabase-edge-function-transaction-rls.html) — SECURITY DEFINER pattern and Edge Function transaction semantics
- [supaexplorer.com — FOR UPDATE SKIP LOCKED](https://supaexplorer.com/best-practices/supabase-postgres/lock-skip-locked/) — atomic operations in Supabase PostgreSQL
- [postgresql.org/docs/current/explicit-locking.html](https://www.postgresql.org/docs/current/explicit-locking.html) — row-level lock semantics; `FOR UPDATE` vs `SKIP LOCKED`

### Secondary (MEDIUM confidence)

- [ikariam.fandom.com/wiki/Happiness](https://ikariam.fandom.com/wiki/Happiness) — happiness formula: base 196, tavern +12/level, wine +60/load, population penalty
- [ikariam.fandom.com/wiki/Pillaging](https://ikariam.fandom.com/wiki/Pillaging) — warehouse protection, cargo ship loot capacity
- [ikariam.fandom.com/wiki/Saw_mill](https://ikariam.fandom.com/wiki/Saw_mill) — island resource buildings as shared cooperative upgrades
- [ikariam.fandom.com/wiki/Citizen](https://ikariam.fandom.com/wiki/Citizen) — gold income per idle citizen (3 gold/hr)
- [ikariam.fandom.com/wiki/Trading](https://ikariam.fandom.com/wiki/Trading) — trading post mechanics; cargo ship capacity 500 units
- [github.com/anders94/order-matching-engine](https://github.com/anders94/order-matching-engine) — PostgreSQL atomic order matching reference implementation
- [devforum.roblox.com — Grand Strategy population simulation](https://devforum.roblox.com/t/grand-strategy-games-simulating-population-growth-workforce-etc/4041693) — fractional growth accumulation pattern for integer population display
- [scalablearchitect.com — PostgreSQL row-level locks guide](https://scalablearchitect.com/postgresql-row-level-locks-a-complete-guide-to-for-update-for-share-skip-locked-and-nowait/) — join locking pitfalls and same-row contention

### Tertiary (LOW confidence — needs playtesting validation)

- Happiness formula constants adapted for 5-minute tick interval — design estimates derived from Ikariam wiki values, not production-validated
- Population growth rate per tick (`population * 0.01 * happiness/100`) — design estimate, subject to balance tuning
- Pillage rate (30% of unprotected resources per battle win) — design estimate based on Ikariam community guides

---

*Research completed: 2026-03-13*
*Ready for roadmap: yes*
