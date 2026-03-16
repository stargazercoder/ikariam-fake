# Phase 15: Resource Trading - Context

**Gathered:** 2026-03-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Players can send resources to any other player's city (or their own cities) using cargo ships that travel in real time. Resources are deducted immediately from sender, delivered on arrival. Both sender and recipient see in-transit cargo in their movement lists (Phase 14 infrastructure).

</domain>

<decisions>
## Implementation Decisions

### Trade Initiation Flow
- Trade is initiated from **island screen city tap** — tap another city, context menu shows "Attack" and "Trade" options
- Trade option appears for **all cities** on the island (including player's own cities for self-trading)
- Tapping "Trade" opens a **dialog overlay** (showDialog pattern, same as BuildingUpgradeSheet)
- **Single-step send** — fill in resources, tap "Send Trade", done. No confirmation step.

### Resource Selection UX
- **Multiple resources per trade** — dialog shows all resource types with input for each
- **Sliders** per resource type (0 to available amount) for quantity input
- Show **sender's available amounts** next to each slider
- Show **recipient's warehouse capacity** and remaining space per resource (requires extra DB query)
- Show **estimated travel time** before sending ("Arrives in: Xh Ym" using existing distance formula)

### Self-Trading Policy
- **Self-trading allowed** — players can send resources between their own cities
- Trade option appears for own cities on island screen (consistent UX)
- No label distinction — "Trade" for both self and other-player trades

### Trade Movement Type
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

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Trade mechanics
- `supabase/functions/dispatch-units/index.ts` — Travel time calculation (calcTravelMinutes), Edge Function pattern, auth validation
- `supabase/migrations/20260315000001_pillage_schema_and_functions.sql` — cargo JSONB column on unit_movements, process_arrivals() cargo delivery logic
- `supabase/migrations/20260312000001_add_movement_type_to_unit_movements.sql` — movement_type column, CHECK constraint to extend

### Existing patterns
- `lib/features/military/screens/dispatch_screen.dart` — Form input pattern for sending things from cities
- `lib/features/city/screens/building_upgrade_sheet.dart` — Dialog overlay pattern (showDialog with validation)
- `lib/features/military/data/military_repository.dart` — Repository + Edge Function invocation pattern (dispatchUnits)

### Resource system
- `lib/core/constants/resource_constants.dart` — ResourceType enum, warehouseCapacity(level) formula
- `lib/features/city/models/city_resource.dart` — CityResource model
- `lib/features/city/providers/resources_provider.dart` — resourcesProvider stream

### Movement visibility (Phase 14 — no changes needed)
- `lib/features/movements/screens/movements_screen.dart` — _MovementCard with cargo display, movement type icons
- `lib/features/movements/providers/movements_provider.dart` — allMovementsStreamProvider

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `UnitMovement` model: already has `cargo` field (Map<String, int>?) and `movementType` field — trade cargo uses same structure
- `CountdownTimerWidget`: live ETA countdown — reuse in trade dialog for travel time preview
- `cityNameProvider`: FutureProvider.family for city name lookup — reuse in trade dialog header
- `allMovementsStreamProvider`: already streams all movements including cargo — trade movements auto-visible
- `process_arrivals()` SQL function: already handles cargo delivery to city_resources on arrival
- `warehouseCapacity(level)` in resource_constants.dart: capacity formula for overflow validation

### Established Patterns
- Edge Function pattern: POST with JSON body, auth validation, CORS headers, error response (dispatch-units, train-units, upgrade-building)
- Repository pattern: method calls Edge Function, throws typed exception, UI catches for SnackBar (MilitaryRepository.dispatchUnits)
- Dialog pattern: showDialog with StatefulBuilder, _isLoading state, validation checks, async call on confirm (BuildingUpgradeSheet)
- Resource deduction: immediate deduct on send, deliver on arrival (pillage precedent)
- JSONB cargo: `{"wood": 500, "marble": 250}` — immutable after creation

### Integration Points
- Island screen city tap: extend existing tap handler to show "Attack" + "Trade" context menu
- unit_movements table: new rows with movement_type='trade' + cargo JSONB
- movements_screen.dart: needs minor update to show local_shipping icon + green color for 'trade' type
- process_arrivals(): no changes needed — already delivers cargo JSONB to city_resources

</code_context>

<specifics>
## Specific Ideas

- Trade dialog should feel like the existing BuildingUpgradeSheet — compact dialog overlay, not a full screen
- Sliders for resource amounts (not text fields) — more tactile and prevents invalid input
- Green icon for trade movements makes them visually distinct and "friendly" vs attack red and return grey

</specifics>

<deferred>
## Deferred Ideas

- Marketplace with buy/sell orders — v1.3+ feature
- Alliance trading bonuses — requires alliance system
- Trading post building level requirements for cargo capacity — post-Phase 15
- Trade history/log screen — future phase

</deferred>

---

*Phase: 15-resource-trading*
*Context gathered: 2026-03-16*
