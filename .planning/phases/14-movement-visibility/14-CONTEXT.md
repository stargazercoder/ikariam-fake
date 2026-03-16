# Phase 14: Movement Visibility - Context

**Gathered:** 2026-03-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Players can see all their armies and cargo currently in transit with full context (destination city name, live ETA countdown, unit composition, and carried resources). A dedicated Movements screen accessible from bottom navigation shows all movements across all cities. Creating new movement types or trade cargo is out of scope — this phase displays existing movement data.

</domain>

<decisions>
## Implementation Decisions

### Movement list location & navigation
- Dedicated Movements screen — new screen showing ALL movements across all player's cities
- Accessible via new tab in MainShellScreen bottom navigation bar
- Global view (not per-city) — streams all movements owned by the current player
- Sorted by ETA (soonest arrival first)

### Movement row information
- Full unit breakdown per row: show every unit type and quantity (e.g., "50 hoplite, 20 archer, 10 cavalry")
- Cargo (pillage loot / trade resources) displayed inline with movement row using resource icons + amounts
- Destination city names resolved from IDs (not raw UUIDs) — requires city name lookup/join
- Live countdown timer for ETA (ticking: "3m 24s → 3m 23s...") — reuse existing CountdownTimerWidget
- Movement type indicator: attack (⚔) vs return (↩) based on `movement_type` column

### Real-time update behavior
- Auto-remove movements from list when army arrives (Realtime subscription picks up DELETE automatically)
- New dispatches appear immediately via Supabase Realtime subscription (same pattern as existing unitMovementsProvider)
- No "arrived" transition state — movement simply disappears when process_arrivals() deletes the row

### Empty & edge states
- Empty state: simple text message "No armies in transit" — minimal, consistent with existing patterns
- Show ALL own movements: both outgoing attacks and incoming returns (matches MOVE-01 + MOVE-02)

### Claude's Discretion
- Movement row card styling and spacing
- Icon choices for attack vs return movement types
- How city name lookup is implemented (join in query vs separate provider)
- Whether to add movement_type to UnitMovement Dart model or handle display-side
- Resource icon rendering approach for cargo display
- Bottom nav icon choice for Movements tab

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Movement data model
- `lib/features/military/models/unit_movement.dart` — UnitMovement model with units, arriveAt, cargo fields; NOTE: missing `movement_type` field
- `lib/features/military/providers/unit_movements_provider.dart` — StreamProvider filtering by owner_id + originCityId (needs global variant)
- `lib/features/military/data/military_repository.dart` — watchOutgoingMovements() method (streams per-city, needs global method)

### Movement database schema
- `supabase/migrations/20260312000001_add_movement_type_to_unit_movements.sql` — movement_type column ('attack' | 'return')
- `supabase/migrations/20260311000015_movement_functions.sql` — Movement creation and processing functions
- `supabase/migrations/20260315000001_pillage_schema_and_functions.sql` — Pillage cargo population on return movements

### Existing UI patterns
- `lib/features/military/screens/dispatch_screen.dart` — Current per-city movement display with countdown timers
- `lib/features/city/widgets/countdown_timer_widget.dart` — Reusable countdown widget for ETA display

### Navigation
- `lib/core/router/app_router.dart` — GoRouter configuration for app navigation
- `lib/features/map/screens/main_shell_screen.dart` — Bottom navigation shell (where new tab goes)

### Requirements
- `.planning/REQUIREMENTS.md` — MOVE-01, MOVE-02 definitions

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `UnitMovement` model: already parses `units`, `arriveAt`, `cargo` from JSON — needs `movement_type` added
- `CountdownTimerWidget`: live countdown timer already used in dispatch screen — reuse for ETA display
- `unitMovementsProvider`: StreamProvider.autoDispose.family for per-city movements — pattern to extend for global view
- `MilitaryRepository.watchOutgoingMovements()`: Realtime stream pattern — extend for all-movements stream
- Resource icon/color constants likely exist in resource-related widgets

### Established Patterns
- Supabase Realtime `.stream(primaryKey: ['id'])` for live updates
- Client-side filtering of Realtime streams (owner_id filter server-side, additional filtering client-side)
- `ConsumerWidget` / `ConsumerStatefulWidget` + `ref.watch()` for reactive UI
- GoRouter with MainShellScreen for bottom navigation tabs

### Integration Points
- New bottom nav tab in `MainShellScreen` — add alongside City, Map, Military tabs
- New route in `app_router.dart` for Movements screen
- New global movements stream provider (all player movements, not per-city)
- `UnitMovement.fromJson` needs `movement_type` field added
- City name resolution: need to look up city names from IDs (may need cities table query or existing provider)

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 14-movement-visibility*
*Context gathered: 2026-03-16*
