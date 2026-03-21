# Phase 27: Battle UI Improvements - Research

**Researched:** 2026-03-21
**Domain:** Flutter UI — dispatch screen carry capacity widget + battle report pillage verification
**Confidence:** HIGH

## Summary

Phase 27 is a narrow, well-bounded UI phase with two requirements. BTUI-01 is already fully
implemented: `PillageResultCard` renders per-resource pillage breakdowns in `battle_detail_screen.dart`
and `_BattleTile` renders a compact summary line (+W +M +C +S) in `battles_screen.dart`. The only
work needed for BTUI-01 is verification that the existing implementation satisfies the acceptance
criteria.

All genuine implementation effort is in BTUI-02: adding a live carry capacity row to
`dispatch_screen.dart`. The capacity formula is `selectedCargoShips × 500`, identical to the
SQL constant `v_cargo_cap := v_surviving_cs * 500` in the pillage migration. The screen already
manages state correctly — `_selectedUnits` extracts the `cargo_ship` key from `_dispatchControllers`,
and every `onChanged` on a unit row already calls `setState(() {})`, so the capacity widget will
update reactively with zero additional plumbing.

No backend changes are required. The constant `500` must be extracted to `unit_constants.dart` as a
Dart const so the number has a single source of truth matching the SQL.

**Primary recommendation:** Add `cargoCapacityPerShip = 500` to `unit_constants.dart`, then insert
a `_CargoCapacityRow` stateless widget between the unit list and the Dispatch button in
`dispatch_screen.dart`, computing capacity from `_dispatchControllers['cargo_ship']`.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- BTUI-01 is ALREADY FULLY IMPLEMENTED — only verification needed, no new code.
- BTUI-02: carry capacity row goes below the unit selection section in `dispatch_screen.dart`.
- Formula: `selectedCargoShips × 500` (matches SQL `v_cargo_cap := v_surviving_cs * 500`).
- Define `cargoCapacityPerShip = 500` as a Dart constant in `unit_constants.dart`.
- Display format: "Carry Capacity: X / Y" where X = current total capacity, Y = max possible (all available cargo ships × 500).
- Show cargo ship icon (`Icons.directions_boat`) + capacity value.
- When no cargo ships are selected: show "0" capacity with warning text ("No cargo ships — army cannot carry loot").
- Updates live as user changes cargo ship quantity — triggered via existing `setState(() {})` / `onChanged` cycle.
- Only cargo ships contribute to carry capacity — land units do not carry loot.

### Claude's Discretion
- Exact widget styling and spacing for the carry capacity row.
- Whether to show capacity as a progress bar or plain text.
- Color coding for capacity states (zero, partial, full).

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| BTUI-01 | Battle report shows pillaged resource amounts broken down by resource type | `PillageResultCard` already renders per-resource breakdown in detail view; `_BattleTile._pillageSummary` renders compact summary in list view. Verification confirms the implementation is complete. |
| BTUI-02 | Dispatch dialog shows total carry capacity (max lootable amount) of selected units, updating live as units are selected | `_dispatchControllers['cargo_ship']` provides live count; `setState(() {})` already called on every unit change; new `_CargoCapacityRow` widget reads the controller and renders capacity text. |
</phase_requirements>

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter | SDK | UI rendering | Project base |
| flutter_riverpod | project version | State management | Established project pattern |
| flutter/material.dart | SDK | Material widgets (Card, Icon, Text) | Used throughout project |

No new dependencies are required. This phase uses only existing project libraries.

**Installation:** No new packages needed.

---

## Architecture Patterns

### Recommended Project Structure

No new files or directories are needed. All changes are within existing files:

```
lib/
├── core/constants/unit_constants.dart   # Add cargoCapacityPerShip = 500
└── features/military/screens/
    └── dispatch_screen.dart              # Add _CargoCapacityRow widget + insertion point
```

### Pattern 1: Stateless Widget with Controller Read

The carry capacity indicator is a stateless widget that receives the dispatch controllers map
and the roster as parameters. It reads `_dispatchControllers['cargo_ship']?.text` to get the
currently entered quantity, multiplies by `cargoCapacityPerShip`, and renders the result.

**What:** Pure display widget — no state of its own.
**When to use:** Any display-only derived value computed from parent state.

```dart
// Inserted between unit list and Dispatch button in dispatch_screen.dart build():
_CargoCapacityRow(
  controllers: _dispatchControllers,
  roster: roster,
),
```

```dart
// The widget itself (new private class at bottom of dispatch_screen.dart):
class _CargoCapacityRow extends StatelessWidget {
  const _CargoCapacityRow({
    required this.controllers,
    required this.roster,
  });

  final Map<String, TextEditingController> controllers;
  final List<CityUnit> roster;  // needed to know max available cargo ships

  int get _selectedCargoShips {
    final ctrl = controllers[UnitType.cargoShip.dbName];  // 'cargo_ship'
    return int.tryParse(ctrl?.text ?? '0') ?? 0;
  }

  int get _maxCargoShips {
    try {
      return roster.firstWhere(
        (u) => u.unitType == UnitType.cargoShip.dbName,
      ).quantity;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedCargoShips;
    final maxShips = _maxCargoShips;
    final capacity = selected * cargoCapacityPerShip;       // from unit_constants.dart
    final maxCapacity = maxShips * cargoCapacityPerShip;
    final hasNoShips = selected == 0;
    // ... render Card with Icon + "Carry Capacity: X / Y" text + optional warning
  }
}
```

### Pattern 2: Constant Co-location in unit_constants.dart

All unit-related numeric constants live in `unit_constants.dart` alongside the `UnitType` enum.
The file already has `baseMinutesPerGridUnit` as a precedent for game-mechanic constants.

```dart
// Source: lib/core/constants/unit_constants.dart (existing pattern)
/// Base minutes per grid unit of travel distance.
const int baseMinutesPerGridUnit = 2;

// New constant to add:
/// Carry capacity per cargo ship (resources).
/// Keep in sync with v_cargo_cap := v_surviving_cs * 500 in pillage SQL.
const int cargoCapacityPerShip = 500;
```

### Pattern 3: BTUI-01 Verification — Conditional Render Guards

The existing `PillageResultCard` renders nothing when `pillageResult` is null or empty (via
`SizedBox.shrink()`). The battle detail screen guards its render:

```dart
// Source: lib/features/battles/screens/battle_detail_screen.dart line 79
if (!battle.isActive && battle.pillageResult != null) ...[
  PillageResultCard(
    pillageResult: battle.pillageResult,
    isAttacker: isAttacker,
  ),
  ...
],
```

The battles list screen guards its summary line:

```dart
// Source: lib/features/battles/screens/battles_screen.dart line 206
if (battle.pillageResult != null &&
    battle.pillageResult!.values.any((v) => v > 0))
  // renders _pillageSummary text
```

Verification must confirm: (a) `battle.pillageResult` is non-null after an attacker victory,
(b) at least one resource value is > 0, and (c) the `isAttacker` flag is computed correctly from
`battle.attackerId == user?.id`.

### Anti-Patterns to Avoid

- **Reading controller text outside build:** `_dispatchControllers` values must be read during `build()` (after `setState` has triggered a rebuild), not cached between builds.
- **Adding state to the capacity widget:** The parent `_DispatchScreenState` already owns the controllers and calls `setState` on every change. A stateful capacity widget would be redundant.
- **Hard-coding 500 inline:** The magic number must be a named constant — the SQL function uses the same value and both must stay in sync if it ever changes.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Live update on text change | Manual listener/stream on controller | Existing `onChanged: () => setState(() {})` pattern in `_UnitDispatchRow` | Parent already rebuilds on every keystroke — capacity widget gets a fresh controller read for free |
| Resource display in PillageResultCard | Custom resource icon | `ResourceBadge(type: type, radius: 10)` from `lib/shared/widgets/resource_badge.dart` | Already used in `_ResourceRow` inside `PillageResultCard`; consistent visual language |
| Capacity number formatting | Custom formatter | Dart's default `int.toString()` | Amounts are integer resources; no decimal places needed |

**Key insight:** The entire reactivity model for BTUI-02 is already in place. The capacity widget
is a pure render concern — no new state management is needed.

---

## Common Pitfalls

### Pitfall 1: Max Capacity Uses Roster, Not Controller Max
**What goes wrong:** Showing "max capacity" as `int.parse(maxText) * 500` where `maxText` comes
from the controller's helper text (`max ${unit.quantity}`) instead of the `CityUnit.quantity` field.
**Why it happens:** The controller only stores the dispatch quantity, not the available maximum.
**How to avoid:** Always read `roster.firstWhere((u) => u.unitType == 'cargo_ship').quantity` for
the available maximum. Pass `roster` to `_CargoCapacityRow` alongside `controllers`.
**Warning signs:** Y in "Carry Capacity: X / Y" shows 0 even when player has cargo ships.

### Pitfall 2: Null-Safe Controller Access
**What goes wrong:** `controllers['cargo_ship']!.text` throws if no cargo ship row exists in the
roster (player has no shipyard or no cargo ships trained).
**Why it happens:** `_dispatchControllers` is only populated via `_syncControllers(roster)` — if
cargo_ship is not in the roster, the key does not exist.
**How to avoid:** Always use `controllers['cargo_ship']?.text ?? '0'` with null-safe access.
**Warning signs:** Null pointer exception when player opens dispatch without any cargo ships.

### Pitfall 3: isAttacker Flag in Battle Reports
**What goes wrong:** Pillage card shows "Resources gained" to the defender or vice versa.
**Why it happens:** `isAttacker` is derived from `battle.attackerId == user?.id`, but `user` may
be null during async auth resolution.
**How to avoid:** Use `battle.attackerId == (user?.id ?? '')` — the empty string fallback means
`isAttacker` defaults to `false` (defender view) when auth is still loading, which is the safer
default (no false "Resources gained" flash).
**Warning signs:** Green "Resources gained:" text visible to defenders on slow connections.

### Pitfall 4: Roster Empty Race Condition in Dispatch Screen
**What goes wrong:** Capacity row renders with `maxCapacity = 0` momentarily while roster loads.
**Why it happens:** `roster` is set from `rosterAsync.whenOrNull(data:...)` which returns `[]`
during loading.
**How to avoid:** When `maxShips == 0` and `selected == 0`, show a neutral placeholder (e.g.,
"—") rather than "0 / 0", OR simply hide the capacity row when roster is empty (roster empty
state already shows "No units available" card, so the capacity row is irrelevant anyway).
**Warning signs:** "Carry Capacity: 0 / 0" visible during initial load.

---

## Code Examples

Verified patterns from existing codebase:

### Reading cargo ship count from controllers
```dart
// Pattern from dispatch_screen.dart lines 71-78 (_selectedUnits getter)
Map<String, int> get _selectedUnits {
  final result = <String, int>{};
  for (final entry in _dispatchControllers.entries) {
    final qty = int.tryParse(entry.value.text) ?? 0;
    if (qty > 0) result[entry.key] = qty;
  }
  return result;
}

// For cargo ship specifically:
final selectedCs = int.tryParse(
  _dispatchControllers[UnitType.cargoShip.dbName]?.text ?? '0',
) ?? 0;
```

### Existing constant pattern in unit_constants.dart
```dart
// Source: lib/core/constants/unit_constants.dart line 177-178
/// Base minutes per grid unit of travel distance.
const int baseMinutesPerGridUnit = 2;

// New constant follows same pattern:
/// Carry capacity per cargo ship (resources).
/// Keep in sync with v_cargo_cap := v_surviving_cs * 500 in pillage SQL.
const int cargoCapacityPerShip = 500;
```

### Insertion point in dispatch_screen.dart build()
```dart
// dispatch_screen.dart lines 209-229 — the gap between unit list and Dispatch button:
const SizedBox(height: 20),

// INSERT HERE:
if (roster.isNotEmpty) ...[
  _CargoCapacityRow(
    controllers: _dispatchControllers,
    roster: roster,
  ),
  const SizedBox(height: 16),
],

// Dispatch button (existing):
ElevatedButton.icon(
  onPressed: _canDispatch ? _dispatch : null,
  ...
```

### Cargo ship icon + color (from unit_constants.dart)
```dart
// Source: lib/core/constants/unit_constants.dart lines 250, 230
unitTypeIcons[UnitType.cargoShip]  // Icons.directions_boat
unitTypeColors[UnitType.cargoShip] // Color(0xFF607D8B) — blue-grey
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Magic number 500 in SQL only | Dart const + SQL in sync | Phase 27 (now) | Single source of truth, prevents drift |

**No deprecated patterns apply to this phase.**

---

## Open Questions

1. **Progress bar vs plain text for capacity display**
   - What we know: User decision left to Claude's discretion.
   - What's unclear: Whether a progress bar (LinearProgressIndicator) or plain "X / Y" text is clearer.
   - Recommendation: Plain text with color coding is simpler and consistent with the existing card-based UI. A progress bar adds visual weight without clear benefit for a single-resource indicator. Use plain text with three color states: grey (no ships selected), orange (some ships, capacity > 0), green (capacity > 0 with confirmation framing). This matches the established color vocabulary (green = positive outcome, orange = warning/partial).

2. **Visibility when no cargo ships in roster**
   - What we know: `_syncControllers` only adds entries for units present in the roster.
   - What's unclear: Whether to show the capacity row at all when roster has no cargo ships.
   - Recommendation: Hide the row entirely when `maxShips == 0` (no cargo ships available in roster). A zero-capacity row with a warning to train cargo ships is out-of-scope for BTUI-02 and would clutter the dispatch form for pure land-unit dispatches.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (Flutter SDK built-in) |
| Config file | pubspec.yaml dev_dependencies |
| Quick run command | `flutter test test/unit/unit_constants_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BTUI-01 | `PillageResultCard` renders per-resource breakdown; `_pillageSummary` formats +W +M +C +S | unit | `flutter test test/unit/battle_models_test.dart` | ✅ (partial — model tests exist; widget behavior is manual verify) |
| BTUI-01 | Attacker sees green "Resources gained:", defender sees red "Resources lost:" | widget | `flutter test test/widget/` (new test file needed) | ❌ Wave 0 |
| BTUI-02 | `cargoCapacityPerShip = 500` constant exists and equals 500 | unit | `flutter test test/unit/unit_constants_test.dart` | ✅ (file exists, new test case needed) |
| BTUI-02 | Capacity calculation: N ships × 500 = correct capacity | unit | `flutter test test/unit/unit_constants_test.dart` | ✅ (file exists, new test case needed) |
| BTUI-02 | Capacity row shows 0 and warning when 0 cargo ships selected | widget | `flutter test test/widget/` (new test file needed) | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/unit/unit_constants_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/widget/pillage_result_card_test.dart` — covers BTUI-01 attacker/defender label rendering
- [ ] `test/widget/dispatch_capacity_test.dart` — covers BTUI-02 carry capacity row render states (zero ships, some ships)

*(Existing `test/unit/unit_constants_test.dart` will receive new test cases for the `cargoCapacityPerShip` constant — no new file needed for that.)*

---

## Sources

### Primary (HIGH confidence)
- `lib/features/military/screens/dispatch_screen.dart` — Full screen code reviewed; `_selectedUnits`, `_dispatchControllers`, `setState` pattern confirmed
- `lib/core/constants/unit_constants.dart` — `UnitType.cargoShip.dbName`, `unitTypeIcons`, `unitTypeColors` confirmed; no existing cargo capacity constant
- `lib/features/battles/screens/widgets/pillage_result_card.dart` — Full widget reviewed; already complete
- `lib/features/battles/screens/battle_detail_screen.dart` — Conditional render guard confirmed at line 79
- `lib/features/battles/screens/battles_screen.dart` — `_pillageSummary` method confirmed at line 231
- `lib/features/battles/models/battle.dart` — `pillageResult: Map<String, int>?` field confirmed
- `supabase/migrations/20260315000001_pillage_schema_and_functions.sql` — referenced in CONTEXT.md; formula `v_cargo_cap := v_surviving_cs * 500` is the source of truth for the 500 constant
- `.planning/phases/27-battle-ui-improvements/27-CONTEXT.md` — All locked decisions, canonical refs, code context

### Secondary (MEDIUM confidence)
- `test/unit/unit_constants_test.dart` — Existing test file structure confirmed; pattern for adding new constant tests is clear
- `test/widget/barracks_screen_test.dart` — Widget test stub pattern confirmed (flutter_test, testWidgets, skip: true for Wave 0 gaps)

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — No new dependencies; all libraries are existing project dependencies
- Architecture: HIGH — Exact insertion point, widget signature, and constant location confirmed by reading source files
- Pitfalls: HIGH — All pitfalls derived from reading the actual code (null-safe controller access, roster-based max, isAttacker null guard)

**Research date:** 2026-03-21
**Valid until:** 2026-04-20 (stable Flutter/Dart patterns; no time-sensitive ecosystem concerns)
