# Phase 17: UI Polish - Research

**Researched:** 2026-03-17
**Domain:** Flutter Material 3 UI — AppBar transparency, ownership color coding, unit type icon mapping
**Confidence:** HIGH (all findings verified directly from source files; no external library research needed — purely internal wiring)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### City View Layout
- Transparent AppBar with `extendBodyBehindAppBar: true` — building grid extends under AppBar area
- AppBar icons (back button, sign-out) remain with subtle drop shadow (`Shadow(blurRadius: 4, color: Colors.black54)`) for visibility on any background
- Apply to BOTH own city screen (CityScreen) and enemy city view screen (EnemyCityViewScreen) — both get transparent AppBar
- Enemy city view: remove red AppBar, keep "Viewing enemy city — read only" banner as sole visual distinction
- Own city: show city name as small label on the grid (not in AppBar, not hidden entirely)

#### Ownership Colors on Maps
- Color palette: Own=`Colors.green.shade600` (#43A047), Enemy=`Colors.red.shade600` (#E53935), Empty=`Colors.grey.shade400` (#BDBDBD)
- Render method: 2px colored border around city slot container with `BorderRadius.circular(8)`
- Apply to both Island view (per-slot coloring) and World map (per-island coloring)
- World map island color rule: if player has own city on island → green border; otherwise red if enemy cities present; grey if empty
- Simple rule: own city presence takes priority (kendi varsa her zaman yeşil)

#### Unit Type Color Styling
- Display: `CircleAvatar(backgroundColor: unitTypeColors[type], child: Icon(unitTypeIcon, color: Colors.white))`
- Each unit type gets a unique icon (13 icons total for 13 unit types) — not generic shield/sailing
- Add `unitTypeIcons` Map<UnitType, IconData> to `lib/core/constants/unit_constants.dart` alongside existing `unitTypeColors`
- Apply to ALL military screens: Barracks (training queue), Shipyard (training queue), Dispatch (army lists), battle reports

#### Cross-Screen Consistency
- Create `lib/core/constants/ownership_colors.dart` with centralized ownership color constants — all screens import from single source
- Ownership colors used in: island screen city slots, world map island cells, and potentially future alliance screens
- Enemy city view relies on read-only banner (not AppBar color) as visual distinction after transparent AppBar change

### Claude's Discretion
- Exact icon choices for each of the 13 unit types (from Material Icons library)
- City name label positioning and styling on own city grid
- Any animation or transition adjustments related to AppBar transparency

### Deferred Ideas (OUT OF SCOPE)
- Alliance/müttefik sistemi ve müttefik şehir rengi (mavi) — gelecek milestone'da
- Animasyonlu geçişler ve parallax efektleri — ayrı polish phase
- Dark mode desteği — ayrı tema phase'i
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| UIPL-01 | City view screen removes the AppBar title for cleaner layout | Transparent AppBar + `extendBodyBehindAppBar: true` pattern; city name moves to grid body |
| UIPL-02 | Cities on island/world map use distinct colors to differentiate own vs enemy vs ally | `ownership_colors.dart` constant file + border decoration on `_CitySlotCell` and `_IslandCell`; world map needs ownership data from provider |
| UIPL-03 | Unit types in military screens use subtle color coding consistent with unitTypeColors | `unitTypeIcons` map added to `unit_constants.dart`; `CircleAvatar` replaces flat Icon in all roster `ListTile` leading widgets |
</phase_requirements>

---

## Summary

Phase 17 is a pure visual polish phase: no new data models, no Supabase migrations, no new providers. Every change is a targeted widget modification to three independent UI concerns: AppBar transparency, ownership color borders, and unit type icon+color avatars.

The codebase already has all the raw material needed: `unitTypeColors` (13 colors in `unit_constants.dart`), `CitySlot.ownerId` (available on island screen), and the current user ID available via `Supabase.instance.client.auth.currentUser?.id`. The main gap is that the world map's `_IslandCell` widget only receives an `Island` model, which carries no ownership data — it only knows `luxuryType`, `gridX/Y`, and `maxCitySlots`. To show ownership-based borders on the world map, we must enrich the island data or query ownership separately.

The work naturally breaks into three independent workstreams that can be planned and executed in parallel: (1) AppBar transparency on CityScreen + EnemyCityViewScreen, (2) ownership color borders on IslandScreen + WorldMapScreen, and (3) unit icon/color avatars on all four military screens.

**Primary recommendation:** Execute as three plan files — one per UIPL requirement. Each is a self-contained widget change with no inter-dependency.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter/material.dart | SDK | Material 3 widgets (AppBar, CircleAvatar, Container, BoxDecoration) | Already the project UI framework |
| flutter_riverpod | ^3.3.1 | State access for current user ID in ownership checks | Already in use throughout |
| supabase_flutter | ^2.12.0 | `Supabase.instance.client.auth.currentUser?.id` for ownership | Already accessed in IslandScreen |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_test | SDK | Widget and unit tests for new constants and rendering | Existing test infrastructure; add tests for `unitTypeIcons` map and ownership constants |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Border.all (2px colored) | BoxShadow glow | Border is simpler, more legible at small cell sizes; glow requires more color tuning |
| CircleAvatar | Container + Icon | CircleAvatar is the standard Material circular avatar; less boilerplate |
| extendBodyBehindAppBar | Remove AppBar entirely | Removing loses the back/logout button placement; transparent AppBar preserves them |

---

## Architecture Patterns

### Recommended Project Structure

No new directories needed. New file:
```
lib/
├── core/
│   └── constants/
│       ├── unit_constants.dart        # ADD: unitTypeIcons map
│       └── ownership_colors.dart      # NEW: centralized ownership color constants
├── features/
│   ├── city/screens/city_screen.dart  # MODIFY: transparent AppBar
│   ├── map/
│   │   ├── screens/
│   │   │   ├── enemy_city_view_screen.dart  # MODIFY: transparent AppBar
│   │   │   ├── island_screen.dart           # MODIFY: ownership border on _CitySlotCell
│   │   │   └── world_map_screen.dart        # MODIFY: ownership border on _IslandCell
│   │   └── providers/
│   │       └── islands_provider.dart        # POSSIBLY MODIFY: enrich islands with ownership
│   └── military/
│       └── screens/
│           ├── barracks_screen.dart         # MODIFY: CircleAvatar in roster ListTile
│           ├── shipyard_screen.dart         # MODIFY: CircleAvatar in roster ListTile
│           ├── dispatch_screen.dart         # MODIFY: CircleAvatar in _UnitDispatchRow
│           └── battles_screen.dart          # battles_screen uses role icon, not unit type icon
```

### Pattern 1: Transparent AppBar with extendBodyBehindAppBar

**What:** Makes the Scaffold body extend behind the AppBar area; AppBar becomes transparent so the background content shows through.
**When to use:** When you want immersive full-height content without removing navigation controls.

```dart
// Source: Flutter Material docs (verified in current SDK)
Scaffold(
  extendBodyBehindAppBar: true,
  appBar: AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    shadowColor: Colors.transparent,
    // Icons need shadow for visibility on any background
    iconTheme: const IconThemeData(
      color: Colors.white,
      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
    ),
    actions: [
      // existing action icons with same shadow treatment
    ],
  ),
  body: ..., // body now starts from top of screen, behind AppBar
)
```

**City name placement:** Since the title is removed from AppBar, add a small label inside `_CityBody` just above or overlaying the building grid. A simple `Text` widget at the top of the scroll view body works (city name is already displayed in `_CityBody` as a `headlineMedium` — this remains; the AppBar title `Text` widget is what gets removed/hidden).

**Key observation from city_screen.dart:** CityScreen's AppBar title is a dynamic widget that shows a `CircularProgressIndicator` while loading and then the city name. After making transparent, the title can be removed entirely since `_CityBody` already renders the city name prominently at line 153-160 of `city_screen.dart`.

**Key observation from enemy_city_view_screen.dart:** The red AppBar (`backgroundColor: Colors.red.shade800`) needs to change to transparent. The "Viewing enemy city — read only" banner (lines 47-67) stays. Title `'$cityName ($ownerName)'` moves into the banner or disappears (banner already provides context).

### Pattern 2: Ownership Color Border via `ownership_colors.dart`

**What:** Centralized color constants imported by all screens needing ownership distinction.
**When to use:** Whenever rendering a city slot or island cell.

```dart
// lib/core/constants/ownership_colors.dart
import 'package:flutter/material.dart';

/// Ownership colors for city slots and island markers.
/// Single source of truth — import from here, never hardcode.
class OwnershipColors {
  OwnershipColors._();

  /// Player's own city — green.
  static const Color own = Color(0xFF43A047);       // Colors.green.shade600

  /// Enemy-owned city — red.
  static const Color enemy = Color(0xFFE53935);     // Colors.red.shade600

  /// Empty/unoccupied slot — grey.
  static const Color empty = Color(0xFFBDBDBD);     // Colors.grey.shade400
}
```

**Island screen usage** — modify `_CitySlotCell.build()`: the current implementation already uses `theme.colorScheme.primary` (own) vs `theme.colorScheme.secondary` (enemy). Replace with `OwnershipColors.own` / `OwnershipColors.enemy` / `OwnershipColors.empty`.

Current `_CitySlotCell` code (island_screen.dart lines 462-503):
- Already has `_isPlayerOwned` bool
- Already wraps in `Container(decoration: BoxDecoration(border: Border.all(...)))`
- Change `color` and `border.color` to use `OwnershipColors`

**World map usage** — the critical gap: `_IslandCell` only receives `Island?` which has no `ownerId` data. The Island model contains no city ownership information. The `allIslandsProvider` only calls `repository.fetchAllIslands()` which queries only the `islands` table (no join with `cities`).

**Solution for world map ownership:** Two options:
1. Enrich `fetchAllIslands()` to join with `cities` and include owner IDs, OR
2. Create a separate provider `islandOwnershipProvider` that queries `cities` table grouped by `island_id` to determine if the current player has a city on each island.

Option 2 is cleaner (separation of concerns) and matches the "simple bool check" specified in CONTEXT.md. The `_IslandGrid` widget can watch a `Map<String, IslandOwnership>` provider keyed by island ID. The `IslandOwnership` enum/class simply reports: `own`, `enemy`, or `empty`.

**Alternatively** (simpler): pass `playerCityIslandId` to `_IslandGrid` and compare `island.id == playerCityIslandId` for `own`. For enemy detection, we'd need another query. But the CONTEXT.md specifies "if player has own city on island → green; otherwise red if enemy cities present; grey if empty" — which requires knowing if ANY city exists on an island. The Island model already has `maxCitySlots` but not how many are occupied.

**Recommended approach:** Add a new provider `islandOwnershipProvider` (FutureProvider returning `Map<String, String>` of islandId → 'own'|'enemy'|'empty') that queries `SELECT island_id, owner_id FROM cities`. In `_IslandGrid`, watch this provider and pass ownership status to each `_IslandCell`.

### Pattern 3: CircleAvatar Unit Type Icon

**What:** Replace flat `Icon(Icons.shield)` / `Icon(Icons.sailing)` in military roster `ListTile.leading` with a colored `CircleAvatar` showing the unit-type-specific icon.
**When to use:** Any place that renders a unit type in a list (roster, training queue banner, dispatch row).

```dart
// In unit_constants.dart — add alongside unitTypeColors
const Map<UnitType, IconData> unitTypeIcons = {
  UnitType.hoplite:       Icons.shield,
  UnitType.phalanx:       Icons.security,
  UnitType.archer:        Icons.gps_fixed,
  UnitType.cavalry:       Icons.directions_run,
  UnitType.catapult:      Icons.rocket_launch,
  UnitType.mortar:        Icons.explosive,        // fallback: Icons.local_fire_department
  UnitType.medic:         Icons.medical_services,
  UnitType.cook:          Icons.restaurant,
  UnitType.cargoShip:     Icons.local_shipping,
  UnitType.ramShip:       Icons.directions_boat,
  UnitType.catapultShip:  Icons.precision_manufacturing,
  UnitType.mortarShip:    Icons.crisis_alert,
  UnitType.divingBoat:    Icons.scuba_diving,
};
```

Note: `Icons.explosive` does not exist in Material Icons — use `Icons.local_fire_department` for mortar. `Icons.scuba_diving` exists in Material Icons. Icon names above are suggestions per Claude's discretion; final choices at implementation time should be verified against the actual Material Icons set.

```dart
// Usage pattern for ListTile leading
Widget _unitAvatar(UnitType type) {
  return CircleAvatar(
    radius: 18,
    backgroundColor: unitTypeColors[type],
    child: Icon(
      unitTypeIcons[type] ?? Icons.help_outline,
      color: Colors.white,
      size: 18,
    ),
  );
}
```

### Anti-Patterns to Avoid

- **Hardcoding colors inline:** Never write `Colors.green.shade600` directly in screen files — always import from `OwnershipColors`. Consistency breaks the moment one screen uses a slightly different shade.
- **Querying ownership in the widget build method:** Ownership determination should be in a provider, not in `build()`. The island screen already reads `Supabase.instance.client.auth.currentUser?.id` directly — this is acceptable for local comparison but world map ownership needs a Riverpod provider since it involves a DB query.
- **Removing AppBar entirely:** Use `backgroundColor: Colors.transparent` + `extendBodyBehindAppBar: true`, not `appBar: null`. Removing AppBar drops back navigation on EnemyCityViewScreen (which is a push route via `context.push('/city-view...)`).
- **Using `withOpacity` or `withAlpha` on ownership colors:** Ownership colors should be fully saturated and opaque for maximum legibility — the current island screen uses `color.withAlpha(200)` for fill but the border should be full opacity.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Circular icon with background color | Custom `Container` + `ClipOval` | `CircleAvatar` | Material widget handles sizing, clipping, and color; less boilerplate |
| Determining current user | Auth session tracking | `Supabase.instance.client.auth.currentUser?.id` | Already used in island_screen.dart line 95 |
| Color constants across files | Inline `Color(0xFF...)` literals | `OwnershipColors` class | Single source; already decided in CONTEXT.md |

---

## Common Pitfalls

### Pitfall 1: AppBar SafeArea / Status Bar Overlap
**What goes wrong:** With `extendBodyBehindAppBar: true`, the body content starts at `top: 0` (behind status bar). If the city's `SingleChildScrollView` starts padding at `const EdgeInsets.all(16)`, the top content (city name heading) will render behind the status bar.
**Why it happens:** `extendBodyBehindAppBar: true` removes the automatic top padding that Scaffold normally adds.
**How to avoid:** Wrap body content with `SafeArea(top: true)` OR add `MediaQuery.of(context).padding.top` to the top padding of the scroll view. The body's existing `padding: const EdgeInsets.all(16)` in `city_screen.dart` line 144 needs a `top: MediaQuery.of(context).padding.top + AppBar height` offset.
**Warning signs:** City name text renders underneath the clock/signal bar in the status area.

### Pitfall 2: World Map Island Cells Have No Ownership Data
**What goes wrong:** `_IslandCell` only receives `Island?` from `allIslandsProvider`. The Island model has no `ownerId` or city count. Attempting to color-code by ownership will fail at compile time.
**Why it happens:** `fetchAllIslands()` only queries the `islands` table. The `cities` table join was never added to this query.
**How to avoid:** Add a separate `islandOwnershipProvider` that fetches city ownership. Do NOT modify the `Island` model — keep it aligned with the `islands` table schema.
**Warning signs:** `island.ownerId` — this field does not exist; code will not compile.

### Pitfall 3: `unitTypeIcons` Map Null Safety
**What goes wrong:** Using `unitTypeIcons[type]!` (force-unwrap) throws if any `UnitType` is missing from the map.
**Why it happens:** The existing `unitTypeColors` map uses `const` — same pattern will be used for `unitTypeIcons`. If a unit type is accidentally omitted, the `!` operator throws at runtime.
**How to avoid:** Always use `unitTypeIcons[type] ?? Icons.help_outline` as the fallback. Add a unit test asserting all 13 UnitType values are present in `unitTypeIcons` (mirrors existing `unit_type_colors_test.dart`).
**Warning signs:** `Null check operator used on a null value` crash on any military screen.

### Pitfall 4: EnemyCityViewScreen Back Navigation After AppBar Change
**What goes wrong:** After making the AppBar transparent, if the title text is removed along with any reference to it, the back button must still be present and functional.
**Why it happens:** `EnemyCityViewScreen` is pushed via `context.push('/city-view...')`. The default `AppBar` automatically shows a back button when there's a route to pop. Making it transparent preserves this behavior — but if `appBar: null` is used instead, the back button disappears.
**How to avoid:** Keep the AppBar widget; only change `backgroundColor` to transparent. The back button and any remaining actions are preserved.
**Warning signs:** No way to navigate back from the enemy city view.

### Pitfall 5: Battles Screen Has No Per-Unit-Type Rows
**What goes wrong:** The `BattlesScreen` (`battles_screen.dart`) shows battle tiles via `_BattleTile`, which uses a role-based icon (`Icons.gps_fixed_outlined` / `Icons.shield_outlined`) — not per-unit-type coloring. There is no unit type breakdown rendered in the list view.
**Why it happens:** The `allMyBattlesProvider` provides `Battle` objects; battle tiles show attacker/defender status, not unit composition.
**How to avoid:** Unit type color coding applies to the `BattleDetailScreen` (not `BattlesScreen`) if it shows unit breakdowns. Need to check `battle_detail_screen.dart`. However, CONTEXT.md says "battle reports" — if the detail screen shows unit rows, that is the target. The top-level `BattlesScreen` list view does NOT need unit color coding.
**Warning signs:** Trying to add `CircleAvatar` to `_BattleTile` where no `UnitType` data exists.

---

## Code Examples

### Transparent AppBar Pattern
```dart
// Source: Flutter SDK AppBar documentation + extendBodyBehindAppBar property
Scaffold(
  extendBodyBehindAppBar: true,
  appBar: AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    shadowColor: Colors.transparent,
    foregroundColor: Colors.white,
    iconTheme: const IconThemeData(
      color: Colors.white,
      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
    ),
    actionsIconTheme: const IconThemeData(
      color: Colors.white,
      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
    ),
    // Remove title widget entirely (title is in body)
  ),
  body: SafeArea(
    top: false, // let body go behind status bar
    child: SingleChildScrollView(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
        left: 16, right: 16, bottom: 16,
      ),
      child: ...,
    ),
  ),
)
```

### Ownership Color Border on City Slot Cell
```dart
// Source: island_screen.dart _CitySlotCell.build() — existing pattern, updated colors
import '../../../core/constants/ownership_colors.dart';

// In _CitySlotCell.build():
Color _borderColor() {
  if (slot == null || !slot!.isOccupied) return OwnershipColors.empty;
  if (_isPlayerOwned) return OwnershipColors.own;
  return OwnershipColors.enemy;
}

// Container decoration:
decoration: BoxDecoration(
  color: _borderColor().withAlpha(40),  // light fill
  borderRadius: BorderRadius.circular(8),
  border: Border.all(color: _borderColor(), width: 2),
),
```

### World Map Ownership Provider (new)
```dart
// New provider — queries cities table to determine per-island ownership
// Returns Map<islandId, 'own'|'enemy'|'empty'>
final islandOwnershipProvider = FutureProvider<Map<String, String>>((ref) async {
  final currentUserId = Supabase.instance.client.auth.currentUser?.id;
  final rows = await supabaseClient
      .from('cities')
      .select('island_id, owner_id');

  final result = <String, String>{};
  for (final row in rows as List<dynamic>) {
    final islandId = row['island_id'] as String;
    final ownerId = row['owner_id'] as String;
    if (ownerId == currentUserId) {
      result[islandId] = 'own';  // own takes priority
    } else if (!result.containsKey(islandId)) {
      result[islandId] = 'enemy';
    }
    // if already 'own', skip (own takes priority per CONTEXT.md)
  }
  return result;
});
```

### CircleAvatar Unit Type Icon in ListTile
```dart
// Source: existing barracks_screen.dart _ArmyRosterSection + unit_constants.dart
import '../../../core/constants/unit_constants.dart';

// Replace:  leading: const Icon(Icons.shield),
// With:
leading: Builder(builder: (context) {
  UnitType? type;
  try { type = unitTypeFromDbName(u.unitType); } catch (_) {}
  if (type == null) return const Icon(Icons.help_outline);
  return CircleAvatar(
    radius: 16,
    backgroundColor: unitTypeColors[type],
    child: Icon(
      unitTypeIcons[type] ?? Icons.help_outline,
      color: Colors.white,
      size: 16,
    ),
  );
}),
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Solid colored AppBar (`primaryColor`) | Transparent AppBar + `extendBodyBehindAppBar` | Phase 17 | City grid fills full vertical space |
| Generic shield/sailing icon for all units | Per-unit-type icon + color via `unitTypeIcons` | Phase 17 | Players immediately identify unit types visually |
| Theme-based ownership colors (primary/secondary) | Semantic `OwnershipColors` constants (green/red/grey) | Phase 17 | Consistent cross-screen ownership language |
| `Colors.red.shade800` AppBar on EnemyCityViewScreen | Transparent AppBar + red banner only | Phase 17 | Consistent AppBar pattern across all city views |

---

## Open Questions

1. **BattleDetailScreen unit type rows**
   - What we know: `BattlesScreen` does not display per-unit-type rows. The spec says "battle reports."
   - What's unclear: Whether `BattleDetailScreen` renders unit composition rows that need `CircleAvatar`. The file was not read during research.
   - Recommendation: Read `lib/features/battles/screens/battle_detail_screen.dart` in Wave 0 of the relevant plan task. If it has unit type rows, apply the same `CircleAvatar` pattern. If not, UIPL-03 is fully satisfied by barracks + shipyard + dispatch alone.

2. **World map ownership query performance**
   - What we know: `islandOwnershipProvider` needs to scan the `cities` table. There are at most 5×5=25 islands × max 16 slots = 400 cities total in the current world layout.
   - What's unclear: Whether a single `SELECT island_id, owner_id FROM cities` query is fast enough for the world map load. Given the small dataset (≤400 rows), it is acceptable.
   - Recommendation: Use a single query with no pagination. Cache via FutureProvider (re-fetches on invalidation only).

3. **Body padding with transparent AppBar on CityScreen**
   - What we know: `CityScreen._CityBody` uses `SingleChildScrollView(padding: const EdgeInsets.all(16))` (city_screen.dart line 144). With `extendBodyBehindAppBar: true`, the content will scroll under the AppBar.
   - What's unclear: Whether the city name `headlineMedium` text at the top of `_CityBody` should be visible immediately or scroll under the AppBar.
   - Recommendation: Add `top: kToolbarHeight + MediaQuery.of(context).padding.top` to the scroll view padding. This ensures content starts below the transparent AppBar area.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK bundled) |
| Config file | none — standard Flutter test runner |
| Quick run command | `flutter test test/unit/unit_constants_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UIPL-01 | Transparent AppBar renders without title text | Widget (smoke) | `flutter test test/widget/city_screen_appbar_test.dart` | ❌ Wave 0 |
| UIPL-02 | OwnershipColors constants have correct hex values | Unit | `flutter test test/unit/ownership_colors_test.dart` | ❌ Wave 0 |
| UIPL-02 | _CitySlotCell renders green border for own city | Widget | `flutter test test/widget/island_screen_ownership_test.dart` | ❌ Wave 0 |
| UIPL-03 | unitTypeIcons has 13 entries, all UnitType values covered | Unit | `flutter test test/unit/unit_constants_test.dart` | ✅ (extend existing) |
| UIPL-03 | unitTypeIcons values are all distinct IconData | Unit | `flutter test test/unit/unit_constants_test.dart` | ✅ (extend existing) |

### Sampling Rate
- **Per task commit:** `flutter test test/unit/unit_constants_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/widget/city_screen_appbar_test.dart` — covers UIPL-01 (transparent AppBar smoke test)
- [ ] `test/unit/ownership_colors_test.dart` — covers UIPL-02 (color constant values)
- [ ] `test/widget/island_screen_ownership_test.dart` — covers UIPL-02 (slot border colors)

*(Existing `test/unit_type_colors_test.dart` will be extended for UIPL-03 unitTypeIcons coverage — no new file needed for that check.)*

---

## Sources

### Primary (HIGH confidence)
- `lib/core/constants/unit_constants.dart` — confirmed `unitTypeColors` map with 13 entries; `UnitType` enum with all 13 values; no `unitTypeIcons` map currently exists
- `lib/core/theme/app_theme.dart` — confirmed `AppBarTheme(backgroundColor: primaryColor, elevation: 0)` global theme; transparent AppBar will override this per-screen
- `lib/features/city/screens/city_screen.dart` — confirmed AppBar title structure (dynamic Text/spinner); `_CityBody` already renders city name at headline level (line 153); body uses `SingleChildScrollView(padding: EdgeInsets.all(16))`
- `lib/features/map/screens/enemy_city_view_screen.dart` — confirmed `Colors.red.shade800` AppBar; read-only banner at lines 47-67; Scaffold body is a `Column` not `SingleChildScrollView`
- `lib/features/map/screens/island_screen.dart` — confirmed `_CitySlotCell` with `_isPlayerOwned` bool and existing `theme.colorScheme.primary/secondary` coloring; ready to swap for `OwnershipColors`
- `lib/features/map/screens/world_map_screen.dart` — confirmed `_IslandCell` only receives `Island?`; no ownership data; uses `_islandColor()` based on `luxuryType` only
- `lib/features/map/models/island.dart` — confirmed Island model has NO ownership fields
- `lib/features/map/models/island_city_slot.dart` — confirmed `ownerId` field present on `CitySlot`
- `lib/features/map/data/map_repository.dart` — confirmed `fetchAllIslands()` queries `islands` table only; `fetchIslandDetail()` does query `cities` table with `owner_id`
- `lib/features/military/screens/barracks_screen.dart` — confirmed `_ArmyRosterSection` uses `ListTile(leading: const Icon(Icons.shield))` — target for CircleAvatar replacement
- `lib/features/military/screens/shipyard_screen.dart` — confirmed `_NavyRosterSection` uses `ListTile(leading: const Icon(Icons.sailing))` — target for CircleAvatar replacement
- `lib/features/military/screens/dispatch_screen.dart` — confirmed `_UnitDispatchRow` uses `Icon(isNaval ? Icons.sailing : Icons.shield)` — target for CircleAvatar replacement
- `lib/features/battles/screens/battles_screen.dart` — confirmed `_BattleTile` uses role-based icon only; NO unit type breakdown rows in list view; battle reports unit colors would be in BattleDetailScreen (unread)

### Secondary (MEDIUM confidence)
- Flutter SDK documentation on `extendBodyBehindAppBar` and transparent AppBar — standard pattern, well-known behavior

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new libraries; all existing project dependencies
- Architecture: HIGH — direct code inspection of all target files; exact widget locations identified
- Pitfalls: HIGH — based on direct code reading (e.g., world map ownership gap confirmed by reading Island model and map_repository.dart)

**Research date:** 2026-03-17
**Valid until:** 2026-04-17 (stable Flutter Material 3 patterns; project code is stable)
