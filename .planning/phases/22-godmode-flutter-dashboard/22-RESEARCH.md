# Phase 22: GodMode Flutter Dashboard - Research

**Researched:** 2026-03-17
**Domain:** Flutter admin dashboard — polling-based data refresh, tabbed layout, inline row editing, Riverpod AsyncNotifier, Supabase RPC integration
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Dashboard Layout**
- Tabbed layout with TabBar at the top: **Players** | **Events**
- `/godmode` route is full-page (outside StatefulShellRoute, no bottom nav) — carried from Phase 21
- Each tab has its own content area, no cross-tab navigation needed

**Player Table (Players Tab)**
- Compact rows with columns: Name, total resources (single number), land army count, naval army count, building count, bot/human indicator, active battles count, actions column
- Column headers are sortable (tap to sort by that column)
- Bot players show a small "BOT" badge next to their name — visible only to admin
- Bot rows have inline controls in the actions column: pause/play toggle icon + force action button
- Human player rows have only the edit (resource/army) action
- "Pause All Bots" / "Resume All Bots" bulk control button above the table

**Event Feed (Events Tab)**
- Chronological timeline list, newest first
- Each event shows: event type icon + timestamp + one-line summary with player names
- Filter chips at the top: All | Battle | Trade | Espionage (maps to `godmode_get_events` `p_event_type` parameter)
- Event type icons: sword for battle, package for trade, spy for espionage

**Data Refresh & Polling**
- Auto-poll every 30 seconds for both world state and events
- Stale data stays visible during refresh — no loading overlay on subsequent polls
- AppBar shows "Last updated: Xs ago" indicator that counts up between refreshes
- Small spinner icon in AppBar during active refresh
- Manual refresh button also available in AppBar
- Initial load shows standard loading spinner (first load only)

**Bot Control Interactions**
- Pause/resume: instant toggle (no confirmation dialog), result shown via SnackBar
- Force action: confirmation dialog before executing ("Force bot [name] to act now?"), result SnackBar shows which action the bot took (upgrade/train/attack/none)
- Bulk pause/resume: instant (no confirmation), SnackBar confirms count

**Resource & Army Editing**
- Inline table editing: tap a resource/army cell to enter edit mode for that row
- Edit mode activates for the entire row — all editable fields become text inputs with current values pre-filled
- Row-level Save button appears when in edit mode; Cancel button to discard changes
- Resources: 5 fields (Wood, Marble, Crystal, Sulfur, Gold) — calls existing `admin_set_resources` RPC
- Army: 13 unit type fields (8 land + 5 naval) — requires new `admin_set_army` SECURITY DEFINER RPC
- Save calls the appropriate RPC(s) and exits edit mode on success; shows error SnackBar on failure
- Only one row can be in edit mode at a time

### Claude's Discretion
- Exact tab order and naming
- Color scheme and typography for the dashboard
- Loading skeleton design for initial load
- Exact layout of inline edit mode (how fields are arranged in the row)
- Whether to use Flutter DataTable or custom Row/Column for the player table
- Error state design (RPC failure, network issues)
- AppBar design and back navigation to game

### Deferred Ideas (OUT OF SCOPE)
- GodMode world map overlay — v1.3+ future requirement (GOD-F01)
- Time-travel replay — v1.3+ future requirement (GOD-F02)
- Economy analytics dashboard — v1.3+ future requirement (GOD-F03)
- Bot speed adjustment (manipulating `next_action_at`) — could add later if needed
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| GOD-01 | Admin sees all players' resources, armies, and building levels in a single full-page dashboard table | `godmode_get_world_state()` RPC returns full JSONB snapshot; players table backed by `AsyncNotifierProvider` with 30-second poll via `Timer.periodic` |
| GOD-02 | Admin can pause, resume, and adjust speed of bot behaviors | `godmode_set_bot_paused(p_bot_id, p_paused)` RPC; bulk operations iterate over bot-only player rows; inline toggle in actions column |
| GOD-03 | Admin sees a live event feed showing battles, trades, and espionage actions | `godmode_get_events(p_limit, p_event_type)` RPC; filter chip maps to `p_event_type` param; same 30-second poll cycle |
| GOD-04 | Admin can modify any player's resources and army counts | `admin_set_resources(...)` exists; new `admin_set_army(...)` SECURITY DEFINER RPC needed for 13 unit types; inline row edit mode with TextFields |
</phase_requirements>

---

## Summary

Phase 22 builds the Flutter-side admin dashboard that consumes the five SECURITY DEFINER RPCs created in Phase 21. The backend is complete and stable; all work in this phase is Flutter UI and one new Supabase migration (`admin_set_army`).

The project uses Flutter Riverpod 3.x with manual `AsyncNotifier` definitions (no code-gen due to analyzer conflicts). All data access follows the established repository pattern and raw `Map<String, dynamic>` data model — no typed Dart classes. Polling (not Supabase Realtime) is the correct approach for GodMode because the RPC returns aggregated multi-table snapshots that cannot be streamed via Realtime's single-table subscriptions.

The dashboard is structurally simple: one `AsyncNotifierProvider` for world state, one for events, a `StatefulWidget` for the 30-second "elapsed time" counter in the AppBar, and local `StatefulWidget` row-edit state in the player table. The highest-complexity piece is the inline edit mode with 13+ TextFields and the new `admin_set_army` RPC migration.

**Primary recommendation:** Use a custom `Column`/`Row`/`SingleChildScrollView` layout for the player table (not Flutter's `DataTable`) — DataTable does not support mixed-height rows needed for inline edit mode expansion, and the project has no prior use of DataTable.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_riverpod | ^3.3.1 (pinned in pubspec.yaml) | State management, provider composition | Project standard throughout all phases |
| supabase_flutter | ^2.12.0 (pinned in pubspec.yaml) | RPC calls, auth | Project standard; `_client.rpc()` pattern established in `DevRpcService` |
| go_router | ^17.1.0 (pinned in pubspec.yaml) | `/godmode` route already registered | Route + redirect guard already implemented in Phase 21 |
| flutter (Material) | SDK (Dart ^3.10.1) | TabBar, DataTable candidates, SnackBar, showDialog | No external UI library; project uses Material widgets throughout |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| dart:async `Timer` | SDK built-in | 30-second poll cycle, 1-second elapsed counter | Used already in `CountdownTimerWidget`; same pattern applies here |
| mocktail | ^1.0.4 (dev) | Mock repository in widget tests | Used in existing widget tests |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom Row/Column table | `DataTable` | DataTable works for static rows, but does not gracefully expand rows for inline edit mode. Custom layout is more code but gives full control over row height and edit state. Project has no existing DataTable usage. |
| `Timer.periodic` polling | Supabase Realtime streams | Realtime subscriptions work per-table; GodMode world state is an aggregated multi-table RPC result — not streamable. Polling is the correct fit. |
| `AsyncNotifierProvider` | `FutureProvider` with `ref.invalidateSelf()` | AsyncNotifierProvider allows exposing `refresh()` and `sort()` methods alongside data, matching the pattern used by `CityNotifier` and `ProfileNotifier`. |

**Installation:** No new packages required. All dependencies already in `pubspec.yaml`.

---

## Architecture Patterns

### Recommended Project Structure
```
lib/features/godmode/
├── data/
│   └── godmode_repository.dart       # RPC calls: getWorldState, setbotPaused, forceAction, setResources, setArmy, getEvents
├── models/
│   ├── godmode_player.dart           # Parsed from world state JSONB row
│   └── godmode_event.dart            # Parsed from events JSONB row
├── providers/
│   ├── godmode_world_provider.dart   # AsyncNotifierProvider<List<GodmodePlayer>>
│   └── godmode_events_provider.dart  # AsyncNotifierProvider<List<GodmodeEvent>>
├── screens/
│   └── godmode_dashboard_screen.dart # Replaces GodModePlaceholderScreen
└── widgets/
    ├── player_table.dart             # Scrollable table with sort, edit mode
    ├── player_row.dart               # Normal row + expanded edit row
    ├── bot_badge.dart                # "BOT" chip widget
    ├── event_feed.dart               # ListView for event tab
    ├── event_tile.dart               # Single event row widget
    └── elapsed_timer_text.dart       # "Last updated: Xs ago" StatefulWidget
```

### Pattern 1: Polling AsyncNotifier with elapsed timer
**What:** `AsyncNotifierProvider` that holds fetched data and exposes `refresh()`. A separate `StatefulWidget` (`ElapsedTimerText`) tracks seconds-since-last-update using `Timer.periodic(1 second)`.
**When to use:** Any RPC-backed data that cannot use Supabase Realtime (aggregated multi-table results).
**Example:**
```dart
// Source: project pattern — mirrors CityNotifier in lib/features/city/providers/city_provider.dart
class GodmodeWorldNotifier extends AsyncNotifier<List<GodmodePlayer>> {
  Timer? _pollTimer;

  @override
  Future<List<GodmodePlayer>> build() async {
    // Cancel any existing timer when provider rebuilds.
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      refresh();
    });
    ref.onDispose(() => _pollTimer?.cancel());
    return _fetch();
  }

  Future<List<GodmodePlayer>> _fetch() async {
    final repo = ref.read(godmodeRepositoryProvider);
    return repo.getWorldState();
  }

  Future<void> refresh() async {
    // Keep stale data visible (do not set AsyncLoading) — per CONTEXT.md decision.
    // Use guard so errors surface via AsyncError without clearing data.
    final data = await AsyncValue.guard(_fetch);
    state = data;
  }

  // Sort mutates cached list without re-fetching.
  void sortBy(String column, bool ascending) {
    final current = state.asData?.value;
    if (current == null) return;
    final sorted = [...current];
    // ... sort logic ...
    state = AsyncData(sorted);
  }
}

final godmodeWorldProvider =
    AsyncNotifierProvider<GodmodeWorldNotifier, List<GodmodePlayer>>(
  GodmodeWorldNotifier.new,
);
```

### Pattern 2: Stale-while-refresh (keep data visible during re-poll)
**What:** On refresh, do NOT call `state = const AsyncLoading()`. Call the RPC, then assign `state = AsyncData(result)` or `state = AsyncError(e, s)`. The widget renders stale data while refresh is in flight.
**When to use:** All subsequent polls after initial load — per locked decision.
**Example:**
```dart
// During refresh (NOT initial build):
Future<void> refresh() async {
  // Do NOT reset to AsyncLoading here.
  try {
    final result = await _fetch();
    state = AsyncData(result);
  } catch (e, s) {
    state = AsyncError(e, s);
  }
}
```

### Pattern 3: AppBar spinner + elapsed indicator
**What:** A boolean `_isRefreshing` field in the notifier (or a separate `StateProvider<bool>`) drives a small spinning icon. `ElapsedTimerText` is a `StatefulWidget` with `Timer.periodic(1 second)` that receives a `DateTime lastUpdated` and formats "Xs ago".
**When to use:** The AppBar of `GodModeDashboardScreen`.
**Example:**
```dart
// ElapsedTimerText — adapts the CountdownTimerWidget pattern already in the codebase.
class ElapsedTimerText extends StatefulWidget {
  const ElapsedTimerText({super.key, required this.since});
  final DateTime since;
  // ...
}
// Mirrors: lib/features/city/widgets/countdown_timer_widget.dart
// Timer.periodic(1 second) → setState → format elapsed seconds
```

### Pattern 4: Inline row edit mode (local StatefulWidget state)
**What:** The player table is a `ListView.builder`. Each row widget is a `StatefulWidget` that has a boolean `_editing` flag and a map of `TextEditingController`s. Switching to edit mode creates controllers pre-filled with current values.
**When to use:** Resource/army editing in player rows.
**Example:**
```dart
// PlayerRow manages its own edit state locally — no Riverpod state needed.
class PlayerRow extends StatefulWidget {
  const PlayerRow({super.key, required this.player, required this.onEditDone});
  final GodmodePlayer player;
  final VoidCallback onEditDone;
  // ...
}

class _PlayerRowState extends State<PlayerRow> {
  bool _editing = false;
  final _controllers = <String, TextEditingController>{};

  void _enterEditMode() {
    // Pre-fill controllers with current values from widget.player.
    setState(() => _editing = true);
  }

  Future<void> _save(WidgetRef ref) async {
    // Call RPC via ref.read(godmodeRepositoryProvider).setResources(...)
    // On success: setState(() => _editing = false)
    // On failure: ScaffoldMessenger.of(context).showSnackBar(...)
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }
}
```

### Pattern 5: Force action confirmation dialog
**What:** `showDialog<bool>` returns a nullable bool; only execute RPC if result is `true`.
**When to use:** Force action button in bot row actions column.
**Example:**
```dart
// Established pattern in project — uses showDialog from Material library.
final confirmed = await showDialog<bool>(
  context: context,
  builder: (_) => AlertDialog(
    title: const Text('Force Action'),
    content: Text('Force bot ${player.displayName} to act now?'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
    ],
  ),
);
if (confirmed == true) {
  final action = await ref.read(godmodeRepositoryProvider).forceAction(player.id);
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${player.displayName} chose: $action')),
    );
  }
}
```

### Pattern 6: New admin_set_army RPC (backend migration)
**What:** New SECURITY DEFINER function following the exact same pattern as `admin_set_resources`. Takes `p_player_id uuid` + one parameter per unit type (8 land + 5 naval = 13 params), UPSERTs into `city_units`.
**When to use:** Army count editing in player row edit mode.
**Signature (to implement):**
```sql
-- Follows admin_set_resources pattern from 20260317000005_godmode_rpcs.sql
CREATE OR REPLACE FUNCTION public.admin_set_army(
  p_player_id  uuid,
  p_hoplite    integer DEFAULT NULL,
  p_phalanx    integer DEFAULT NULL,
  p_archer     integer DEFAULT NULL,
  p_cavalry    integer DEFAULT NULL,
  p_catapult   integer DEFAULT NULL,
  p_mortar     integer DEFAULT NULL,
  p_medic      integer DEFAULT NULL,
  p_cook       integer DEFAULT NULL,
  p_cargo_ship integer DEFAULT NULL,
  p_ram_ship   integer DEFAULT NULL,
  p_catapult_ship integer DEFAULT NULL,
  p_mortar_ship   integer DEFAULT NULL,
  p_diving_boat   integer DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
-- Admin guard identical to admin_set_resources
-- UPSERTs city_units rows for the player's city
```

### Anti-Patterns to Avoid
- **Setting `state = AsyncLoading()` on refresh:** Causes the table to blank out for 30 seconds every poll. The locked decision is "stale data stays visible during refresh."
- **Calling `Supabase.instance.client.rpc()` directly from widgets:** All RPC calls go through `GodmodeRepository` — consistent with `DevRpcService` and `BattleRepository` patterns.
- **Global `editingPlayerId` in a provider:** Edit state is per-row and ephemeral. Local `StatefulWidget` state avoids unnecessary provider rebuilds across the whole table on every keystroke.
- **Using `riverpod_generator` / `@riverpod` annotation:** Not supported in this project (analyzer conflict with Dart 3.10.1 — documented in `pubspec.yaml` comments).
- **`DataTable` widget for the player table:** DataTable renders fixed-height rows and doesn't support row expansion for inline edit mode. Custom `Column`/`Row` layout gives full height control.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SnackBar feedback for actions | Custom toast overlay | `ScaffoldMessenger.of(context).showSnackBar()` | Established pattern in entire project; integrates with Material scaffold |
| Confirmation dialog | Custom modal widget | `showDialog<bool>()` + `AlertDialog` | Material built-in; already used in project (Phase 7 espionage flow) |
| 1-second elapsed counter | New timer architecture | Adapt `CountdownTimerWidget` pattern (`dart:async Timer.periodic`) | Pattern already in `lib/features/city/widgets/countdown_timer_widget.dart` |
| Admin guard in Flutter | Manual auth checks in each widget | `profileNotifier.isAdmin` + existing GoRouter redirect guard | Guard already implemented in `app_router.dart` Rule 4b |
| Multi-table aggregation for table data | Client-side joining multiple Supabase stream subscriptions | `godmode_get_world_state()` RPC | Backend RPC already handles the 4-table join; Realtime cannot OR-filter across tables |

**Key insight:** The backend RPCs were designed to serve this dashboard exactly. The Flutter layer's job is purely to call them, parse the JSONB, and render — no complex client-side data aggregation needed.

---

## Common Pitfalls

### Pitfall 1: Timer not cancelled on provider dispose
**What goes wrong:** `_pollTimer` keeps firing after the user navigates away from `/godmode`, causing periodic RPC calls and state mutations on a disposed provider.
**Why it happens:** `Timer.periodic` runs independently of Flutter's widget lifecycle unless explicitly cancelled.
**How to avoid:** Call `ref.onDispose(() => _pollTimer?.cancel())` immediately after creating the timer in `build()`.
**Warning signs:** RPC calls in logs after leaving `/godmode` route.

### Pitfall 2: TextEditingController leak in row edit mode
**What goes wrong:** Controllers created on entering edit mode are never disposed, accumulating with each edit session.
**Why it happens:** TextEditingControllers are not automatically GC'd — they hold native resources.
**How to avoid:** Dispose all controllers in `_PlayerRowState.dispose()`. See Pattern 4 example above.
**Warning signs:** Memory growth during long admin sessions; Flutter debug warnings about disposed controllers.

### Pitfall 3: Sort mutating provider state with original list reference
**What goes wrong:** Calling `.sort()` on `state.asData!.value` mutates the cached list in-place. Next refresh compares a sorted list to new data, causing subtle ordering bugs.
**How to avoid:** Always sort a copy: `final sorted = [...current]; sorted.sort(...); state = AsyncData(sorted);`
**Warning signs:** Table order randomly changes on refresh even when data hasn't changed.

### Pitfall 4: `admin_set_army` called with null-vs-zero confusion
**What goes wrong:** Passing `null` for an army field (meaning "don't change") vs `0` (meaning "delete all units") are semantically different. If the Flutter form sends `0` for untouched fields, it wipes unit counts.
**Why it happens:** `int.tryParse(controller.text)` returns `null` for empty string — but the controller may have been pre-filled with `0`.
**How to avoid:** Use `DEFAULT NULL` parameters in the RPC; Flutter sends only non-null values for fields the admin has touched. Or: always send all 13 values (pre-fill form with current counts), making 0 explicitly intentional.
**Recommendation:** Pre-fill all 13 fields with current counts and always send all values — simpler logic, no null ambiguity.

### Pitfall 5: `mounted` check omitted after async RPC call
**What goes wrong:** After `await repo.forceAction(...)`, the user may have navigated away. Calling `ScaffoldMessenger.of(context)` on an unmounted widget throws.
**Why it happens:** `async`/`await` yields control; widgets can be disposed while waiting.
**How to avoid:** Check `if (mounted)` before any `context` access after an `await`. This pattern is used in existing project screens.
**Warning signs:** `FlutterError: Looking up a deactivated widget's ancestor is unsafe`.

### Pitfall 6: Bulk pause iterates over all players instead of bots-only
**What goes wrong:** "Pause All Bots" calls `godmode_set_bot_paused` for human players too, causing a `bot_not_found` exception from the RPC (bot_schedules only has rows for bots).
**How to avoid:** Filter `player.isBot == true` before iterating for bulk operations.
**Warning signs:** SnackBar shows lower count than expected, or error SnackBars appear.

---

## Code Examples

Verified patterns from project source:

### Repository RPC call pattern
```dart
// Source: lib/core/dev/dev_rpc_service.dart
Future<void> setBotPaused(String botId, bool paused) async {
  try {
    await _client.rpc('godmode_set_bot_paused', params: {
      'p_bot_id': botId,
      'p_paused': paused,
    });
  } catch (e) {
    debugPrint('[GodmodeRepository] setBotPaused error: $e');
    rethrow;
  }
}
```

### RPC returning JSONB → parse to model list
```dart
// Source: pattern — godmode_get_world_state returns jsonb with 'players' array
Future<List<GodmodePlayer>> getWorldState() async {
  final result = await _client.rpc('godmode_get_world_state');
  final map = result as Map<String, dynamic>;
  final players = map['players'] as List<dynamic>;
  return players.map((p) => GodmodePlayer.fromJson(p as Map<String, dynamic>)).toList();
}
```

### AsyncValue.when with stale-data pattern
```dart
// Source: movements_screen.dart pattern — loading/error/data branches
body: worldAsync.when(
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (e, _) => Center(child: Text('Failed to load: $e')),
  data: (players) => PlayerTable(players: players),
),
// On subsequent polls, worldAsync stays in AsyncData — no loading flash.
```

### SnackBar feedback
```dart
// Source: established pattern across project screens
if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Bot ${player.displayName} paused')),
  );
}
```

### GodmodePlayer model from JSONB
```dart
// Model shape from godmode_get_world_state() RPC response:
// {
//   "id": "...",
//   "display_name": "...",
//   "is_bot": true,
//   "is_paused": false,      // null for human players (no bot_schedules row)
//   "resources": {"wood": 1000, "marble": 500, ...},
//   "army": {"land_count": 120, "naval_count": 30},
//   "buildings": {"town_hall": 3, "barracks": 2, ...},
//   "active_battles": [{"battle_id": "...", "attacker_name": "...", ...}]
// }
class GodmodePlayer {
  final String id;
  final String displayName;
  final bool isBot;
  final bool isPaused;           // false for humans (coerce null → false)
  final Map<String, dynamic> resources;
  final int landCount;
  final int navalCount;
  final int buildingCount;
  final int activeBattleCount;

  factory GodmodePlayer.fromJson(Map<String, dynamic> json) {
    final army = json['army'] as Map<String, dynamic>? ?? {};
    final buildings = json['buildings'] as Map<String, dynamic>? ?? {};
    final battles = json['active_battles'] as List<dynamic>? ?? [];
    return GodmodePlayer(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? '—',
      isBot: (json['is_bot'] as bool?) ?? false,
      isPaused: (json['is_paused'] as bool?) ?? false,
      resources: json['resources'] as Map<String, dynamic>? ?? {},
      landCount: (army['land_count'] as num?)?.toInt() ?? 0,
      navalCount: (army['naval_count'] as num?)?.toInt() ?? 0,
      buildingCount: buildings.length,
      activeBattleCount: battles.length,
    );
  }
}
```

### GodmodeEvent model from JSONB
```dart
// Shape from godmode_get_events() RPC:
// {"event_type": "battle", "timestamp": "...", "detail": {...}}
class GodmodeEvent {
  final String eventType;   // 'battle' | 'trade' | 'espionage'
  final DateTime timestamp;
  final Map<String, dynamic> detail;

  factory GodmodeEvent.fromJson(Map<String, dynamic> json) => GodmodeEvent(
    eventType: json['event_type'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    detail: json['detail'] as Map<String, dynamic>? ?? {},
  );
}
// detail['summary'] is the pre-formatted one-line string from the RPC.
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `FutureProvider` for one-shot fetch | `AsyncNotifierProvider` with `refresh()` method | Riverpod 2.x+ | Allows method exposure alongside state; matches project pattern |
| `riverpod_generator` / `@riverpod` | Manual AsyncNotifier definitions | Pinned by Dart 3.10.1 + analyzer conflict | No code-gen; all providers written manually — project convention |
| `DataTable` for tabular data | Custom `Row`/`Column` layout | N/A | DataTable row height is fixed; inline editing requires variable-height rows |

**Deprecated/outdated:**
- `StateNotifier` + `StateNotifierProvider`: Replaced by `Notifier`/`AsyncNotifier` in Riverpod 2+. Project does not use StateNotifier anywhere — do not introduce it.
- `ref.read()` inside `build()` for state watching: Use `ref.watch()` in `build`, `ref.read()` only in callbacks/methods.

---

## Backend Migration Needed

### admin_set_army RPC (new — not in Phase 21)

This RPC does not exist yet. It must be created as a new migration in this phase.

**Migration file:** `supabase/migrations/20260322000001_admin_set_army.sql` (date TBD by implementer)

**Unit type list** (from `godmode_get_world_state` land/naval classification in Phase 21 migration):
- Land (8): `hoplite`, `phalanx`, `archer`, `cavalry`, `catapult`, `mortar`, `medic`, `cook`
- Naval (5): `cargo_ship`, `ram_ship`, `catapult_ship`, `mortar_ship`, `diving_boat`

**Pattern to follow:** `admin_set_resources` in `20260317000005_godmode_rpcs.sql` (lines 190-231):
1. Admin guard: `SELECT is_admin FROM profiles WHERE id = auth.uid()`
2. Resolve city: `SELECT id FROM cities WHERE owner_id = p_player_id LIMIT 1`
3. For each unit type: `INSERT INTO city_units (...) VALUES (...) ON CONFLICT (city_id, unit_type) DO UPDATE SET quantity = GREATEST(p_value, 0)`
4. Grant: `GRANT EXECUTE ON FUNCTION public.admin_set_army(...) TO authenticated`

**city_units table:** Confirmed from `godmode_get_world_state` query — table is `public.city_units` with columns `city_id`, `unit_type`, `quantity`. The RPC must UPSERT (not UPDATE) because a player may have zero of a unit type (no row exists).

---

## Open Questions

1. **city_units schema — PK/unique constraint**
   - What we know: `godmode_get_world_state` queries `city_units cu WHERE cu.city_id = c.id AND cu.unit_type IN (...)` — implies `(city_id, unit_type)` is a unique combination
   - What's unclear: Whether there is an explicit `UNIQUE (city_id, unit_type)` constraint for ON CONFLICT
   - Recommendation: Check `20260311000006_create_military_units.sql` (file not found in filesystem — may be under a different name). The planner should confirm the constraint before writing the UPSERT in `admin_set_army`. Alternatively, use `UPDATE ... WHERE city_id = v_city_id AND unit_type = '...'` with a preceding INSERT if no row exists.

2. **Total resources display column**
   - What we know: CONTEXT.md specifies "total resources (single number)" in the table
   - What's unclear: Whether total = sum of all 5 resource types, or just the luxury resource, or gold
   - Recommendation: Implement as `wood + marble + crystal + sulfur + gold` sum — simplest interpretation, shows overall wealth.

3. **Bulk pause — implementation approach**
   - What we know: "Pause All Bots" must be instant with SnackBar confirmation of count
   - What's unclear: Whether to call N individual `godmode_set_bot_paused` RPCs client-side, or add a `godmode_bulk_set_bots_paused(p_paused boolean)` RPC
   - Recommendation: Call individual RPCs client-side in a `Future.wait([...])` over bot-only players. N ≤ 20 bots; parallelized with `Future.wait` is acceptable. Avoids adding a 6th RPC to the backend.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK bundled) + mocktail ^1.0.4 |
| Config file | None — tests discovered by `flutter test` convention |
| Quick run command | `flutter test test/widget/godmode_dashboard_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| GOD-01 | Dashboard renders player table with correct columns | widget | `flutter test test/widget/godmode_dashboard_test.dart -x` | ❌ Wave 0 |
| GOD-01 | GodmodePlayer.fromJson parses JSONB correctly | unit | `flutter test test/unit/godmode_models_test.dart -x` | ❌ Wave 0 |
| GOD-02 | Pause toggle calls setBotPaused RPC with correct args | widget | `flutter test test/widget/godmode_dashboard_test.dart -x` | ❌ Wave 0 |
| GOD-03 | Event feed renders events by type after filter chip tap | widget | `flutter test test/widget/godmode_events_test.dart -x` | ❌ Wave 0 |
| GOD-03 | GodmodeEvent.fromJson parses timestamp and eventType | unit | `flutter test test/unit/godmode_models_test.dart -x` | ❌ Wave 0 |
| GOD-04 | PlayerRow enters edit mode with pre-filled controllers | widget | `flutter test test/widget/godmode_player_row_test.dart -x` | ❌ Wave 0 |
| GOD-04 | admin_set_resources called with correct values on Save | widget | `flutter test test/widget/godmode_player_row_test.dart -x` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/unit/godmode_models_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/unit/godmode_models_test.dart` — covers GOD-01, GOD-03 model parsing
- [ ] `test/widget/godmode_dashboard_test.dart` — covers GOD-01, GOD-02 table + controls
- [ ] `test/widget/godmode_events_test.dart` — covers GOD-03 filter chips + list
- [ ] `test/widget/godmode_player_row_test.dart` — covers GOD-04 inline edit mode
- [ ] `test/helpers/test_helpers.dart` — `createTestProviderScope` helper currently commented out; needs to be enabled with ProviderScope for GodMode widget tests

---

## Sources

### Primary (HIGH confidence)
- Project source: `lib/core/dev/dev_rpc_service.dart` — RPC call pattern (`_client.rpc('name', params: {...})`)
- Project source: `supabase/migrations/20260317000005_godmode_rpcs.sql` — All 5 RPC signatures and response shapes
- Project source: `lib/features/city/providers/city_provider.dart` — `AsyncNotifierProvider` manual definition pattern
- Project source: `lib/features/city/widgets/countdown_timer_widget.dart` — `Timer.periodic` + `StatefulWidget` pattern
- Project source: `lib/core/router/app_router.dart` — `/godmode` route already registered; Rule 4b admin guard confirmed
- Project source: `pubspec.yaml` — package versions verified directly from lockfile

### Secondary (MEDIUM confidence)
- Project source: `lib/features/battles/providers/battles_provider.dart` — `StreamProvider.autoDispose.family` and `Provider.autoDispose` patterns
- Project source: `lib/features/movements/screens/movements_screen.dart` — `AsyncValue.when` rendering pattern, `SnackBar` feedback pattern
- Flutter Material documentation (training knowledge, Dart 3.x stable) — `TabBar`/`TabBarView`, `DataTable` limitations with variable-height rows

### Tertiary (LOW confidence)
- `admin_set_army` UPS ERT approach — inferred from `admin_set_resources` pattern; `city_units` unique constraint not directly confirmed (migration file not found)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages verified in pubspec.yaml; no new dependencies needed
- Architecture: HIGH — patterns verified from existing project source files
- Backend RPC shapes: HIGH — verified from actual migration SQL
- admin_set_army implementation: MEDIUM — pattern inferred from admin_set_resources; city_units constraint needs verification
- Pitfalls: HIGH — derived from project-specific patterns and Flutter StatefulWidget conventions

**Research date:** 2026-03-17
**Valid until:** 2026-04-17 (stable stack; 30-day validity)
