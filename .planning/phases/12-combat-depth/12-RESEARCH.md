# Phase 12: Combat Depth - Research

**Researched:** 2026-03-15
**Domain:** PostgreSQL pillage mechanics, Flutter fl_chart stacked bar visualization, Supabase JSONB cargo transport
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Pillage Mechanics**
- Pillage percentage scales with surviving attacker units (not a fixed %) — more survivors = higher % of unprotected resources
- Pillageable resources: wood, marble, crystal, sulfur (gold is exempt — tax income stays safe)
- Resources can be pillaged down to the Hideout protection floor (not capped at zero separately)
- Pillage details shown in battle report for BOTH attacker and defender — per-resource breakdown

**Cargo Transport**
- Pillaged resources ride on the existing return movement (movement_type='return') — added as a JSONB cargo field on unit_movements
- Only cargo ships carry loot — 500 resources per surviving cargo ship
- 0 surviving cargo ships = 0 pillage, regardless of battle outcome
- Partial capacity: if loot exceeds cargo capacity, only carry what fits (excess stays with defender)
- Resources delivered to attacker's city when return movement arrives (process_arrivals handles it)

**Battle Report Visualization**
- Stacked bar chart for turn-by-turn unit loss display
- Each unit type has a fixed color across all reports (hoplite=color1, archer=color2, etc.) — consistent identity
- Naval and land phases shown as separate chart sections (naval on top, land below) — clear phase separation
- Use fl_chart package for charting — supports stacked bars with animation

**Hideout Protection**
- Protection formula: 100 * 1.5^level per resource type (exponential, matches Warehouse capacity curve)
- Protection applied per resource independently (Hideout lv5 = 759 protected for EACH of wood, marble, crystal, sulfur)
- Base protection: 50 per resource even without Hideout built (protects new players)
- Warehouse does NOT provide pillage protection — only storage capacity. Hideout is the sole protection mechanism.

### Claude's Discretion
- Exact pillage % formula based on survivor count (design the scaling curve)
- Specific color assignments for each unit type (13 unit types need distinct colors)
- fl_chart configuration and animation details
- How to distribute pillage across resource types when cargo capacity is limited (proportional vs priority)
- Stacked bar chart layout details (bar width, spacing, legend placement)
- resolve_battles() integration approach for pillage calculation

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CMBT-01 | Winning attacker pillages resources from defender city (% of unprotected resources) | resolve_battles() attacker_won branch + new pillage calculation block + cargo column on unit_movements |
| CMBT-02 | Warehouse + Hideout levels protect a floor of resources from pillage | Hideout level lookup from city_buildings + formula: floor = 50 + 100 * 1.5^level (base 50 + hideout contribution) |
| CMBT-03 | User can view turn-by-turn unit loss chart in battle reports (stacked bar chart) | fl_chart BarChart with BarChartRodStackItem — data source is existing battle_turns.naval/land_attacker/defender_casualties JSONB |
| CMBT-04 | Each unit type has a distinct color code in battle report visualization | 13 unit type color map constant in unit_constants.dart; reused by chart widget and legend |
</phase_requirements>

## Summary

Phase 12 adds two orthogonal features to the existing combat system: a server-side pillage mechanic and a client-side battle visualization upgrade. The database work is concentrated in two existing SQL functions (`resolve_battles()` and `process_arrivals()`) plus a single schema migration to add a `cargo` JSONB column to `unit_movements`. The Flutter work is concentrated in `battle_detail_screen.dart` and a new chart widget.

The pillage flow is: attacker wins → resolve_battles() computes loot (survivor scaling, hideout floor, cargo cap) → attacker return movement row gets `cargo` JSONB → process_arrivals() detects cargo on return movement → adds resources to attacker city. The entire pillage computation is server-authoritative (SECURITY DEFINER), which matches the project's established pattern.

The visualization upgrade uses fl_chart 1.2.0 (latest as of 2026-03-15). `BarChartRodStackItem(fromY, toY, color)` stacks segments within a single bar rod, with each segment representing one unit type's losses per turn. The data source is the already-existing `battle_turns` table (no schema change). The chart renders two `BarChart` widgets — one for naval, one for land — stacked vertically in the battle detail screen.

**Primary recommendation:** Implement in two waves: Wave 1 = SQL migration + pillage logic (CMBT-01, CMBT-02); Wave 2 = Flutter chart widget (CMBT-03, CMBT-04). The SQL wave has no Flutter dependencies; the chart wave has no SQL dependencies.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| fl_chart | ^1.2.0 | Stacked bar chart rendering | Locked decision; supports BarChartRodStackItem for stacked segments, animations, custom colors |
| supabase_flutter | ^2.12.0 | Already in pubspec — no change | All Realtime, DB, and RLS integration is established |
| flutter_riverpod | ^3.3.1 | Already in pubspec — no change | All existing providers follow this pattern |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| dart:math | SDK | pow() for Hideout protection formula | Already used in resource_constants.dart |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| fl_chart BarChart | syncfusion_flutter_charts | syncfusion is heavier, has licensing constraints; fl_chart is locked decision |
| fl_chart BarChart | charts_flutter (google) | google/charts is effectively unmaintained as of 2024 |

**Installation:**
```bash
flutter pub add fl_chart
```

## Architecture Patterns

### Recommended Project Structure
```
supabase/migrations/
├── 20260315000001_add_cargo_to_unit_movements.sql   # ADD COLUMN cargo jsonb
├── 20260315000002_pillage_functions.sql              # resolve_battles() + process_arrivals() updated

lib/features/battles/
├── models/
│   └── battle_turn.dart          # no change — data already present
├── screens/
│   ├── battle_detail_screen.dart # extend: add BattleLossChartSection widget
│   └── widgets/
│       ├── battle_turn_card.dart  # no change
│       └── battle_loss_chart.dart # NEW: stacked bar chart widget

lib/core/constants/
├── unit_constants.dart           # extend: add unitTypeColor map (13 colors)
├── building_constants.dart       # extend: add hideoutProtectionFloor() helper
```

### Pattern 1: Pillage Calculation Inside resolve_battles() (Server-Authoritative)
**What:** All pillage math runs inside the `attacker_won` branch of `resolve_battles()`. No Edge Function, no client call.
**When to use:** Any game state mutation — established project rule.
**Example:**
```sql
-- Inside resolve_battles(), attacker_won branch:
DECLARE
  v_hideout_level   integer;
  v_cargo_cap       numeric;
  v_surviving_cs    numeric;
  v_total_att       numeric;
  v_pillage_ratio   numeric;
  v_loot            jsonb := '{}';
  v_resource_types  text[] := ARRAY['wood','marble','crystal','sulfur'];
  v_res_type        text;
  v_defender_amt    numeric;
  v_protected       numeric;
  v_unprotected     numeric;
  v_raw_loot        numeric;
  v_total_loot      numeric := 0;
  v_scaled_loot     jsonb := '{}';

-- 1. Hideout protection floor per resource
SELECT COALESCE(
  (SELECT level FROM public.city_buildings
   WHERE city_id = b.defender_city_id AND building_type = 'hideout'),
  0
) INTO v_hideout_level;
-- floor = 50 + 100 * 1.5^level  (base 50 protects new players even with level 0)
-- At level 0: floor = 50 + 100 = 150... but user specified: base=50 even WITHOUT hideout built
-- Interpretation: if hideout level=0 (built but not upgraded), floor = 100 * 1.5^0 = 100
--                 if hideout not in city_buildings at all, floor = 50 (new player guard)
-- Use: COALESCE(level, -1) where -1 means "not built" → floor = 50
--       level = 0 means "built at lv0" → floor = 100 * 1.5^0 = 100

-- 2. Cargo capacity
v_surviving_cs := COALESCE((v_att_units->>'cargo_ship')::numeric, 0);
v_cargo_cap := v_surviving_cs * 500;  -- 500 per cargo ship

-- 3. Pillage ratio from survivor count (see Pillage Formula section)
-- Total surviving attacker units (land only, cargo ships don't fight)
v_total_att := 0;
FOR v_kv IN SELECT key, value FROM jsonb_each_text(v_att_units) LOOP
  IF NOT (v_kv.key = ANY(v_naval_types)) THEN
    v_total_att := v_total_att + v_kv.value::numeric;
  END IF;
END LOOP;
-- ratio = LEAST(0.8, total_att_survivors / 100 * 0.1) → cap 80%

-- 4. Compute raw loot per resource
FOREACH v_res_type IN ARRAY v_resource_types LOOP
  SELECT COALESCE(amount, 0)
  INTO v_defender_amt
  FROM public.city_resources
  WHERE city_id = b.defender_city_id AND resource_type = v_res_type
  FOR UPDATE;  -- SELECT FOR UPDATE prevents race with resource tick

  v_protected := <floor_formula>;
  v_unprotected := GREATEST(0, v_defender_amt - v_protected);
  v_raw_loot := FLOOR(v_unprotected * v_pillage_ratio);
  -- accumulate into v_loot, v_total_loot
END LOOP;

-- 5. Apply cargo cap (proportional distribution across resource types)
IF v_total_loot > v_cargo_cap THEN
  -- scale each resource proportionally: actual = raw * (cargo_cap / total_loot)
END IF;

-- 6. Deduct from defender, store loot on return movement's cargo field
UPDATE public.city_resources SET amount = amount - actual_loot ...;
-- cargo goes onto the INSERT INTO unit_movements (..., cargo) VALUES (..., v_loot);
```

### Pattern 2: Cargo Delivery in process_arrivals()
**What:** When a return movement has a non-null `cargo` JSONB field, add each resource to the attacker's city.
**When to use:** Arrivals with `cargo IS NOT NULL` on a `movement_type = 'return'` row.
**Example:**
```sql
-- Inside process_arrivals(), friendly arrival branch (owner_id = dest owner):
IF m.cargo IS NOT NULL THEN
  FOR v_type, v_qty_txt IN
    SELECT key, value FROM jsonb_each_text(m.cargo)
  LOOP
    v_qty := v_qty_txt::numeric;
    IF v_qty > 0 THEN
      UPDATE public.city_resources
      SET amount = amount + v_qty, updated_at = NOW()
      WHERE city_id = m.destination_city_id AND resource_type = v_type;
    END IF;
  END LOOP;
END IF;
```

### Pattern 3: fl_chart Stacked Bar Chart for Unit Losses
**What:** One bar per turn, one stacked segment per unit type that had losses. Two separate `BarChart` widgets for naval phase and land phase.
**When to use:** CMBT-03 visualization in `battle_detail_screen.dart`.
**Example:**
```dart
// Source: fl_chart 1.2.0 official docs / pub.dev
BarChart(
  BarChartData(
    alignment: BarChartAlignment.spaceAround,
    maxY: maxLossValue,
    barGroups: turns.asMap().entries.map((entry) {
      final turn = entry.value;
      final casualties = turn.navalAttackerCasualties ?? {};
      double runningY = 0;
      final stackItems = orderedNavalTypes
          .where((type) => (casualties[type] ?? 0) > 0)
          .map((type) {
        final from = runningY;
        final to = runningY + (casualties[type] ?? 0).toDouble();
        runningY = to;
        return BarChartRodStackItem(
          fromY: from,
          toY: to,
          color: unitTypeColors[type]!,
        );
      }).toList();
      return BarChartGroupData(
        x: turn.turnNumber,
        barRods: [
          BarChartRodData(
            toY: runningY,
            rodStackItem: stackItems,
            width: 20,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      );
    }).toList(),
    titlesData: FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) => Text('T${value.toInt()}'),
        ),
      ),
    ),
  ),
  swapAnimationDuration: const Duration(milliseconds: 300),
)
```

### Pattern 4: Unit Type Color Map (13 colors, distinct)
**What:** A constant map in `unit_constants.dart` keyed on UnitType enum.
**When to use:** All chart renders and the chart legend widget.

Color assignment recommendation (Claude's discretion — all visually distinct on dark and light themes):
```dart
const Map<UnitType, Color> unitTypeColors = {
  // Land units — warm-to-cool spectrum
  UnitType.hoplite:       Color(0xFF4CAF50), // green
  UnitType.phalanx:       Color(0xFF8BC34A), // light green
  UnitType.archer:        Color(0xFF2196F3), // blue
  UnitType.cavalry:       Color(0xFF9C27B0), // purple
  UnitType.catapult:      Color(0xFFFF9800), // orange
  UnitType.mortar:        Color(0xFFF44336), // red
  UnitType.medic:         Color(0xFF00BCD4), // cyan
  UnitType.cook:          Color(0xFFFFEB3B), // yellow
  // Naval units — distinct from land via cooler/metallic palette
  UnitType.cargoShip:     Color(0xFF607D8B), // blue-grey
  UnitType.ramShip:       Color(0xFF795548), // brown
  UnitType.catapultShip:  Color(0xFFE91E63), // pink
  UnitType.mortarShip:    Color(0xFF673AB7), // deep purple
  UnitType.divingBoat:    Color(0xFF009688), // teal
};
```

### Anti-Patterns to Avoid
- **Pillage in an Edge Function:** resolve_battles() is a pg_cron SQL function. Adding a separate Edge Function call for pillage creates a race condition with the resource tick. Stay in SQL.
- **SELECT without FOR UPDATE on defender resources:** The resource tick runs every 5 minutes and can overlap with battle resolution. Must use `SELECT ... FOR UPDATE` on city_resources rows when reading for pillage.
- **Storing chart data client-side:** All chart data comes from the existing `battle_turns` Realtime stream. Do not add a separate provider or cache — the `battleTurnsProvider` already emits the needed data.
- **Modifying battles table schema:** The `pillage_result` should be stored on the `battles` table (add a `pillage_result` JSONB column) OR it can be included in the return movement's `cargo` and read back from unit_movements. Decision: store it on `battles` so the defender can also see it in their report without needing to read the attacker's movement.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Stacked bar rendering | Custom Canvas painter or Row+SizedBox stacks | fl_chart BarChartRodStackItem | Handles animation, axis labels, touch interaction, maxY scaling |
| Race condition on resource update | Application-level locking / retry | PostgreSQL `SELECT FOR UPDATE` inside SECURITY DEFINER transaction | DB transaction atomicity is guaranteed; app-level locking is not |
| Proportional cargo distribution | Manual loop with remainders | Simple multiplication: `FLOOR(raw * cargo_cap / total_raw)` | Prevents over-allocation while remaining deterministic |
| Chart legend | Custom lookup widget | Derive from `unitTypeColors` map + `UnitType.displayName` | Same source of truth for color used in chart |

**Key insight:** The most dangerous hand-roll risk is the resource read-modify-write for pillage. PostgreSQL's `SELECT FOR UPDATE` inside the existing `resolve_battles()` transaction is the correct and proven approach (noted in STATE.md under key decisions).

## Common Pitfalls

### Pitfall 1: Defender Can't See Pillage in Battle Report
**What goes wrong:** Pillage result is stored only on the attacker's `unit_movements.cargo` row. Defender has no RLS access to the attacker's movements (policy is `owner_id = auth.uid()`).
**Why it happens:** CONTEXT.md requires "pillage details shown for BOTH attacker and defender."
**How to avoid:** Store the pillage result as a `pillage_result JSONB` column on the `battles` table (or `battle_turns` final turn). Both participants have SELECT access to battles via the existing `battles_select_participant` RLS policy.
**Warning signs:** Defender's battle report shows no pillage section; attacker sees it fine.

### Pitfall 2: Cargo Field Missing on Old unit_movements Rows
**What goes wrong:** `UnitMovement.fromJson()` throws a cast error if `cargo` is absent from the JSON.
**Why it happens:** Migration adds nullable `cargo` column; old return movements lack it.
**How to avoid:** The `cargo` column must be nullable (no DEFAULT, no NOT NULL). In `UnitMovement.fromJson()`, parse as `json['cargo'] as Map<String, dynamic>?`.
**Warning signs:** Crash on arrival processing for pre-migration movements.

### Pitfall 3: fl_chart Bar Height of Zero When No Casualties
**What goes wrong:** A turn where one phase had zero losses produces a `toY = 0` rod, which fl_chart may render as a zero-height bar or cause assertion errors.
**Why it happens:** `rodStackItem` list is empty, `toY = 0`.
**How to avoid:** Filter out turns with no casualties from the barGroups list for that chart section. Show a "No losses" text label instead of an empty chart.
**Warning signs:** Flutter assertion `toY must be >= fromY` or invisible bars at y=0.

### Pitfall 4: Hideout Level NULL vs Level 0
**What goes wrong:** `city_buildings` only has a row when the building was constructed. A city that never built a Hideout has NO row — not a row with `level = 0`.
**Why it happens:** The `on_city_created` trigger inserts buildings at level 0 for core buildings only, or may not insert Hideout at all. Need to verify the trigger.
**How to avoid:** Use `COALESCE((SELECT level FROM city_buildings WHERE ... AND building_type='hideout'), -1)`. Where `-1` maps to the "not built" base protection of 50 per resource. Level 0 (row exists, level=0) maps to `100 * 1.5^0 = 100`.
**Warning signs:** Hideout protection always 50 even for players who built a Hideout.

### Pitfall 5: Stacked Segment fromY/toY Ordering
**What goes wrong:** `BarChartRodStackItem` requires `fromY < toY`. If unit types are iterated in different order across turns, the running cumulative Y must be computed in the same consistent order.
**Why it happens:** `Map` iteration order in Dart is insertion order — JSONB from Postgres may return keys in arbitrary order.
**How to avoid:** Define a canonical `orderedUnitTypes` list (same order as `UnitType.values`) and always iterate that order when building stack items.
**Warning signs:** Stacked bars with incorrect colors assigned to wrong segments.

### Pitfall 6: Cargo Ship Survivors Count After Naval Phase
**What goes wrong:** Pillage counts `cargo_ship` survivors from `v_att_units` after the naval battle resolves. If cargo ships were destroyed in the naval phase, the correct surviving count is already in `v_att_units` at the point pillage is calculated.
**Why it happens:** `v_att_units` is mutated during naval phase — this is correct. Just read `v_att_units->>'cargo_ship'` at the `attacker_won` block entry, not from the original `b.attacker_units` snapshot.
**Warning signs:** Pillage occurs even when all cargo ships were sunk in naval phase.

## Code Examples

Verified patterns from official sources:

### fl_chart BarChart Stacked Rod Construction
```dart
// Source: fl_chart 1.2.0 pub.dev + GitHub docs
BarChartRodData(
  toY: totalLossesThisTurn,
  width: 20,
  borderRadius: BorderRadius.circular(3),
  rodStackItem: [
    BarChartRodStackItem(fromY: 0,   toY: 5,   color: unitTypeColors[UnitType.hoplite]!),
    BarChartRodStackItem(fromY: 5,   toY: 8,   color: unitTypeColors[UnitType.archer]!),
    BarChartRodStackItem(fromY: 8,   toY: 12,  color: unitTypeColors[UnitType.cavalry]!),
  ],
)
```

### Hideout Protection Floor Formula (SQL)
```sql
-- v_hideout_level = COALESCE(SELECT level ... WHERE building_type='hideout', -1)
-- -1 = not built → floor = 50
-- 0  = built at lv0 → floor = 100 * 1.5^0 = 100
-- 1  = lv1 → floor = 100 * 1.5^1 = 150
-- 5  = lv5 → floor = 100 * 1.5^5 ≈ 759
v_hideout_floor :=
  CASE
    WHEN v_hideout_level < 0 THEN 50
    ELSE FLOOR(100.0 * POWER(1.5, v_hideout_level))
  END;
```

### Pillage Ratio Formula (Claude's Discretion)
The scaling curve should feel rewarding for large armies without being catastrophic for defenders. Recommended formula:
```
pillage_ratio = LEAST(0.75, surviving_land_attackers / 50 * 0.10)
```
Examples:
- 10 survivors: 2% of unprotected resources
- 50 survivors: 10%
- 100 survivors: 20%
- 375+ survivors: capped at 75%

This is graduated, not a cliff, and the 75% cap means a massive army never takes everything.

```sql
-- Count surviving land units (non-naval)
v_total_att_land := 0;
FOR v_kv IN SELECT key, value FROM jsonb_each_text(v_att_units) LOOP
  IF NOT (v_kv.key = ANY(v_naval_types)) THEN
    v_total_att_land := v_total_att_land + v_kv.value::numeric;
  END IF;
END LOOP;
v_pillage_ratio := LEAST(0.75, v_total_att_land / 50.0 * 0.10);
```

### Proportional Cargo Distribution (Claude's Discretion)
When total loot > cargo capacity, distribute proportionally across resource types:
```sql
-- After computing raw loot per resource into v_loot (JSONB)
IF v_total_raw_loot > 0 AND v_cargo_cap < v_total_raw_loot THEN
  v_scale := v_cargo_cap / v_total_raw_loot;
  -- scale each resource: actual = FLOOR(raw * scale)
ELSE
  v_scale := 1.0;
END IF;
```

### Cargo Delivery in process_arrivals()
```sql
-- Source: process_arrivals() extension pattern — matches existing friendly arrival block
SELECT id, destination_city_id, origin_city_id, owner_id, units, cargo
FROM public.unit_movements
WHERE arrive_at <= NOW()

-- In friendly arrival block:
IF m.cargo IS NOT NULL THEN
  FOR v_res_type, v_qty_txt IN
    SELECT key, value FROM jsonb_each_text(m.cargo)
  LOOP
    UPDATE public.city_resources
    SET amount = LEAST(amount + v_qty_txt::numeric,
                       <warehouse_capacity>),  -- respect storage cap
        updated_at = NOW()
    WHERE city_id = m.destination_city_id
      AND resource_type = v_res_type;
  END LOOP;
END IF;
```

### Pillage Result on battles Table (for defender visibility)
```sql
-- Add column (migration):
ALTER TABLE public.battles ADD COLUMN pillage_result JSONB;
-- {"wood": 450, "marble": 200, "crystal": 0, "sulfur": 120}

-- Set during resolve_battles() at attacker_won:
UPDATE public.battles
SET pillage_result = v_loot_delivered, ...
WHERE id = b.id;
```

### Flutter: Reading cargo and pillage_result
```dart
// UnitMovement model extension:
final Map<String, int>? cargo;  // nullable — most movements have no cargo

factory UnitMovement.fromJson(Map<String, dynamic> json) {
  return UnitMovement(
    // ...existing fields...
    cargo: json['cargo'] == null
        ? null
        : (json['cargo'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toInt())),
  );
}

// Battle model extension:
final Map<String, int>? pillageResult;  // null until attacker wins

factory Battle.fromJson(Map<String, dynamic> json) {
  return Battle(
    // ...existing fields...
    pillageResult: json['pillage_result'] == null
        ? null
        : (json['pillage_result'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toInt())),
  );
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| fl_chart 0.x (BarChartRodStackItem no gradient) | fl_chart 1.2.0 (gradient + label support on stack items) | 2025 | Can use gradient colors on segments if desired |
| google/charts_flutter | fl_chart (locked decision) | 2024 — charts_flutter archived | No alternative needed |
| Fixed pillage % | Survivor-scaled pillage ratio | Phase 12 design | More strategic — large armies earn more loot |

**Deprecated/outdated:**
- `charts_flutter` (google): Archived repository — do not use.
- fl_chart < 0.4.2: No stacked bar support. Current version 1.2.0 fully supports it.

## Open Questions

1. **Does on_city_created trigger insert Hideout at level 0?**
   - What we know: `city_buildings` only holds rows for buildings that exist; the trigger (`20260311000007_on_city_created_trigger.sql`) is not read in this research.
   - What's unclear: Whether a freshly created city has a `hideout` row at `level=0` or no row at all.
   - Recommendation: Read the trigger SQL before implementing. If no row → use `COALESCE(..., -1)` → floor=50. If row at level 0 → floor=100. Both are handled by the proposed formula.

2. **Should returning cargo be capped at Warehouse capacity?**
   - What we know: `process_arrivals()` currently does uncapped `quantity + EXCLUDED.quantity`. Warehouses have capacity limits enforced elsewhere (or not enforced in storage, only in production).
   - What's unclear: Whether pillaged resources delivered above warehouse capacity should overflow (be lost) or be accepted regardless.
   - Recommendation: For simplicity, allow overflow delivery (attacker earned the loot). Document as a known soft-cap bypass.

3. **Is `pillage_result` needed on `battles` table or is it derivable?**
   - What we know: Defender has RLS SELECT on `battles`; defender has no RLS SELECT on attacker's `unit_movements`.
   - What's unclear: Whether to add a column to `battles` or use a different approach.
   - Recommendation: Add `pillage_result JSONB` to `battles` table (nullable). Defender can then read it from the same stream they already have. This is the cleanest approach for CMBT-01 "shown for BOTH attacker and defender."

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Flutter integration_test (SDK) + flutter_test |
| Config file | none — tests in test/ directory |
| Quick run command | `flutter test test/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CMBT-01 | Attacker wins → pillage_result populated on battles row | manual-only (requires running Supabase + pg_cron) | n/a | n/a |
| CMBT-02 | Hideout lv5 protects 759 per resource; base 50 without hideout | unit | `flutter test test/hideout_protection_test.dart` | ❌ Wave 0 |
| CMBT-03 | Battle chart widget renders correct number of bars | unit (widget test) | `flutter test test/battle_loss_chart_test.dart` | ❌ Wave 0 |
| CMBT-04 | Each unit type maps to a distinct non-null color | unit | `flutter test test/unit_type_colors_test.dart` | ❌ Wave 0 |

Note: CMBT-01 and CMBT-02 SQL logic is integration-only (requires live Supabase). The Dart-side of CMBT-02 (the `hideoutProtectionFloor()` helper in building_constants.dart) is unit-testable.

### Sampling Rate
- **Per task commit:** `flutter test test/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/hideout_protection_test.dart` — unit tests for `hideoutProtectionFloor(level)` formula
- [ ] `test/battle_loss_chart_test.dart` — widget test for `BattleLossChart` renders N bars for N turns
- [ ] `test/unit_type_colors_test.dart` — asserts all 13 unit types have a distinct color entry

## Sources

### Primary (HIGH confidence)
- fl_chart 1.2.0 pub.dev page — version number, BarChartRodStackItem, BarChartRodData confirmed
- GitHub imaNNeo/fl_chart bar_chart.md (raw) — constructor signatures confirmed
- Codebase inspection (20260312000004_battle_functions.sql) — resolve_battles() structure confirmed
- Codebase inspection (20260312000005_modify_process_arrivals.sql) — process_arrivals() structure confirmed
- Codebase inspection (battle_turn.dart, battle.dart, battle_detail_screen.dart) — existing data models confirmed

### Secondary (MEDIUM confidence)
- WebSearch fl_chart stacked bar — confirmed BarChartRodStackItem gradient/label features added in recent versions
- STATE.md key decision: "SELECT FOR UPDATE on defender resource rows inside resolve_battles()" — design decision confirmed

### Tertiary (LOW confidence)
- Pillage ratio formula (0.10 per 50 survivors, cap 0.75) — Claude design choice, needs playtesting
- Color assignments for 13 unit types — Claude design choice, visually evaluated but not playtested

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — fl_chart 1.2.0 verified on pub.dev, all other deps already in pubspec
- Architecture: HIGH — integration points confirmed by reading actual source files
- Pitfalls: HIGH — most identified from direct code inspection (process_arrivals, resolve_battles, RLS policies)
- Pillage formula: LOW — design choice by Claude, requires playtesting to tune

**Research date:** 2026-03-15
**Valid until:** 2026-04-15 (fl_chart moves fast; verify fl_chart version before implementation)
