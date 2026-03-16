# Phase 13: Dev Acceleration - Research

**Researched:** 2026-03-16
**Domain:** Flutter dev toolbar (Dart/Flutter), Supabase Edge Functions (Deno/TypeScript), PostgreSQL SECURITY DEFINER functions
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Bulk spawn dialog (DEVT-01)
- Checklist layout: all 13 unit types listed with a checkbox and a quantity input field per row
- Default quantity when checkbox toggled on: 50
- Single RPC call with JSONB map (e.g., `{"hoplite": 100, "archer": 50, "cargo_ship": 20}`) — server loops and inserts atomically
- New `dev_bulk_spawn_units(p_city_id, p_units_map)` RPC function
- Keep the existing single-type "Spawn Units" button alongside the new bulk spawn button

#### Timer speed mechanism (DEVT-02, DEVT-03)
- Server-side `app.environment` check — same pattern as existing env_guard_timers migration
- Divide training time by 5 when `app.environment IS DISTINCT FROM 'production'`
- Divide travel time by 5 when `app.environment IS DISTINCT FROM 'production'`
- Training + travel only — building construction times NOT modified (per requirements)
- Keep existing speed-ups (10s battle turns, 1min resource ticks) untouched — add 1/5 training/travel on top

#### Dev toolbar scope
- Add new "Bulk Spawn" button to toolbar (alongside existing single-spawn)
- Add "Instant Complete" button — instantly completes all in-progress training queues AND construction in the current city
- New `dev_instant_complete(p_city_id)` RPC function for instant completion
- Timer speed-ups are server-side only — no new toolbar UI needed for DEVT-02/03

### Claude's Discretion
- Bulk spawn dialog scrollability and layout details
- Instant-complete RPC implementation approach (UPDATE timestamps vs DELETE+INSERT)
- Error handling and snackbar messaging for new buttons
- Whether to add a "Select All / Deselect All" toggle to bulk spawn

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DEVT-01 | Dev toolbar supports bulk unit spawning (select multiple types and quantities in one action) | New `dev_bulk_spawn_units` RPC + Flutter bulk spawn dialog using StatefulBuilder + Map<String,int> state |
| DEVT-02 | Unit training times reduced to 1/5 of normal in dev mode | `train-units` Edge Function computes `finish_at` — divide `durationMinutes` by 5 when env IS DISTINCT FROM 'production' |
| DEVT-03 | Unit travel/arrival times reduced to 1/5 of normal in dev mode | `dispatch-units` Edge Function uses `calcTravelMinutes` — divide result by 5 (or multiply `BASE_MINUTES_PER_GRID_UNIT` by 0.2) when env IS DISTINCT FROM 'production' |
</phase_requirements>

---

## Summary

Phase 13 is a pure developer-tooling phase with no production-visible changes. All work lives behind `kDebugMode` (Flutter tree-shaking) and `app.environment IS DISTINCT FROM 'production'` (server-side guard). The codebase already has a mature dev toolbar (`DevToolbarWrapper` / `_DevToolbarFab`), a `DevRpcService` client, and a set of SECURITY DEFINER helper functions — this phase extends each layer by one new feature.

The bulk spawn dialog (DEVT-01) follows the established `StatefulBuilder`-inside-`showDialog` pattern used by the existing `_levelUpBuilding` and `_spawnUnits` dialogs, but adds per-unit checkbox + quantity input state stored in a `Map<String, int>`. On the server, `dev_bulk_spawn_units` iterates the JSONB map and calls the same upsert logic as the existing `dev_spawn_units` function.

Timer speed-ups (DEVT-02, DEVT-03) require patching two independent locations: the `train-units` Edge Function's `finish_at` calculation, and the `dispatch-units` Edge Function's `calcTravelMinutes` call. The pattern mirrors how `20260312000010_env_guard_timers.sql` uses `current_setting('app.environment', true)` — except here the guard runs in TypeScript (Deno), reading `Deno.env.get('APP_ENVIRONMENT')` (or equivalent). The existing server-side speed-ups (battles, resource ticks) are untouched.

**Primary recommendation:** Implement in three independent streams — (1) SQL migration for new RPC functions, (2) Edge Function patches for timers, (3) Flutter toolbar additions — all gated behind existing dev-mode guards.

---

## Standard Stack

### Core
| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Flutter / Dart | SDK in pubspec | `kDebugMode` guard, `StatefulBuilder`, `showDialog`, `ElevatedButton.icon` | Project-wide Flutter UI |
| supabase_flutter | from pubspec | `Supabase.instance.client.rpc()` for calling new RPC functions | Already used in `DevRpcService` |
| PostgreSQL (Supabase) | 15.x (Supabase default) | SECURITY DEFINER functions, JSONB operations, `jsonb_each_text` iteration | Existing pattern in `dev_rpc_helpers.sql` |
| Deno (Edge Functions) | Supabase-managed | TypeScript env-guard logic in `train-units` and `dispatch-units` | Already used by all Edge Functions |

### Supporting
| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| `flutter/foundation.dart` | SDK | `kDebugMode` constant | Every new dev-only class/file |
| `flutter_riverpod` | from pubspec | `ref.read(cityProvider)` to get current city ID | Any toolbar button that needs city context |

---

## Architecture Patterns

### Recommended File Structure for Phase 13

No new files required. All changes are additive modifications to existing files:

```
lib/core/dev/
├── dev_toolbar.dart          # ADD: _bulkSpawnUnits() method + _instantComplete() method + 2 new _ActionButton entries
└── dev_rpc_service.dart      # ADD: bulkSpawnUnits() method + instantComplete() method

supabase/
├── functions/
│   ├── train-units/index.ts       # PATCH: divide durationMinutes by 5 when not production
│   └── dispatch-units/index.ts    # PATCH: divide travelMinutes by 5 when not production
└── migrations/
    └── 2026XXXX_dev_bulk_spawn_and_instant_complete.sql   # NEW: dev_bulk_spawn_units + dev_instant_complete
```

### Pattern 1: SECURITY DEFINER Dev RPC Function

All dev RPC functions follow the same template established in `20260312000008_dev_rpc_helpers.sql`:

```sql
-- Source: supabase/migrations/20260312000008_dev_rpc_helpers.sql
CREATE OR REPLACE FUNCTION public.dev_bulk_spawn_units(
  p_city_id  uuid,
  p_units    jsonb   -- e.g. '{"hoplite":100,"archer":50}'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_unit_type text;
  v_quantity  integer;
BEGIN
  FOR v_unit_type, v_quantity IN
    SELECT key, value::integer FROM jsonb_each_text(p_units)
  LOOP
    INSERT INTO public.city_units (city_id, unit_type, quantity, updated_at)
    VALUES (p_city_id, v_unit_type, v_quantity, NOW())
    ON CONFLICT (city_id, unit_type)
    DO UPDATE SET
      quantity   = public.city_units.quantity + EXCLUDED.quantity,
      updated_at = NOW();
  END LOOP;
END;
$$;
```

### Pattern 2: Instant Complete RPC

Two tables need to be cleared/updated atomically: `training_queue` and `building_construction_queue` (if it exists). The simplest approach for `training_queue` is to update `finish_at` to `NOW() - interval '1 second'` so that the next `complete_training()` cron tick picks it up — OR directly upsert units + delete rows inline. Direct inline completion is more reliable in testing:

```sql
CREATE OR REPLACE FUNCTION public.dev_instant_complete(
  p_city_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  q RECORD;
BEGIN
  -- Instantly complete all training queue entries for this city
  FOR q IN
    SELECT id, unit_type, quantity FROM public.training_queue
    WHERE city_id = p_city_id
  LOOP
    INSERT INTO public.city_units (city_id, unit_type, quantity, updated_at)
    VALUES (p_city_id, q.unit_type, q.quantity, NOW())
    ON CONFLICT (city_id, unit_type)
    DO UPDATE SET
      quantity   = public.city_units.quantity + EXCLUDED.quantity,
      updated_at = NOW();
    DELETE FROM public.training_queue WHERE id = q.id;
  END LOOP;

  -- Instantly complete all building construction for this city
  -- (set finish_at to past so cron picks up, or direct level update)
  UPDATE public.building_construction_queue
    SET finish_at = NOW() - INTERVAL '1 second'
    WHERE city_id = p_city_id;
END;
$$;
```

NOTE: The `building_construction_queue` table name must be verified against actual schema before implementing. See Open Questions.

### Pattern 3: StatefulBuilder Bulk Spawn Dialog

Follows the exact same pattern as `_levelUpBuilding` dialog. The state to track per dialog is `Map<String, int> _selectedUnits` where key = unit type, value = quantity (0 means unchecked/excluded):

```dart
// Source: lib/core/dev/dev_toolbar.dart (_spawnUnits pattern extended)
Future<void> _bulkSpawnUnits() async {
  final cityId = _currentCityId();
  if (cityId == null) {
    _showSnack('No city loaded');
    return;
  }

  final Map<String, int> selectedUnits = {};
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Bulk Spawn Units'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,  // scrollable area — Claude's discretion
        child: StatefulBuilder(
          builder: (ctx2, setStateDialog) => ListView.builder(
            itemCount: _unitTypes.length,
            itemBuilder: (_, i) {
              final type = _unitTypes[i];
              final qty = selectedUnits[type] ?? 0;
              final isChecked = qty > 0;
              return Row(children: [
                Checkbox(
                  value: isChecked,
                  onChanged: (v) => setStateDialog(() {
                    selectedUnits[type] = (v == true) ? 50 : 0;
                  }),
                ),
                Expanded(child: Text(type)),
                SizedBox(
                  width: 60,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: qty.toString()),
                    enabled: isChecked,
                    onChanged: (v) => setStateDialog(() {
                      selectedUnits[type] = int.tryParse(v) ?? 50;
                    }),
                  ),
                ),
              ]);
            },
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Spawn')),
      ],
    ),
  );

  if (confirmed != true) return;
  final toSpawn = Map.fromEntries(
    selectedUnits.entries.where((e) => e.value > 0),
  );
  if (toSpawn.isEmpty) return;
  try {
    await _devRpc.bulkSpawnUnits(cityId, toSpawn);
    _showSnack('Spawned units: ${toSpawn.keys.join(', ')}');
  } catch (_) {
    _showSnack('Failed to bulk spawn units');
  }
}
```

### Pattern 4: Dev Environment Guard in Edge Functions

The `app.environment` setting is a PostgreSQL custom parameter. In Edge Functions (Deno), the equivalent guard reads `Deno.env.get('APP_ENVIRONMENT')` (the Supabase Edge Runtime exposes custom secrets as env vars). However, since the existing timer guards are SQL-side only, the correct approach for Edge Functions is to query the DB setting or use a dedicated env variable.

**Recommended approach:** Read the existing `APP_ENVIRONMENT` Supabase secret (set in Edge Function secrets in Supabase dashboard). If not set (local dev), treat as non-production.

```typescript
// Source: dispatch-units/index.ts and train-units/index.ts (to be added)
const appEnv = Deno.env.get('APP_ENVIRONMENT') ?? 'development';
const isProduction = appEnv === 'production';
const DEV_SPEED_MULTIPLIER = isProduction ? 1.0 : 0.2;  // 1/5 speed = 0.2
```

For training time:
```typescript
// In train-units/index.ts — line 225 area
const durationMinutes = UNIT_BASE_TIMES[unit_type] * quantity * DEV_SPEED_MULTIPLIER;
```

For travel time:
```typescript
// In dispatch-units/index.ts — calcTravelMinutes call
const rawMinutes = calcTravelMinutes(originIsland, destIsland);
const travelMinutes = Math.max(1, Math.ceil(rawMinutes * DEV_SPEED_MULTIPLIER));
```

### Pattern 5: DevRpcService New Methods

```dart
// Source: lib/core/dev/dev_rpc_service.dart (extension of existing pattern)
Future<void> bulkSpawnUnits(String cityId, Map<String, int> units) async {
  try {
    await _client.rpc('dev_bulk_spawn_units', params: {
      'p_city_id': cityId,
      'p_units': units,  // supabase_flutter serializes Map<String,int> to JSONB
    });
  } catch (e) {
    debugPrint('[DevRpcService] bulkSpawnUnits error: $e');
    rethrow;
  }
}

Future<void> instantComplete(String cityId) async {
  try {
    await _client.rpc('dev_instant_complete', params: {
      'p_city_id': cityId,
    });
  } catch (e) {
    debugPrint('[DevRpcService] instantComplete error: $e');
    rethrow;
  }
}
```

### Anti-Patterns to Avoid

- **DO NOT add timer speed-up logic to Flutter client:** All speed logic is server-side. The client never computes `finish_at` or `arrive_at` — those are set by Edge Functions.
- **DO NOT use a new toolbar widget:** Follow the `_ActionButton` pattern already in `dev_toolbar.dart`. No separate Widget class needed for buttons.
- **DO NOT guard with `if (kDebugMode)` inside RPC functions:** The SQL functions are always callable; the Flutter guard (`kDebugMode` in `DevToolbarWrapper`) is the production barrier.
- **DO NOT wrap timer patches in a new migration using the `DO $$ IF... END $$` pattern:** The existing env_guard migration runs at deploy time; the Edge Function env var is checked at request time. These are separate mechanisms.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSONB iteration in SQL | Custom loop over array | `jsonb_each_text(p_units)` | Native PostgreSQL — handles any key set, type-safe |
| Dialog state in Flutter | External `StatefulWidget` | `StatefulBuilder` inside `showDialog` | Existing project pattern — keeps dialog state local without a new file |
| Production guard in Edge Function | Per-function flags or constants | `Deno.env.get('APP_ENVIRONMENT')` | Matches same `app.environment` concept as SQL-side guard, single source of truth |
| Instant complete via time manipulation | Setting timestamps to far future/past | Direct upsert + DELETE inline in PL/pgSQL | More reliable than relying on cron pickup; no residual stale rows |

---

## Common Pitfalls

### Pitfall 1: TextEditingController in ListView.builder
**What goes wrong:** Creating `TextEditingController(text: qty.toString())` inside `itemBuilder` creates a new controller on every rebuild, causing text input to reset when the `StatefulBuilder` rebuilds.
**Why it happens:** `ListView.builder` rebuilds all visible items on `setStateDialog` call.
**How to avoid:** Pre-create a `Map<String, TextEditingController>` initialized for all 13 unit types before the `showDialog` call, pass controllers into the builder.
**Warning signs:** Quantity field clears itself when toggling a checkbox.

### Pitfall 2: Edge Function `APP_ENVIRONMENT` vs `app.environment`
**What goes wrong:** The Supabase `app.environment` PostgreSQL setting is NOT automatically available to Edge Functions as `Deno.env.get('app.environment')`.
**Why it happens:** PostgreSQL custom config and Supabase Edge Function secrets are separate systems. Edge Function env vars are set in the Supabase dashboard under "Edge Functions → Secrets".
**How to avoid:** Use `Deno.env.get('APP_ENVIRONMENT')` (uppercase, no dot) — a separately configured secret. Document that local dev has no secret set, so `?? 'development'` default applies.
**Warning signs:** Speed-up applies in production because the secret is not set and defaults to non-production.

### Pitfall 3: `Math.max(1, ...)` after dividing travel time
**What goes wrong:** `calcTravelMinutes` already applies `Math.max(1, ...)`. After multiplying by 0.2, `Math.ceil(0.2)` = 1. So very short distances will still yield 1 minute even in dev mode.
**Why it happens:** The minimum floor is applied before the dev multiplier could reduce it further.
**How to avoid:** Apply the multiplier before `Math.max` — i.e., modify `calcTravelMinutes` to accept a multiplier param, or call it and then apply: `Math.max(1, Math.ceil(rawMinutes * 0.2))` (the same result in this case — just be aware 1 minute is the floor).
**Warning signs:** Same-island or adjacent-island dispatches don't appear faster than non-dev mode.

### Pitfall 4: `building_construction_queue` table name assumption
**What goes wrong:** `dev_instant_complete` is expected to also complete building construction, but the actual table name must match the schema.
**Why it happens:** CONTEXT.md mentions "all in-progress training queues AND construction" but the migration file name is not verified here.
**How to avoid:** Check `20260311000012_create_training_queue.sql` and construction queue migration for exact table name before writing the instant-complete SQL.
**Warning signs:** SQL error on `dev_instant_complete` call if table name is wrong.

### Pitfall 5: Supabase RPC JSONB parameter serialization
**What goes wrong:** Passing `Map<String, int>` directly to `_client.rpc()` `params` map may serialize incorrectly (as a nested JSON object within the params map).
**Why it happens:** `supabase_flutter` serializes the params map to JSON; a nested `Map<String, int>` is treated as a JSON object. PostgreSQL expects `jsonb` — this should work, but must be verified against the actual Supabase client behavior for JSONB params.
**How to avoid:** Pass the map directly — `supabase_flutter` handles it. If issues arise, serialize manually: `jsonEncode(units)`.
**Warning signs:** PostgreSQL error `invalid input syntax for type json` or `42883 function does not exist` with wrong type signature.

---

## Code Examples

Verified patterns from project source:

### Existing single-spawn RPC (model for bulk spawn)
```dart
// Source: lib/core/dev/dev_rpc_service.dart
Future<void> spawnUnits(String cityId, String unitType, {int quantity = 50}) async {
  try {
    await _client.rpc('dev_spawn_units', params: {
      'p_city_id': cityId,
      'p_unit_type': unitType,
      'p_quantity': quantity,
    });
  } catch (e) {
    debugPrint('[DevRpcService] spawnUnits error: $e');
    rethrow;
  }
}
```

### Existing dev_spawn_units SQL (model for dev_bulk_spawn_units)
```sql
-- Source: supabase/migrations/20260312000008_dev_rpc_helpers.sql
CREATE OR REPLACE FUNCTION public.dev_spawn_units(
  p_city_id   uuid,
  p_unit_type text,
  p_quantity  int DEFAULT 50
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.city_units (city_id, unit_type, quantity)
    VALUES (p_city_id, p_unit_type, p_quantity)
    ON CONFLICT (city_id, unit_type)
    DO UPDATE SET quantity = public.city_units.quantity + EXCLUDED.quantity;
END;
$$;
```

### Training time calculation in Edge Function (to be patched)
```typescript
// Source: supabase/functions/train-units/index.ts line 225
const durationMinutes = UNIT_BASE_TIMES[unit_type] * quantity;
const finishAt = new Date(Date.now() + durationMinutes * 60 * 1000).toISOString();
```

### Travel time calculation in Edge Function (to be patched)
```typescript
// Source: supabase/functions/dispatch-units/index.ts line 190
const travelMinutes = calcTravelMinutes(originIsland, destIsland);
// ...
const arriveAt = new Date(now + travelMinutes * 60 * 1000).toISOString();
```

### Production env guard pattern (SQL)
```sql
-- Source: supabase/migrations/20260312000010_env_guard_timers.sql
IF current_setting('app.environment', true) = 'production' THEN
  -- production behavior
END IF;
-- ELSE: app.environment IS DISTINCT FROM 'production' = dev mode active
```

### _ActionButton in toolbar (model for new buttons)
```dart
// Source: lib/core/dev/dev_toolbar.dart
_ActionButton(
  icon: Icons.groups,
  label: 'Spawn Units',
  onPressed: _spawnUnits,
),
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single-type spawn dialog (dropdown) | Keep + add bulk spawn (checklist) | Phase 13 | Faster multi-unit test setup |
| No training speed-up | 1/5 training time in dev mode | Phase 13 | Faster barracks testing |
| Existing travel: `BASE_SECONDS_PER_GRID_UNIT = 10` | Plus additional 1/5 multiplier from `APP_ENVIRONMENT` guard | Phase 13 | Note: dispatch-units already uses seconds-based fast travel — 1/5 of that is already very fast |

**Important note on existing travel speed:** `dispatch-units/index.ts` currently uses `BASE_MINUTES_PER_GRID_UNIT = 2` for the `calcTravelMinutes` function, but also has `BASE_SECONDS_PER_GRID_UNIT = 10` defined (unused in the main path). The actual `arriveAt` calculation uses `travelMinutes * 60 * 1000` ms. The 1/5 multiplier will reduce this further from production values. Verify which base value is currently active.

---

## Open Questions

1. **Building construction queue table name**
   - What we know: CONTEXT.md says `dev_instant_complete` should complete training AND construction; `20260311000014_training_functions.sql` confirms `training_queue` table
   - What's unclear: The exact table name for the building construction queue (likely `building_construction_queue` or `construction_queue`)
   - Recommendation: Read the construction queue migration file before writing `dev_instant_complete` SQL — add a task to read `20260311000012_create_training_queue.sql` and related construction migrations in Wave 0

2. **`APP_ENVIRONMENT` secret currently set in Supabase project**
   - What we know: SQL guard uses `app.environment`; Edge Functions need a separate secret
   - What's unclear: Whether `APP_ENVIRONMENT` is already configured in the Supabase dashboard for this project
   - Recommendation: Document the secret requirement in code comments; default to `'development'` so speed-ups are active unless explicitly set to `'production'`

3. **`dispatch-units` active base speed**
   - What we know: Two constants exist — `BASE_SECONDS_PER_GRID_UNIT = 10` and `BASE_MINUTES_PER_GRID_UNIT = 2`; the function `calcTravelMinutes` uses `BASE_MINUTES_PER_GRID_UNIT`
   - What's unclear: Whether `BASE_SECONDS_PER_GRID_UNIT` is used anywhere (appears unused — dead code)
   - Recommendation: Apply 1/5 multiplier to `calcTravelMinutes` result; the `BASE_SECONDS_PER_GRID_UNIT` constant can be ignored or removed

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None detected — no test/ directory, no pubspec test dependencies found |
| Config file | none |
| Quick run command | `flutter analyze` |
| Full suite command | `flutter analyze && dart format --output=none --set-exit-if-changed lib/` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DEVT-01 | Bulk spawn dialog opens with 13 unit checkboxes | manual-only | — | ❌ |
| DEVT-01 | `dev_bulk_spawn_units` RPC inserts units into city_units | manual-only (SQL test) | — | ❌ |
| DEVT-02 | Training `finish_at` is ~1/5 of normal duration in dev | manual-only | — | ❌ |
| DEVT-03 | `arrive_at` is ~1/5 of normal travel time in dev | manual-only | — | ❌ |

All DEVT requirements are dev-tooling behaviors that require live Supabase + Flutter runtime to verify. Automated unit tests are not applicable for this phase.

**Manual verification approach:**
1. Spawn 50 hoplites via bulk spawn — confirm `city_units` row added in Supabase dashboard
2. Train 10 hoplites — check `finish_at` is ~2 seconds away (10 * 1min * 0.2 = 2min → but with 1/5: 0.2 * 10 * 1 = 2 min... see actual base times)
3. Dispatch to nearby city — confirm `arrive_at` is ~1/5 of expected production time

### Wave 0 Gaps
- [ ] Verify building construction queue table name — read construction-related migration files
- [ ] Confirm `APP_ENVIRONMENT` secret availability in local Supabase dev setup

*(No test framework gaps — project has no automated test suite; static analysis via `flutter analyze` is the automated gate)*

---

## Sources

### Primary (HIGH confidence)
- `lib/core/dev/dev_toolbar.dart` — Full toolbar implementation read directly
- `lib/core/dev/dev_rpc_service.dart` — Full RPC service read directly
- `supabase/migrations/20260312000008_dev_rpc_helpers.sql` — All 4 existing dev RPC functions
- `supabase/migrations/20260312000010_env_guard_timers.sql` — Full env guard pattern
- `supabase/migrations/20260312000007_speed_up_all_timers.sql` — Existing speed-up implementation
- `supabase/functions/train-units/index.ts` — Training time formula (line 225)
- `supabase/functions/dispatch-units/index.ts` — Travel time formula (line 190)
- `supabase/migrations/20260311000014_training_functions.sql` — `complete_training()` and `training_queue` schema

### Secondary (MEDIUM confidence)
- `.planning/phases/13-dev-acceleration/13-CONTEXT.md` — All locked decisions

### Tertiary (LOW confidence)
- Building construction queue table name — not directly verified in this research session

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all files read directly from project source
- Architecture patterns: HIGH — all patterns derived from existing project code
- Pitfalls: HIGH (TextEditingController, env var naming) / MEDIUM (construction table name)
- Timer mechanism: HIGH — both Edge Functions fully read, exact patch locations identified

**Research date:** 2026-03-16
**Valid until:** 2026-04-16 (stable codebase — no external dependencies being introduced)
