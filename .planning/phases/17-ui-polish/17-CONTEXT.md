# Phase 17: UI Polish - Context

**Gathered:** 2026-03-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Visual polish across city view, map, and military screens. Remove AppBar title from city view for cleaner layout, color-code cities by ownership on island and world maps, and apply unit type colors consistently across all military screens. No new features or data dependencies — purely visual changes.

</domain>

<decisions>
## Implementation Decisions

### City View Layout
- Transparent AppBar with `extendBodyBehindAppBar: true` — building grid extends under AppBar area
- AppBar icons (back button, sign-out) remain with subtle drop shadow (`Shadow(blurRadius: 4, color: Colors.black54)`) for visibility on any background
- Apply to BOTH own city screen (CityScreen) and enemy city view screen (EnemyCityViewScreen) — both get transparent AppBar
- Enemy city view: remove red AppBar, keep "Viewing enemy city — read only" banner as sole visual distinction
- Own city: show city name as small label on the grid (not in AppBar, not hidden entirely)

### Ownership Colors on Maps
- Color palette: Own=`Colors.green.shade600` (#43A047), Enemy=`Colors.red.shade600` (#E53935), Empty=`Colors.grey.shade400` (#BDBDBD)
- Render method: 2px colored border around city slot container with `BorderRadius.circular(8)`
- Apply to both Island view (per-slot coloring) and World map (per-island coloring)
- World map island color rule: if player has own city on island → green border; otherwise red if enemy cities present; grey if empty
- Simple rule: own city presence takes priority (kendi varsa her zaman yeşil)

### Unit Type Color Styling
- Display: `CircleAvatar(backgroundColor: unitTypeColors[type], child: Icon(unitTypeIcon, color: Colors.white))`
- Each unit type gets a unique icon (13 icons total for 13 unit types) — not generic shield/sailing
- Add `unitTypeIcons` Map<UnitType, IconData> to `lib/core/constants/unit_constants.dart` alongside existing `unitTypeColors`
- Apply to ALL military screens: Barracks (training queue), Shipyard (training queue), Dispatch (army lists), battle reports

### Cross-Screen Consistency
- Create `lib/core/constants/ownership_colors.dart` with centralized ownership color constants — all screens import from single source
- Ownership colors used in: island screen city slots, world map island cells, and potentially future alliance screens
- Enemy city view relies on read-only banner (not AppBar color) as visual distinction after transparent AppBar change

### Claude's Discretion
- Exact icon choices for each of the 13 unit types (from Material Icons library)
- City name label positioning and styling on own city grid
- Any animation or transition adjustments related to AppBar transparency

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Theme & Constants
- `lib/core/theme/app_theme.dart` — Global Material 3 theme, primary/secondary/error colors, AppBar styling
- `lib/core/constants/unit_constants.dart` — Existing `unitTypeColors` map (13 colors), `UnitType` enum, unit definitions

### City Screens (modification targets)
- `lib/features/city/screens/city_screen.dart` — Main city view AppBar to make transparent
- `lib/features/map/screens/enemy_city_view_screen.dart` — Enemy city view AppBar to make transparent (Phase 16)
- `lib/features/map/screens/city_grid_screen.dart` — Building grid layout (used by both screens)

### Map Screens (modification targets)
- `lib/features/map/screens/island_screen.dart` — Island view with city slots to color-code
- `lib/features/map/screens/world_map_screen.dart` — World map with island grid cells to color-code
- `lib/features/map/models/island_city_slot.dart` — CitySlot model with `ownerId` field

### Military Screens (modification targets)
- `lib/features/military/screens/barracks_screen.dart` — Land unit training queue
- `lib/features/military/screens/shipyard_screen.dart` — Naval unit training queue
- `lib/features/military/screens/dispatch_screen.dart` — Army/movement lists
- `lib/features/battles/screens/battles_screen.dart` — Battle reports display

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `unitTypeColors` map in `unit_constants.dart`: 13 distinct colors already defined for all unit types — ready to use
- `CitySlot.ownerId` field: already available for ownership comparison against current user
- `app_theme.dart`: Material 3 theme with established color system (navy primary, gold secondary)
- `CountdownTimerWidget`: reusable for any training/ETA displays

### Established Patterns
- AppBar styling: currently `primaryColor` background, elevation 0, white text
- List items: `ListTile` based layouts in military screens
- Color coding precedent: Phase 15 trade movements use `Colors.green`, Phase 16 enemy city uses `Colors.red.shade800`

### Integration Points
- `CityScreen` Scaffold: AppBar modification point
- `IslandScreen._buildCitySlot()`: city slot rendering (add border based on ownership)
- `WorldMapScreen` grid cells: island rendering (add border based on ownership)
- Military screen list builders: unit row rendering (add CircleAvatar leading)

</code_context>

<specifics>
## Specific Ideas

- Phase 16'da oluşturulan kırmızı AppBar enemy city view'dan kaldırılacak, yerine transparent AppBar + mevcut "read only" banner kalacak
- unitTypeColors zaten tanımlı — yeni renk eklemeye gerek yok, sadece ikonlar ve uygulama noktaları eklenmeli
- World map'te "kendi şehrim var mı?" kontrolü basit tutulmalı — karmaşık dominant renk hesaplaması yerine bool kontrol

</specifics>

<deferred>
## Deferred Ideas

- Alliance/müttefik sistemi ve müttefik şehir rengi (mavi) — gelecek milestone'da
- Animasyonlu geçişler ve parallax efektleri — ayrı polish phase
- Dark mode desteği — ayrı tema phase'i

</deferred>

---

*Phase: 17-ui-polish*
*Context gathered: 2026-03-17*
