# Phase 10: Economy Foundation - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Players can manage city happiness through the tavern, watch their population grow over time, and earn gold tax income that scales with city size. Wine consumption, happiness calculation, population growth, and tax collection all run inside `process_resource_tick()` every tick.

</domain>

<decisions>
## Implementation Decisions

### Tavern Wine Slider UI
- Wine spending slider lives inside the existing building_upgrade_sheet (not a separate screen)
- Slider is continuous 0-100% (not stepped/discrete)
- Saving is instant with debounce (300ms) — no separate save button
- When wine stock hits 0, slider position stays but happiness gain stops; resumes automatically when wine is available again
- Slider shows: current happiness contribution, wine consumed per tick, current wine stock

### Happiness Formula & Display
- Happiness shown in resource bar area as emoji + number (e.g. 😄+12 or 😟-5), green for positive, red for negative
- Tavern level determines max wine consumption capacity — higher level = more wine can be spent = more happiness
- Formula: happiness = (wine_rate * tavern_level) - (population * 0.02)
- When happiness is negative: population growth stops AND resource production drops by 50%
- When happiness is positive: population grows each tick (NUMERIC storage for fractional growth)
- Negative happiness does NOT cause population loss (per requirements — anti-death-spiral)

### Population & Tax Visibility
- Population info shown as compact summary below resource bar: "👥 142 (+0.3/tick)  🪙 Tax: +12/hr"
- Starting population: 100 (when city is created)
- Idle citizens = population - SUM(all assigned workers across all buildings)
- Worker assignment is capped at population — UI prevents assigning more workers than available population
- Idle citizens generate 3 gold/hour (per requirements: ECON-03)

### Town Hall Gold Production
- Remove Town Hall worker-based gold production from process_resource_tick()
- Gold income comes ONLY from idle citizen tax — eliminates double income risk (STATE.md concern resolved)

### Tick Processing Order
- Inside process_resource_tick(), execute in this order:
  1. Resource production (wood, marble, crystal, sulfur, wine — normal formulas)
  2. Wine consumption (tavern consumes wine at configured rate)
  3. Happiness calculation (based on wine consumed and population)
  4. Population growth (if happiness > 0, grow; if happiness < 0, halt + production penalty)
  5. Tax collection (idle citizens * 3 gold/hour, prorated for tick interval)
- All steps in ONE function call — no separate cron job (per prior decision)

### Test Speed Configuration
- Tick interval: 30 seconds (instead of production 5 minutes) — 10x speed for rapid testing
- Happiness and population growth formulas also accelerated to be visible within a few ticks

### Claude's Discretion
- Exact debounce implementation for slider
- Happiness formula constant tuning (0.02 population penalty multiplier is a starting point)
- Population growth rate per tick (design estimate, tune post-launch)
- Wine consumption per tavern level scaling
- Resource production penalty implementation when happiness < 0 (apply to all resources or selective)
- Edge function for updating wine spending rate (new or extend existing)

</decisions>

<specifics>
## Specific Ideas

- Resource bar layout: resources on top row, happiness emoji + population summary on second row
- Preview mockup approved: "🌲 1,240  ⛪ 580  💎 120  💥 90  🪙 450  😄+12" with "👥 142 (+0.3/tick)  🪙 Tax: +12/hr" below
- Tavern sheet: shows happiness contribution, wine/tick, current wine stock alongside normal upgrade UI
- Wine slider in tavern sheet positioned between building info header and upgrade cost section

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `building_upgrade_sheet.dart`: Extend with wine slider section for tavern building type
- `process_resource_tick()` in migration 20260311000008: Main integration point for all economy logic
- `ResourceType` enum + `CityResource` model: Already tracks wine as a resource type
- `BuildingType.tavern`: Already defined in building_constants.dart with costs
- Realtime stream providers (`resourcesStreamProvider`, `buildingsStreamProvider`): Auto-update UI on DB changes
- `_ResourcePanel` / `_ResourceChip` widgets in city_screen.dart: Extend for happiness + population display

### Established Patterns
- All game mutations via Edge Functions (server authority)
- pg_cron for periodic game loops (resource-tick every 5 min, construction-tick every 1 min)
- Supabase Realtime for reactive UI updates
- Riverpod StreamProviders for data flow
- Resource amounts stored as DOUBLE in city_resources table

### Integration Points
- `cities` table: Add `population` (NUMERIC) and `happiness` (NUMERIC) columns
- `cities` table or new field: Add `wine_spending_rate` (0-100 INTEGER or 0.0-1.0 NUMERIC)
- `process_resource_tick()`: Extend with wine consumption, happiness calc, population growth, tax collection steps
- `building_upgrade_sheet.dart`: Conditional wine slider when building type is tavern
- `city_screen.dart` resource panel: Add happiness indicator and population summary row
- `on_city_created` trigger: Set initial population to 100
- New Edge Function or RPC: Update wine_spending_rate for a city

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 10-economy-foundation*
*Context gathered: 2026-03-13*
