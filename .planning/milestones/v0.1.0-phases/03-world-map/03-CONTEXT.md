# Phase 3: World Map - Context

**Gathered:** 2026-03-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Players can navigate a 2D grid world map, view islands with city slots and resource areas, and see their own city laid out on a building grid. The map renders as simple 2D grid (not isometric) and is navigable by pan and zoom. No new game mechanics — this phase is purely visual navigation across three views: world, island, city.

</domain>

<decisions>
## Implementation Decisions

### Rendering Technology
- Standard Flutter widgets only — Flame engine NOT used for map rendering
- InteractiveViewer for pan and zoom on the world map
- No Flame GameWidget, no canvas rendering — pure Material/widget-based approach

### Navigation Structure
- Bottom navigation bar with 3 tabs: World Map / Island / City
- Each view is a separate tab destination (not nested GoRouter routes)
- World tab: tapping an island navigates to that island's view in the Island tab
- Island tab: defaults to the player's own island; can switch via world map tap
- City tab: current city management screen (existing city_screen.dart content)
- Existing `/city` route replaced by tabbed shell with 3 views

### World Map Layout
- 10 islands total (reduced from 100 for v1 scope)
- Islands displayed as colored squares on a 2D grid
- InteractiveViewer wraps the grid for pan and zoom
- Island seed migration updated from 100 to 10 islands

### Island View
- Grid layout showing 16-17 city slots per island
- Empty slots displayed as grey squares
- Occupied slots displayed with player's color/identifier
- Resource areas (wood + luxury resource) shown with distinct icons
- Tapping an owned city slot switches to City tab

### City View
- 2D grid layout with buildings placed at predetermined positions
- Building positions determined by Claude (can be randomized per city or fixed template)
- Replaces the current list-based building display (city_screen.dart) with a spatial grid view
- Existing resource panel and construction banner remain above the grid
- Tapping a building on the grid opens the existing upgrade bottom sheet

### Claude's Discretion
- Exact grid dimensions for world map (e.g., 5x2, 4x3 for 10 islands)
- Building position assignments on the city grid
- Color scheme for island squares (aligned with existing navy/gold/white palette)
- Empty slot vs occupied slot visual treatment
- Island view grid arrangement for city slots and resource areas
- Whether to keep the building list alongside the grid or fully replace it

</decisions>

<specifics>
## Specific Ideas

- Islands as simple colored squares — no illustrations or detailed graphics for v1
- Bottom nav bar provides quick switching between the three main game views
- City grid should show buildings spatially rather than as a flat list — gives a sense of "place"
- Building positions can be randomized but should look reasonable on the grid

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `CityScreen` (city_screen.dart): Full economy UI with resource panel, construction banner, building list — becomes the City tab content
- `_ResourcePanel`, `_BuildingsList`, `_ConstructionBanner`: Reusable widgets that stay in City tab
- `BuildingUpgradeSheet`: Tapped from both list and grid views
- `AvatarWidget`: Reusable in any view's AppBar
- `CityRepository.fetchPlayerCity()`: Already joins cities with islands(*) — provides island data

### Established Patterns
- Riverpod AsyncNotifier/StreamProvider for reactive data
- Supabase Realtime streams for live updates (resources, buildings, construction)
- GoRouter with _RouterNotifier for auth-aware routing
- Material 3 theming with navy/gold/white palette

### Integration Points
- `app_router.dart`: Currently has `/city` route — needs to become tabbed shell route
- `islands` table: Already has grid_x, grid_y, max_city_slots, luxury_type — all data needed for map display
- `cities` table: Has island_id foreign key — can query cities per island
- Island seed (seed.sql or migration): Needs update from 100 to 10 islands
- `_RouterNotifier`: Auth redirect Rule 4 sends to `/city` — needs update to new main route

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-world-map*
*Context gathered: 2026-03-11*
