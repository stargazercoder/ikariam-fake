# Phase 27: Battle UI Improvements - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning
**Source:** Auto-generated with codebase analysis

<domain>
## Phase Boundary

Battle reports show what resources were pillaged, and the dispatch dialog shows how much loot the selected army can carry. Two requirements: BTUI-01 (pillage in reports) and BTUI-02 (carry capacity in dispatch).

**Critical finding:** BTUI-01 is ALREADY FULLY IMPLEMENTED. `PillageResultCard` widget exists and is rendered in both `battle_detail_screen.dart` (full breakdown with ResourceBadge per resource) and `battles_screen.dart` (summary line with +W +M +C +S format). No new code needed for BTUI-01 — only verification that it works correctly.

Phase 27 work is therefore focused entirely on BTUI-02: adding a live carry capacity indicator to the dispatch dialog.

</domain>

<decisions>
## Implementation Decisions

### BTUI-01: Pillage in battle reports (ALREADY DONE)
- `PillageResultCard` widget already shows per-resource pillage breakdown in battle detail screen
- `_BattleTile` in battles list screen already shows pillage summary line (+W +M +C +S)
- Attacker sees green "Resources gained:", defender sees red "Resources lost:"
- No new code needed — verify existing implementation satisfies the requirement

### BTUI-02: Carry capacity in dispatch dialog
- Add a live carry capacity summary row below the unit selection section in `dispatch_screen.dart`
- Formula: `selectedCargoShips × 500` (matches SQL `v_cargo_cap := v_surviving_cs * 500`)
- Define `cargoCapacityPerShip = 500` as a Dart constant in `unit_constants.dart` (currently only in SQL)
- Display format: "Carry Capacity: X / Y" where X = current total loot capacity, Y = max possible (all available cargo ships × 500)
- Show cargo ship icon (Icons.directions_boat) + capacity value
- When no cargo ships are selected: show "0" capacity with a subtle warning text ("No cargo ships — army cannot carry loot")
- Updates live as user changes cargo ship quantity in the dispatch form
- Only cargo ships contribute to carry capacity — land units do not carry loot

### Claude's Discretion
- Exact widget styling and spacing for the carry capacity row
- Whether to show capacity as a progress bar or plain text
- Color coding for capacity states (zero, partial, full)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Dispatch UI (primary modification target)
- `lib/features/military/screens/dispatch_screen.dart` — Current dispatch screen with unit selection, `_selectedUnits` map, and dispatch button

### Unit constants (carry capacity formula source)
- `lib/core/constants/unit_constants.dart` — UnitType enum, all unit stats; cargo capacity constant to be added here

### Pillage backend (carry capacity formula reference)
- `supabase/migrations/20260315000001_pillage_schema_and_functions.sql` — `v_cargo_cap := v_surviving_cs * 500` formula, pillage ratio calculation

### Battle report UI (BTUI-01 verification)
- `lib/features/battles/screens/battle_detail_screen.dart` — Battle detail with PillageResultCard
- `lib/features/battles/screens/battles_screen.dart` — Battle list with pillage summary
- `lib/features/battles/screens/widgets/pillage_result_card.dart` — Per-resource pillage breakdown widget

### Resource display
- `lib/shared/widgets/resource_badge.dart` — ResourceBadge widget (may be used in capacity display)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `_selectedUnits` getter in `_DispatchScreenState`: already computes Map<String, int> of selected units — can extract cargo_ship count from this
- `unitTypeIcons[UnitType.cargoShip]` = `Icons.directions_boat` — use for cargo capacity indicator
- `unitTypeColors[UnitType.cargoShip]` = `Color(0xFF607D8B)` blue-grey — use for capacity indicator color
- `UnitType.cargoShip.dbName` = `'cargo_ship'` — key to look up in selected units map

### Established Patterns
- `setState(() {})` on `onChanged` in dispatch rows — same pattern triggers capacity recalculation
- `_UnitDispatchRow` calls `onChanged` callback on quantity change — capacity updates automatically through build cycle
- Card-based UI with consistent padding (16px) and section headings

### Integration Points
- Capacity row goes between unit selection list and Dispatch button in `dispatch_screen.dart` build method
- `_dispatchControllers['cargo_ship']` text value provides live cargo ship count
- No backend changes needed — carry capacity is a pure client-side calculation

</code_context>

<specifics>
## Specific Ideas

- Carry capacity only counts cargo ships (500 per ship) — this matches the backend formula exactly
- Display should make it obvious when player has zero cargo ships selected (cannot carry any loot)
- BTUI-01 verification should confirm pillage amounts appear in both list and detail views

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 27-battle-ui-improvements*
*Context gathered: 2026-03-21 via auto mode with codebase analysis*
