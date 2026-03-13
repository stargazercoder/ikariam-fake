---
phase: 10-economy-foundation
verified: 2026-03-13T21:00:00Z
status: human_needed
score: 13/13 must-haves verified (automated)
re_verification: false
human_verification:
  - test: "Open city screen and verify happiness indicator, population summary, and wine chip appear in resource panel"
    expected: "Resource bar shows 6 resource chips including wine (purple icon). Below resources: happiness emoji+number (😄/😐/😟) in green/grey/red, and population count with growth/tick and tax/hr."
    why_human: "Visual layout and correct emoji rendering cannot be confirmed by grep/static analysis."
  - test: "Tap the Tavern building to open its upgrade sheet"
    expected: "Wine spending slider (0–100%) appears above the upgrade section. Moving the slider shows happiness contribution, wine/tick, and wine stock values updating in real-time."
    why_human: "Slider state initialization, debounce behavior, and live display values require runtime interaction."
  - test: "Move wine slider to ~50%, wait 300ms, then close and reopen the tavern sheet"
    expected: "Slider re-opens at the same position (reads from cities.wine_spending_rate via Realtime stream)."
    why_human: "Persistence across sheet close/reopen requires a running Supabase instance and timer trigger."
  - test: "Wait one tick (~60s if pg_cron is configured at 1-min). Observe happiness, population, and gold in city resource bar."
    expected: "Happiness updates from the DB tick. If positive, population increases slightly. Gold increases by idle_citizens * 0.05 per tick."
    why_human: "Tick-driven Realtime updates require a live Supabase with pg_cron running — cannot be verified statically."
---

# Phase 10: Economy Foundation — Verification Report

**Phase Goal:** Players can manage city happiness through the tavern, watch their population grow over time, and earn gold tax income that scales with city size.
**Verified:** 2026-03-13T21:00:00Z
**Status:** human_needed (all automated checks PASSED — 4 items require live runtime confirmation)
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Player can open Tavern screen and see current happiness score | ? HUMAN | `_HappinessChip` widget exists, wired to `cityEconomyStreamProvider` in city_screen.dart:134,340 |
| 2 | Player can move wine spending slider and see projected happiness change | ? HUMAN | `_TavernWineSlider` in building_upgrade_sheet.dart:404, `happinessContribution` derived locally at line 488 |
| 3 | Every tick: wine consumed at configured rate, happiness updates | ? HUMAN | DB: `process_resource_tick()` Steps 2+3 verified in migration; Realtime publication confirmed at migration line 83-84 |
| 4 | When happiness positive, population increases each tick (NUMERIC) | ✓ VERIFIED | DB: Step 4 in migration (lines 229-235); `population NUMERIC NOT NULL DEFAULT 100` in migration line 14 |
| 5 | Idle citizens generate 3 gold/hour, appears in resource bar each tick | ✓ VERIFIED | DB: Step 5 in migration (lines 243-263), `idle * 0.05` formula confirmed; gold chip in resource bar via ResourceType.gold |

**Automated score: 5/5 truths have supporting implementation** (2 verified purely statically, 3 require live runtime for full confirmation)

---

## Plan-Level Must-Have Verification

### Plan 01 — Schema Migration + process_resource_tick()

**Artifacts:**

| Artifact | Status | Details |
|----------|--------|---------|
| `supabase/migrations/20260313000001_economy_schema_and_tick.sql` | ✓ VERIFIED | 269 lines (min_lines=80 satisfied). Contains all 5 economy steps, schema DDL, Realtime setup. |
| `test/unit/economy_formulas_test.dart` | ✓ VERIFIED | 257 lines, 16 skipped Wave 0 stubs covering ECON-01/02/03/05. |

**Truths verified:**

| Truth | Status | Evidence |
|-------|--------|----------|
| cities has population (NUMERIC), happiness (NUMERIC), wine_spending_rate (INTEGER 0-100) | ✓ VERIFIED | Migration lines 13-17: `ALTER TABLE public.cities ADD COLUMN population NUMERIC NOT NULL DEFAULT 100, happiness NUMERIC NOT NULL DEFAULT 0, wine_spending_rate INTEGER NOT NULL DEFAULT 0 CHECK (wine_spending_rate BETWEEN 0 AND 100)` |
| city_resources CHECK constraint includes 'wine' | ✓ VERIFIED | Migration lines 22-27: constraint rebuilt as `IN ('wood','marble','crystal','sulfur','gold','wine')` |
| on_city_created trigger seeds wine=500 for new cities | ✓ VERIFIED | Migration line 52: `(NEW.id, 'wine', 500)` in on_city_created INSERT |
| process_resource_tick() has 5-step loop: production (no gold), wine consumption, happiness, population growth, tax | ✓ VERIFIED | Migration lines 117-266: outer `FOR c IN SELECT id, population, happiness, wine_spending_rate` loop confirmed; gold/town_hall mapping absent from production CASE; gold produced only in Step 5 |
| cities table in supabase_realtime with REPLICA IDENTITY FULL | ✓ VERIFIED | Migration lines 83-84: `ALTER TABLE public.cities REPLICA IDENTITY FULL; ALTER PUBLICATION supabase_realtime ADD TABLE public.cities;` |
| Negative happiness halts population growth AND applies 50% production penalty | ✓ VERIFIED | Migration lines 127-131: `v_production_mult := 0.5` when `c.happiness < 0`; lines 229-235: growth block only executes when `v_new_happiness > 0` |
| Tax = idle_citizens * 3 * (tick_seconds / 3600) gold per tick | ✓ VERIFIED | Migration line 249: `v_gold_income := v_idle * 0.05` — mathematically identical to `idle * 3 * (60/3600)` |

**Key Links:**

| From | To | Via | Status | Evidence |
|------|----|-----|--------|----------|
| process_resource_tick() | cities.population, cities.happiness | `UPDATE public.cities SET` | ✓ WIRED | Migration lines 219-222 (happiness) and 232-234 (population) |
| process_resource_tick() | city_resources WHERE resource_type='wine' | Wine consumption step | ✓ WIRED | Migration lines 183, 196: `WHERE city_id = c.id AND resource_type = 'wine'` |
| process_resource_tick() | city_resources WHERE resource_type='gold' | Tax collection step | ✓ WIRED | Migration line 263: `WHERE city_id = c.id AND resource_type = 'gold'` with `v_gold_income` |

---

### Plan 02 — set-wine-rate Edge Function + CityRepository

**Artifacts:**

| Artifact | Status | Details |
|----------|--------|---------|
| `supabase/functions/set-wine-rate/index.ts` | ✓ VERIFIED | 131 lines (min_lines=50 satisfied). CORS, auth, ownership check, integer validation, cities.wine_spending_rate update all present. |
| `lib/features/city/data/city_repository.dart` | ✓ VERIFIED | Contains `setWineRate` method at line 31 invoking `'set-wine-rate'` Edge Function. |
| `test/widget/tavern_wine_slider_test.dart` | ✓ VERIFIED | 20 lines, 3 skipped stubs, contains `'tavern_wine_slider'` in group name. |

**Truths verified:**

| Truth | Status | Evidence |
|-------|--------|----------|
| Client can call set-wine-rate Edge Function with city_id and wine_spending_rate (0-100) | ✓ VERIFIED | `index.ts` line 60-73: validates `city_id` string + `wine_spending_rate` integer 0-100 with float rejection |
| Edge Function validates auth, city ownership, and rate range before updating | ✓ VERIFIED | `index.ts` lines 75-113: anon auth check → admin city ownership check → `Number.isInteger()` + range guard |
| cities.wine_spending_rate column updated to new value | ✓ VERIFIED | `index.ts` lines 116-119: `admin.from('cities').update({ wine_spending_rate }).eq('id', city_id)` |
| Flutter repository has setWineRate method | ✓ VERIFIED | `city_repository.dart` lines 31-45: `Future<void> setWineRate(...)` throws on non-200 |

**Key Links:**

| From | To | Via | Status | Evidence |
|------|----|-----|--------|----------|
| lib/features/city/data/city_repository.dart | supabase/functions/set-wine-rate/index.ts | `supabaseClient.functions.invoke('set-wine-rate')` | ✓ WIRED | city_repository.dart line 35: `supabaseClient.functions.invoke('set-wine-rate', body: {...})` |
| supabase/functions/set-wine-rate/index.ts | cities.wine_spending_rate | `admin.from('cities').update()` | ✓ WIRED | index.ts line 118: `.update({ wine_spending_rate })` |

---

### Plan 03 — Flutter UI (ResourceType, cityEconomyStreamProvider, city screen, tavern slider)

**Artifacts:**

| Artifact | Status | Details |
|----------|--------|---------|
| `lib/core/constants/resource_constants.dart` | ✓ VERIFIED | Contains `wine;` at line 13 in ResourceType enum with `String get value => name` getter. |
| `lib/features/city/providers/city_economy_provider.dart` | ✓ VERIFIED | 26 lines (min_lines=15 satisfied). `cityEconomyStreamProvider` as `StreamProvider.autoDispose.family` watching cities table via `.stream().eq().map()`. |
| `lib/features/city/screens/city_screen.dart` | ✓ VERIFIED | Contains `happiness` (multiple refs). `_HappinessChip` at line 458, `_PopulationSummary` at line 505, `economyAsync` watched at line 134. |
| `lib/features/city/screens/building_upgrade_sheet.dart` | ✓ VERIFIED | Contains `_TavernWineSlider` class at line 404 with debounce Timer, `setWineRate` call at line 439, 300ms debounce at line 436. |

**Truths verified:**

| Truth | Status | Evidence |
|-------|--------|----------|
| ResourceType enum includes wine | ✓ VERIFIED | resource_constants.dart line 13: `wine;` — exhaustive switch enforcement confirmed (10 wine cases across lib/) |
| City screen shows happiness indicator (emoji + number, green/red) in resource bar area | ✓ VERIFIED | city_screen.dart lines 458-498: `_HappinessChip` with emoji selection (😄/😟/😐) and colored Text; wired in `_ResourcePanel` at line 340 |
| City screen shows population summary below resource bar | ✓ VERIFIED | city_screen.dart lines 505-539: `_PopulationSummary` showing pop, growthPerTick, taxPerHour; wired in `_ResourcePanel` at line 342 |
| Tavern building_upgrade_sheet shows wine spending slider (0-100%) with debounced save | ✓ VERIFIED | building_upgrade_sheet.dart lines 203-208: `if (building.buildingType == BuildingType.tavern)` gates `_TavernWineSlider`; Timer 300ms debounce at line 436 |
| Wine slider displays: happiness contribution, wine consumed per tick, current wine stock | ✓ VERIFIED | building_upgrade_sheet.dart lines 488-609: `happinessContribution`, `winePerTick`, `wineAmount` all computed and rendered |
| Slider position persists via cities.wine_spending_rate | ✓ VERIFIED | building_upgrade_sheet.dart lines 461-473: `cityEconomyStreamProvider` read on first emission → `_rate = serverRate` initialization |
| Wine resource appears in resource bar | ✓ VERIFIED | city_screen.dart lines 305-315: `ResourceType.values.map(...)` iterates all 6 types including wine; `_ResourceChip` handles wine at lines 409, 426, 443 |

**Key Links:**

| From | To | Via | Status | Evidence |
|------|----|-----|--------|----------|
| lib/features/city/screens/city_screen.dart | lib/features/city/providers/city_economy_provider.dart | `ref.watch(cityEconomyStreamProvider)` | ✓ WIRED | city_screen.dart line 134: `final economyAsync = ref.watch(cityEconomyStreamProvider(cityId))` |
| lib/features/city/screens/building_upgrade_sheet.dart | lib/features/city/data/city_repository.dart | `cityRepository.setWineRate()` | ✓ WIRED | building_upgrade_sheet.dart line 439: `ref.read(cityRepositoryProvider).setWineRate(cityId: ..., wineSpendingRate: ...)` |
| lib/features/city/screens/building_upgrade_sheet.dart | lib/features/city/providers/city_economy_provider.dart | `ref.watch(cityEconomyStreamProvider)` | ✓ WIRED | building_upgrade_sheet.dart line 461: `ref.watch(cityEconomyStreamProvider(widget.cityId))` |

---

## Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| ECON-01 | 01, 03 | User can see happiness score for their city | ✓ SATISFIED | DB: `happiness NUMERIC` column computed per tick in process_resource_tick() Step 3; UI: `_HappinessChip` in city_screen.dart |
| ECON-02 | 01, 03 | Population grows when happiness positive (NUMERIC storage) | ✓ SATISFIED | DB: Step 4 growth formula; `population NUMERIC`; UI: `_PopulationSummary` shows growth/tick |
| ECON-03 | 01, 03 | Idle citizens generate 3 gold/hour | ✓ SATISFIED | DB: Step 5 `idle * 0.05`; UI: `_PopulationSummary` shows `taxPerHour = idle * 3` |
| ECON-04 | 02, 03 | User can adjust wine spending rate in tavern (slider UI) | ✓ SATISFIED | Edge Function: set-wine-rate/index.ts; Flutter: `_TavernWineSlider` with debounced `setWineRate` call |
| ECON-05 | 01, 03 | Tavern consumes wine from city resources each tick | ✓ SATISFIED | DB: Step 2 `v_actual_consumed = LEAST(v_wine_per_tick, v_wine_amount)`; UI: wine stock shown in slider |

**All 5 ECON requirements satisfied. No orphaned requirements detected.**

---

## Anti-Patterns Found

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| None detected | — | — | — |

Scan of city/ providers, screens, and data directories: no TODO/FIXME/placeholder comments in production code. No stub return values in implemented methods. No empty handlers. The `return null` in city_provider.dart line 35 is intentional guard logic (`if (userId == null) return null`), not a stub.

---

## Human Verification Required

### 1. Happiness Indicator Rendering

**Test:** Run the app and navigate to the city screen. Observe the resource panel.
**Expected:** Six resource chips appear including a purple wine-bar icon labeled "Wine". Below the chips, a happiness emoji (😄 green / 😐 grey / 😟 red) with a signed number appears on the left, and population count with growth/tick and tax/hr appears on the right.
**Why human:** Visual layout, emoji font rendering, and color visibility require a running device.

### 2. Tavern Wine Slider Interaction

**Test:** Tap the Tavern building. Open its upgrade sheet.
**Expected:** A "Wine Spending" section with a 0-100% slider appears above the upgrade cost section. The slider shows happiness contribution (green), wine/tick (purple), and current wine stock. Moving the slider updates these values instantly.
**Why human:** Widget render tree, slider appearance, and live local state update cannot be verified statically.

### 3. Slider Persistence Across Close/Reopen

**Test:** Set the wine slider to ~50%, wait 300ms, close the dialog, then reopen the Tavern upgrade sheet.
**Expected:** Slider reopens at ~50% (reads from `cities.wine_spending_rate` via Realtime stream).
**Why human:** Requires running Supabase to confirm Edge Function write and stream read-back.

### 4. Tick-Driven Economy Loop (Live)

**Test:** Wait one pg_cron tick (~60s) with wine spending rate set above 0.
**Expected:** Wine stock decreases by `rate% * tavernLevel * 5.0`. Happiness value in city screen updates. If happiness is positive, population increases slightly. Gold increases from idle citizen tax.
**Why human:** Requires live Supabase with pg_cron configured, cannot verify tick scheduling statically.

---

## Gaps Summary

No automated gaps found. All 13 must-have truths across 3 plans are VERIFIED at the artifact level:

- Migration file (Plan 01): 269 lines, all 5 economy steps confirmed by content grep. Schema DDL, Realtime publication, correct formulas all present.
- Edge Function (Plan 02): 131 lines, full auth+validation+mutation pipeline confirmed.
- Flutter UI (Plan 03): All 4 key artifacts exist and are substantively implemented. All 3 key links are wired (grep-confirmed import + usage). ResourceType.wine propagated exhaustively to all 10 switch sites across the codebase.

The 4 human verification items are runtime/visual concerns, not code deficiencies. The implementation is structurally complete.

---

_Verified: 2026-03-13T21:00:00Z_
_Verifier: Claude (gsd-verifier)_
