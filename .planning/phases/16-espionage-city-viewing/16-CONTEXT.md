# Phase 16: Espionage & City Viewing - Context

**Gathered:** 2026-03-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Players can spy on enemy cities to gather intelligence (resource amounts, building levels, total army count) and view a read-only version of any previously-spied city's building layout. Espionage is an instant server-side action costing gold — no spy units, no travel time. Read-only city view requires a prior spy report to unlock.

</domain>

<decisions>
## Implementation Decisions

### Spy Report Presentation
- **Dialog popup** after spy action completes — consistent with trade dialog and upgrade sheet patterns
- Report shows: city name, owner name, resource amounts (all 5 types), building list with levels, total army count (number only, not per-type breakdown)
- Report includes a **"View City" button** that navigates to the read-only city view (connects ESPY-01 and ESPY-02)
- **Spy reports are saved** to a DB table (spy_reports) — player can review past espionage results
- **Spy log accessible from Military tab** as a sub-section — keeps navigation compact

### City Viewing Navigation
- "View City" available from **island city tap menu** (added to _showCityActionDialog alongside Attack/Trade/Spy)
- **Requires spy first** — player must have at least one spy report for that city before viewing
- Island tap menu shows **"View City (spy first)" greyed out** for un-spied cities — teaches the feature exists
- "View City" also available as button in spy report dialog — natural flow: spy → report → view city
- **Full screen push navigation** (GoRouter route) — reuses CityScreen/CityGridScreen pattern in read-only mode

### Spy Action Trigger & Feedback
- "Spy" action in **city action dialog** on island screen — alongside Attack, Trade, View City
- **Gold cost: flat 100 gold** per spy action — no cooldown, no spy units consumed
- Cost shown inline: **"Spy (100 gold)"** in the action menu — player knows cost before tapping
- **No confirmation step** — tap Spy → brief loading spinner → spy report dialog opens with results
- Edge Function validates gold balance, deducts gold atomically, queries target city data, inserts spy_report row, returns report data

### Read-Only City View
- Shows **building grid with building names and levels** — reuses CityGridScreen in read-only mode
- **No resource amounts** in city view — resources only visible in spy reports (gives espionage ongoing value)
- **Shows construction queue** if enemy has active construction — reveals what's being upgraded and ETA
- **Different AppBar color (red/grey) + label** "CityName (PlayerName)" — clear visual distinction, no action buttons
- No upgrade sheets, no build buttons — purely observational

### Claude's Discretion
- Exact spy report dialog layout and spacing
- Spy log list design within Military tab (list tiles, sorting)
- Error handling for insufficient gold
- How to store/query "has player spied on this city" for View City unlock check
- CityGridScreen read-only mode implementation details (disable tap handlers vs separate widget)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Espionage backend
- `supabase/functions/send-trade/index.ts` — Edge Function pattern: auth validation, DB queries, atomic operations, CORS headers
- `supabase/functions/dispatch-units/index.ts` — Another Edge Function reference with travel time calc (not needed for spy but good pattern ref)

### City screen (read-only target)
- `lib/features/city/screens/city_screen.dart` — CityScreen with AppBar, resources, building list, construction queue
- `lib/features/map/screens/city_grid_screen.dart` — CityGridScreen building grid layout — read-only variant reuses this
- `lib/features/city/providers/buildings_provider.dart` — buildingsProvider for fetching building data
- `lib/features/city/providers/construction_provider.dart` — constructionProvider for construction queue

### Island screen integration
- `lib/features/map/screens/island_screen.dart` — _showCityActionDialog: existing unified city tap handler to extend with Spy + View City actions
- `lib/features/map/models/island_city_slot.dart` — IslandCitySlot model with city/player info

### Military tab (spy log host)
- `lib/features/military/screens/` — Military screen where spy log sub-section will live

### Resource system
- `lib/core/constants/resource_constants.dart` — ResourceType enum, resource display names
- `lib/features/city/models/city_resource.dart` — CityResource model for spy report resource display

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `CityScreen` / `CityGridScreen`: full city display — read-only mode can wrap these with disabled interactions
- `_showCityActionDialog` on IslandScreen: unified city tap handler — extend with "Spy" and "View City" options
- `cityNameProvider`: FutureProvider.family for city name lookup — reuse in spy report dialog header
- Edge Function pattern (send-trade, dispatch-units): auth + validation + DB mutation + response — spy function follows same pattern
- `resourcesProvider`: stream provider for resources — reference for spy report resource display format

### Established Patterns
- Edge Function: POST JSON body, Supabase auth, CORS, typed error response
- Repository pattern: method calls Edge Function, throws typed exception, UI catches for SnackBar
- Dialog pattern: showDialog with StatefulBuilder, _isLoading state, async call on confirm
- Island city tap: _showCityActionDialog shows action buttons based on city ownership

### Integration Points
- Island screen: add "Spy" + "View City" to _showCityActionDialog
- Military screen: add spy log section/tab
- GoRouter: new route for read-only city view (e.g., /city/:cityId/view)
- New DB table: spy_reports (id, player_id, target_city_id, report_data JSONB, created_at)
- New Edge Function: spy-city (validate gold, deduct, query target, insert report, return data)

</code_context>

<specifics>
## Specific Ideas

- Spy report dialog should feel instant and rewarding — brief spinner then data appears
- "Spy (100 gold)" inline cost prevents accidental spending
- Greyed-out "View City (spy first)" teaches the mechanic without cluttering docs
- Red/grey AppBar for enemy city view creates clear "you're looking at someone else's city" feeling
- Construction queue visible in read-only view adds strategic depth — see what enemy is building

</specifics>

<deferred>
## Deferred Ideas

- Counter-espionage (spy defense, detection) — explicitly out of scope per REQUIREMENTS.md
- Spy unit type with travel time — deferred, v1.2 uses instant action
- Spy report expiration/staleness indicator — future polish
- Alliance-wide intel sharing — requires alliance system
- Spy cost scaling with target level — keep flat 100 gold for v1.2

</deferred>

---

*Phase: 16-espionage-city-viewing*
*Context gathered: 2026-03-16*
