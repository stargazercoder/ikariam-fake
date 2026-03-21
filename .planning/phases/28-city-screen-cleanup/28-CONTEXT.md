# Phase 28: City Screen Cleanup - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Remove city name and player name title texts from all city screen views. After this phase, city screens present only gameplay content — no standalone name/title text. Names will be re-added with proper design in a future milestone.

</domain>

<decisions>
## Implementation Decisions

### Own city screen (city_screen.dart)
- Remove the city name headline Text widget (headlineMedium, white, shadowed) at lines 160-170
- Remove the "Governor: $displayName" Text widget at lines 172-177
- Remove surrounding SizedBox/padding for these text widgets entirely — content shifts up, no spacer left behind
- Keep the rest of the city screen body intact (resource panel, building grid, etc.)

### AppBar player info (city_screen.dart)
- Remove the display_name Text from AppBar actions area (lines 66-85)
- Keep the player avatar icon only — no text label, no tooltip needed
- Avatar alone is sufficient context for the player

### Enemy city view banner (enemy_city_view_screen.dart)
- Replace "Viewing $cityName ($ownerName) — read only" with "Viewing enemy city — read only"
- Keep the red Container banner styling unchanged — read-only warning is still needed
- Remove city name and owner name from the banner text, but preserve the banner structure

### Navigation and borders
- Removing titles must NOT break navigation (back button, route params still work)
- Ownership color borders on city grid must remain unaffected
- All other UI elements (resource bar, building cells, construction banner) untouched

### Claude's Discretion
- Whether to remove the `cityName` and `displayName` variable declarations if they become unused after title removal
- Any cleanup of imports that become unused
- Exact dead code removal scope (only remove what's directly related to title display)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### City screens (modification targets)
- `lib/features/city/screens/city_screen.dart` — Own city screen with city name headline (lines 160-170), Governor text (lines 172-177), and AppBar player info (lines 66-85)
- `lib/features/map/screens/enemy_city_view_screen.dart` — Foreign city view with "Viewing CityName (OwnerName) — read only" banner (lines 66-71)

### City grid (verify no breakage)
- `lib/features/map/screens/city_grid_screen.dart` — Spatial grid view, currently has no city/player name titles (verify stays clean)

### Visual constants (ownership borders)
- `lib/core/constants/visual_constants.dart` — Ownership color definitions used for city borders — must remain working

</canonical_refs>

<code_context>
## Existing Code Insights

### Modification Targets
- `city_screen.dart` lines 160-177: Two Text widgets (city name + governor) in a Column — remove both plus any surrounding SizedBox spacers
- `city_screen.dart` lines 66-85: AppBar actions with avatar CircleAvatar + display_name Text — remove only the Text, keep CircleAvatar
- `enemy_city_view_screen.dart` lines 66-71: Single Text widget in red Container — change text content only

### Established Patterns
- city_screen.dart uses transparent AppBar with `backgroundColor: Colors.transparent` and `elevation: 0`
- Enemy city view passes `cityName` and `ownerName` as constructor parameters from the navigation route

### Integration Points
- `city_screen.dart` gets city data from `cityStreamProvider` — cityName variable may become unused after removal
- `enemy_city_view_screen.dart` receives cityName/ownerName from constructor — parameters may become unused for display but might still be needed for other logic (verify before removing)
- Navigation routes pass city/player names — removing display doesn't affect route parameters

</code_context>

<specifics>
## Specific Ideas

- This is the last phase of v1.4 — keep it clean and simple
- Out of Scope note confirms: "Names removed now; will be re-added with proper design later"
- city_grid_screen.dart already has no name titles — no changes needed there

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 28-city-screen-cleanup*
*Context gathered: 2026-03-21*
