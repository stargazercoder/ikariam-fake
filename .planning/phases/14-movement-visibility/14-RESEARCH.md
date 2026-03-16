# Phase 14: Movement Visibility - Research

**Researched:** 2026-03-16
**Domain:** Flutter/Riverpod real-time UI — Supabase Realtime stream extension, new navigation tab, model update
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Dedicated Movements screen — new screen showing ALL movements across all player's cities
- Accessible via new tab in MainShellScreen bottom navigation bar
- Global view (not per-city) — streams all movements owned by the current player
- Sorted by ETA (soonest arrival first)
- Full unit breakdown per row: show every unit type and quantity (e.g., "50 hoplite, 20 archer, 10 cavalry")
- Cargo (pillage loot / trade resources) displayed inline with movement row using resource icons + amounts
- Destination city names resolved from IDs (not raw UUIDs) — requires city name lookup/join
- Live countdown timer for ETA (ticking: "3m 24s → 3m 23s...") — reuse existing CountdownTimerWidget
- Movement type indicator: attack (⚔) vs return (↩) based on `movement_type` column
- Auto-remove movements from list when army arrives (Realtime subscription picks up DELETE automatically)
- New dispatches appear immediately via Supabase Realtime subscription (same pattern as existing unitMovementsProvider)
- No "arrived" transition state — movement simply disappears when process_arrivals() deletes the row
- Empty state: simple text message "No armies in transit" — minimal, consistent with existing patterns
- Show ALL own movements: both outgoing attacks and incoming returns (matches MOVE-01 + MOVE-02)

### Claude's Discretion
- Movement row card styling and spacing
- Icon choices for attack vs return movement types
- How city name lookup is implemented (join in query vs separate provider)
- Whether to add movement_type to UnitMovement Dart model or handle display-side
- Resource icon rendering approach for cargo display
- Bottom nav icon choice for Movements tab

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| MOVE-01 | User can see a list of outgoing army movements (attack, return) with destination, ETA, and unit composition | Global movements stream (all owner_id rows), UnitMovement model with movement_type, city name resolution, CountdownTimerWidget reuse |
| MOVE-02 | User can see returning cargo ships with carried resource amounts (pillage loot and trade cargo) | cargo JSONB already parsed in UnitMovement.fromJson; display inline in movement card; ResourceType enum maps keys |
</phase_requirements>

---

## Summary

Phase 14 is a pure read/display phase. All backend data exists: `unit_movements` table has `movement_type` ('attack'|'return'), `cargo` JSONB (populated by `resolve_battles()` on pillage victory), and `arrive_at` for ETA. The Dart `UnitMovement` model already parses `units` and `cargo` — the only missing field is `movement_type`, which must be added to the model. The existing `watchOutgoingMovements()` method streams all owner movements and filters client-side by `originCityId`; a global variant simply drops that client-side filter. City name resolution requires a one-time Supabase fetch (cities table, SELECT id+name WHERE id IN [...]) since the movement rows only store destination_city_id UUIDs.

The navigation extension is well-understood: `MainShellScreen` uses `StatefulShellRoute.indexedStack` with four `StatefulShellBranch` entries today. Adding a fifth branch for `/movements` follows the exact same pattern already used for Battles. `allMyBattlesProvider` (combining two streams via `Provider.autoDispose`) is the canonical model for a global, merged, sorted list provider — the movements equivalent is simpler because there is only one stream (owner_id already covers all own movements).

**Primary recommendation:** Add `movement_type` to `UnitMovement` model, add `watchAllMovements()` to `MilitaryRepository`, create `allMovementsProvider` mirroring `allMyBattlesProvider` pattern, add fifth nav branch, build `MovementsScreen` reusing `_MovementCard`-style card with city name lookup.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_riverpod | project-pinned | Reactive state + stream binding | Already used throughout, all providers are Riverpod |
| supabase_flutter | project-pinned | Realtime `.stream()` for live data | Established pattern in MilitaryRepository, BattleRepository |
| go_router | project-pinned | StatefulShellRoute for bottom nav branches | Already drives all navigation tabs |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| dart:async | stdlib | Stream transformation | Not needed — Riverpod handles stream subscription lifecycle |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| One-time fetch for city names | Supabase Realtime stream on cities table | Overkill — city names rarely change; one-time fetch is sufficient and cheaper |
| Provider.autoDispose for merged list | StreamProvider with Rx combineLatest | Project uses non-codegen Riverpod; Provider.autoDispose matching battles pattern is simpler |

**Installation:**
No new packages required — all needed libraries already in pubspec.

---

## Architecture Patterns

### Recommended Project Structure
```
lib/features/movements/
├── models/                      # (none needed — reuse UnitMovement)
├── providers/
│   └── movements_provider.dart  # allMovementsProvider + cityNamesProvider
├── data/
│   └── (no new repository — extend MilitaryRepository)
└── screens/
    └── movements_screen.dart    # MovementsScreen + _MovementCard widget
```

Note: `movement_type` addition to `UnitMovement` stays in `lib/features/military/models/unit_movement.dart` since it belongs to the military domain model.

### Pattern 1: Global Movements Stream (no per-city filter)
**What:** `watchAllMovements()` is identical to `watchOutgoingMovements()` but without the `.where(m => m.originCityId == cityId)` client-side filter. The Supabase `.stream().eq('owner_id', userId)` filter is sufficient — it returns all own movements regardless of origin city.

**When to use:** Any screen that needs all player movements globally (this phase).

**Example:**
```dart
// lib/features/military/data/military_repository.dart (extend existing)
Stream<List<UnitMovement>> watchAllMovements() {
  final userId = supabaseClient.auth.currentUser?.id;
  if (userId == null) return const Stream.empty();
  return supabaseClient
      .from('unit_movements')
      .stream(primaryKey: ['id'])
      .eq('owner_id', userId)
      .map(
        (rows) => rows
            .map((r) => UnitMovement.fromJson(r))
            .toList()
          ..sort((a, b) => a.arriveAt.compareTo(b.arriveAt)), // soonest first
      );
}
```

### Pattern 2: allMovementsProvider (mirrors allMyBattlesProvider)
**What:** A `Provider.autoDispose` that watches the stream provider and returns a sorted, client-ready list. Handles unauthenticated state gracefully.

**When to use:** Global screens that need live list with no family parameter.

**Example:**
```dart
// lib/features/movements/providers/movements_provider.dart
final allMovementsStreamProvider =
    StreamProvider.autoDispose<List<UnitMovement>>(
  (ref) => ref.read(militaryRepositoryProvider).watchAllMovements(),
);

final allMovementsProvider = Provider.autoDispose<List<UnitMovement>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.watch(allMovementsStreamProvider).asData?.value ?? [];
});
```

### Pattern 3: City Name Resolution via FutureProvider.family
**What:** A `FutureProvider.autoDispose.family<String?, String>` that fetches a city name by ID from Supabase. The movements screen calls this for each unique `destinationCityId`.

**When to use:** When displaying city names in any widget given only a city UUID.

**Example:**
```dart
final cityNameProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, cityId) async {
  final row = await supabaseClient
      .from('cities')
      .select('name')
      .eq('id', cityId)
      .maybeSingle();
  return row?['name'] as String?;
});
```

Alternatively (lower N+1 risk): fetch all distinct city IDs in one query. With a small number of movements per player, individual family providers are acceptable and cache naturally via `autoDispose`.

### Pattern 4: Navigation Branch Addition
**What:** Add a fifth `StatefulShellBranch` to `StatefulShellRoute.indexedStack` in `app_router.dart`, and a fifth `NavigationDestination` in `MainShellScreen`.

**When to use:** Every new global tab follows this exact pattern.

**Example (app_router.dart):**
```dart
// Add at file level alongside existing navigator keys
final _movementsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'movementsNav');

// Add inside StatefulShellRoute.indexedStack branches list
StatefulShellBranch(
  navigatorKey: _movementsNavigatorKey,
  routes: [
    GoRoute(
      path: '/movements',
      builder: (context, state) => const MovementsScreen(),
    ),
  ],
),
```

**Example (main_shell_screen.dart destinations list):**
```dart
NavigationDestination(
  icon: Icon(Icons.swap_horiz_outlined),
  selectedIcon: Icon(Icons.swap_horiz),
  label: 'Movements',
),
```

### Pattern 5: UnitMovement model — movement_type addition
**What:** Add `movementType` field to `UnitMovement` model. The DB column `movement_type` has `DEFAULT 'attack'` so all existing rows are non-null.

**Example:**
```dart
// In UnitMovement constructor
final String movementType; // 'attack' | 'return'

// In fromJson
movementType: json['movement_type'] as String? ?? 'attack',
```

Handling display-side only (without adding to model) is also viable but less clean — the model change is the right approach since the field is a first-class DB column.

### Anti-Patterns to Avoid
- **Filtering movements by `originCityId` in the global provider:** The global view must show ALL movements; the per-city filter belongs only to `watchOutgoingMovements()`.
- **Opening a second Realtime subscription for global movements:** Re-use the same `.stream().eq('owner_id', userId)` pattern — the Supabase client deduplicates by channel key, but avoid creating duplicate providers.
- **Using `.select()` with join for city names inside the Realtime stream:** Supabase `.stream()` does not support joins. City names must be fetched separately (one-time `.select()` queries via `FutureProvider.family`).
- **Trusting `hasArrived` on the model to hide movements:** The Realtime DELETE event removes the row server-side; no client-side arrival gating is needed or desired.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Live countdown timer | Custom StatefulWidget with Timer | `CountdownTimerWidget` (`lib/features/city/widgets/countdown_timer_widget.dart`) | Already handles Timer lifecycle, `didUpdateWidget`, zero-clamp, `FontFeature.tabularFigures` |
| Realtime subscription lifecycle | Manual `SupabaseStreamSubscription` | Riverpod `StreamProvider.autoDispose` | autoDispose cancels subscription when widget unmounts |
| Unit display name lookup | String mapping switch | `unitTypeFromDbName(dbName).displayName` from `unit_constants.dart` | Covers all 13 unit types, throws on unknown |
| Resource type display | Custom string switch | `ResourceType` enum from `resource_constants.dart` | Consistent snake_case → enum mapping |
| Unit color coding | Hardcoded color map | `unitTypeColors` map from `unit_constants.dart` | 13 distinct colors, both light/dark safe |

**Key insight:** Every visual primitive for this phase (countdown, unit name, resource name, colors) already exists in the codebase. This phase is assembly, not construction.

---

## Common Pitfalls

### Pitfall 1: Supabase .stream() does not support joins or multi-column EQ filters
**What goes wrong:** Attempting `.stream().eq('owner_id', x).eq('movement_type', 'return')` or trying to join cities for names inside the stream — both silently fail or throw at runtime.
**Why it happens:** Supabase Realtime `.stream()` only supports a single `.eq()` filter. JOINs are not supported.
**How to avoid:** Stream only by `owner_id`. Client-side sort/filter for everything else. Fetch city names separately via `FutureProvider.family` using standard `.select()`.
**Warning signs:** Runtime exception "Invalid filter" or city names never resolving.

### Pitfall 2: GlobalKey navigator keys must be file-level constants
**What goes wrong:** If `GlobalKey<NavigatorState>` for the new branch is declared inside a build method or provider, GoRouter recreates it on every rebuild, causing navigation state loss.
**Why it happens:** StatefulShellRoute requires stable keys across rebuilds — this is why existing keys (`_worldNavigatorKey` etc.) are file-level `final` constants.
**How to avoid:** Declare `final _movementsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'movementsNav')` at file level in `app_router.dart`, alongside the existing four.
**Warning signs:** Tab state resets on every navigation, or GoRouter asserts about duplicate keys.

### Pitfall 3: Branch index must match destinations list order
**What goes wrong:** The `StatefulShellBranch` list index in `app_router.dart` must exactly match the `NavigationDestination` list index in `MainShellScreen`. Mismatch causes wrong tab to appear selected or wrong screen shown.
**Why it happens:** `navigationShell.currentIndex` drives `selectedIndex` in `NavigationBar` — it's positional.
**How to avoid:** Add the new branch and destination at the same position in both files (both as index 4, after Battles).
**Warning signs:** Tapping "Movements" tab navigates to a different screen.

### Pitfall 4: JSONB int parsing inconsistency
**What goes wrong:** `cargo` values parsed as `v as int` fail at runtime when Supabase returns numeric values as `double` or `num` (e.g., `450.0` instead of `450`).
**Why it happens:** Supabase JSON decoding can return numerics as `num`, not always `int`. The project's STATE.md explicitly notes this as known tech debt.
**How to avoid:** Use `(v as num).toInt()` when parsing cargo map values (already correctly done in `UnitMovement.fromJson`). Do not change this pattern.
**Warning signs:** `type 'double' is not a subtype of type 'int'` crash when viewing cargo movements.

### Pitfall 5: Empty movement_type from older rows
**What goes wrong:** Pre-migration rows have `movement_type = 'attack'` (the column DEFAULT). But if somehow `fromJson` reads a null value (e.g., stale cache), display logic breaks.
**Why it happens:** The migration added `DEFAULT 'attack' NOT NULL`, so this should not occur in practice. However defensive parsing is cheap.
**How to avoid:** Parse as `json['movement_type'] as String? ?? 'attack'` — the null-coalesce covers any edge cases.
**Warning signs:** Null reference in movement type display logic.

---

## Code Examples

Verified patterns from existing codebase:

### Existing _MovementCard pattern (to extend)
```dart
// Source: lib/features/military/screens/dispatch_screen.dart _MovementCard
// Current: shows shortened UUID destination
// Phase 14: replace _shortId() call with cityNameProvider lookup + show movement_type icon

Row(
  children: [
    const Icon(Icons.military_tech, size: 18),
    const SizedBox(width: 8),
    Expanded(
      child: Text(
        'To: ${_shortId(movement.destinationCityId)}',
        ...
      ),
    ),
  ],
),
```

### CountdownTimerWidget usage (verified in dispatch_screen.dart and battles_screen.dart)
```dart
// Source: lib/features/city/widgets/countdown_timer_widget.dart
CountdownTimerWidget(
  finishAt: movement.arriveAt,
  style: theme.textTheme.bodySmall?.copyWith(
    fontWeight: FontWeight.bold,
    fontFeatures: [const FontFeature.tabularFigures()],
  ),
),
```

### Unit composition display (derived from existing _MovementCard.unitSummary)
```dart
// Source: lib/features/military/screens/dispatch_screen.dart
final unitSummary = movement.units.entries
    .map((e) => '${unitTypeFromDbName(e.key).displayName} x${e.value}')
    .join(', ');
```

### Cargo display (new — cargo JSONB already parsed in model)
```dart
// movement.cargo is Map<String, int>? — keys are ResourceType.value strings
if (movement.cargo != null && movement.cargo!.isNotEmpty)
  Wrap(
    spacing: 8,
    children: movement.cargo!.entries
        .map((e) => Text('${e.key}: ${e.value}'))
        .toList(),
  ),
```

### allMyBattlesProvider merge pattern (canonical reference for allMovementsProvider)
```dart
// Source: lib/features/battles/providers/battles_provider.dart
final allMyBattlesProvider = Provider.autoDispose<List<Battle>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final attackerAsync = ref.watch(attackerBattlesProvider(user.id));
  final defenderAsync = ref.watch(defenderBattlesProvider(user.id));
  // ... merge and sort
});
// Movements equivalent is simpler: single stream, no merge needed
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Per-city movements only (watchOutgoingMovements) | Global movements stream (watchAllMovements) | Phase 14 | New method needed in MilitaryRepository |
| UnitMovement without movement_type | UnitMovement with movementType field | Phase 14 | fromJson update + display logic |
| Destination shown as short UUID | Destination resolved to city name | Phase 14 | cityNameProvider FutureProvider.family |
| 4-tab bottom nav | 5-tab bottom nav | Phase 14 | New branch + destination in router + shell |

**No deprecated patterns** — existing code is current with project conventions.

---

## Open Questions

1. **City name resolution strategy: per-ID FutureProvider.family vs batch fetch**
   - What we know: `FutureProvider.autoDispose.family<String?, String>` is clean and Riverpod-standard; with typical <20 concurrent movements per player the N+1 is trivial
   - What's unclear: If a player has many movements simultaneously (edge case), multiple sequential fetches could cause visible flash of UUIDs
   - Recommendation: Use `FutureProvider.family` per city ID — simple and sufficient. If batch matters, a single `FutureProvider<Map<String,String>>` that fetches all distinct city IDs from the current movements list is the upgrade path.

2. **Whether to display origin city in the movement row**
   - What we know: CONTEXT.md only requires destination city name; origin is not mentioned
   - What's unclear: For the global view (all cities), showing origin may help context
   - Recommendation: Claude's Discretion — include origin city name as secondary text if it fits the card layout naturally; do not add a second cityNameProvider call if it complicates the card.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Flutter test (built-in) |
| Config file | none detected at project root |
| Quick run command | `flutter test` |
| Full suite command | `flutter test --coverage` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MOVE-01 | `UnitMovement.fromJson` parses `movement_type` field | unit | `flutter test test/features/military/models/unit_movement_test.dart -x` | ❌ Wave 0 |
| MOVE-01 | `watchAllMovements()` streams all owner movements without city filter | unit (mock) | `flutter test test/features/military/data/military_repository_test.dart -x` | ❌ Wave 0 |
| MOVE-01 | `allMovementsProvider` sorts by ETA soonest first | unit | `flutter test test/features/movements/providers/movements_provider_test.dart -x` | ❌ Wave 0 |
| MOVE-02 | `UnitMovement.fromJson` correctly parses cargo JSONB with `(v as num).toInt()` | unit | `flutter test test/features/military/models/unit_movement_test.dart -x` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test`
- **Per wave merge:** `flutter test --coverage`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/features/military/models/unit_movement_test.dart` — covers MOVE-01 (movement_type parsing), MOVE-02 (cargo parsing)
- [ ] `test/features/movements/providers/movements_provider_test.dart` — covers MOVE-01 (sort order, empty state)
- [ ] `test/features/military/data/military_repository_test.dart` — covers MOVE-01 (global stream no city filter)

---

## Sources

### Primary (HIGH confidence)
- Direct code inspection: `lib/features/military/models/unit_movement.dart` — confirmed fields, fromJson, cargo parsing
- Direct code inspection: `lib/features/military/data/military_repository.dart` — confirmed stream pattern, single eq filter
- Direct code inspection: `lib/core/router/app_router.dart` — confirmed StatefulShellBranch pattern, navigator key pattern
- Direct code inspection: `lib/features/map/screens/main_shell_screen.dart` — confirmed NavigationDestination list, 4 existing tabs
- Direct code inspection: `lib/features/battles/providers/battles_provider.dart` — confirmed allMyBattlesProvider pattern for global provider
- Direct code inspection: `supabase/migrations/20260312000001_add_movement_type_to_unit_movements.sql` — confirmed movement_type column, DEFAULT 'attack', CHECK constraint
- Direct code inspection: `supabase/migrations/20260315000001_pillage_schema_and_functions.sql` — confirmed cargo JSONB column, how return movements are created with cargo

### Secondary (MEDIUM confidence)
- Supabase Realtime `.stream()` single-filter limitation: confirmed by existing codebase comment in `military_repository.dart` line 73-74: "Supabase Realtime .stream() does not support filtering by two columns simultaneously"

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries already in project, no new dependencies
- Architecture: HIGH — all patterns directly observed in existing codebase
- Pitfalls: HIGH — Supabase limitation documented in codebase, navigator key pitfall from GoRouter docs confirmed by existing code pattern
- Validation: MEDIUM — test file paths inferred from Flutter convention; no existing test files found for military feature

**Research date:** 2026-03-16
**Valid until:** 2026-04-16 (stable — no fast-moving dependencies; all code is project-internal)
