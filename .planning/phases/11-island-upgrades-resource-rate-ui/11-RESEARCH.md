# Phase 11: Island Upgrades + Resource Rate UI — Research

**Researched:** 2026-03-14
**Domain:** Flutter/Riverpod UI, Supabase Edge Functions, PostgreSQL schema extension
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| RSRC-01 | User can donate wood to upgrade island shared resource level | New Edge Function `donate-island-wood`; new `island_resource_level` column on `islands`; deduct_resource RPC already exists for wood deduction |
| RSRC-02 | Island resource level multiplier applies to all cities on that island | `process_resource_tick()` must JOIN `islands` to read `resource_level`, multiply production by `1 + (island_resource_level * 0.10)` |
| RSRC-03 | User can see hourly production rate per resource in main resource bar | Pure Dart computation from existing streams (`buildingsStreamProvider`, `resourcesStreamProvider`); add "+X/hr" label to `_ResourceChip` in `city_screen.dart` |
| RSRC-04 | User can see detailed production breakdown per resource (base rate, building level bonus, island level bonus, research bonus) | New `_ProductionBreakdownSheet` dialog; requires island data joined into city provider; research bonus is fixed 1.0 (v1 deferred) |
</phase_requirements>

---

## Summary

Phase 11 adds two orthogonal features: (1) cooperative island upgrades that require wood donations from any city on the island, and (2) a production-rate display in the resource bar. Both features build directly on the architecture established in Phase 10 without requiring schema redesign.

The island upgrade feature needs a new `resource_level` integer column on the `islands` table (not on `cities` — it is shared state), a new Edge Function following the same INFR-02 pattern as `upgrade-building`, and a one-line addition to `process_resource_tick()` to multiply production by an island-level multiplier. The island screen already exists (`island_screen.dart`) and already has a `_ResourceCell` widget that can be tapped — this is the natural entry point for the donate-wood UI.

The production-rate display (RSRC-03 and RSRC-04) is pure Dart: the tick formula from `process_resource_tick()` is already known, building data already streams in real time, and island level will be fetched from the islands table. No new backend code is needed for the display-only features beyond ensuring island data flows to the Flutter layer.

**Primary recommendation:** Implement in three tasks — (1) DB migration + Edge Function for island upgrade, (2) `process_resource_tick()` multiplier patch, (3) Flutter UI (donation UI + production rate display + breakdown sheet).

---

## Standard Stack

### Core (already in project)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_riverpod | latest (already in project) | State management, async data, provider family | All existing providers use this pattern |
| supabase_flutter | latest (already in project) | Realtime streams, Edge Function invocation | All data access goes through Supabase |
| go_router | latest (already in project) | Navigation | Already used for all routing |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| dart:math | stdlib | `pow()` for level multiplier formula | Needed for production formula replication in Dart |

### No New Dependencies Needed

Phase 11 requires zero new Flutter packages. All features are buildable from existing project dependencies.

**Installation:** none required.

---

## Architecture Patterns

### Recommended Project Structure

New files for this phase:

```
supabase/
├── functions/
│   └── donate-island-wood/
│       └── index.ts              # new Edge Function (RSRC-01)
├── migrations/
│   └── 20260314000001_island_resource_level.sql  # new migration (RSRC-01, RSRC-02)

lib/features/
├── map/
│   ├── data/
│   │   └── map_repository.dart   # extend: fetchIslandResourceLevel(islandId)
│   ├── models/
│   │   └── island.dart           # extend: add resourceLevel field
│   ├── providers/
│   │   └── island_detail_provider.dart  # extend or new provider for island level
│   └── screens/
│       └── island_screen.dart    # extend: tappable resource cell with donate UI
│
└── city/
    └── screens/
        └── city_screen.dart      # extend: _ResourceChip gets "+X/hr" label; tap opens breakdown
```

### Pattern 1: Edge Function for Island Wood Donation (INFR-02)

**What:** Stateless Deno function that validates auth, verifies city-island membership, deducts wood via `deduct_resource` RPC, increments `islands.resource_level` (max 10), returns new level.
**When to use:** All game-state mutations go through Edge Functions — never direct client writes.
**Example (follows upgrade-building pattern exactly):**

```typescript
// Source: supabase/functions/upgrade-building/index.ts (existing pattern)
// donate-island-wood/index.ts
Deno.serve(async (req: Request) => {
  // 1. Parse body: { city_id, wood_amount }
  // 2. Auth: anonClient.auth.getUser()
  // 3. Verify city ownership + city.island_id
  // 4. Read islands.resource_level — reject if already 10
  // 5. Compute donation cost (wood_amount = fixed per-level cost)
  // 6. admin.rpc('deduct_resource', { p_city_id, p_resource_type: 'wood', p_amount })
  // 7. admin.from('islands').update({ resource_level: current + 1 }).eq('id', island_id)
  // 8. Return { success: true, new_level: current + 1 }
});
```

### Pattern 2: `process_resource_tick()` Multiplier (Step 1 extension)

**What:** In the existing Step 1 loop, JOIN `islands` to get `resource_level` for each city's island, then multiply production by `(1.0 + resource_level * 0.10)`.
**When to use:** This is the only correct place — the tick function already iterates all cities.

```sql
-- Source: supabase/migrations/20260313000001_economy_schema_and_tick.sql (existing tick)
-- Extension to Step 1: add island multiplier
v_island_mult := 1.0 + (island_resource_level * 0.10);
-- Then: amount + (r.workers * r.prod_level * 5.0 * v_production_mult * v_island_mult)
```

Multiplier design (to define in phase):
- Level 0 → 1.0x (no bonus)
- Level 1 → 1.1x
- Level 5 → 1.5x
- Level 10 → 2.0x

### Pattern 3: Hourly Rate Computation in Dart (RSRC-03)

**What:** Pure Dart function that replicates the server tick formula to compute hourly rate. Called from `_ResourceChip` or a dedicated provider.
**When to use:** Display-only — never authoritative. Rate is approximate because it mirrors server formula.

```dart
// Source: production formula from process_resource_tick() migration
// Tick interval: 5 minutes = 12 ticks/hr
// Rate per hr = workers * buildingLevel * 5.0 * productionMult * islandMult * 12
double hourlyRate({
  required int workers,
  required int buildingLevel,
  required double productionMult,   // 0.5 if happiness < 0, else 1.0
  required double islandMult,       // 1.0 + islandLevel * 0.10
}) {
  const ticksPerHour = 12; // 60 min / 5 min tick
  return workers * buildingLevel * 5.0 * productionMult * islandMult * ticksPerHour;
}
```

### Pattern 4: Island Level Data Flow to Flutter

**What:** The city screen currently loads island data via `cityProvider` which fetches `cities.*, islands(*)`. The `island` nested map already arrives in the city map (see `city_screen.dart` lines 125-128). Add `resource_level` to the islands SELECT so it is available without a second query.

Currently `fetchPlayerCity` returns: `select('*, islands(*)')` — this already fetches the full islands row. After the migration adds `resource_level` to `islands`, this will automatically include it in the response with no query change needed.

For the island screen's donate button, `islandDetailProvider` fetches from `islands` table — `Island.fromJson` needs to parse `resource_level`.

### Pattern 5: Production Breakdown Sheet (RSRC-04)

**What:** A `showDialog` (same pattern as `showBuildingUpgradeSheet`) triggered by tapping a resource chip. Displays a table with 4 rows: base rate, building level bonus, island level bonus, research bonus (always 0% in v1).
**When to use:** On tap of `_ResourceChip` in `city_screen.dart` or building screen context.

```dart
// Breakdown model (pure value object, no DB calls needed)
class ProductionBreakdown {
  final double baseRate;           // workers * 1 * 5 * 12 (level-1 equivalent)
  final double buildingBonus;      // additional from building level above 1
  final double islandBonus;        // islandMult contribution
  final double researchBonus;      // always 0 in v1
  double get total => baseRate + buildingBonus + islandBonus + researchBonus;
}
```

### Anti-Patterns to Avoid

- **Do NOT add resource_level to `cities`**: It is an island-shared field. Adding it to cities would require sync logic across all co-island players.
- **Do NOT compute hourly rate in SQL**: The UI-side formula mirror is sufficient; SQL is not needed for display-only data.
- **Do NOT use a separate cron for island level effects**: The existing `process_resource_tick()` already iterates all cities; extending it is the right approach.
- **Do NOT allow client to write `islands.resource_level` directly**: INFR-02 mandates Edge Function for all game mutations.
- **Do NOT build a separate island_level stream**: The city data already contains island info; extend the existing `Island.fromJson` to include `resource_level`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Wood deduction atomicity | Custom subtract logic | `deduct_resource` RPC (already exists) | Already handles race conditions via `WHERE amount >= p_amount` |
| Real-time island level updates | Polling or manual refresh | Supabase Realtime on `islands` table OR re-fetch on screen focus | Islands change rarely — re-fetch on island screen mount is sufficient for v1 |
| Auth validation in Edge Function | Custom JWT parsing | `anonClient.auth.getUser()` pattern (existing in all Edge Functions) | Already implemented in upgrade-building — copy exactly |
| Hourly rate number formatting | Custom formatter | `toStringAsFixed(1)` or `NumberFormat.compact()` from intl (already in project if used) | No new dependency needed |

**Key insight:** The `deduct_resource` RPC and the Edge Function shell already exist as proven patterns. The island upgrade Edge Function is a near-copy of `upgrade-building` — the main difference is writing to `islands` instead of `construction_queue`.

---

## Common Pitfalls

### Pitfall 1: Island `resource_level` Missing RLS Policy

**What goes wrong:** The new `resource_level` column on `islands` can be read by all authenticated users (SELECT) but can only be written by the Edge Function (service role). Forgetting the RLS SELECT policy will cause the island screen to fail to load island data.
**Why it happens:** The `islands` table already has RLS. Adding a new column does not automatically inherit a policy.
**How to avoid:** The existing RLS on `islands` covers the entire row — adding a column to a table with row-level SELECT policies automatically includes that column. No new policy needed for reads. The Edge Function uses `service role` for the UPDATE, bypassing RLS.
**Warning signs:** `islandDetailProvider` returning empty or error after migration.

### Pitfall 2: `process_resource_tick()` Island JOIN — Cities Without Islands

**What goes wrong:** If a city has no `island_id` (shouldn't happen by design, but defensively), `LEFT JOIN islands` returns NULL `resource_level`, and `1.0 + NULL * 0.10` = NULL, breaking the multiplication.
**Why it happens:** NULL propagation in PostgreSQL arithmetic.
**How to avoid:** Use `COALESCE(island_resource_level, 0)` in the JOIN result.

### Pitfall 3: `Island.fromJson` Missing `resource_level`

**What goes wrong:** After migration, `islands(*)` in the city query returns `resource_level` but `Island.fromJson` ignores it with `as int? ?? 0` fallback. This is fine for display but must not be forgotten — if you forget to add it to `Island`, production rate computation in Dart will always show island bonus = 0.
**Why it happens:** The Dart model is not auto-updated by DB migrations.
**How to avoid:** Update `Island` model and `Island.fromJson` in the same task as the migration.

### Pitfall 4: Hourly Rate Displayed Before Island Level Loads

**What goes wrong:** `_ResourceChip` shows "+0/hr" briefly because island data hasn't loaded yet, then jumps to the correct value once it arrives. Causes visible flicker.
**Why it happens:** Async data — the city provider loads island level as part of its initial fetch.
**How to avoid:** Show a loading placeholder or use `0` as a safe default ("+0/hr" is acceptable until data arrives — same pattern as resource amounts already loading as 0).

### Pitfall 5: Max Level Enforcement — Race Condition

**What goes wrong:** Two players simultaneously donate wood to an island at level 9 both succeed, pushing it to level 11.
**Why it happens:** The Edge Function reads current level and checks `< 10`, then separately does an UPDATE — classic check-then-act race.
**How to avoid:** Use a conditional UPDATE: `UPDATE islands SET resource_level = resource_level + 1 WHERE id = ? AND resource_level < 10` and check `rowsAffected == 0` to detect the race. This is atomic in PostgreSQL.

### Pitfall 6: `deduct_resource` RPC Not Accepting `wood` (Already in Constraint)

**What goes wrong:** The `deduct_resource` function works on any `resource_type` without type checking — it will happily deduct wood. This is correct behavior and NOT a pitfall, but verify the `city_resources` constraint includes `wood` (it does: `CHECK (resource_type IN ('wood', 'marble', 'crystal', 'sulfur', 'gold', 'wine'))`).
**No action needed.**

---

## Code Examples

Verified patterns from existing project code:

### Extending Island Model with `resource_level`

```dart
// lib/features/map/models/island.dart — extend existing Island class
class Island {
  const Island({
    required this.id,
    required this.gridX,
    required this.gridY,
    required this.luxuryType,
    required this.maxCitySlots,
    this.resourceLevel = 0,   // new field
  });

  // ... existing fields ...
  final int resourceLevel;   // new field: 0–10, shared across all cities on island

  factory Island.fromJson(Map<String, dynamic> json) {
    return Island(
      id: json['id'] as String? ?? '',
      gridX: json['grid_x'] as int? ?? 0,
      gridY: json['grid_y'] as int? ?? 0,
      luxuryType: json['luxury_type'] as String? ?? 'marble',
      maxCitySlots: json['max_city_slots'] as int? ?? 16,
      resourceLevel: json['resource_level'] as int? ?? 0,  // new
    );
  }
}
```

### Atomic Island Level Increment (Edge Function)

```typescript
// supabase/functions/donate-island-wood/index.ts (key mutation step)
const { data, error } = await admin
  .from('islands')
  .update({ resource_level: currentLevel + 1 })
  .eq('id', islandId)
  .eq('resource_level', currentLevel)  // optimistic lock — prevents race condition
  .select('resource_level')
  .single();

if (error || !data) {
  return errorResponse('Island already upgraded by another player', 409);
}
```

### Hourly Rate Provider (Dart)

```dart
// lib/features/city/providers/production_rate_provider.dart — new provider
// Computes hourly production rate per resource type from existing streams.
// Returns Map<ResourceType, double> where value is units/hour.
//
// Formula mirrors process_resource_tick() Step 1:
//   per_tick = workers * buildingLevel * 5.0 * productionMult * islandMult
//   per_hour = per_tick * 12  (12 ticks/hr at 5-min interval)

final productionRateProvider = Provider.autoDispose.family<
  Map<ResourceType, double>, String
>((ref, cityId) {
  final buildings = ref.watch(buildingsStreamProvider(cityId))
      .whenOrNull(data: (b) => b) ?? <CityBuilding>[];
  final economy = ref.watch(cityEconomyStreamProvider(cityId))
      .whenOrNull(data: (e) => e);
  final happiness = (economy?['happiness'] as num?)?.toDouble() ?? 0.0;
  final productionMult = happiness < 0 ? 0.5 : 1.0;

  // Island level comes from city provider's nested islands map
  // (requires cityProvider to include island resource_level)
  final city = ref.watch(cityProvider).whenOrNull(data: (c) => c);
  final islandLevel = (city?['islands']?['resource_level'] as int?) ?? 0;
  final islandMult = 1.0 + islandLevel * 0.10;

  const ticksPerHour = 12;
  final rates = <ResourceType, double>{};

  for (final resourceType in [
    ResourceType.wood,
    ResourceType.marble,
    ResourceType.crystal,
    ResourceType.sulfur,
  ]) {
    final buildingType = _productionBuilding(resourceType);
    final building = buildings.where((b) => b.buildingType == buildingType).firstOrNull;
    if (building == null || building.assignedWorkers == 0 || building.level == 0) {
      rates[resourceType] = 0.0;
    } else {
      rates[resourceType] = building.assignedWorkers
          * building.level
          * 5.0
          * productionMult
          * islandMult
          * ticksPerHour;
    }
  }
  return rates;
});
```

### DB Migration: Island Resource Level

```sql
-- supabase/migrations/20260314000001_island_resource_level.sql

-- 1. Add resource_level column to islands
ALTER TABLE public.islands
  ADD COLUMN resource_level INTEGER NOT NULL DEFAULT 0
    CHECK (resource_level BETWEEN 0 AND 10);

-- 2. Extend process_resource_tick() to apply island multiplier
-- (Full rewrite of Step 1 block — adds v_island_level lookup before inner loop)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Gold produced by Town Hall workers | Gold produced ONLY by idle citizen tax | Phase 10 | process_resource_tick() no longer maps gold to town_hall building |
| Simple `process_resource_tick()` loop | 5-step economy loop with happiness/wine/population | Phase 10 | Island multiplier is a new 6th variable in Step 1, not a separate step |
| Islands table: id, grid_x, grid_y, luxury_type, max_city_slots | Same + `resource_level` INT 0–10 | Phase 11 (new) | Shared cooperative state per island |

**Deprecated/outdated:**
- The `20260311000008_resource_production_functions.sql` original `process_resource_tick()` was superseded by `20260313000001_economy_schema_and_tick.sql`. Phase 11 must extend the CURRENT (Phase 10) version, not the original.

---

## Open Questions

1. **Wood donation cost per level**
   - What we know: The requirements say "donate wood" but do not specify how much wood per level.
   - What's unclear: Is the cost fixed (e.g., 500 wood per level), scaling (e.g., `500 * 1.5^currentLevel`), or designer's choice?
   - Recommendation: Use a fixed cost table in the Edge Function (similar to `buildingBaseTimes` pattern): e.g., level 0→1 costs 300 wood, scaling by 1.5x per level. Define in a constant in the Edge Function and mirror in Dart for UI cost preview.

2. **Which resource types get island bonus**
   - What we know: The island has a `luxury_type` (marble, crystal, or sulfur). In the original Ikariam, the island resource building boosts wood AND the island's luxury resource.
   - What's unclear: Does the Phase 11 multiplier apply to all 4 production resources, or only to wood + the island's luxury type?
   - Recommendation: Apply the multiplier to all 4 production resources for simplicity (v1). The luxury type distinction can be added in v1.2.

3. **Should `islands` table be in Realtime publication?**
   - What we know: The `islands` table is not currently in `supabase_realtime`. After a donation, other cities on the same island should see their production increase at the next tick.
   - What's unclear: Is live push of island level changes necessary, or is re-fetch on island screen open sufficient?
   - Recommendation: Do NOT add `islands` to Realtime for v1 — the effect is visible at the next 5-minute tick anyway. The island screen can re-fetch island detail on mount. This avoids unbounded fan-out (up to 16 cities watching one island row).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None detected — no test/ directory, no pubspec test dependencies visible |
| Config file | none |
| Quick run command | `flutter test` (if tests added) |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| RSRC-01 | Wood deduction succeeds + island level increments | manual smoke | — | No test infra |
| RSRC-01 | Max level 10 enforcement (race-safe) | manual smoke | — | No test infra |
| RSRC-02 | Production tick uses island multiplier | manual smoke (observe resource increase rate) | — | No test infra |
| RSRC-03 | "+X/hr" appears in resource bar | manual visual | — | No test infra |
| RSRC-04 | Breakdown sheet shows all 4 components | manual visual | — | No test infra |

### Wave 0 Gaps

- [ ] No test infrastructure exists — no Wave 0 test files needed; all validation is manual smoke testing in Supabase local dev.

*(All validation for this phase is manual — observe in app and via Supabase Studio SQL queries)*

---

## Sources

### Primary (HIGH confidence)

- `supabase/migrations/20260313000001_economy_schema_and_tick.sql` — full `process_resource_tick()` with 5-step loop; production formula confirmed
- `supabase/migrations/20260311000008_resource_production_functions.sql` — `deduct_resource` RPC signature
- `supabase/functions/upgrade-building/index.ts` — complete Edge Function pattern (INFR-02 template)
- `lib/features/map/models/island.dart` — current Island model (no resource_level)
- `lib/features/map/screens/island_screen.dart` — existing island UI with `_ResourceCell` widgets
- `lib/features/city/screens/city_screen.dart` — `_ResourceChip` widget (target for "+X/hr")
- `lib/features/city/data/city_repository.dart` — `fetchPlayerCity` with `select('*, islands(*)')`
- `lib/core/constants/building_constants.dart` — `upgradeCost()` pattern to mirror in Edge Function
- `lib/core/constants/resource_constants.dart` — `ResourceType` enum, all 6 types confirmed

### Secondary (MEDIUM confidence)

- REQUIREMENTS.md — RSRC-01 through RSRC-04 definitions
- STATE.md Decisions log — INFR-02 rule (Edge Functions for all mutations), no research bonus in v1

### Tertiary (LOW confidence)

- Original Ikariam game design knowledge (island resource building = Miracle / resource building boosting luxury + wood production) — used only for context, not enforced in this implementation.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — existing codebase fully audited, no new dependencies required
- Architecture: HIGH — patterns directly derived from existing Edge Function and migration code
- Pitfalls: HIGH — derived from direct code analysis of existing production tick and RLS setup
- Open questions: MEDIUM — design values (wood cost, which resources get bonus) require planner/designer decision

**Research date:** 2026-03-14
**Valid until:** 2026-04-14 (stable stack; Supabase JS v2 and Flutter stable are not fast-moving for this use case)
