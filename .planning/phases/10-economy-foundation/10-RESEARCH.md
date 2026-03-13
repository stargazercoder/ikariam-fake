# Phase 10: Economy Foundation - Research

**Researched:** 2026-03-13
**Domain:** Flutter/Supabase game economy — happiness, population growth, wine mechanics, gold tax
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Tavern Wine Slider UI**
- Wine spending slider lives inside the existing building_upgrade_sheet (not a separate screen)
- Slider is continuous 0-100% (not stepped/discrete)
- Saving is instant with debounce (300ms) — no separate save button
- When wine stock hits 0, slider position stays but happiness gain stops; resumes automatically when wine is available again
- Slider shows: current happiness contribution, wine consumed per tick, current wine stock

**Happiness Formula & Display**
- Happiness shown in resource bar area as emoji + number (e.g. +12 or -5), green for positive, red for negative
- Tavern level determines max wine consumption capacity — higher level = more wine can be spent = more happiness
- Formula: `happiness = (wine_rate * tavern_level) - (population * 0.02)`
- When happiness is negative: population growth stops AND resource production drops by 50%
- When happiness is positive: population grows each tick (NUMERIC storage for fractional growth)
- Negative happiness does NOT cause population loss (anti-death-spiral)

**Population & Tax Visibility**
- Population info shown as compact summary below resource bar: "142 (+0.3/tick)  Tax: +12/hr"
- Starting population: 100 (when city is created)
- Idle citizens = population - SUM(all assigned workers across all buildings)
- Worker assignment is capped at population — UI prevents assigning more workers than available population
- Idle citizens generate 3 gold/hour (per requirements: ECON-03)

**Town Hall Gold Production**
- Remove Town Hall worker-based gold production from process_resource_tick()
- Gold income comes ONLY from idle citizen tax — eliminates double income risk

**Tick Processing Order**
Inside process_resource_tick(), execute in this order:
1. Resource production (wood, marble, crystal, sulfur, wine — normal formulas)
2. Wine consumption (tavern consumes wine at configured rate)
3. Happiness calculation (based on wine consumed and population)
4. Population growth (if happiness > 0, grow; if happiness < 0, halt + production penalty)
5. Tax collection (idle citizens * 3 gold/hour, prorated for tick interval)
All steps in ONE function call — no separate cron job.

**Test Speed Configuration**
- Tick interval: 30 seconds (instead of production 5 minutes) — 10x speed for rapid testing
- Note: pg_cron minimum is 1 minute; 30s must be achieved via application-level scheduling or accepted as "every minute" for cron with internal timestamp guards

### Claude's Discretion
- Exact debounce implementation for slider
- Happiness formula constant tuning (0.02 population penalty multiplier is a starting point)
- Population growth rate per tick (design estimate, tune post-launch)
- Wine consumption per tavern level scaling
- Resource production penalty implementation when happiness < 0 (apply to all resources or selective)
- Edge function for updating wine spending rate (new or extend existing)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| ECON-01 | User can see happiness score for their city (derived from tavern level + wine spending - population) | cities table schema extension (happiness NUMERIC column), Realtime stream from cities table, UI in _ResourcePanel |
| ECON-02 | Population grows automatically when happiness is positive (pg_cron tick, NUMERIC storage) | cities table extension (population NUMERIC column), process_resource_tick() extension step 4 |
| ECON-03 | Idle citizens generate gold tax income (population - workers = idle, idle x 3 gold/hour) | process_resource_tick() extension step 5, worker SUM query across city_buildings |
| ECON-04 | User can adjust wine spending rate in tavern (slider UI, affects happiness per tick) | building_upgrade_sheet.dart extension, new set-wine-rate Edge Function or RPC, cities.wine_spending_rate column |
| ECON-05 | Tavern consumes wine from city resources each tick based on configured spending rate | process_resource_tick() extension step 2, city_resources wine row (already exists as 'wine' type — VERIFY) |
</phase_requirements>

---

## Summary

Phase 10 extends an already-solid Supabase/Flutter game stack with three interlinked economy mechanics: happiness, population, and gold tax. All three run inside the existing `process_resource_tick()` PostgreSQL function that the resource-tick pg_cron job calls every minute (reduced from 5 minutes in the last speed-up migration).

The key integration risks are: (1) the cities table currently has no `population`, `happiness`, or `wine_spending_rate` columns — a schema migration is needed before any other code; (2) the Town Hall gold production path in `process_resource_tick()` currently maps `gold -> town_hall` and produces gold when workers > 0 and prod_level > 0 — this MUST be removed before adding tax gold to prevent double income; (3) `city_resources` does not currently track wine as a resource type — the CHECK constraint and seed data both must be updated. All of these must happen atomically in a single migration wave to avoid broken intermediate state.

The Flutter side is straightforward: the existing `_ResourcePanel` widget and `building_upgrade_sheet.dart` dialog are well-structured for extension. Riverpod StreamProviders from `resourcesStreamProvider` and `buildingsStreamProvider` already power the UI via Supabase Realtime, so adding `cities` Realtime will give live `population` and `happiness` values in the UI with no polling.

**Primary recommendation:** Execute schema migration first (add columns, fix wine resource, remove TownHall gold route), then extend process_resource_tick(), then build the Flutter UI layers — in that order to avoid integration failures.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| supabase_flutter | ^2.x (existing) | Realtime streams, RPC calls, auth | Already in project, all data flows through it |
| flutter_riverpod | ^2.x (existing) | State management, StreamProviders | Established pattern — all providers use this |
| PostgreSQL (Supabase) | 15 (Supabase hosted) | process_resource_tick() extension, schema | All game logic server-side |
| pg_cron | Existing | Periodic tick scheduling | Already registered resource-tick job |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Deno/Edge Functions | Existing (JSR @supabase/supabase-js@2) | set-wine-rate mutation | All client-facing mutations go through Edge Functions per INFR-02 |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Extending process_resource_tick() | Separate cron function for economy | Decision: single function, fixed order, no race on wine row |
| New Edge Function for wine rate | Direct Supabase RPC from Flutter | Decision: Edge Function preferred per established INFR-02 pattern |
| INTEGER population | NUMERIC population | NUMERIC required for fractional tick growth (INTEGER would truncate sub-1 growth to 0) |

**Installation:** No new packages — all existing stack.

---

## Architecture Patterns

### Schema Extension (Migration)

The cities table needs three new columns:

```sql
-- Source: cities table (20260311000002_create_cities.sql) — extend via new migration
ALTER TABLE public.cities
  ADD COLUMN population        NUMERIC  NOT NULL DEFAULT 100,
  ADD COLUMN happiness         NUMERIC  NOT NULL DEFAULT 0,
  ADD COLUMN wine_spending_rate INTEGER  NOT NULL DEFAULT 0
    CHECK (wine_spending_rate BETWEEN 0 AND 100);
```

The `on_city_created` trigger must also set population = 100 for new cities (the DEFAULT covers it, but the trigger's explicit INSERT omits the column so DEFAULT applies — verify behavior in Supabase trigger context).

### Wine as a Resource Type

Currently `city_resources.resource_type` has CHECK constraint:
```sql
CHECK (resource_type IN ('wood','marble','crystal','sulfur','gold'))
```

Wine is NOT in this list. The phase requires adding wine:
```sql
ALTER TABLE public.city_resources
  DROP CONSTRAINT city_resources_resource_type_check;

ALTER TABLE public.city_resources
  ADD CONSTRAINT city_resources_resource_type_check
    CHECK (resource_type IN ('wood','marble','crystal','sulfur','gold','wine'));
```

And seed wine into `on_city_created` + existing cities:
```sql
-- In on_city_created trigger: add wine row
(NEW.id, 'wine', 0)

-- For existing cities:
INSERT INTO public.city_resources (city_id, resource_type, amount)
SELECT id, 'wine', 0 FROM public.cities
ON CONFLICT (city_id, resource_type) DO NOTHING;
```

The Flutter `ResourceType` enum must also gain `wine`:
```dart
enum ResourceType {
  wood, marble, crystal, sulfur, gold, wine;
  String get value => name;
}
```

### Removing Town Hall Gold Production

Current `process_resource_tick()` maps gold to `town_hall` via the CASE statement. The entire gold-production path must be removed from the FOR loop CASE:

```sql
-- OLD (produces gold via town_hall workers):
WHEN 'gold' THEN 'town_hall'

-- NEW: remove the WHEN 'gold' line entirely from the CASE
-- Gold will be produced only by tax collection step
```

The CONTINUE WHEN guard (`CONTINUE WHEN r.workers = 0 OR r.prod_level = 0`) will then skip gold rows naturally since town_hall produces no match, OR explicitly filter gold resource type out of the production loop.

### process_resource_tick() Extended Structure

The rewritten function processes five ordered steps per city (not per resource row). This requires restructuring from a resource-row loop to a city loop with inner logic:

```sql
-- Pseudocode structure:
FOR city IN SELECT all cities LOOP
  -- Step 1: Normal resource production (wood, marble, crystal, sulfur ONLY — no gold)
  FOR each production resource of this city LOOP
    UPDATE city_resources SET amount = LEAST(current + production, capacity);
  END LOOP;

  -- Step 2: Wine consumption
  wine_consumed := LEAST(wine_stock, wine_spending_rate * tavern_level * wine_per_unit);
  UPDATE city_resources SET amount = amount - wine_consumed WHERE resource_type = 'wine';

  -- Step 3: Happiness calculation
  new_happiness := (wine_rate * tavern_level) - (population * 0.02);
  UPDATE cities SET happiness = new_happiness;

  -- Step 4: Population growth (or halt)
  IF new_happiness > 0 THEN
    growth := population * growth_rate_per_tick;
    UPDATE cities SET population = population + growth;
  END IF;

  -- Step 5: Tax collection
  idle := population - total_assigned_workers;
  idle := GREATEST(idle, 0);
  -- 3 gold/hour, prorated for tick_seconds/3600
  gold_income := idle * 3 * (tick_seconds / 3600.0);
  UPDATE city_resources SET amount = LEAST(amount + gold_income, capacity)
    WHERE resource_type = 'gold';
END LOOP;
```

### Realtime for cities Table

Currently only `city_resources` and `city_buildings` publish to Realtime. The `cities` table is NOT in the `supabase_realtime` publication. To stream population and happiness live:

```sql
ALTER TABLE public.cities REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.cities;
```

**Warning from STATE.md:** Enabling REPLICA IDENTITY FULL on cities broadcasts a city UPDATE to ALL subscribers every tick. At 50+ concurrent players this could be a fan-out bottleneck. Acceptable for v1.1; note for Phase 11+ monitoring.

Flutter side — new StreamProvider for cities:
```dart
// Pattern mirrors resourcesStreamProvider
final cityStreamProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, cityId) {
  return supabaseClient
      .from('cities')
      .stream(primaryKey: ['id'])
      .eq('id', cityId)
      .map((rows) => rows.isNotEmpty ? rows.first : null);
});
```

### Tavern Wine Slider in building_upgrade_sheet.dart

The existing `_BuildingUpgradeContent` widget has a clear structure: header → upgrade-in-progress OR upgrade cost → confirm button. The tavern slider section inserts BETWEEN the header and the upgrade section:

```dart
// In _BuildingUpgradeContent.build():
if (widget.building.buildingType == BuildingType.tavern) ...[
  _TavernWineSlider(
    cityId: widget.cityId,
    tavernLevel: widget.building.level,
    currentWine: _currentAmounts[ResourceType.wine] ?? 0.0,
  ),
  const Divider(height: 24),
],
// ... existing upgrade content ...
```

The `_TavernWineSlider` is a `ConsumerStatefulWidget` with:
- Local `double _rate` state (0.0-1.0, maps to 0-100%)
- `Timer? _debounce` for 300ms debounce
- On change: cancel previous timer, start new 300ms timer, call set-wine-rate Edge Function
- Display: happiness contribution (calculated locally), wine/tick, current wine stock

### set-wine-rate Edge Function

New Edge Function following the identical pattern as `upgrade-building/index.ts`:

```typescript
// supabase/functions/set-wine-rate/index.ts
// POST { city_id: string, wine_spending_rate: number (0-100) }
// 1. Authenticate caller
// 2. Verify city ownership
// 3. admin.from('cities').update({ wine_spending_rate: rate }).eq('id', city_id)
// 4. Return success
```

Flutter call pattern (mirrors BuildingsRepository.upgradeBuilding):
```dart
await supabaseClient.functions.invoke(
  'set-wine-rate',
  body: {'city_id': cityId, 'wine_spending_rate': rate},
);
```

### Population & Happiness in UI

The `_ResourcePanel` in `city_screen.dart` currently shows resources in a `Wrap`. The approved layout adds a second row below:

```
Row 1: [Wood] [Marble] [Crystal] [Sulfur] [Gold] [Wine]
Row 2: [Population summary]  [Happiness chip]  [Tax rate]
```

The `_ResourcePanel` widget rebuilds from `resourcesStreamProvider`. Population and happiness come from `cityStreamProvider`. Both streams can be watched in `_CityBody` and passed down together.

### Anti-Patterns to Avoid
- **Separate cron for economy:** Locked decision — all economy in one process_resource_tick() call.
- **INTEGER population:** Truncates fractional tick growth silently to 0. Use NUMERIC.
- **Double gold income:** Town Hall worker gold + tax gold simultaneously. Remove TownHall gold route first.
- **wine not in city_resources:** Do not skip seeding wine rows — process_resource_tick() will fail if no wine row exists for a city.
- **Missing REPLICA IDENTITY FULL on cities:** Supabase Realtime will not send old row values on UPDATE without it. Symptom: UI sees changes but cannot compute deltas.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Debounce for slider | Custom Timer lifecycle | Flutter `Timer` with cancel-and-restart (documented pattern) | Simple, already in Flutter SDK |
| Realtime subscription | Polling loop | Supabase `.stream()` API (existing pattern in codebase) | Already proven — see resourcesStreamProvider |
| Atomic multi-step tick | Multiple separate cron jobs | Single process_resource_tick() with ordered steps | Race condition on wine row if separate |
| Wine row seeding | Manual insert per player | Extend on_city_created trigger | Trigger already handles all resource seeding |
| Gold capacity cap | Manual CASE in tick | Existing LEAST(amount + delta, capacity) pattern | Already proven pattern in tick function |

**Key insight:** The existing `process_resource_tick()` architecture already handles per-city iteration, capacity capping, and conditional SKIP logic. The economy extension reuses these patterns — no novel infrastructure needed.

---

## Common Pitfalls

### Pitfall 1: Wine Resource Type Not Registered
**What goes wrong:** process_resource_tick() tries to UPDATE city_resources WHERE resource_type = 'wine' — finds 0 rows (or violates CHECK constraint on INSERT). Wine consumption silently does nothing.
**Why it happens:** city_resources has a CHECK constraint listing only 5 resource types. 'wine' is not in it.
**How to avoid:** Migration must DROP old CHECK, ADD new CHECK with 'wine', seed wine rows for all existing cities AND update on_city_created trigger.
**Warning signs:** Wine consumption step updates 0 rows; happiness always uses wine_consumed = 0.

### Pitfall 2: Town Hall Double Gold Income
**What goes wrong:** Gold produced by town_hall workers (existing path) PLUS gold from tax both add to gold each tick — city earns roughly 2x intended gold.
**Why it happens:** The current CASE maps 'gold' -> 'town_hall' in the production loop. Adding tax without removing this produces two income streams.
**How to avoid:** In the rewritten process_resource_tick(), explicitly exclude 'gold' from the production resource loop OR remove the 'gold' WHEN clause from the CASE.
**Warning signs:** Gold accumulates far faster than expected even with 0 idle citizens.

### Pitfall 3: NUMERIC vs INTEGER for Population
**What goes wrong:** Population column declared as INTEGER — fractional growth (e.g., 0.3/tick) truncates to 0 every tick. Population never grows.
**Why it happens:** PostgreSQL integer silently truncates decimals.
**How to avoid:** ALTER TABLE cities ADD COLUMN population NUMERIC NOT NULL DEFAULT 100.
**Warning signs:** Population stays at 100 forever despite positive happiness.

### Pitfall 4: cities Table Not in Realtime Publication
**What goes wrong:** Flutter UI watches a city stream but never receives updates when population/happiness change each tick.
**Why it happens:** Only city_resources and city_buildings are in supabase_realtime publication. cities table is not.
**How to avoid:** Migration must ALTER PUBLICATION supabase_realtime ADD TABLE public.cities AND set REPLICA IDENTITY FULL.
**Warning signs:** StreamProvider for cities emits one value at load then never updates.

### Pitfall 5: Slider Debounce Memory Leak
**What goes wrong:** Widget is disposed while a pending 300ms Timer fires — the callback calls `setState` or the repository on a disposed widget. Flutter throws "setState called after dispose".
**Why it happens:** Timer callback holds reference to StatefulWidget state.
**How to avoid:** In `dispose()`, call `_debounce?.cancel()`. Check `mounted` in Timer callback before calling any method.
**Warning signs:** Exception in Flutter console after rapidly tapping Close in the tavern dialog.

### Pitfall 6: Tick Interval Mismatch for Tax Proration
**What goes wrong:** Tax is calculated as `idle * 3 / hour` but the tick runs every 1 minute (current pg_cron schedule). If the tick interval changes, tax income changes proportionally.
**Why it happens:** The proration factor is hardcoded rather than derived from actual tick interval.
**How to avoid:** Store tick interval as a constant or compute from actual elapsed time. For v1.1, hardcode 60 seconds and document it. Tax per tick = `idle * 3 * (60 / 3600)` = `idle * 0.05 gold/tick`.
**Warning signs:** Tick interval changed but gold income feels wrong.

### Pitfall 7: pg_cron Cannot Schedule Sub-Minute Intervals
**What goes wrong:** CONTEXT.md says "30 seconds" for testing speed. pg_cron minimum is 1 minute.
**Why it happens:** pg_cron uses standard cron syntax — minimum granularity is 1 minute.
**How to avoid:** Use 1 minute as the actual cron schedule (which is already the case from migration 20260312000007). The "30 seconds" target from CONTEXT.md should be treated as "as fast as pg_cron allows" = 1 minute. The CONTEXT.md note about 30 seconds likely refers to a desired feel — document the limitation clearly.
**Warning signs:** Attempt to schedule `*/30 * * * * *` (6-field cron) fails with pg_cron error.

---

## Code Examples

Verified patterns from existing codebase:

### Pattern: Extending process_resource_tick() with City Loop
```sql
-- Source: 20260311000017_boost_resources_5x.sql (most recent version)
-- Current pattern: FOR r IN SELECT from city_resources JOIN buildings LOOP
-- New pattern needs: outer city loop, inner resource production sub-loop
CREATE OR REPLACE FUNCTION public.process_resource_tick()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  c          RECORD;   -- city row
  r          RECORD;   -- resource production row
  v_wine     RECORD;   -- wine resource row
  v_tavern   RECORD;   -- tavern building row
  -- ... economy variables
BEGIN
  FOR c IN SELECT id, population, happiness, wine_spending_rate FROM public.cities LOOP
    -- Step 1: Resource production (wood, marble, crystal, sulfur only)
    FOR r IN
      SELECT cr.id AS resource_id, cr.amount AS current_amount,
             COALESCE(pb.level, 0) AS prod_level,
             COALESCE(pb.assigned_workers, 0) AS workers,
             COALESCE(wh.level, 0) AS warehouse_level
      FROM public.city_resources cr
      LEFT JOIN public.city_buildings pb ON pb.city_id = c.id AND ...
      LEFT JOIN public.city_buildings wh ON wh.city_id = c.id AND wh.building_type = 'warehouse'
      WHERE cr.city_id = c.id
        AND cr.resource_type IN ('wood', 'marble', 'crystal', 'sulfur')
    LOOP
      CONTINUE WHEN r.workers = 0 OR r.prod_level = 0;
      UPDATE public.city_resources
      SET amount = LEAST(r.current_amount + (r.workers * r.prod_level * 5.0),
                         500.0 * POWER(1.5, r.warehouse_level)),
          updated_at = NOW()
      WHERE id = r.resource_id;
    END LOOP;

    -- Steps 2-5: wine, happiness, population, tax...
  END LOOP;
END;
$$;
```

### Pattern: Riverpod StreamProvider for cities Table
```dart
// Source: resources_provider.dart pattern
final cityEconomyStreamProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, cityId) {
  return supabaseClient
      .from('cities')
      .stream(primaryKey: ['id'])
      .eq('id', cityId)
      .map((rows) => rows.isNotEmpty ? rows.first : null);
});
```

### Pattern: Debounced Slider with Dispose Safety
```dart
// Standard Flutter Timer debounce pattern
Timer? _debounce;
double _wineRate = 0.0;

void _onSliderChanged(double value) {
  setState(() => _wineRate = value);
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 300), () {
    if (!mounted) return;
    _saveWineRate((_wineRate * 100).round());
  });
}

@override
void dispose() {
  _debounce?.cancel();
  super.dispose();
}
```

### Pattern: Edge Function in Flutter (mirrors buildings_repository.dart)
```dart
// Source: established pattern from upgrade-building Edge Function calls
Future<void> setWineRate({
  required String cityId,
  required int wineSpendingRate,
}) async {
  final response = await supabaseClient.functions.invoke(
    'set-wine-rate',
    body: {
      'city_id': cityId,
      'wine_spending_rate': wineSpendingRate,
    },
  );
  if (response.status != 200) {
    throw Exception('Failed to set wine rate: ${response.data}');
  }
}
```

### Pattern: Wine in ResourceType enum
```dart
// Source: lib/core/constants/resource_constants.dart — extend with wine
enum ResourceType {
  wood, marble, crystal, sulfur, gold, wine;
  String get value => name;
}
```

Note: `name` getter returns the enum member name as a string, so `ResourceType.wine.value` returns `'wine'` — matches the new DB CHECK constraint value.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| 5-min resource tick | 1-min resource tick | Migration 20260312000007 | Economy changes visible faster during testing |
| 1x production | 5x production | Migration 20260311000017 | Starting resources boosted for testing |
| No economy columns | Need population/happiness/wine_spending_rate on cities | Phase 10 | Schema migration required |
| Gold via TownHall workers | Gold via idle citizen tax only | Phase 10 decision | Removes double-income risk; simplifies mental model |

---

## Open Questions

1. **Wine production building**
   - What we know: Wine is a luxury resource in the original Ikariam. The island has a `luxury_type` field. Tavern consumes wine.
   - What's unclear: Does Phase 10 need a wine production mechanism, or does wine only come from island trade/donation? Currently there is no wine production building in the schema.
   - Recommendation: For Phase 10, wine starts at 0 and must be manually obtained or seeded via dev tools. The CONTEXT.md does not mention wine production — defer to a later phase. Seed wine = 0 for new cities.

2. **wine_spending_rate storage type: INTEGER (0-100) vs NUMERIC (0.0-1.0)**
   - What we know: CONTEXT.md says "0-100 INTEGER or 0.0-1.0 NUMERIC" as options.
   - What's unclear: Which is cleaner for the happiness formula `wine_rate * tavern_level`?
   - Recommendation: Use INTEGER 0-100 (matches slider percentage display). In SQL: `wine_spending_rate / 100.0 * tavern_level` in the formula. Avoids floating point imprecision in the DB column.

3. **Happiness formula units and scale**
   - What we know: Formula is `(wine_rate * tavern_level) - (population * 0.02)`. With population=100, tavern=1, wine_rate=50: happiness = (50 * 1) - (100 * 0.02) = 50 - 2 = +48. That seems very positive very quickly.
   - What's unclear: The 0.02 constant was noted as "a starting point" — it needs tuning.
   - Recommendation: This is Claude's Discretion. Start with the formula as specified. The dev tick speed (1 min) will allow rapid playtesting. Constants are easy to tune via a subsequent migration.

4. **Population growth rate per tick**
   - What we know: Population must grow fractionally each tick when happiness > 0. No specific rate was locked.
   - What's unclear: What growth rate makes population visible within a few minutes of testing?
   - Recommendation: Use `population * 0.01 * (happiness / 100)` growth rate per tick. At pop=100, happiness=48, tick=1 min: growth = 100 * 0.01 * 0.48 = 0.48/tick. After 10 ticks (~10 min): +4.8 citizens. Visible and tunable.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (existing) |
| Config file | pubspec.yaml (flutter test section) |
| Quick run command | `flutter test test/unit/economy_formulas_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ECON-01 | Happiness formula: (wine_rate * tavern_level) - (population * 0.02) | unit | `flutter test test/unit/economy_formulas_test.dart -x` | Wave 0 |
| ECON-02 | Population growth calculation when happiness > 0; halt when <= 0 | unit | `flutter test test/unit/economy_formulas_test.dart -x` | Wave 0 |
| ECON-03 | Tax formula: idle * 3 gold/hour prorated for tick interval | unit | `flutter test test/unit/economy_formulas_test.dart -x` | Wave 0 |
| ECON-04 | Wine slider state persists across slider moves; debounce fires 300ms after last change | widget | `flutter test test/widget/tavern_wine_slider_test.dart -x` | Wave 0 |
| ECON-05 | Wine consumption calculation: capped at available wine stock | unit | `flutter test test/unit/economy_formulas_test.dart -x` | Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/unit/economy_formulas_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/unit/economy_formulas_test.dart` — covers ECON-01, ECON-02, ECON-03, ECON-05 (happiness formula, population growth, tax proration, wine consumption cap)
- [ ] `test/widget/tavern_wine_slider_test.dart` — covers ECON-04 (slider UI, debounce behavior, display values)

---

## Sources

### Primary (HIGH confidence)
- Direct codebase inspection — all migration files, Flutter source, existing test patterns
- `supabase/migrations/20260311000008_resource_production_functions.sql` — current process_resource_tick() structure
- `supabase/migrations/20260311000017_boost_resources_5x.sql` — most recent version of tick function
- `supabase/migrations/20260311000002_create_cities.sql` — cities table schema
- `supabase/migrations/20260311000004_create_city_resources.sql` — city_resources CHECK constraint
- `supabase/migrations/20260311000007_on_city_created_trigger.sql` — city seeding trigger
- `supabase/migrations/20260311000010_pg_cron_jobs.sql` — cron schedule
- `supabase/migrations/20260312000007_speed_up_all_timers.sql` — current tick schedule (1 min)
- `lib/features/city/screens/city_screen.dart` — _ResourcePanel, _CityBody structure
- `lib/features/city/screens/building_upgrade_sheet.dart` — extension point for tavern slider
- `lib/features/city/providers/resources_provider.dart` — StreamProvider pattern
- `lib/core/constants/resource_constants.dart` — ResourceType enum (needs wine)
- `supabase/functions/upgrade-building/index.ts` — Edge Function pattern to replicate

### Secondary (MEDIUM confidence)
- `STATE.md` — documented decision: NUMERIC population, single tick function, Realtime fan-out concern
- `REQUIREMENTS.md` — requirement descriptions and traceability

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries already in use, verified from source files
- Architecture patterns: HIGH — derived directly from existing codebase code paths
- Pitfalls: HIGH — derived from actual schema constraints and STATE.md documented concerns
- Formula constants: MEDIUM — numbers are design estimates per CONTEXT.md, not verified empirically

**Research date:** 2026-03-13
**Valid until:** 2026-04-13 (stable stack; constants may change via playtesting)
