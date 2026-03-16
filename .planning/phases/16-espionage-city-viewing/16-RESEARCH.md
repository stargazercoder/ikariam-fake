# Phase 16: Espionage & City Viewing - Research

**Researched:** 2026-03-16
**Domain:** Flutter/Riverpod + Supabase Edge Function + GoRouter — espionage action, spy report dialog, read-only city view
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Spy Report Presentation**
- Dialog popup after spy action completes — consistent with trade dialog and upgrade sheet patterns
- Report shows: city name, owner name, resource amounts (all 5 types), building list with levels, total army count (number only, not per-type breakdown)
- Report includes a "View City" button that navigates to the read-only city view (connects ESPY-01 and ESPY-02)
- Spy reports are saved to a DB table (spy_reports) — player can review past espionage results
- Spy log accessible from Military tab as a sub-section — keeps navigation compact

**City Viewing Navigation**
- "View City" available from island city tap menu (added to _showCityActionDialog alongside Attack/Trade/Spy)
- Requires spy first — player must have at least one spy report for that city before viewing
- Island tap menu shows "View City (spy first)" greyed out for un-spied cities — teaches the feature exists
- "View City" also available as button in spy report dialog — natural flow: spy → report → view city
- Full screen push navigation (GoRouter route) — reuses CityScreen/CityGridScreen pattern in read-only mode

**Spy Action Trigger & Feedback**
- "Spy" action in city action dialog on island screen — alongside Attack, Trade, View City
- Gold cost: flat 100 gold per spy action — no cooldown, no spy units consumed
- Cost shown inline: "Spy (100 gold)" in the action menu — player knows cost before tapping
- No confirmation step — tap Spy → brief loading spinner → spy report dialog opens with results
- Edge Function validates gold balance, deducts gold atomically, queries target city data, inserts spy_report row, returns report data

**Read-Only City View**
- Shows building grid with building names and levels — reuses CityGridScreen in read-only mode
- No resource amounts in city view — resources only visible in spy reports (gives espionage ongoing value)
- Shows construction queue if enemy has active construction — reveals what's being upgraded and ETA
- Different AppBar color (red/grey) + label "CityName (PlayerName)" — clear visual distinction, no action buttons
- No upgrade sheets, no build buttons — purely observational

### Claude's Discretion
- Exact spy report dialog layout and spacing
- Spy log list design within Military tab (list tiles, sorting)
- Error handling for insufficient gold
- How to store/query "has player spied on this city" for View City unlock check
- CityGridScreen read-only mode implementation details (disable tap handlers vs separate widget)

### Deferred Ideas (OUT OF SCOPE)
- Counter-espionage (spy defense, detection) — explicitly out of scope per REQUIREMENTS.md
- Spy unit type with travel time — deferred, v1.2 uses instant action
- Spy report expiration/staleness indicator — future polish
- Alliance-wide intel sharing — requires alliance system
- Spy cost scaling with target level — keep flat 100 gold for v1.2
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| ESPY-01 | User can send a spy to an enemy city to reveal resource amounts, building levels, and army counts | Edge Function `spy-city` follows `send-trade` pattern; spy_reports table stores results; spy dialog follows trade_dialog.dart pattern |
| ESPY-02 | User can view a read-only version of another player's city screen (buildings layout) | `BuildingsGrid` is already a standalone widget; `BuildingCell` tap handler disabled for read-only mode; new GoRouter route `/city-view/:cityId` pushes from island action menu or spy report dialog |
</phase_requirements>

---

## Summary

Phase 16 is a well-bounded, mid-complexity feature that has clear precedents in the existing codebase. The primary work is: (1) a new `spy-city` Supabase Edge Function following the `send-trade` pattern exactly, (2) a `spy_reports` DB migration, (3) a spy report dialog following the `_TradeDialogContent` pattern, (4) a read-only city view screen that wraps the existing `BuildingsGrid` + `constructionQueueProvider` without tap handlers or upgrade sheets, and (5) route + island action menu integration.

No new architectural patterns are required. Every sub-problem maps to an established pattern in this codebase. The biggest implementation decision (Discretion area) is how to implement read-only mode in `BuildingCell`/`BuildingsGrid` — the recommended approach is a `readOnly: bool` parameter added to `BuildingCell` which suppresses the `GestureDetector` `onTap`, rather than creating a separate widget tree. This avoids duplication while keeping the grid widget small.

**Primary recommendation:** Wire the three layers (DB migration → Edge Function → Flutter UI) in sequence per wave. DB first, Edge Function second, Flutter last. The spy report dialog and read-only city view are independent Flutter tasks that can run in parallel once the Edge Function is deployed.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| supabase_flutter | existing | Supabase client, auth, Realtime, Edge Function invocation | Already in pubspec; all previous phases use it |
| flutter_riverpod | existing | State management, providers for spy reports and city data | All providers in this project use Riverpod |
| go_router | existing | Navigation to new read-only city view route | Already powers all routing in app_router.dart |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| jsr:@supabase/supabase-js@2 | existing | Deno Edge Function Supabase client | Required for all Edge Functions |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `readOnly` param on BuildingCell | Separate `ReadOnlyBuildingCell` widget | Duplicate widget is harder to maintain when BuildingCell evolves; param approach is simpler |
| GoRouter push for city view | showModalBottomSheet full-screen | Push route gives proper AppBar with back button and clear navigation hierarchy; bottom sheet is harder to distinguish as "enemy city" |

**Installation:** No new packages needed.

---

## Architecture Patterns

### Recommended Project Structure

New files to create:
```
supabase/
├── functions/
│   └── spy-city/
│       └── index.ts                           # Edge Function: spy action
├── migrations/
│   └── 20260316000003_spy_reports.sql         # spy_reports table + gold deduct RPC

lib/features/
├── espionage/
│   ├── data/
│   │   └── espionage_repository.dart          # callSpyCity(), fetchSpyReports()
│   ├── models/
│   │   └── spy_report.dart                    # SpyReport model from JSONB
│   ├── providers/
│   │   └── espionage_providers.dart           # spyReportsProvider, hasSpiedProvider
│   └── screens/
│       ├── spy_report_dialog.dart             # showSpyReportDialog()
│       └── spy_log_screen.dart                # Spy log list for Military tab
└── map/
    └── screens/
        └── enemy_city_view_screen.dart        # Read-only city view (new screen)
```

Existing files to modify:
```
lib/features/map/screens/island_screen.dart    # Add Spy + View City to _showCityActionDialog
lib/features/map/screens/city_grid_screen.dart # Add readOnly param to BuildingCell + BuildingsGrid
lib/core/router/app_router.dart                # Add /city-view route
```

### Pattern 1: Edge Function — spy-city

**What:** POST endpoint that validates gold, deducts 100 gold atomically, queries target city data (resources, buildings, army), inserts spy_report row, and returns full report as JSON.
**When to use:** Any server-side game mutation that requires auth + atomic DB operations.

```typescript
// Source: supabase/functions/send-trade/index.ts (established pattern)
// spy-city/index.ts structure:

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS_HEADERS });

  // 1. Parse body: { spy_city_id: string }
  // 2. Authenticate with anon client → user.id
  // 3. Admin client for mutations

  // 4. Verify caller owns a city (to get player_city_id for gold deduction)
  //    SELECT id FROM cities WHERE owner_id = user.id LIMIT 1

  // 5. Check gold balance in city_resources WHERE resource_type = 'gold'
  //    Must have >= 100 gold

  // 6. Verify target city exists
  //    SELECT id, name FROM cities WHERE id = spy_city_id

  // 7. Deduct 100 gold atomically via deduct_resources RPC
  //    (same RPC used in send-trade — already exists)

  // 8. Query target city data:
  //    - city_resources: all resource types + amounts
  //    - city_buildings: all building_type + level
  //    - city_units: SUM of all unit quantities for total army count

  // 9. Insert spy_report row:
  //    { player_id, target_city_id, report_data: JSONB }

  // 10. Return report data
  return successResponse({ report: { ... } });
});
```

### Pattern 2: Spy Report Dialog

**What:** `showDialog` with `StatefulWidget` — shows loading spinner immediately, calls Edge Function, then displays spy report data.
**When to use:** Follows `_TradeDialogContent` pattern from trade_dialog.dart with `_isLoading` state.

```dart
// Source: lib/features/trade/screens/trade_dialog.dart (established pattern)

// Entry point function (matches showTradeDialog convention):
Future<void> showSpyReportDialog(
  BuildContext context, {
  required String playerCityId,
  required String targetCityId,
  required String targetCityName,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _SpyReportDialogContent(
      playerCityId: playerCityId,
      targetCityId: targetCityId,
      targetCityName: targetCityName,
    ),
  );
}

// Inside ConsumerStatefulWidget:
// initState: immediately call _executeSpy() — no confirmation step (locked decision)
// _isLoading = true → show CircularProgressIndicator
// on success: setState(_isLoading = false, _report = result)
// on error (insufficient gold): pop dialog, show SnackBar
```

### Pattern 3: Read-Only BuildingCell / BuildingsGrid

**What:** Add `readOnly: bool` parameter to `BuildingCell` and `BuildingsGrid`. When `readOnly: true`, `GestureDetector` `onTap` is null — no upgrade sheet, no navigation.
**When to use:** Enemy city view where interactions must be disabled.

```dart
// Source: lib/features/map/screens/city_grid_screen.dart

class BuildingCell extends StatelessWidget {
  const BuildingCell({
    super.key,
    required this.building,
    required this.cityId,
    required this.currentResources,
    required this.activeConstruction,
    this.readOnly = false,          // NEW: default false preserves existing behavior
  });

  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: readOnly ? null : () { /* existing tap logic */ },
      child: /* existing cell decoration */,
    );
  }
}

// BuildingsGrid gains same readOnly param, passes it down to each BuildingCell.
```

### Pattern 4: Enemy City View Screen

**What:** A new `EnemyCityViewScreen` that fetches target city data using `buildingsStreamProvider(cityId)` and `constructionQueueProvider(cityId)` — existing providers work for any cityId. AppBar uses red/grey color + "CityName (PlayerName)" title.
**When to use:** Push navigation from spy report dialog "View City" button or island action menu "View City" entry.

```dart
// Source: lib/features/map/screens/city_grid_screen.dart + city_screen.dart

class EnemyCityViewScreen extends ConsumerWidget {
  const EnemyCityViewScreen({
    super.key,
    required this.cityId,
    required this.cityName,
    required this.ownerName,
  });

  final String cityId;
  final String cityName;
  final String ownerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildingsAsync = ref.watch(buildingsStreamProvider(cityId));
    final constructionAsync = ref.watch(constructionQueueProvider(cityId));
    // No resourcesStreamProvider — resources NOT shown in city view (locked decision)

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red.shade800,   // distinct enemy color
        title: Text('$cityName ($ownerName)'),
        // No action buttons — purely observational (locked decision)
      ),
      body: /* BuildingsGrid with readOnly: true + construction banner */,
    );
  }
}
```

### Pattern 5: GoRouter Route for Enemy City View

```dart
// Source: lib/core/router/app_router.dart
// Add under the city StatefulShellBranch (same branch as /city, /barracks, /dispatch)

GoRoute(
  path: '/city-view',
  builder: (context, state) => EnemyCityViewScreen(
    cityId: state.uri.queryParameters['cityId'] ?? '',
    cityName: state.uri.queryParameters['cityName'] ?? 'City',
    ownerName: state.uri.queryParameters['ownerName'] ?? 'Unknown',
  ),
),
```

Navigation call:
```dart
context.push('/city-view?cityId=$cityId&cityName=$encodedName&ownerName=$encodedOwner');
```

### Pattern 6: spy_reports DB Table

```sql
-- spy_reports table
CREATE TABLE public.spy_reports (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  target_city_id uuid NOT NULL REFERENCES public.cities(id) ON DELETE CASCADE,
  report_data   jsonb NOT NULL,    -- { resources, buildings, army_count }
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- Index for spy log queries (player's own reports, ordered by time)
CREATE INDEX spy_reports_player_id_created_at_idx
  ON public.spy_reports (player_id, created_at DESC);

-- RLS: players can only read their own reports
ALTER TABLE public.spy_reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "players read own spy reports"
  ON public.spy_reports FOR SELECT
  USING (player_id = auth.uid());
-- Edge Function inserts with service_role (bypasses RLS — INFR-02 pattern)
```

### Pattern 7: hasSpiedProvider — Unlock Check for "View City"

```dart
// Discretion: query spy_reports for target_city_id to determine unlock state.
// FutureProvider.family returns bool — can be invalidated after a spy action completes.

final hasSpiedProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, targetCityId) async {
  final userId = supabaseClient.auth.currentUser?.id;
  if (userId == null) return false;
  final row = await supabaseClient
      .from('spy_reports')
      .select('id')
      .eq('player_id', userId)
      .eq('target_city_id', targetCityId)
      .limit(1)
      .maybeSingle();
  return row != null;
});
```

### Pattern 8: deduct_gold RPC (or reuse deduct_resources)

**Key insight:** `deduct_resources` RPC already exists from Phase 15 migration (`20260316000002_trade_movement_type_and_deduct_resources.sql`). The spy function can call it with `p_resource_type = 'gold'` and `p_amount = 100`. No new RPC needed.

```typescript
// In spy-city Edge Function:
const { error: goldError } = await admin.rpc('deduct_resources', {
  p_city_id: playerCityId,
  p_resource_type: 'gold',
  p_amount: 100,
});
if (goldError) return errorResponse('Insufficient gold', 400);
```

### Anti-Patterns to Avoid

- **Do NOT call Edge Function client-side with service_role key** — always use anon key for auth header, admin client is server-only (INFR-02).
- **Do NOT create a separate ReadOnlyBuildingCell widget** — add `readOnly` param to existing `BuildingCell` to avoid duplication.
- **Do NOT use Realtime subscription for spy_reports** — a one-shot `FutureProvider` is sufficient; spy log doesn't need live updates.
- **Do NOT navigate to the player's own `/city` route for enemy city view** — the route must be separate (`/city-view`) since it needs different data (enemy cityId) and layout.
- **Do NOT duplicate the `_ConstructionBanner` widget** — it is already defined locally in `city_grid_screen.dart`; the enemy city view screen can import the same private widget or extract it to a shared location.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Atomic gold deduction | Custom UPDATE + SELECT | `deduct_resources` RPC | Already exists; handles insufficient balance atomically via RAISE EXCEPTION |
| City building data fetch | New Supabase query | `buildingsStreamProvider(cityId)` | Works for ANY cityId, not just player's own |
| Construction queue fetch | New Supabase query | `constructionQueueProvider(cityId)` | Same — family provider parameterized by cityId |
| City name lookup | Inline Supabase call | `cityNameProvider(cityId)` | Already in `movements_provider.dart`; FutureProvider.family pattern |
| Auth validation in Edge Function | Custom JWT parsing | `anonClient.auth.getUser()` | Established pattern across all existing Edge Functions |
| Dialog loading state | Custom StatefulWidget | `ConsumerStatefulWidget` + `_isLoading` bool | Same pattern as `_TradeDialogContentState` |

---

## Common Pitfalls

### Pitfall 1: Reading Provider from Wrong Scope in Dialog

**What goes wrong:** Inside a `showDialog` builder, `WidgetRef` from the outer `ConsumerWidget` is stale. If using `ref.read` inside the dialog builder to get cityId, it may return null after the outer widget rebuilds.

**Why it happens:** Dialog outlives the parent widget's rebuild cycle in some cases.

**How to avoid:** Pass all required data (cityId, cityName, ownerName) as constructor parameters to the dialog widget — never read providers inside the builder lambda itself.

**Warning signs:** Null cityId in the dialog despite it being set in the parent.

### Pitfall 2: JSONB Column Type Inconsistency

**What goes wrong:** When reading `report_data` JSONB from `spy_reports`, number fields may come back as `int` or `num` depending on how Postgres serializes them.

**Why it happens:** The codebase already has this documented tech debt: "JSONB cast inconsistency: older models use `v as int`, newer use `(v as num).toInt()`".

**How to avoid:** Always use `(value as num).toInt()` for integer fields parsed from JSONB in `SpyReport.fromJson()`.

**Warning signs:** `type 'int' is not a subtype of type 'double'` at runtime.

### Pitfall 3: Missing CORS Preflight Handler in Edge Function

**What goes wrong:** Browser (or Flutter web) throws CORS error before the function even runs.

**Why it happens:** All Edge Functions must respond to `OPTIONS` preflight with 204 + CORS headers.

**How to avoid:** Copy the CORS block verbatim from `send-trade/index.ts` — it is the canonical pattern.

**Warning signs:** Network error before any auth step runs.

### Pitfall 4: cityId Not Encoded in GoRouter Push

**What goes wrong:** City names or owner names with spaces or special characters break the URL query string for `/city-view`.

**Why it happens:** GoRouter parses query params from the raw URI. Unencoded spaces produce malformed URLs.

**How to avoid:** Use `Uri.encodeComponent()` on `cityName` and `ownerName` before constructing the push path. Or pass as extra data (`context.push('/city-view', extra: {...})`).

**Warning signs:** AppBar shows truncated city name or routing fails entirely.

### Pitfall 5: Spy on Own City

**What goes wrong:** Player spies on their own city — wastes 100 gold, produces a trivially-known report.

**Why it happens:** `_showCityActionDialog` shows "Spy" for non-own cities (`!isOwn`). But the Edge Function should also guard this server-side.

**How to avoid:** In the spy Edge Function, verify `target_city.owner_id != user.id` and return 400 if equal. UI guard (`!isOwn`) provides first line; server guard is the authoritative check.

**Warning signs:** A player manages to spy on themselves via a crafted POST.

### Pitfall 6: BuildingsGrid Requires Non-Null currentResources in Read-Only Mode

**What goes wrong:** `BuildingsGrid` constructor requires `currentResources: List<CityResource>`. In read-only mode there are no resources to pass.

**Why it happens:** `BuildingsGrid` uses `currentResources` only inside `BuildingCell` for the upgrade sheet cost check — which is irrelevant in read-only mode.

**How to avoid:** Pass `readOnly: true` + `currentResources: const []` when instantiating `BuildingsGrid` for the enemy city view. The `readOnly` flag suppresses tap, so `currentResources` is never read.

---

## Code Examples

### Existing deduct_resources RPC (reused for gold)

```typescript
// Source: supabase/migrations/20260316000002_trade_movement_type_and_deduct_resources.sql
// Already created. Call from spy-city with resource_type = 'gold'.
const { error } = await admin.rpc('deduct_resources', {
  p_city_id: playerCityId,
  p_resource_type: 'gold',
  p_amount: 100,
});
```

### Existing Edge Function auth pattern

```typescript
// Source: supabase/functions/send-trade/index.ts lines 128–148
const anonClient = createClient(supabaseUrl, supabaseAnonKey, {
  global: { headers: { Authorization: authHeader } },
});
const { data: { user }, error: authError } = await anonClient.auth.getUser();
if (authError || !user) return errorResponse('Not authenticated', 401);

const admin = createClient(supabaseUrl, supabaseServiceKey, {
  auth: { persistSession: false },
});
```

### Existing _showCityActionDialog pattern (to extend)

```dart
// Source: lib/features/map/screens/island_screen.dart lines 238–336
// Currently shows: Attack, Trade (for enemy cities) | Trade, Go to City (own)
// Phase 16 adds to enemy section: Spy (100 gold), View City (or greyed out)

if (!isOwn) ...[
  // Existing: Attack, Trade
  // NEW: Spy button
  FilledButton(
    onPressed: () {
      Navigator.of(ctx).pop();
      showSpyReportDialog(context,
        playerCityId: playerCityId,
        targetCityId: slot.cityId!,
        targetCityName: slot.cityName ?? 'City',
      );
    },
    child: const Text('Spy (100 gold)'),
  ),
  // NEW: View City (enabled if hasSpied, greyed out otherwise)
  Consumer(builder: (_, ref, __) {
    final hasSpied = ref.watch(hasSpiedProvider(slot.cityId!)).valueOrNull ?? false;
    return OutlinedButton(
      onPressed: hasSpied ? () { /* push /city-view */ } : null,
      child: Text(hasSpied ? 'View City' : 'View City (spy first)'),
    );
  }),
],
```

### SpyReport model pattern

```dart
// Source: lib/features/city/models/city_resource.dart pattern
class SpyReport {
  const SpyReport({
    required this.id,
    required this.targetCityId,
    required this.targetCityName,
    required this.createdAt,
    required this.resources,         // Map<String, int> — all 5 types
    required this.buildings,         // Map<String, int> — building_type → level
    required this.armyCount,         // int — total units, no breakdown
  });

  factory SpyReport.fromJson(Map<String, dynamic> json) {
    final data = json['report_data'] as Map<String, dynamic>;
    return SpyReport(
      id: json['id'] as String,
      targetCityId: json['target_city_id'] as String,
      targetCityName: data['city_name'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      resources: (data['resources'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toInt())),
      buildings: (data['buildings'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toInt())),
      armyCount: (data['army_count'] as num).toInt(),
    );
  }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Separate widget for read-only variant | `readOnly` param on existing widget | Phase 16 decision | Less duplication, same behavior |
| Custom gold deduction logic | Reuse `deduct_resources` RPC with `resource_type = 'gold'` | Phase 15 created RPC | No new DB function needed |
| Player name as UUID | `cityNameProvider` family for name lookup | Phase 14 | Human-readable names in spy log |

---

## Open Questions

1. **Owner display name in spy report dialog**
   - What we know: `spy_city` Edge Function can query the `profiles` table for the target city's `owner_id` to get `display_name`.
   - What's unclear: Whether `profiles` table is publicly readable or RLS-restricted.
   - Recommendation: Query `profiles` in the Edge Function using the admin client (bypasses RLS) and include `owner_name` in `report_data` JSONB. This avoids a separate client-side fetch.

2. **Spy log placement in Military tab**
   - What we know: Military tab currently has Barracks and Shipyard screens — no unified military screen wrapping them.
   - What's unclear: The CONTEXT says "Military tab as a sub-section" but the current router has `/barracks` and `/shipyard` as separate routes, not a parent military screen.
   - Recommendation: Add a "Spy Log" entry to the main shell or battles screen, or create a new `/spy-log` route accessible from a FloatingActionButton on the battles/movements screen. Planner should decide exact tab placement.

3. **Construction queue ETA display in enemy city view**
   - What we know: `constructionQueueProvider(cityId)` works for any cityId. `ConstructionQueueEntry` includes `finishAt`.
   - What's unclear: Whether `CountdownTimerWidget` should show the actual ETA (reveals exact timing intel) — this is a design choice, not a technical gap.
   - Recommendation: Show the countdown timer as-is. It adds strategic value as per the locked decisions ("reveals what's being upgraded and ETA").

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (bundled with Flutter SDK) |
| Config file | none — pubspec.yaml dev_dependencies section |
| Quick run command | `flutter test test/unit/espionage_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ESPY-01 | SpyReport.fromJson parses JSONB correctly | unit | `flutter test test/unit/espionage_test.dart` | ❌ Wave 0 |
| ESPY-01 | spy-city Edge Function validates gold balance | manual | Manual Supabase function invoke | N/A — server-side |
| ESPY-02 | EnemyCityViewScreen renders buildings grid in read-only mode (no tap) | widget | `flutter test test/widget/enemy_city_view_test.dart` | ❌ Wave 0 |
| ESPY-02 | BuildingCell with readOnly=true has null onTap | unit | `flutter test test/unit/espionage_test.dart` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/unit/espionage_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/unit/espionage_test.dart` — covers SpyReport.fromJson (ESPY-01) + readOnly param logic (ESPY-02)
- [ ] `test/widget/enemy_city_view_test.dart` — smoke test EnemyCityViewScreen renders without errors

---

## Sources

### Primary (HIGH confidence)
- Direct source code reading: `supabase/functions/send-trade/index.ts` — Edge Function auth + CORS + RPC pattern
- Direct source code reading: `lib/features/map/screens/island_screen.dart` — `_showCityActionDialog` integration point (lines 238–336)
- Direct source code reading: `lib/features/map/screens/city_grid_screen.dart` — `BuildingsGrid`, `BuildingCell`, `_ConstructionBanner` reuse targets
- Direct source code reading: `lib/features/city/screens/city_screen.dart` — city layout pattern for enemy city view
- Direct source code reading: `lib/core/router/app_router.dart` — GoRouter route registration pattern
- Direct source code reading: `lib/features/trade/screens/trade_dialog.dart` — dialog pattern with loading state
- Direct source code reading: `supabase/migrations/20260316000002_trade_movement_type_and_deduct_resources.sql` — `deduct_resources` RPC exists and is reusable for gold

### Secondary (MEDIUM confidence)
- Project STATE.md accumulated context: JSONB cast inconsistency warning, phase decisions
- CONTEXT.md canonical refs: confirmed provider file locations and names

### Tertiary (LOW confidence)
- None — all findings verified against actual source files.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries already in project, no new dependencies
- Architecture patterns: HIGH — each pattern verified against existing source files
- Pitfalls: HIGH — most sourced from existing code comments and STATE.md tech debt notes
- DB schema: HIGH — migration pattern verified against existing migrations
- Test gaps: HIGH — test directory structure scanned directly

**Research date:** 2026-03-16
**Valid until:** 2026-04-16 (stable project, no fast-moving dependencies)
