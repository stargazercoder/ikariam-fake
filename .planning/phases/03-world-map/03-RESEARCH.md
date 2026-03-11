# Phase 3: World Map - Research

**Researched:** 2026-03-11
**Domain:** Flutter widget-based 2D map rendering, GoRouter StatefulShellRoute tabbed navigation, Riverpod async providers for island/city data
**Confidence:** HIGH

## Summary

Phase 3 adds three interconnected views — World Map, Island, City — behind a persistent bottom navigation bar. The implementation is purely widget-based (no Flame, no canvas): `InteractiveViewer` wraps a fixed-size `SizedBox` grid for the world map, standard `GridView` or `Wrap`+`GestureDetector` for the island slot layout, and a positioned `Stack` grid for the city building layout.

The key navigation challenge is converting the existing single `/city` GoRoute into a `StatefulShellRoute.indexedStack` with three branches. GoRouter 17 (already in pubspec) supports `StatefulShellRoute.indexedStack` directly. The existing `_RouterNotifier` / `refreshListenable` pattern is unaffected because the redirect guard still targets a single shell path (e.g., `/map`).

The Supabase schema is already fully prepared: `islands` has `grid_x`, `grid_y`, `max_city_slots`, `luxury_type`; `cities` has `island_id`, `slot_number`, `owner_id`. The only migration change required is updating the seed from 100 islands to 10.

**Primary recommendation:** Use `InteractiveViewer(constrained: false)` wrapping a plain `SizedBox`-based grid of `GestureDetector` squares for the world map. Use `StatefulShellRoute.indexedStack` for the bottom-nav shell. Use `FutureProvider` (not StreamProvider) for island list and island detail — this data does not change in real-time during a session.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Standard Flutter widgets only — Flame engine NOT used for map rendering
- InteractiveViewer for pan and zoom on the world map
- No Flame GameWidget, no canvas rendering — pure Material/widget-based approach
- Bottom navigation bar with 3 tabs: World Map / Island / City
- Each view is a separate tab destination (not nested GoRouter routes)
- World tab: tapping an island navigates to that island's view in the Island tab
- Island tab: defaults to the player's own island; can switch via world map tap
- City tab: current city management screen (existing city_screen.dart content)
- Existing `/city` route replaced by tabbed shell with 3 views
- 10 islands total (reduced from 100 for v1 scope)
- Islands displayed as colored squares on a 2D grid
- InteractiveViewer wraps the grid for pan and zoom
- Island seed migration updated from 100 to 10 islands
- Grid layout showing 16-17 city slots per island
- Empty slots displayed as grey squares
- Occupied slots displayed with player's color/identifier
- Resource areas (wood + luxury resource) shown with distinct icons
- Tapping an owned city slot switches to City tab
- 2D grid layout with buildings placed at predetermined positions
- Building positions determined by Claude
- Replaces the current list-based building display with a spatial grid view
- Existing resource panel and construction banner remain above the grid
- Tapping a building on the grid opens the existing upgrade bottom sheet

### Claude's Discretion
- Exact grid dimensions for world map (e.g., 5x2, 4x3 for 10 islands)
- Building position assignments on the city grid
- Color scheme for island squares (aligned with existing navy/gold/white palette)
- Empty slot vs occupied slot visual treatment
- Island view grid arrangement for city slots and resource areas
- Whether to keep the building list alongside the grid or fully replace it

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| MAP-01 | World map displays islands on a grid coordinate system | InteractiveViewer + SizedBox grid; islands table has grid_x/grid_y; FutureProvider fetches all 10 islands |
| MAP-02 | Each island contains 16-17 city slots, 1 wood resource, and 1 luxury resource (marble/crystal/sulfur) | islands.max_city_slots, islands.luxury_type already in DB; slot count from cities query per island |
| MAP-03 | Island view shows all cities on the island and resource gathering areas | Supabase query: `cities.select('*').eq('island_id', id)`; island data joined; Grid widget renders slots |
| MAP-04 | City view displays buildings on a grid layout | Fixed-position Stack or GridView; buildings data from existing buildingsStreamProvider; tap opens BuildingUpgradeSheet |
| MAP-05 | Map renders as simple 2D grid (not isometric) | Pure widget approach locked; InteractiveViewer + Row/Column grid confirmed approach |
</phase_requirements>

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter/widgets (InteractiveViewer) | SDK (Flutter 3.x) | Pan and zoom container for world map | Built-in Flutter widget; no additional dependency; handles multi-touch and mouse wheel |
| go_router (StatefulShellRoute) | ^17.1.0 (already in pubspec) | 3-tab bottom nav shell with state persistence per tab | Project already uses go_router; StatefulShellRoute preserves Navigator stack per branch |
| flutter_riverpod (FutureProvider) | ^3.3.1 (already in pubspec) | Async data fetch for island list and island detail | Consistent with project pattern; AsyncNotifier for notifier-based island selection state |
| supabase_flutter | ^2.12.0 (already in pubspec) | DB queries for islands and cities by island_id | Already connected; islands/cities tables have all needed columns |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Flutter Stack widget | SDK | Overlay positioned building icons on city grid | City grid needs absolute coordinates per building |
| Flutter GestureDetector | SDK | Tap detection on island squares and city slots | Wraps each colored square in world map and slot cells in island view |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| InteractiveViewer | Flame GameWidget | Flame adds rendering overhead and ~4MB; user locked decision rejects Flame |
| StatefulShellRoute | ShellRoute + manual IndexedStack | ShellRoute does not preserve branch Navigator state; each tab resets on switch |
| FutureProvider (islands) | StreamProvider (islands) | Islands do not change in real-time during a session; FutureProvider simpler and sufficient |
| GridView.count (city grid) | Stack with Positioned | GridView auto-lays out uniformly; Stack allows exact (x,y) placement which city buildings need |

**Installation:** No new packages needed. All required libraries are already in `pubspec.yaml`.

---

## Architecture Patterns

### Recommended Project Structure
```
lib/
├── core/
│   └── router/
│       └── app_router.dart          # Replace /city GoRoute with StatefulShellRoute
├── features/
│   ├── map/
│   │   ├── data/
│   │   │   └── map_repository.dart  # fetchAllIslands(), fetchIslandDetail(id)
│   │   ├── models/
│   │   │   ├── island.dart          # Island model (id, grid_x, grid_y, max_city_slots, luxury_type)
│   │   │   └── island_city_slot.dart # CitySlot model (slot_number, city_name, owner_id, owner_display_name)
│   │   ├── providers/
│   │   │   ├── islands_provider.dart        # FutureProvider<List<Island>>
│   │   │   └── island_detail_provider.dart  # FutureProvider<IslandDetail> by island_id
│   │   └── screens/
│   │       ├── main_shell_screen.dart       # StatefulShellRoute builder: Scaffold + BottomNavigationBar
│   │       ├── world_map_screen.dart        # InteractiveViewer + grid of island squares
│   │       ├── island_screen.dart           # Grid of 16-17 city slots + resource areas
│   │       └── city_grid_screen.dart        # Stack-based building grid wrapper
│   └── city/
│       └── screens/
│           └── city_screen.dart             # Existing — promoted to City tab content unchanged
└── shared/
    └── widgets/
        └── ...                              # Existing shared widgets unchanged
```

### Pattern 1: StatefulShellRoute.indexedStack for 3-Tab Shell

**What:** Wraps the three game views in a persistent bottom navigation bar. Each branch has its own Navigator stack and state that survives tab switches.

**When to use:** Any multi-tab app where each tab can have its own navigation depth and must not reset on tab switch.

**Example:**
```dart
// Source: https://pub.dev/documentation/go_router/latest/go_router/StatefulShellRoute-class.html
// In app_router.dart — replace the /city GoRoute

final _shellNavigatorWorldKey = GlobalKey<NavigatorState>(debugLabel: 'world');
final _shellNavigatorIslandKey = GlobalKey<NavigatorState>(debugLabel: 'island');
final _shellNavigatorCityKey = GlobalKey<NavigatorState>(debugLabel: 'city');

StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) {
    return MainShellScreen(navigationShell: navigationShell);
  },
  branches: [
    StatefulShellBranch(
      navigatorKey: _shellNavigatorWorldKey,
      routes: [GoRoute(path: '/map', builder: (_, __) => const WorldMapScreen())],
    ),
    StatefulShellBranch(
      navigatorKey: _shellNavigatorIslandKey,
      routes: [GoRoute(path: '/island', builder: (_, __) => const IslandScreen())],
    ),
    StatefulShellBranch(
      navigatorKey: _shellNavigatorCityKey,
      routes: [GoRoute(path: '/city', builder: (_, __) => const CityScreen())],
    ),
  ],
)
```

**Auth redirect update:** Rule 4 in `_redirect()` must redirect to `/map` instead of `/city`. The `_RouterNotifier` ChangeNotifier pattern remains identical — no structural change.

### Pattern 2: InteractiveViewer for Pannable World Map

**What:** `InteractiveViewer` with `constrained: false` wraps a fixed-size `SizedBox` that contains a grid of colored square containers. The grid is sized larger than the viewport, forcing the viewer to allow panning.

**When to use:** Any widget content larger than the screen that needs pan and pinch-zoom. Use `constrained: false` when the child is larger than the viewport.

**Example:**
```dart
// Source: https://api.flutter.dev/flutter/widgets/InteractiveViewer-class.html
// In world_map_screen.dart

final _transformController = TransformationController();

InteractiveViewer(
  transformationController: _transformController,
  constrained: false,           // Required: child is larger than viewport
  boundaryMargin: const EdgeInsets.all(80),
  minScale: 0.3,
  maxScale: 3.0,
  child: SizedBox(
    width: 5 * _cellSize,       // 5 columns for 10-island grid (5x2)
    height: 2 * _cellSize,      // 2 rows
    child: GridView.count(
      crossAxisCount: 5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(), // InteractiveViewer handles scroll
      children: islands.map((island) => _IslandCell(island: island)).toList(),
    ),
  ),
)
```

**Critical:** Set `physics: NeverScrollableScrollPhysics()` on the inner GridView — otherwise scroll events fight between GridView scroll and InteractiveViewer pan.

### Pattern 3: Island View — Slot Grid with Resource Areas

**What:** A fixed `GridView.count` (or custom `Wrap`) showing 16-17 numbered slots, plus 2 resource area cells (wood, luxury). Each slot cell is colored based on occupancy.

**Example:**
```dart
// In island_screen.dart
GridView.builder(
  physics: const NeverScrollableScrollPhysics(),
  shrinkWrap: true,
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 6,
    mainAxisSpacing: 4,
    crossAxisSpacing: 4,
    childAspectRatio: 1.0,
  ),
  itemCount: island.maxCitySlots + 2, // slots + wood + luxury
  itemBuilder: (context, index) {
    if (index < island.maxCitySlots) {
      final slotNumber = index + 1;
      final city = cities.firstWhereOrNull((c) => c.slotNumber == slotNumber);
      return _CitySlotCell(slotNumber: slotNumber, city: city, playerOwnerId: playerId);
    } else if (index == island.maxCitySlots) {
      return const _ResourceCell(type: 'wood');
    } else {
      return _ResourceCell(type: island.luxuryType);
    }
  },
)
```

### Pattern 4: City Building Grid — Stack with Positioned

**What:** A fixed-size `Stack` where each building occupies a predetermined (x, y) cell position. Buildings are represented as tappable squares with an icon and level label.

**Rationale for Stack over GridView:** Buildings have spatial meaning (Town Hall center, Barracks near wall, etc.). A fixed-position layout conveys this better than a sequential list. GridView assigns sequential positions automatically and cannot express spatial relationships.

**Example:**
```dart
// In city_grid_screen.dart
// Grid: 6 columns x 5 rows, each cell 64x64 logical pixels
const double cellSize = 64.0;
const int cols = 6;
const int rows = 5;

Stack(
  children: [
    // Grid background
    SizedBox(
      width: cols * cellSize,
      height: rows * cellSize,
      child: GridPaper(color: Colors.grey.withOpacity(0.2)),
    ),
    // Buildings at predetermined positions
    ...buildings.map((building) {
      final pos = _buildingPositions[building.buildingType]!;
      return Positioned(
        left: pos.col * cellSize,
        top: pos.row * cellSize,
        width: cellSize,
        height: cellSize,
        child: _BuildingCell(building: building, cityId: cityId),
      );
    }),
  ],
)
```

### Pattern 5: Island Selection State (Cross-Tab Communication)

**What:** When the user taps an island on the world map, the Island tab must update to show that island. Use a `StateProvider<String?>` holding the selected `island_id`. The island screen watches this provider.

**Example:**
```dart
// In islands_provider.dart
final selectedIslandIdProvider = StateProvider<String?>((ref) => null);

// In WorldMapScreen tap handler:
ref.read(selectedIslandIdProvider.notifier).state = island.id;
navigationShell.goBranch(1); // switch to Island tab

// In IslandScreen:
final selectedId = ref.watch(selectedIslandIdProvider);
final effectiveId = selectedId ?? playerIslandId; // default to player's island
```

### Anti-Patterns to Avoid

- **Inner GridView scrollable inside InteractiveViewer:** Set `physics: NeverScrollableScrollPhysics()` on any scroll widget inside InteractiveViewer — competing gesture recognizers produce erratic behavior.
- **Recreating GoRouter on shell navigation:** GoRouter is created once per app lifetime. Do not put `appRouterProvider` inside a widget `build()` method.
- **Using StreamProvider for island list:** Islands do not update in real-time. StreamProvider adds a Supabase Realtime subscription unnecessarily. Use `FutureProvider` instead.
- **Placing tab navigation logic inside tab screens:** Each screen should call `navigationShell.goBranch(index)` only from `MainShellScreen`. Island tap should use a shared `StateProvider`, not imperative navigation calls deep in the tree.
- **Using `constrained: true` (default) with a large grid child:** When the child is larger than the viewport, `constrained: true` forces the child to shrink-wrap. The grid becomes invisible or the wrong size. Always use `constrained: false` for world maps.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Tab state persistence | Custom IndexedStack + manual state tracking | `StatefulShellRoute.indexedStack` | GoRouter handles Navigator stacks, back button behavior, and branch restoration automatically |
| Pan and zoom with boundary clipping | Custom GestureDetector + Matrix4 math | `InteractiveViewer` | InteractiveViewer handles multi-touch, mouse wheel, fling, boundary clamping with `boundaryMargin` |
| Cross-tab island selection | Navigation arguments / route params | `StateProvider<String?>` (Riverpod) | Providers outlive navigation; passing island ID through route params breaks the stateful shell pattern |
| Island data with city occupancy join | Separate queries + manual join in Dart | Single Supabase query: `cities.select('*, islands(*)').eq('island_id', id)` | DB-side join is correct; the project already uses this pattern in `CityRepository` |

**Key insight:** The tab shell and pan/zoom widget are the two most common Flutter dev hand-roll traps. Both have first-class framework solutions that handle edge cases (back button on Android, fling deceleration, pinch-zoom center point) that a hand-rolled solution would miss.

---

## Common Pitfalls

### Pitfall 1: InteractiveViewer `constrained: false` + inner scroll widget gesture conflict

**What goes wrong:** The user cannot pan the map — the scroll widget inside intercepts drag gestures.

**Why it happens:** `GridView` (and `ListView`, `SingleChildScrollView`) absorbs vertical scroll events before `InteractiveViewer` sees them.

**How to avoid:** Set `physics: NeverScrollableScrollPhysics()` on every scrollable widget inside `InteractiveViewer`. The outer viewer handles all scroll/drag events.

**Warning signs:** Vertical pan works but horizontal does not (or vice versa); scrolling inside the grid causes the grid content to scroll instead of the viewport panning.

### Pitfall 2: `StatefulShellRoute` navigator key collision

**What goes wrong:** Runtime error: "Multiple navigators with the same key" or "Navigator.pop() called on wrong navigator."

**Why it happens:** Each `StatefulShellBranch` requires a unique `GlobalKey<NavigatorState>`. If keys are reused or not declared at the file scope, they are recreated on each build.

**How to avoid:** Declare all branch navigator keys as file-level `final` variables (not inside `build` or provider functions). Three keys minimum for three branches.

**Warning signs:** App crashes on tab switch; `context.go()` navigates to wrong tab.

### Pitfall 3: Auth redirect points to `/city` which no longer exists as a top-level route

**What goes wrong:** After login, router redirect sends to `/city` — but the city screen is now a branch inside `StatefulShellRoute` at path `/city`. GoRouter resolves it correctly only if the route path matches exactly. If the shell's initial branch is `/map`, the Rule 4 redirect must send to `/map`, not `/city`.

**How to avoid:** Update `_redirect()` Rule 4 to return `'/map'` instead of `'/city'`. GoRouter will load the shell with the world map tab active by default. The city branch at `/city` is still accessible by switching tabs.

**Warning signs:** After login, blank screen or "No route found for /city"; router loops between create-profile and city.

### Pitfall 4: Seed migration — 100 vs 10 islands

**What goes wrong:** Local DB still has 100 islands after code changes; `supabase db reset` replays seed with old count; the world map grid shows a 10x10 grid instead of 5x2.

**How to avoid:** Update `seed.sql` to generate 10 islands in a 5x2 grid before running tests. Alternatively, create a migration file that deletes islands with `grid_x > 5 OR grid_y > 2` and adjusts the seed generation. Run `supabase db reset` to apply.

**Warning signs:** `SELECT count(*) FROM islands;` returns 100 after reset; world map shows 10 rows instead of 2.

### Pitfall 5: `selectedIslandIdProvider` not reset on logout

**What goes wrong:** Player logs out, another player logs in, island tab shows previous player's island.

**Why it happens:** `StateProvider` lives in the `ProviderScope` which persists across re-auth unless `ProviderScope` is recreated or the provider is invalidated.

**How to avoid:** On sign-out (in `AuthRepository.signOut()`), call `ref.invalidate(selectedIslandIdProvider)` to reset to `null`. Also invalidate `islandDetailProvider` so it does not serve cached data.

**Warning signs:** Island tab shows wrong island after login with different account.

### Pitfall 6: `InteractiveViewer` scale-jumps to maxScale on two-finger pinch start (known Flutter bug)

**What goes wrong:** Two-finger pinch immediately jumps to maximum scale, then cannot zoom out.

**Why it happens:** Confirmed Flutter issue #88467: when using `constrained: false`, scale can jump to maxScale on the initial pinch gesture.

**How to avoid:** Set `maxScale` conservatively (2.0-2.5 max). Set `minScale: 0.3`. Add a `TransformationController` and clamp in `onInteractionEnd`. This bug is most reproducible when the child's natural size differs from what the viewer expects — ensure the `SizedBox` child has explicit width and height set.

**Warning signs:** Two-finger pinch causes map to instantly fill the screen and cannot zoom out.

---

## Code Examples

Verified patterns from official sources:

### InteractiveViewer with TransformationController
```dart
// Source: https://api.flutter.dev/flutter/widgets/InteractiveViewer-class.html
final TransformationController _controller = TransformationController();

@override
void dispose() {
  _controller.dispose();
  super.dispose();
}

InteractiveViewer(
  transformationController: _controller,
  constrained: false,
  boundaryMargin: const EdgeInsets.all(80),
  minScale: 0.3,
  maxScale: 2.5,
  child: SizedBox(
    width: 5 * 120.0,  // 5 columns
    height: 2 * 120.0, // 2 rows
    child: /* grid content */,
  ),
)
```

### StatefulShellRoute.indexedStack with BottomNavigationBar
```dart
// Source: https://pub.dev/documentation/go_router/latest/go_router/StatefulShellRoute-class.html
final _worldKey  = GlobalKey<NavigatorState>(debugLabel: 'world');
final _islandKey = GlobalKey<NavigatorState>(debugLabel: 'island');
final _cityKey   = GlobalKey<NavigatorState>(debugLabel: 'city');

StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) => MainShellScreen(navigationShell: navigationShell),
  branches: [
    StatefulShellBranch(navigatorKey: _worldKey,
      routes: [GoRoute(path: '/map', builder: (_, __) => const WorldMapScreen())]),
    StatefulShellBranch(navigatorKey: _islandKey,
      routes: [GoRoute(path: '/island', builder: (_, __) => const IslandScreen())]),
    StatefulShellBranch(navigatorKey: _cityKey,
      routes: [GoRoute(path: '/city', builder: (_, __) => const CityScreen())]),
  ],
)

// MainShellScreen
class MainShellScreen extends StatelessWidget {
  const MainShellScreen({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'World'),
          BottomNavigationBarItem(icon: Icon(Icons.island), label: 'Island'),
          BottomNavigationBarItem(icon: Icon(Icons.location_city), label: 'City'),
        ],
      ),
    );
  }
}
```

### Supabase query — fetch all cities on an island
```dart
// Pattern consistent with CityRepository.fetchPlayerCity()
// In MapRepository:
Future<List<Map<String, dynamic>>> fetchCitiesOnIsland(String islandId) {
  return supabaseClient
      .from('cities')
      .select('id, slot_number, name, owner_id')
      .eq('island_id', islandId);
}

// cities table RLS: "cities_select_authenticated" — all authenticated users can read
```

### Riverpod — FutureProvider for islands list
```dart
// In islands_provider.dart
final allIslandsProvider = FutureProvider<List<Island>>((ref) async {
  final repo = ref.read(mapRepositoryProvider);
  return repo.fetchAllIslands();
});

// Family provider for island detail by id
final islandDetailProvider = FutureProvider.family<IslandDetail, String>((ref, islandId) async {
  final repo = ref.read(mapRepositoryProvider);
  return repo.fetchIslandDetail(islandId);
});

// Selected island for cross-tab communication
final selectedIslandIdProvider = StateProvider<String?>((ref) => null);
```

### Building position map — predetermined city grid positions (6x5 grid)
```dart
// In city_grid_screen.dart constants
// Grid: 6 columns, 5 rows; Town Hall at center
const Map<BuildingType, ({int row, int col})> kBuildingPositions = {
  BuildingType.townHall:    (row: 2, col: 2),
  BuildingType.warehouse:   (row: 0, col: 0),
  BuildingType.barracks:    (row: 0, col: 4),
  BuildingType.shipyard:    (row: 4, col: 5),
  BuildingType.academy:     (row: 0, col: 2),
  BuildingType.embassy:     (row: 2, col: 0),
  BuildingType.tradingPort: (row: 4, col: 0),
  BuildingType.townWall:    (row: 2, col: 5),
  BuildingType.hideout:     (row: 4, col: 3),
  BuildingType.tavern:      (row: 4, col: 1),
  BuildingType.sawmill:     (row: 1, col: 1),
  BuildingType.quarry:      (row: 1, col: 3),
  BuildingType.glassblower: (row: 3, col: 1),
  BuildingType.sulfurPit:   (row: 3, col: 3),
};
// All 14 buildings fit in 6x5 = 30 cells with 16 cells free for visual breathing room
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| ShellRoute (no state) | StatefulShellRoute.indexedStack | GoRouter 7.1.0 (2023) | Each tab retains Navigator stack; back button works per-tab |
| ManualIndexedStack widget | StatefulShellRoute built-in IndexedStack | GoRouter 7.1.0 | Less boilerplate; GoRouter manages lifecycle |
| GoRouter `refreshListenable` with Provider | Same pattern works with Riverpod ChangeNotifier | Unchanged | Project's `_RouterNotifier` pattern remains valid in v17 |
| flame for 2D grids | InteractiveViewer + plain widgets | — | Flame is for game loops; simple grids do not need a game engine |

**Deprecated/outdated:**
- `ShellRoute` for multi-tab with state: replaced by `StatefulShellRoute` for stateful tabs. `ShellRoute` still valid for non-stateful wrappers.
- Seed generating 100 islands (10x10): Must be replaced with 10 islands (5x2) to match v1 scope decision.

---

## Open Questions

1. **`StatefulShellRoute` with top-level redirect — does Rule 4 redirect to `/map` or `/city`?**
   - What we know: The shell contains both `/map` and `/city` as branch paths. GoRouter resolves them within the shell context.
   - What's unclear: Whether redirecting to `/city` activates the shell with the City tab active, or triggers a "no route" error if `/city` is not a direct GoRouter top-level path.
   - Recommendation: Redirect to `/map` (shell's first branch / default location). This is the safer choice — user enters the game at the world map. The City tab is accessible via bottom nav.

2. **`BottomNavigationBar` vs `NavigationBar` (Material 3)**
   - What we know: The project uses Material 3 (`ThemeData.useMaterial3` assumed from existing navy/gold palette and Material 3 theming). `NavigationBar` is the M3 component; `BottomNavigationBar` is M2.
   - What's unclear: Whether the existing `app_theme.dart` explicitly sets `useMaterial3: true`.
   - Recommendation: Read `app_theme.dart` before implementing. If M3 is active, use `NavigationBar` + `NavigationDestination` to match the app's visual language.

3. **10-island seed — migration file or seed.sql update?**
   - What we know: Current `seed.sql` generates 100 islands. The project uses `supabase db reset` to apply migrations + seed.
   - What's unclear: Whether seed.sql should be updated in-place or a new migration added to delete the extra 90 islands.
   - Recommendation: Update `seed.sql` in-place (it is idempotent on `db reset`) AND add a migration that truncates and re-inserts 10 islands for production-like environments. This is a Wave 0 task.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK, Dart 3.10.1) |
| Config file | none (uses default flutter test runner) |
| Quick run command | `flutter test test/unit/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MAP-01 | Island model parses grid_x/grid_y from Supabase JSON | unit | `flutter test test/unit/map_models_test.dart` | ❌ Wave 0 |
| MAP-02 | Island model exposes max_city_slots and luxury_type | unit | `flutter test test/unit/map_models_test.dart` | ❌ Wave 0 |
| MAP-03 | IslandDetail aggregates cities by slot_number correctly | unit | `flutter test test/unit/map_models_test.dart` | ❌ Wave 0 |
| MAP-04 | kBuildingPositions contains all 14 BuildingType values with no duplicate positions | unit | `flutter test test/unit/city_grid_test.dart` | ❌ Wave 0 |
| MAP-05 | Smoke test: WorldMapScreen renders without error | widget | `flutter test test/widget/world_map_smoke_test.dart` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/unit/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/unit/map_models_test.dart` — covers MAP-01, MAP-02, MAP-03 (Island.fromJson, IslandDetail slot aggregation)
- [ ] `test/unit/city_grid_test.dart` — covers MAP-04 (kBuildingPositions completeness and uniqueness)
- [ ] `test/widget/world_map_smoke_test.dart` — covers MAP-05 (WorldMapScreen renders with mocked provider)

---

## Sources

### Primary (HIGH confidence)
- [Flutter InteractiveViewer API docs](https://api.flutter.dev/flutter/widgets/InteractiveViewer-class.html) — constructor parameters, constrained, boundaryMargin, TransformationController
- [GoRouter StatefulShellRoute API docs](https://pub.dev/documentation/go_router/latest/go_router/StatefulShellRoute-class.html) — indexedStack constructor, StatefulShellBranch, StatefulNavigationShell.goBranch
- [GoRouter v17 changelog](https://pub.dev/packages/go_router/changelog) — Breaking changes in v15-17; notifyRootObserver addition

### Secondary (MEDIUM confidence)
- [codewithandrea.com — Flutter Bottom Navigation Bar with Stateful Nested Routes](https://codewithandrea.com/articles/flutter-bottom-navigation-bar-nested-routes-gorouter/) — Confirmed StatefulShellRoute pattern; widely referenced community source
- [gladimdim.org — Animating InteractiveViewer in Flutter](https://gladimdim.org/animating-interactiveviewer-in-flutter-or-how-to-animate-map-in-your-game) — Game map use case with TransformationController animation
- Project codebase (directly read): `app_router.dart`, `city_screen.dart`, `city_repository.dart`, migration files, seed.sql — HIGH confidence for existing patterns

### Tertiary (LOW confidence — verify in implementation)
- Flutter issue #88467: InteractiveViewer constrained: false scale-jumps to maxScale — reported but fix status unclear; mitigate with bounded maxScale
- Flutter issue #159690: InteractiveViewer zoom targets wrong point during pan on mouse scroll — low impact for mobile-primary use; flagged for web testing

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries already in pubspec; API docs verified
- Architecture: HIGH — patterns directly derived from existing project code + official docs
- Pitfalls: MEDIUM — InteractiveViewer issues verified from Flutter GitHub issues tracker; StatefulShellRoute key collision is known community pitfall
- Building positions: HIGH — layout is Claude's discretion; positions verified to fit 14 buildings in 6x5 grid (30 cells, no overlaps)

**Research date:** 2026-03-11
**Valid until:** 2026-04-10 (go_router API stable; Flutter widget API stable)
