# Phase 15: Resource Trading - Research

**Researched:** 2026-03-16
**Domain:** Flutter (Riverpod + Supabase) — trade dialog, Edge Function, DB migration
**Confidence:** HIGH

## Summary

Phase 15 adds resource trading between cities using the existing cargo ship / unit_movements infrastructure. The codebase already has every mechanical piece required: `cargo` JSONB column on `unit_movements`, `process_arrivals()` SQL function that delivers cargo on arrival, `movement_type` column on `unit_movements`, `warehouseCapacity()` formula in Dart, and a well-established Edge Function pattern from `dispatch-units`.

The work is almost entirely additive. The DB migration extends the CHECK constraint on `movement_type` to include `'trade'`. The new Edge Function `send-trade` mirrors `dispatch-units` but validates resource balances and warehouse capacity instead of unit counts. On the Flutter side, a new `TradeDialog` (a `showDialog` popup) is triggered from the island screen city-tap handler, and the movements screen needs a minor icon/color patch for `'trade'` rows.

**Primary recommendation:** Clone `dispatch-units` as the Edge Function scaffold — it already has auth, island coordinate lookup, travel time calculation, CORS headers, dev-speed multiplier, and the movement insert pattern. Replace unit deduction with resource deduction via a new `deduct_resources` RPC.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Trade is initiated from **island screen city tap** — tap another city, context menu shows "Attack" and "Trade" options
- Trade option appears for **all cities** on the island (including player's own cities for self-trading)
- Tapping "Trade" opens a **dialog overlay** (showDialog pattern, same as BuildingUpgradeSheet)
- **Single-step send** — fill in resources, tap "Send Trade", done. No confirmation step.
- **Multiple resources per trade** — dialog shows all resource types with input for each
- **Sliders** per resource type (0 to available amount) for quantity input
- Show **sender's available amounts** next to each slider
- Show **recipient's warehouse capacity** and remaining space per resource (requires extra DB query)
- Show **estimated travel time** before sending ("Arrives in: Xh Ym" using existing distance formula)
- **Self-trading allowed** — players can send resources between their own cities
- Trade option appears for own cities on island screen (consistent UX)
- No label distinction — "Trade" for both self and other-player trades
- **New 'trade' movement_type** — add to CHECK constraint on unit_movements table
- Trade movements use **local_shipping** icon in movements list
- Trade icon color: **green (Colors.green)** — distinct from primary (attack) and grey (return)
- DB migration needed to extend movement_type CHECK constraint to include 'trade'

### Claude's Discretion
- Exact slider widget implementation (Material Slider vs custom)
- Dialog layout and spacing details
- Error message wording for rejection cases
- How to fetch recipient warehouse capacity (RPC vs direct query)
- Success feedback after trade sent (SnackBar text)

### Deferred Ideas (OUT OF SCOPE)
- Marketplace with buy/sell orders — v1.3+ feature
- Alliance trading bonuses — requires alliance system
- Trading post building level requirements for cargo capacity — post-Phase 15
- Trade history/log screen — future phase
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| TRAD-01 | User can send resources to another player's city via cargo ships (with travel time) | DB migration (movement_type constraint), new `send-trade` Edge Function, `TradeDialog` Flutter widget, `TradeRepository` invoker, movements_screen icon patch, `process_arrivals()` already delivers cargo JSONB — no changes needed |
</phase_requirements>

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `supabase_flutter` | project-pinned | Edge Function invocation, Realtime streams | All game mutations use `supabase.functions.invoke()` — INFR-02 |
| `flutter_riverpod` | project-pinned | State management, StreamProvider, FutureProvider | Established project-wide pattern |
| `flutter/material.dart` | SDK | Slider, showDialog, SnackBar | Native Flutter; no custom widget lib needed |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| PostgreSQL RPC (`deduct_resources`) | Supabase | Atomic resource deduction with insufficient-funds guard | Must be atomic — same pattern as `deduct_units` RPC used by `dispatch-units` |
| `CountdownTimerWidget` | lib/features/city/widgets | Live travel time countdown in dialog | Reuse directly; already handles future DateTime |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Material `Slider` | Custom numeric `TextField` | Slider prevents invalid input, more tactile; TextField mirrors dispatch_screen but allows out-of-range entry |
| Direct Supabase query for recipient resources | Supabase RPC | Direct query is simpler for read-only capacity check; RPC adds roundtrip overhead. Direct preferred here |

**Installation:** No new packages required. All dependencies already in `pubspec.yaml`.

---

## Architecture Patterns

### Recommended Project Structure
```
supabase/
├── functions/send-trade/index.ts          # NEW — mirrors dispatch-units
├── migrations/YYYYMMDD_trade_movement_type.sql  # NEW — extend CHECK constraint
lib/features/
├── trade/                                 # NEW feature folder
│   ├── data/trade_repository.dart        # invokeEdgeFunction + TradeException
│   ├── screens/trade_dialog.dart         # showTradeDialog() + _TradeDialogContent
│   └── providers/trade_providers.dart   # recipientResourcesProvider (FutureProvider)
├── movements/screens/movements_screen.dart  # PATCH — add 'trade' icon/color branch
├── map/screens/island_screen.dart         # PATCH — extend city tap to show "Trade" option
```

### Pattern 1: Edge Function — send-trade
**What:** POST endpoint that validates sender resources, warehouse capacity, deducts resources, inserts unit_movements row with movement_type='trade' and cargo JSONB.
**When to use:** All game state mutations go through Edge Functions (INFR-02).

Key structure copied from `dispatch-units`:
```typescript
// Source: supabase/functions/dispatch-units/index.ts
// 1. Parse body: origin_city_id, destination_city_id, cargo (Record<string,number>)
// 2. Authenticate via anon client, get user.id
// 3. Service-role admin client for mutations
// 4. Verify origin city ownership (.eq('owner_id', user.id))
// 5. Verify destination city exists (self-trade: allow same owner)
// 6. Fetch island coordinates for both cities
// 7. calcTravelMinutes(originIsland, destIsland) * DEV_SPEED_MULTIPLIER
// 8. Validate cargo amounts > 0, check sender has enough of each resource
// 9. Validate recipient warehouse won't overflow per resource type
// 10. Deduct resources via deduct_resources RPC (one call per resource)
// 11. Insert unit_movements with movement_type='trade', units={}, cargo=cargoJson
// 12. Return { success: true, arrive_at, travel_minutes }
```

**Trade movement insert:**
```typescript
// units field is empty object {} for trade movements (no military units)
await admin.from('unit_movements').insert({
  origin_city_id,
  destination_city_id,
  owner_id: user.id,
  units: {},              // trade movements carry no army units
  depart_at: departAt,
  arrive_at: arriveAt,
  movement_type: 'trade',
  cargo: cargoObject,    // e.g. {"wood": 500, "marble": 250}
});
```

### Pattern 2: DB Migration — extend movement_type CHECK constraint
**What:** ALTER TABLE to drop old CHECK constraint and add new one including 'trade'.

```sql
-- Source: supabase/migrations/20260312000001_add_movement_type_to_unit_movements.sql
-- Current constraint: CHECK (movement_type IN ('attack', 'return'))
-- New constraint: CHECK (movement_type IN ('attack', 'return', 'trade'))
ALTER TABLE public.unit_movements
  DROP CONSTRAINT IF EXISTS unit_movements_movement_type_check;

ALTER TABLE public.unit_movements
  ADD CONSTRAINT unit_movements_movement_type_check
  CHECK (movement_type IN ('attack', 'return', 'trade'));
```

### Pattern 3: TradeRepository
**What:** Repository class with `sendTrade()` method mirroring `MilitaryRepository.dispatchUnits()`. Throws `TradeException` on non-200.

```dart
// Source pattern: lib/features/military/data/military_repository.dart
class TradeException implements Exception {
  const TradeException(this.message);
  final String message;
}

class TradeRepository {
  Future<void> sendTrade({
    required String originCityId,
    required String destinationCityId,
    required Map<String, int> cargo,  // resource_type -> amount
  }) async {
    final response = await supabaseClient.functions.invoke(
      'send-trade',
      body: {
        'origin_city_id': originCityId,
        'destination_city_id': destinationCityId,
        'cargo': cargo,
      },
    );
    if (response.status != 200) {
      final data = response.data;
      String errorMessage = 'Trade failed';
      if (data is Map<String, dynamic>) {
        errorMessage = (data['error'] as String?) ?? errorMessage;
      }
      throw TradeException(errorMessage);
    }
  }
}
```

### Pattern 4: TradeDialog
**What:** `showDialog` popup with `StatefulWidget`, slider per resource type, capacity info rows, and travel time preview. Triggered from island screen city-tap context menu.

Structure mirrors `building_upgrade_sheet.dart`:
```dart
// Source pattern: lib/features/city/screens/building_upgrade_sheet.dart
Future<bool?> showTradeDialog(
  BuildContext context, {
  required String originCityId,
  required String destinationCityId,
  required String destinationCityName,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: _TradeDialogContent(
          originCityId: originCityId,
          destinationCityId: destinationCityId,
          destinationCityName: destinationCityName,
        ),
      ),
    ),
  );
}
```

The content widget is a `ConsumerStatefulWidget`:
- Watches `resourcesStreamProvider(originCityId)` for sender amounts (live)
- Fetches recipient resources + warehouse level via one-time FutureProvider for capacity display
- Maintains `Map<String, double> _sliderValues` (resource_type -> amount 0..available)
- Calculates travel time preview using same `calcTravelMinutes` formula (client-side)
- On submit: call `ref.read(tradeRepositoryProvider).sendTrade(...)`, show SnackBar, pop dialog

### Pattern 5: Island Screen — extend city tap
**What:** The existing `_showEnemyCityDialog()` only shows "Attack". Must be extended to also show "Trade" for all occupied slots. The own-city tap currently does `context.go('/city')` — must change to also show dialog.

```dart
// Current own-city tap (island_screen.dart line 226-227):
if (slot.ownerId == currentUserId) {
  context.go('/city');
} else if (slot.cityId != null) {
  _showEnemyCityDialog(context, ref, slot);
}

// After change:
if (slot.isOccupied && slot.cityId != null) {
  _showCityActionDialog(context, ref, slot);
}

// _showCityActionDialog replaces both paths — always shows dialog with:
// - "Go to City" (own only) or header info (others)
// - "Trade" button (all cities)
// - "Attack" button (enemy only, i.e. slot.ownerId != currentUserId)
```

### Pattern 6: Movements Screen — add 'trade' type
**What:** Minor patch to `_MovementCard.build()` in `movements_screen.dart`.

```dart
// Current (movements_screen.dart line 102-109):
Icon(
  movement.movementType == 'return'
      ? Icons.call_received
      : Icons.call_made,
  color: movement.movementType == 'return'
      ? Colors.grey.shade600
      : theme.colorScheme.primary,
)

// After:
Icon(
  _movementIcon(movement.movementType),
  color: _movementColor(movement.movementType, theme),
)

// Helpers:
IconData _movementIcon(String type) => switch (type) {
  'return' => Icons.call_received,
  'trade'  => Icons.local_shipping,
  _        => Icons.call_made,
};

Color _movementColor(String type, ThemeData theme) => switch (type) {
  'return' => Colors.grey.shade600,
  'trade'  => Colors.green,
  _        => theme.colorScheme.primary,
};
```

### Anti-Patterns to Avoid
- **Direct client DB write for resources:** Never `supabaseClient.from('city_resources').update(...)` from Flutter — all mutations through Edge Functions (INFR-02).
- **Non-atomic deduction order:** Validate all resources are available BEFORE deducting any. Deduct in a loop only after all validations pass (same lesson learned in dispatch-units).
- **Cargo with amount=0:** Filter out zero-amount entries before inserting cargo JSONB. Empty cargo `{}` should be inserted as `null`.
- **Same-city trade with movement_type check only:** The Edge Function must explicitly allow `origin_city_id == destination_city_id` for self-trade (dispatch-units rejects this — send-trade must NOT reject it).
- **Warehouse overflow per resource type:** Check each resource independently — sender might have enough wood but would overflow recipient's marble storage.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Travel time calculation | Custom distance formula | `calcTravelMinutes()` in `dispatch-units/index.ts` | Already tested, uses same formula as Dart `calcTravelMinutes` in unit_constants.dart — must stay in sync |
| Resource deduction with guard | Manual SELECT then UPDATE | New `deduct_resources` RPC (mirrors `deduct_units`) | Non-atomic SELECT+UPDATE allows race conditions; RPC uses single transaction |
| Cargo delivery on arrival | Custom arrival handler | Existing `process_arrivals()` SQL function | Already delivers `cargo` JSONB to `city_resources` — no changes needed |
| Realtime movement visibility | Custom polling | `allMovementsStreamProvider` + `UnitMovement` model | Trade rows auto-appear in movements list because `owner_id` filter matches |
| Warehouse capacity formula | Hardcoded constant | `warehouseCapacity(level)` from `resource_constants.dart` | Same formula used everywhere; keep centralized |

**Key insight:** `process_arrivals()` already handles cargo delivery — it checks `m.cargo IS NOT NULL` and does `UPDATE city_resources SET amount = amount + v_qty`. Trade cargo is structurally identical to pillage return cargo. Zero new SQL needed for delivery.

---

## Common Pitfalls

### Pitfall 1: Same-city dispatch rejection
**What goes wrong:** `dispatch-units` explicitly rejects `origin_city_id === destination_city_id` with a 400 error. `send-trade` must NOT copy this check — self-trading between own cities is allowed by design.
**Why it happens:** Pillaging own city is nonsensical; trading to own second city is valid.
**How to avoid:** Remove the origin/destination equality check when scaffolding `send-trade` from `dispatch-units`.

### Pitfall 2: Slider value range vs available amount
**What goes wrong:** `resourcesStreamProvider` emits live data. If the slider max is bound to the initial amount and resources tick upward between render and submit, the slider max is stale. Conversely if resources are spent elsewhere, slider max may exceed actual available.
**Why it happens:** Slider `max` is set at build time; resources are live.
**How to avoid:** Server-side validation in Edge Function is the authoritative gate. Client sliders show current amount as max (re-render on stream update). Accept minor UX glitch — server will reject if stale.
**Warning signs:** "Insufficient resource_type" error from server when slider was at max.

### Pitfall 3: Warehouse overflow check — current vs at-arrival amount
**What goes wrong:** Resources in transit from other sources may arrive before the trade. Client shows "enough space" but at arrival time warehouse is full.
**Why it happens:** Trade travel time can be minutes to hours; other deliveries happen in between.
**How to avoid:** Document this as accepted behavior (same as pillage loot overflow). Server checks current capacity at time of trade initiation only. Resources in excess of warehouse cap at arrival are silently lost — or capped to available space.
**Decision needed:** Does `process_arrivals()` need a cap, or is overflow accepted? Current implementation does `amount + v_qty` with no cap. Recommend adding cap in the Edge Function's server-side check at send-time; overflow at arrival is accepted as v1 behavior.

### Pitfall 4: units field must be valid JSONB (not NULL or omitted)
**What goes wrong:** `unit_movements.units` is NOT NULL in the schema. Trade movements have no army units. If you omit the field or pass `null`, the insert fails.
**Why it happens:** Schema was designed for military movements first.
**How to avoid:** Always pass `units: {}` (empty object) for trade movement inserts.

### Pitfall 5: movement_type CHECK constraint violation before migration
**What goes wrong:** If the Edge Function is deployed before the DB migration runs, inserts with `movement_type='trade'` fail at the CHECK constraint.
**Why it happens:** Supabase Edge Functions deploy independently from DB migrations.
**How to avoid:** DB migration MUST be run (via supabase migration push or local reset) before the Edge Function is tested. Plan the migration as Wave 0 step.

### Pitfall 6: Island screen own-city tap regression
**What goes wrong:** Changing own-city tap from `context.go('/city')` to open a dialog breaks the existing "go to my city" flow.
**Why it happens:** Adding Trade option requires restructuring the tap handler.
**How to avoid:** Include "Go to City" as the primary action in the new dialog for own cities. The dialog shows both "Go to City" and "Trade" options for own cities; only "Trade" for others.

---

## Code Examples

Verified patterns from existing source files:

### Deduct resources — RPC pattern (mirrors deduct_units in dispatch-units)
```typescript
// Source: supabase/functions/dispatch-units/index.ts (lines 204-213)
// dispatch-units uses deduct_units RPC — send-trade needs deduct_resources RPC:
const { error: deductError } = await admin.rpc('deduct_resources', {
  p_city_id: origin_city_id,
  p_resource_type: resourceType,
  p_amount: amount,
});
if (deductError) {
  return errorResponse(`Insufficient ${resourceType}`, 400);
}
```

The `deduct_resources` RPC must be created in the DB migration using the same pattern as `deduct_units`:
```sql
CREATE OR REPLACE FUNCTION public.deduct_resources(
  p_city_id uuid,
  p_resource_type text,
  p_amount numeric
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  UPDATE public.city_resources
  SET amount = amount - p_amount, updated_at = NOW()
  WHERE city_id = p_city_id
    AND resource_type = p_resource_type
    AND amount >= p_amount;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Insufficient %', p_resource_type;
  END IF;
END;
$$;
```

### Warehouse capacity check in Edge Function
```typescript
// Recipient's warehouse level query + capacity check
const { data: recipientBuilding } = await admin
  .from('city_buildings')
  .select('level')
  .eq('city_id', destination_city_id)
  .eq('building_type', 'warehouse')
  .maybeSingle();

const warehouseLevel = recipientBuilding?.level ?? 0;
const capacity = 500 * Math.pow(1.5, warehouseLevel);  // warehouseCapacity formula

// Per resource type — check current amount + trade amount <= capacity
const { data: recipientResource } = await admin
  .from('city_resources')
  .select('amount')
  .eq('city_id', destination_city_id)
  .eq('resource_type', resourceType)
  .maybeSingle();

const currentAmount = recipientResource?.amount ?? 0;
if (currentAmount + tradeAmount > capacity) {
  return errorResponse(`Recipient warehouse would overflow for ${resourceType}`, 400);
}
```

### Slider per resource type — Flutter
```dart
// Source pattern: lib/features/city/screens/building_upgrade_sheet.dart _TavernWineSlider
// For each ResourceType in ResourceType.values (excluding gold, wine if desired):
Slider(
  value: _sliderValues[type.value] ?? 0,
  min: 0,
  max: (senderAmount).clamp(0, senderAmount),
  divisions: senderAmount > 0 ? senderAmount.toInt().clamp(1, 500) : 1,
  label: (_sliderValues[type.value] ?? 0).toInt().toString(),
  onChanged: senderAmount > 0
      ? (v) => setState(() => _sliderValues[type.value] = v)
      : null,
),
```

### Travel time preview (client-side)
```dart
// Source: lib/core/constants/unit_constants.dart (calcTravelMinutes)
// Display in dialog before sending — no server round-trip needed:
final travelMinutes = calcTravelMinutes(originIsland, destIsland);
final arriveAt = DateTime.now().add(Duration(minutes: travelMinutes));
// Then pass to CountdownTimerWidget or format as "Xh Ym"
```

### Island screen city tap — new unified handler
```dart
// Source: lib/features/map/screens/island_screen.dart _IslandDetailBody.onTap
// Replace the current branching onTap with _showCityActionDialog for all occupied slots:
onTap: () {
  if (slot == null || !slot.isOccupied) return;
  _showCityActionDialog(context, ref, slot, currentUserId);
},
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Attack-only city context menu | "Attack" + "Trade" context menu | Phase 15 | Own cities also show dialog instead of direct navigation |
| movement_type IN ('attack','return') | movement_type IN ('attack','return','trade') | Phase 15 migration | Enables trade row storage and display |
| Movements show attack/return icons only | Movements show attack/return/trade icons with color coding | Phase 15 | Green trade rows visually distinct |

**No deprecated patterns** — this phase only extends existing infrastructure.

---

## Open Questions

1. **Warehouse overflow at arrival time**
   - What we know: `process_arrivals()` does `amount + v_qty` with no cap check
   - What's unclear: Should excess resources be silently lost or clamped to capacity?
   - Recommendation: Clamp to capacity in `process_arrivals()` for trade movements. Add a check: `LEAST(amount + v_qty, capacity)`. Server-side send-time check is best effort only.

2. **Resource types available for trading**
   - What we know: `ResourceType` enum has 6 types: wood, marble, crystal, sulfur, gold, wine
   - What's unclear: Should gold and wine be tradeable? Gold is currency; wine is consumed by Tavern.
   - Recommendation: Planner decides. Simplest: allow all 6 types. Game-design concern: sending gold could be exploited. Suggest excluding gold from trade dialog (4 tradeable: wood, marble, crystal, sulfur; wine optional).

3. **What to show for trade movements in `units` display row**
   - What we know: `movements_screen.dart` line 136-143 renders units summary from `movement.units.entries`
   - What's unclear: Trade movements have `units = {}`, so the units row will be empty/blank
   - Recommendation: In `_MovementCard`, show "Cargo shipment" text when `movementType == 'trade'` instead of the units summary.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Flutter widget tests + integration tests (flutter test) |
| Config file | None detected — standard Flutter test runner |
| Quick run command | `flutter test test/ --name "trade"` |
| Full suite command | `flutter test test/` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TRAD-01 | Trade dialog opens from island screen | Widget test | `flutter test test/features/trade/trade_dialog_test.dart -x` | ❌ Wave 0 |
| TRAD-01 | Sliders clamp to available amount | Widget test | `flutter test test/features/trade/trade_dialog_test.dart -x` | ❌ Wave 0 |
| TRAD-01 | Send button disabled when all sliders at 0 | Widget test | `flutter test test/features/trade/trade_dialog_test.dart -x` | ❌ Wave 0 |
| TRAD-01 | TradeRepository invokes send-trade Edge Function | Unit test | `flutter test test/features/trade/trade_repository_test.dart -x` | ❌ Wave 0 |
| TRAD-01 | movements_screen shows green local_shipping icon for trade | Widget test | `flutter test test/features/movements/movements_screen_test.dart -x` | ❌ Wave 0 |
| TRAD-01 | Edge Function validation (insufficient resources) | Manual / integration | n/a — server-side | Manual |
| TRAD-01 | Edge Function validation (warehouse overflow) | Manual / integration | n/a — server-side | Manual |
| TRAD-01 | Cargo delivered on arrival (process_arrivals) | Manual / DB test | n/a — existing SQL function | Manual |

### Sampling Rate
- **Per task commit:** `flutter test test/features/trade/ --name "trade"`
- **Per wave merge:** `flutter test test/`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/features/trade/trade_dialog_test.dart` — covers TRAD-01 UI behavior
- [ ] `test/features/trade/trade_repository_test.dart` — covers repository pattern
- [ ] `test/features/movements/movements_screen_test.dart` — covers trade icon display

*(No new framework install needed — `flutter test` already available)*

---

## Sources

### Primary (HIGH confidence)
- Direct source read: `supabase/functions/dispatch-units/index.ts` — Edge Function pattern, auth, travel time, movement insert
- Direct source read: `supabase/migrations/20260315000001_pillage_schema_and_functions.sql` — `process_arrivals()` cargo delivery, `deduct_units` RPC pattern
- Direct source read: `supabase/migrations/20260312000001_add_movement_type_to_unit_movements.sql` — CHECK constraint to extend
- Direct source read: `lib/features/city/screens/building_upgrade_sheet.dart` — dialog pattern, Slider usage
- Direct source read: `lib/features/map/screens/island_screen.dart` — city tap handler to extend
- Direct source read: `lib/features/movements/screens/movements_screen.dart` — movement icon/color code to patch
- Direct source read: `lib/features/military/data/military_repository.dart` — repository + exception pattern
- Direct source read: `lib/core/constants/resource_constants.dart` — ResourceType enum, warehouseCapacity formula
- Direct source read: `lib/features/military/models/unit_movement.dart` — cargo field, movementType field

### Secondary (MEDIUM confidence)
- Direct source read: `lib/features/movements/providers/movements_provider.dart` — cityNameProvider, allMovementsStreamProvider
- Direct source read: `lib/features/city/models/city_resource.dart` — CityResource model structure
- Direct source read: `lib/features/city/providers/resources_provider.dart` — resourcesStreamProvider pattern

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries already in use, no new dependencies
- Architecture: HIGH — all patterns verified by reading actual source files
- DB migration: HIGH — exact constraint syntax verified from existing migration
- Edge Function: HIGH — scaffold is a direct clone of dispatch-units with known-working pattern
- Pitfalls: HIGH — derived from reading actual dispatch-units, process_arrivals, and island screen code

**Research date:** 2026-03-16
**Valid until:** 2026-04-16 (stable Flutter + Supabase project, low churn risk)
