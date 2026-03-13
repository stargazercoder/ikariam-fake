# Feature Research

**Domain:** Ikariam-style browser strategy game — v1.1 Economy & Combat Depth features
**Researched:** 2026-03-13
**Confidence:** HIGH (Ikariam Fandom wiki, community guides, original game mechanics cross-referenced)

> **Scope note:** This document focuses on the 9 new features targeted for v1.1. The v0.1.0
> feature landscape was documented in the prior research pass. All existing systems (auth,
> buildings, combat, map) are treated as stable dependencies here.

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist in any Ikariam-like game. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Happiness system (tavern + wine → mood) | Every Ikariam player knows this mechanic; without it the Tavern building serves no purpose | MEDIUM | Tavern gives +12 happiness/level; wine loads give +60/load; pg_cron distributes wine every 20 min; happiness formula = 196 + tavern + wine - population - corruption |
| Population growth driven by happiness | Core Ikariam loop: happiness → population → workers → production; missing this breaks the city progression curve | MEDIUM | happiness score > population = growth; 1 point of "total satisfaction" above current pop = 1 citizen/period; natural cap forms as city grows |
| Tax / gold income from population | Players expect gold to scale with city size; if gold only comes from idle citizens at a flat rate the economy feels static | LOW | In original: each idle citizen = +3 gold/hr; each worker = 0 gold (they work, not tax); a tax-rate slider (0–33%) is the standard UI control for this |
| Configurable wine spending rate | Tavern slider to control happiness-vs-wine tradeoff is genre standard; without it players can't manage wine scarcity | LOW | Slider sets % of hourly wine supply fed to tavern; at 0% no wine is served (happiness drops); at 100% maximum happiness boost; stored as city setting |
| Island resource buildings upgradeable | All Ikariam players expect to click on the sawmill and donate wood to upgrade it for the whole island; skipping this breaks the island cooperation loop | MEDIUM | Shared building level, stored per island (not per city); all cities on island benefit; donations proportional to upgrade cost (wood only for tier 1); upgrade gates more workers |
| Resource production rate visible in UI | Players cannot plan without knowing their hourly rates; the resource bar without a rate label is a major UX gap | LOW | Show +X/hr next to each resource in top bar; tooltip or detail screen shows worker breakdown: base rate x island level x research bonus |
| Pillage resources on battle victory | Winning a battle must have a tangible economic reward; without pillage, aggressive play has no incentive | MEDIUM | Cargo ships required to carry loot; warehouse protects a fixed floor (e.g. 100 + 480/warehouse level); stolen proportional to resource ratios in target warehouse; 15 goods/ship/minute loading rate |
| Battle report shows unit losses per turn | After a 5-minute turn-based battle players need to see what died when; flat win/loss summary feels inadequate | MEDIUM | Turn-by-turn table: attacker losses vs defender losses per unit type; color-code unit types; naval phase then land phase per turn; already have raw data in battle_turns or equivalent |

### Differentiators (Competitive Advantage)

Features not strictly required by genre expectations but that meaningfully elevate this game above the original Ikariam's UX.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Marketplace order book (buy/sell offers posted globally) | Original Ikariam trading is radius-limited search; a global order book with async fill creates a real economy and more player interaction | HIGH | Players post: resource type, amount, price-per-unit in gold; buyer accepts offer → cargo ships depart; order remains open until accepted or cancelled; requires Trading Port building; no gold-for-gold trades (original Ikariam rule) |
| Direct player-to-player resource transfer | Faster than marketplace for allied trades or targeted help; simpler UX for informal economy | LOW | Both players need Trading Port; sender selects city, target city, resource type, amount; cargo ships carry 500 units each; travel time = distance / ship speed; already have dispatch infrastructure |
| Battle report visualization with color-coded unit chart | Showing a stacked bar or table of unit losses per turn (each unit type in its own color) is far above original Ikariam's text-based reports | MEDIUM | fl_chart (bar chart) per turn; attacker side blue, defender red; each unit type a color segment; click turn to expand detail; no external lib needed beyond fl_chart (already pub.dev standard) |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Automatic wine restocking / trade routes | Players don't want to manually send wine to cities | Removes resource scarcity tension; wine management IS the happiness gameplay loop | Manual wine transport via cargo ships; optional: configurable auto-send if player sets standing transfer |
| Instant pillage (no cargo ship travel) | Simpler implementation | Breaks balance — attackers would farm resources instantly with no risk window; the cargo loading delay is intentional counterplay | Keep 15-goods/ship/minute loading rate; defenders can surrender or reinforce before loading completes |
| Negative happiness → population loss | Seems realistic | Catastrophic death spiral if a new player runs out of wine; extremely punishing for beginners | Cap minimum growth at 0 (no shrink); happiness just controls growth rate, not population decay |
| Gold-for-gold marketplace trades | Financial speculation appeal | Original Ikariam explicitly prohibits gold trades; enables gold laundering / real-money trade workarounds | Resources only in marketplace; gold is the pricing unit, not a tradeable commodity |
| Per-city island resource ownership (only your city benefits from upgrade) | Simpler DB model | Removes island cooperation social dynamic — the key differentiator; players would never donate for others | Shared island-level building; all cities benefit equally regardless of who donated |
| Real-time happiness ticker (WebSocket every second) | More responsive UI | Battery drain on mobile web; happiness changes slowly (once/20 min tick); overkill for the mechanic | Refresh on pg_cron tick (5 min) + manual pull-to-refresh; Realtime only for battle events |
| Complex tax rate formula with diminishing returns and corruption | Depth appeal | Harder to communicate to players; original Ikariam's corruption mechanic is widely disliked for being opaque | Simple: idle citizens x gold_rate x tax_pct; corruption only at high city count (defer to v1.2+) |

---

## Feature Dependencies

```
[Happiness System]
    └──requires──> [Tavern Building] (already built v0.1.0)
    └──requires──> [Wine resource supply] (already built v0.1.0)
    └──requires──> [pg_cron wine distribution tick] (new tick handler)
    └──enables──>  [Population Growth Rate] (calculated from happiness surplus)

[Population Growth Rate]
    └──requires──> [Happiness System]
    └──enables──>  [Tax Income] (more citizens = more gold)
    └──enables──>  [More Workers] (larger pool to assign)

[Tax Income]
    └──requires──> [Population system] (citizen count)
    └──requires──> [Tax rate setting] (configurable per city)
    └──enhances──> [Gold resource] (additional income stream)

[Tavern Happiness Config]
    └──requires──> [Tavern Building] (already built v0.1.0)
    └──requires──> [Happiness System]
    └──enables──>  [Player control over wine burn rate]

[Island Resource Upgrade]
    └──requires──> [Island model with resource_building_level] (schema change)
    └──requires──> [Wood donation mechanism] (Edge Function)
    └──enables──>  [Higher worker capacity at island resource]
    └──enables──>  [Higher production rate for all island cities]

[Resource Rate UI]
    └──requires──> [Production formula already implemented] (v0.1.0)
    └──requires──> [Island building level exposed to client] (island resource upgrade)
    └──no new backend needed──> [Pure frontend enhancement]

[Player-to-Player Trading]
    └──requires──> [Trading Port Building] (already built v0.1.0)
    └──requires──> [Cargo Ship unit] (already built v0.1.0 as naval unit? verify)
    └──requires──> [Dispatch infrastructure] (already built v0.1.0 for military)
    └──enhances──> [Island resource cooperation] (wine transport between islands)

[Marketplace Order Book]
    └──requires──> [Player-to-Player Trading] (cargo ship transport mechanic)
    └──requires──> [marketplace_orders table] (new schema)
    └──requires──> [Trading Port Building] (already built)
    └──enhances──> [Player-to-Player Trading]

[Pillage Mechanic]
    └──requires──> [Battle system] (already built v0.1.0)
    └──requires──> [Battle victory detection] (already built)
    └──requires──> [Cargo ships present in attacking fleet] (new check)
    └──requires──> [Warehouse protection formula] (new calculation)
    └──modifies──> [Resource balances of both players] (via Edge Function)

[Battle Report Visualization]
    └──requires──> [Battle turn data] (already stored server-side v0.1.0)
    └──requires──> [fl_chart Flutter package] (frontend only)
    └──enhances──> [Battle reports] (already sent via Realtime v0.1.0)
    └──no new backend needed──> [Pure frontend enhancement]
```

### Dependency Notes

- **Island Resource Upgrade requires schema change**: `islands` table needs `resource_building_level` (int) and `resource_building_donated_wood` (int) columns. All cities on island read from this shared row.
- **Pillage depends on cargo ships in fleet**: Attacking fleet must include at least one Cargo Ship to loot; if none sent, battle can still happen but no resources are taken. This is original Ikariam's design — intentional choice.
- **Battle Report Visualization is pure frontend**: All turn data already exists server-side from v0.1.0. This is a UI-only phase; no new Edge Functions needed.
- **Resource Rate UI is pure frontend**: Production formula (workers x island_level x research_bonus) is already server-side. Frontend just needs to display the rate it can calculate from known values.
- **Tax Income integrates into existing pg_cron tick**: The 5-minute resource tick already runs; gold from tax is added to the same calculation (idle_citizens x gold_rate x tax_pct_decimal).
- **Happiness System needs new pg_cron handler**: Every 20 minutes (or every 5-min tick), wine is deducted from city storage and happiness is updated. Population growth applies once per tick based on surplus happiness.
- **Marketplace Order Book is independent of direct trading**: Both can exist simultaneously. Marketplace is async (post offer, wait for match); direct trading is synchronous (both players agree out-of-game, then transfer).

---

## MVP Definition

### Launch With (v1.1 — this milestone)

- [x] Happiness system: pg_cron distributes wine to tavern, calculates happiness score, updates population growth rate — closes the tavern building's purpose
- [x] Tavern happiness configuration: wine spending rate slider (0–100%), stored per city
- [x] Population-based tax income: idle_citizens x 3 gold/hr included in 5-min resource tick
- [x] Island resource building upgrade: donation screen, shared level per island, all cities benefit
- [x] Resource rate UI: +X/hr suffix in top resource bar; detail breakdown in building screen
- [x] Player-to-player resource transfer: send resources via cargo ships (direct, no order book)
- [x] Marketplace order book: post buy/sell offers, accept offers, cargo ships fulfill
- [x] Pillage mechanic: cargo ships load resources after battle win; warehouse protection floor
- [x] Battle report visualization: turn-by-turn unit loss table with color-coded unit types

### Add After Validation (v1.x)

- [ ] Corruption mechanic (gold penalty at high city count) — only relevant once players have 3+ cities; defer to v1.2
- [ ] Marketplace trade treaties (priority access for allied cities) — requires alliance system maturity
- [ ] Auto wine-send standing orders — quality-of-life once wine management is validated as engaging
- [ ] Population decay from extreme unhappiness — only if players request more punishing mechanics post-launch

### Future Consideration (v2+)

- [ ] Museum building for happiness (culture goods) — high complexity, low immediate value
- [ ] Barbarian village wine supply (PvE wine source) — requires barbarian villages first
- [ ] Dynamic pricing in marketplace (supply/demand curves) — requires enough player volume

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Resource rate UI (+X/hr display) | HIGH | LOW | P1 — pure frontend, high immediate value |
| Tavern happiness config slider | HIGH | LOW | P1 — closes existing building's missing function |
| Happiness system + population growth | HIGH | MEDIUM | P1 — unlocks the city progression curve |
| Tax income from population | HIGH | LOW | P1 — piggybacks on existing resource tick |
| Pillage mechanic | HIGH | MEDIUM | P1 — makes combat victories meaningful |
| Battle report visualization | HIGH | MEDIUM | P1 — improves existing battle report UX significantly |
| Island resource upgrade | MEDIUM | MEDIUM | P1 — enables island cooperation; needed for production scaling |
| Player-to-player resource transfer | MEDIUM | LOW | P1 — prerequisite for marketplace; needed for wine trading |
| Marketplace order book | MEDIUM | HIGH | P1 — drives player interaction and island economy |

**Priority key:**
- P1: Must have for v1.1 launch (all features in this milestone are P1)
- P2: Should have, add in v1.2 after validation
- P3: Nice to have, v2+

---

## Competitor Feature Analysis

| Feature | Ikariam (original) | Our v1.1 Approach |
|---------|-------------------|-------------------|
| Happiness formula | 196 base + tavern(+12/lvl) + wine(+60/load) + museum - population - corruption | Same formula without museum (museum deferred); corruption deferred to v1.2 |
| Wine distribution | Every 20 min in thirds (HH:00, HH:20, HH:40) | pg_cron every 5 min (simplify); deduct wine, add happiness |
| Population growth | Happiness surplus = growth/hr; cap at Town Hall housing limit | Same; cap enforced server-side in pg_cron tick |
| Tax / gold | 3 gold/hr per idle citizen; scientists cost 6/hr | 3 gold/hr per idle citizen; no scientists yet (research deferred) |
| Island upgrade | All cities donate wood; all benefit equally | Same; level stored on island row; donation Edge Function |
| Pillage | Cargo ships required; 15 goods/ship/min; warehouse protects floor | Same mechanics; floor = 100 (Town Hall) + 480 per warehouse level |
| Trading post | Radius-limited offer search; "I offer / I am looking for" UI | Order book global (no radius limit in v1.1 for simplicity); direct transfer also available |
| Battle reports | Text-based round summaries; morale % per round | Same data + color-coded unit loss chart (fl_chart); naval phase then land phase per turn |

---

## Implementation Complexity Notes

### Happiness System (MEDIUM)

The happiness formula is straightforward but requires a new pg_cron job or extended existing tick:

1. Every tick: calculate `happiness_score = 196 + (tavern_level * 12) + (wine_loads_served * 60) - current_population`
2. Deduct wine from city warehouse (based on slider setting)
3. If `happiness_score > current_population`: grow population by `(happiness_score - current_population) * growth_factor`
4. Store `happiness_score` and `population` on city row
5. Frontend reads and displays happiness bar

Key risk: wine depletion when warehouse runs dry → happiness crash → population stops growing. Handle gracefully: if wine = 0, happiness drops to base (196 + tavern only), growth slows but does not reverse.

### Island Resource Upgrade (MEDIUM)

Schema: add `resource_level INT DEFAULT 1` and `wood_donated INT DEFAULT 0` to `islands` table.

Edge Function `donate-to-island-resource`:
1. Validate player has a city on the island
2. Deduct wood from player city warehouse
3. Add to `wood_donated` on island row
4. If `wood_donated >= upgrade_cost(resource_level)`: increment `resource_level`, reset `wood_donated = 0`
5. All production ticks now use `island.resource_level` in formula

Production formula becomes: `workers * island_resource_level * research_bonus`.

### Pillage Mechanic (MEDIUM)

After battle victory detection in existing Edge Function:
1. Count cargo ships in attacking fleet
2. Calculate `max_loot = cargo_ship_count * 500` (capacity)
3. Calculate `unprotected = max(0, target_resource - warehouse_protection(target_warehouse_level))`
4. Distribute loot proportionally across resource types (ratio matches target's resource ratios)
5. Deduct from target, add to attacker — both within same DB transaction
6. Cargo loading is instantaneous at battle end (simplify from original's 15-goods/min — too complex for turn-based model)

Note: Original Ikariam's loading timer made sense for continuous battles. In our 5-minute turn model, simplifying to instant transfer at battle end is more appropriate and avoids a separate cargo-loading state machine.

### Marketplace Order Book (HIGH)

New table: `marketplace_orders(id, seller_city_id, resource_type, amount, price_per_unit, status, created_at)`

Flow:
1. Player posts offer → insert row, deduct resources from city (held in escrow)
2. Buyer accepts offer → Edge Function: transfer resources via cargo ship dispatch, transfer gold, mark order filled
3. Partial fills: split order into filled + remaining
4. Cancel: return escrowed resources to seller

Key constraint: no client writes to marketplace table directly — all via Edge Functions (existing security model).

### Battle Report Visualization (MEDIUM)

Frontend-only. Data already exists in battle report. Add:
- `fl_chart` BarChart widget showing attacker vs defender losses per turn
- Each unit type gets a fixed color (Hoplite=blue, Archer=green, etc.)
- Naval turns shown separately from land turns
- Click any turn bar to expand unit-by-unit breakdown in a detail card

---

## Sources

- [Ikariam Fandom: Happiness](https://ikariam.fandom.com/wiki/Happiness) — Happiness formula, tavern mechanics
- [Ikariam Fandom: Citizen](https://ikariam.fandom.com/wiki/Citizen) — Population and gold per citizen
- [Ikariam Fandom: Gold](https://ikariam.fandom.com/wiki/Gold) — Gold income mechanics
- [Ikariam Fandom: Pillaging](https://ikariam.fandom.com/wiki/Pillaging) — Cargo loading, warehouse protection
- [Ikariam Fandom: Trading](https://ikariam.fandom.com/wiki/Trading) — Trading post offer mechanics
- [Ikariam Fandom: Trading Resources](https://ikariam.fandom.com/wiki/Trading_Resources) — Resource transfer mechanics
- [Ikariam Fandom: Cargo Ship](https://ikariam.fandom.com/wiki/Unit-ship:Cargo_Ship) — Capacity (500 units/ship)
- [Ikariam Fandom: Saw mill](https://ikariam.fandom.com/wiki/Saw_mill) — Island resource upgrade cooperation
- [Ikariam Forum: About warehouse protection](https://forum.ikariam.gameforge.com/forum/thread/100026-about-warehouse-protection/) — Protection floor formula
- [Ikariam Forum: Markets and trading system](https://forum.ikariam.gameforge.com/forum/thread/69404-markets-and-trading-system/) — Order book discussion
- [fl_chart Flutter package (pub.dev)](https://pub.dev/packages/fl_chart) — Battle visualization library
- [Ikariam Finances and Gold Guide (GuideScroll)](https://guidescroll.com/2011/09/ikariam-finances-and-gold-guide/) — Tax/gold formula details
- [Ikariam Forum: Happiness calculation bug (2023)](https://forum.ikariam.gameforge.com/forum/thread/96997-fixed-happiness-calculation-in-tavern-slider-does-not-account-for-corruption/) — Slider behavior confirmation

---

*Feature research for: Ikariam clone v1.1 — Economy & Combat Depth (Flutter + Supabase)*
*Researched: 2026-03-13*
