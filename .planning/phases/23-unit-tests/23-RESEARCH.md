# Phase 23: Unit Tests - Research

**Researched:** 2026-03-18
**Domain:** Deno unit testing (pure function extraction) + Flutter widget testing (Riverpod provider isolation)
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Edge Function extraction
- Extract pure functions into `supabase/functions/_shared/formulas.ts` (centralized shared lib)
- Constants (BASE_COSTS, UNIT_BASE_COSTS, BASE_TIMES, UNIT_BASE_TIMES, UNIT_UNLOCK_LEVELS) move to `_shared/formulas.ts` as named exports
- Each Edge Function `index.ts` imports from `../_shared/formulas.ts`
- Extract formulas only: `calcUpgradeCost`, `calcUpgradeDurationMinutes`, `calcTrainingCost`, `calcTrainingDuration`
- Validation functions (isValidBuildingType, etc.) stay in index.ts — not extracted

#### GodMode widget coverage
- Test ALL 8 GodMode widgets: bot_badge, elapsed_timer_text, event_feed, event_tile, player_row, player_table, godmode_dashboard_screen, godmode_placeholder_screen
- Provider isolation via `ProviderScope` with `overrides` (existing codebase pattern from dev_toolbar_test.dart)
- Assertions verify rendering + key data display (text, icons, data from mock providers)
- Do NOT test tap handlers that call Supabase RPCs, scroll behavior, or refresh fetching
- Test all 3 async states for widgets with async providers: loading (spinner), error (error message), data (content)

#### Test file organization
- Deno tests: `supabase/functions/tests/upgrade_building_test.ts` and `train_units_test.ts` (underscore naming)
- Flutter GodMode tests: `test/widget/godmode/` subdirectory with per-widget test files
- Shared mock data: `test/widget/godmode/godmode_test_helpers.dart` with mock GodmodePlayer, GodmodeEvent objects

#### Test scope boundaries
- Edge Function formula tests: happy path + edge cases (level 0, mid-level ~5, high-level ~20)
- Test every building/unit type returns valid non-empty cost at level 0
- Dev speed multiplier tested in both modes (devMode=true → 0.2x, devMode=false → 1.0x)
- Flutter widget tests cover loading, error, and data-loaded states for async providers

### Claude's Discretion
- Exact mock data values for GodmodePlayer and GodmodeEvent objects
- Which specific building types to use as test subjects for mid/high level tests
- Loading spinner and error message widget finder patterns
- Whether to add a deno.json test task configuration

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| TEST-01 | Critical Edge Functions are unit tested with Deno test runner | Deno `Deno.test()` API, pure function extraction to `_shared/formulas.ts`, `supabase/functions/tests/` directory pattern |
| TEST-02 | GodMode and critical Flutter widgets are tested with Riverpod ProviderContainer | `ProviderScope(overrides: [...])` pattern, `AsyncNotifier` stub approach, `flutter_riverpod 3.3.1` API |
</phase_requirements>

---

## Summary

This phase has two entirely separate testing tracks: Deno pure-function tests and Flutter widget tests. They share no infrastructure and can be planned as parallel plans.

**Track 1 — Deno:** The upgrade-building and train-units Edge Functions already contain pure arithmetic functions (`calcUpgradeCost`, `calcUpgradeDurationMinutes`, plus the training equivalents) and all their constants, but these are currently declared inside `index.ts` and tangled with `Deno.serve()`. The plan must first extract them into `supabase/functions/_shared/formulas.ts`, then have both `index.ts` files import from there. The test files in `supabase/functions/tests/` then import from `_shared/formulas.ts` directly — no HTTP server, no Supabase client required. Deno 2.4.5 is installed and ready.

**Track 2 — Flutter:** The project already has 27 test files, flutter_riverpod 3.3.1 installed, and a clear `ProviderScope(overrides: [...])` pattern established in `dev_toolbar_test.dart`. The 8 GodMode widgets need fresh test files under `test/widget/godmode/`. The two async providers (`godmodeWorldProvider`, `godmodeEventsProvider`) must be overridden via stub `AsyncNotifier` classes that return pre-baked data without touching Supabase. A shared `godmode_test_helpers.dart` will hold `GodmodePlayer` and `GodmodeEvent` fixtures usable across all 8 test files.

**Primary recommendation:** Plan as two plans: Plan 23-01 (Deno extraction + tests) and Plan 23-02 (Flutter GodMode widget tests). Both are self-contained and can be verified independently.

---

## Standard Stack

### Core — Deno
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Deno built-in test runner | 2.4.5 (installed) | `Deno.test()` API with `assertEquals`, `assertThrows` | Ships with Deno — zero dependencies |
| `jsr:@std/assert` | latest via JSR | Assertion helpers: `assertEquals`, `assertExists`, `assertThrows` | Official Deno standard library; replaces old `std/testing/asserts.ts` |

### Core — Flutter
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter_test` | sdk: flutter | `testWidgets`, `WidgetTester`, `find.*`, `expect` | Ships with Flutter SDK |
| `flutter_riverpod` | 3.3.1 | `ProviderScope(overrides: [...])` for provider isolation | Already in pubspec.yaml |
| `mocktail` | 1.0.4 | Stub classes for repository | Already in pubspec.yaml dev_dependencies |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Deno `deno.json` tasks | N/A config file | `deno test supabase/functions/tests/` alias | Add if planner decides to provide shortcut command |

**Installation:**
```bash
# Deno: no install needed — Deno 2.4.5 already installed
# Flutter: no new deps needed — all already in pubspec.yaml
flutter pub get  # ensure lock file is fresh
```

**Note on Deno standard library import:** With Deno 2.x and JSR, the import is:
```typescript
import { assertEquals, assertExists } from 'jsr:@std/assert';
```
The old `https://deno.land/std/testing/asserts.ts` import style still works but JSR is the current approach.

---

## Architecture Patterns

### Plan 23-01: Deno Extraction + Tests

#### Step 1 — Create `_shared/formulas.ts`

The `_shared/` directory does not yet exist. It must be created. The file exports only pure arithmetic — no `Deno.serve`, no `createClient`, no env reads.

```typescript
// supabase/functions/_shared/formulas.ts
// Source: extracted from upgrade-building/index.ts and train-units/index.ts

export const BASE_COSTS: Record<string, Record<string, number>> = { ... };
export const BASE_TIMES: Record<string, number> = { ... };
export const UNIT_BASE_COSTS: Record<string, Record<string, number>> = { ... };
export const UNIT_BASE_TIMES: Record<string, number> = { ... };
export const UNIT_UNLOCK_LEVELS: Record<string, { building: string; minLevel: number }> = { ... };

export const COST_GROWTH_FACTOR = 1.5;
export const TIME_GROWTH_FACTOR = 1.2;

// Dev speed: pass as explicit parameter so tests can control it
// (index.ts reads Deno.env; formulas.ts must not — it has no env access)
export function calcUpgradeCost(
  buildingType: string,
  currentLevel: number,
): Record<string, number> { ... }

export function calcUpgradeDurationMinutes(
  buildingType: string,
  currentLevel: number,
): number { ... }

export function calcTrainingCost(
  unitType: string,
  quantity: number,
): Record<string, number> { ... }

export function calcTrainingDurationMinutes(
  unitType: string,
  quantity: number,
  devSpeedMultiplier: number,  // caller passes 0.2 or 1.0
): number { ... }
```

**CRITICAL design decision:** `train-units/index.ts` reads `Deno.env.get('APP_ENVIRONMENT')` to set `DEV_SPEED_MULTIPLIER`. For `formulas.ts` to be pure and testable without env, the multiplier must be a **parameter** to `calcTrainingDurationMinutes`. The `index.ts` remains responsible for reading the env and passing the value.

#### Step 2 — Update `index.ts` files to import from `_shared`

```typescript
// supabase/functions/upgrade-building/index.ts
import {
  BASE_COSTS,
  BASE_TIMES,
  calcUpgradeCost,
  calcUpgradeDurationMinutes,
} from '../_shared/formulas.ts';
```

```typescript
// supabase/functions/train-units/index.ts
import {
  UNIT_BASE_COSTS,
  UNIT_BASE_TIMES,
  UNIT_UNLOCK_LEVELS,
  calcTrainingCost,
  calcTrainingDurationMinutes,
} from '../_shared/formulas.ts';
```

The constants (used for `VALID_BUILDING_TYPES`, `VALID_UNIT_TYPES` sets) and functions imported — local declarations removed from both `index.ts`.

#### Step 3 — Test files

```typescript
// supabase/functions/tests/upgrade_building_test.ts
import { assertEquals, assertExists } from 'jsr:@std/assert';
import {
  BASE_COSTS,
  calcUpgradeCost,
  calcUpgradeDurationMinutes,
} from '../_shared/formulas.ts';

Deno.test('calcUpgradeCost: level 0 returns base cost', () => {
  const cost = calcUpgradeCost('town_hall', 0);
  assertEquals(cost.gold, 100);
  assertEquals(cost.wood, 200);
});

Deno.test('calcUpgradeCost: every building type returns non-empty cost at level 0', () => {
  for (const buildingType of Object.keys(BASE_COSTS)) {
    const cost = calcUpgradeCost(buildingType, 0);
    assertExists(cost);
    expect(Object.keys(cost).length).toBeGreaterThan(0); // at least one resource
  }
});
```

```typescript
// supabase/functions/tests/train_units_test.ts
import { assertEquals } from 'jsr:@std/assert';
import {
  UNIT_BASE_COSTS,
  calcTrainingCost,
  calcTrainingDurationMinutes,
} from '../_shared/formulas.ts';

Deno.test('calcTrainingDurationMinutes: dev mode applies 0.2x multiplier', () => {
  // hoplite base time = 1 min, qty=1, dev mode = 0.2 min
  const duration = calcTrainingDurationMinutes('hoplite', 1, 0.2);
  assertEquals(duration, 0.2);
});

Deno.test('calcTrainingDurationMinutes: production mode uses 1.0x multiplier', () => {
  const duration = calcTrainingDurationMinutes('hoplite', 1, 1.0);
  assertEquals(duration, 1.0);
});
```

**Run command:**
```bash
deno test supabase/functions/tests/
```

### Plan 23-02: Flutter GodMode Widget Tests

#### Directory Structure

```
test/
└── widget/
    └── godmode/
        ├── godmode_test_helpers.dart     # shared mock GodmodePlayer + GodmodeEvent
        ├── bot_badge_test.dart
        ├── elapsed_timer_text_test.dart
        ├── event_tile_test.dart
        ├── event_feed_test.dart
        ├── player_row_test.dart
        ├── player_table_test.dart
        ├── godmode_dashboard_screen_test.dart
        └── godmode_placeholder_screen_test.dart
```

#### Stub Pattern for AsyncNotifier

For `godmodeWorldProvider` (returns `AsyncNotifier<List<GodmodePlayer>>`):

```dart
// Inside test file or godmode_test_helpers.dart
class _FakeWorldNotifier extends AsyncNotifier<List<GodmodePlayer>> {
  final List<GodmodePlayer> players;
  _FakeWorldNotifier(this.players);

  @override
  Future<List<GodmodePlayer>> build() async => players;
}

// Override in ProviderScope:
godmodeWorldProvider.overrideWith(() => _FakeWorldNotifier([mockPlayer])),
```

For loading state:
```dart
class _LoadingWorldNotifier extends AsyncNotifier<List<GodmodePlayer>> {
  @override
  Future<List<GodmodePlayer>> build() async {
    // Never complete — stays in loading
    await Completer<void>().future;
    return [];
  }
}
```

For error state:
```dart
class _ErrorWorldNotifier extends AsyncNotifier<List<GodmodePlayer>> {
  @override
  Future<List<GodmodePlayer>> build() async {
    throw Exception('Network error');
  }
}
```

#### Provider Override Approach for `godmodeRepositoryProvider`

`PlayerRow` and `PlayerTable` both do `ref.read(godmodeRepositoryProvider)` inside tap handlers (pause, force action, save). Since we are NOT testing tap handlers that call Supabase, we do NOT need to mock `godmodeRepositoryProvider` — but if the widget reads it during `build()` (it does not), we would.

However, `godmodeRepositoryProvider` uses `Supabase.instance.client` which throws in tests. Since `PlayerRow` only accesses it inside button `onPressed` callbacks (not in `build()`), the provider does not need to be overridden for rendering tests. **Verify this**: if the test pumps `PlayerRow` and `Supabase.instance` is never touched during rendering, no override is needed.

If Supabase.instance IS accessed during widget tree construction, override with:
```dart
godmodeRepositoryProvider.overrideWithValue(_FakeRepository()),
```

where `_FakeRepository` is a stub that extends `GodmodeRepository` with a fake `SupabaseClient`.

#### `godmode_test_helpers.dart` — Mock Data Fixtures

```dart
// test/widget/godmode/godmode_test_helpers.dart
import 'package:ikariam/features/godmode/models/godmode_player.dart';
import 'package:ikariam/features/godmode/models/godmode_event.dart';

GodmodePlayer mockHumanPlayer() => GodmodePlayer(
  id: 'player-001',
  displayName: 'TestHuman',
  isBot: false,
  isPaused: false,
  resources: {'wood': 1000, 'marble': 500, 'crystal': 200, 'sulfur': 100, 'gold': 800},
  landCount: 50,
  navalCount: 10,
  buildingCount: 5,
  activeBattleCount: 0,
  activeBattles: [],
  buildings: {'town_hall': 3, 'barracks': 2},
);

GodmodePlayer mockBotPlayer({bool isPaused = false}) => GodmodePlayer(
  id: 'bot-001',
  displayName: 'Bot01',
  isBot: true,
  isPaused: isPaused,
  resources: {'wood': 500, 'marble': 200, 'crystal': 100, 'sulfur': 50, 'gold': 300},
  landCount: 30,
  navalCount: 5,
  buildingCount: 3,
  activeBattleCount: 1,
  activeBattles: [{'battle_id': 'b-001', 'attacker_name': 'Bot01', 'defender_name': 'TestHuman'}],
  buildings: {'town_hall': 2, 'barracks': 1},
);

GodmodeEvent mockBattleEvent() => GodmodeEvent(
  eventType: 'battle',
  timestamp: DateTime(2026, 3, 18, 10, 30),
  detail: {
    'battle_id': 'b-001',
    'attacker': 'Bot01',
    'defender': 'TestHuman',
    'summary': 'Battle turn 2 - active',
  },
);

GodmodeEvent mockTradeEvent() => GodmodeEvent(
  eventType: 'trade',
  timestamp: DateTime(2026, 3, 18, 9, 0),
  detail: {'summary': 'Trade completed'},
);
```

#### Widget Test Pattern — All 3 States

```dart
// test/widget/godmode/event_feed_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikariam/features/godmode/providers/godmode_events_provider.dart';
import 'package:ikariam/features/godmode/widgets/event_feed.dart';
import 'godmode_test_helpers.dart';

void main() {
  group('EventFeed', () {
    testWidgets('shows loading spinner while events load', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            godmodeEventsProvider.overrideWith(() => _LoadingEventsNotifier()),
            godmodeEventFilterProvider.overrideWith(() => _StaticFilterNotifier()),
          ],
          child: const MaterialApp(home: Scaffold(body: EventFeed())),
        ),
      );
      await tester.pump(); // let provider initiate
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message on failure', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            godmodeEventsProvider.overrideWith(() => _ErrorEventsNotifier()),
            godmodeEventFilterProvider.overrideWith(() => _StaticFilterNotifier()),
          ],
          child: const MaterialApp(home: Scaffold(body: EventFeed())),
        ),
      );
      await tester.pump();
      await tester.pump(); // let future settle
      expect(find.textContaining('Failed to load events'), findsOneWidget);
    });

    testWidgets('shows event tiles when data loaded', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            godmodeEventsProvider.overrideWith(
              () => _DataEventsNotifier([mockBattleEvent()]),
            ),
            godmodeEventFilterProvider.overrideWith(() => _StaticFilterNotifier()),
          ],
          child: const MaterialApp(home: Scaffold(body: EventFeed())),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Battle turn 2 - active'), findsOneWidget);
    });
  });
}
```

### Recommended Project Structure (additions only)

```
supabase/functions/
├── _shared/
│   └── formulas.ts              # NEW: extracted pure functions + constants
├── tests/                       # NEW directory
│   ├── upgrade_building_test.ts # NEW: Deno tests for calcUpgradeCost
│   └── train_units_test.ts      # NEW: Deno tests for calcTrainingDurationMinutes
├── upgrade-building/
│   └── index.ts                 # MODIFIED: imports from ../_shared/formulas.ts
└── train-units/
    └── index.ts                 # MODIFIED: imports from ../_shared/formulas.ts

test/widget/godmode/             # NEW directory
├── godmode_test_helpers.dart    # NEW: mock fixtures
├── bot_badge_test.dart          # NEW
├── elapsed_timer_text_test.dart # NEW
├── event_tile_test.dart         # NEW
├── event_feed_test.dart         # NEW
├── player_row_test.dart         # NEW
├── player_table_test.dart       # NEW
├── godmode_dashboard_screen_test.dart  # NEW
└── godmode_placeholder_screen_test.dart # NEW
```

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Async provider states in tests | Custom Future wrapper | `AsyncNotifier` stub class with overrideWith | Riverpod 3.x provides first-class test support via provider overrides |
| Deno assertions | Custom assertEqual helpers | `jsr:@std/assert` | Ships with Deno stdlib — zero setup |
| Mock SupabaseClient in Deno tests | HTTP interceptor or Supabase mock | Pure function extraction (no client in formulas.ts) | Extraction is the entire strategy — no mock needed when functions are pure |
| Fake timer for ElapsedTimerText | Real timer waits | `tester.pump(Duration(seconds: N))` or `tester.pumpAndSettle()` | Flutter test pump advances fake clock |

**Key insight:** The Deno test strategy is entirely about extraction — by moving arithmetic into functions with no side effects and no imports of `createClient` or `Deno.env`, the tests become trivially simple assertions. No mocking framework required.

---

## Common Pitfalls

### Pitfall 1: Forgetting `Deno.env` in `formulas.ts`
**What goes wrong:** If `calcTrainingDurationMinutes` reads `Deno.env.get('APP_ENVIRONMENT')` inside the function body, the tests cannot control dev/production mode without setting env vars.
**Why it happens:** Copying the constant pattern from `index.ts` without thinking about test isolation.
**How to avoid:** Make `devSpeedMultiplier` a parameter (e.g. `number` defaulting to `0.2`). The `index.ts` reads the env and passes the value; tests pass `0.2` or `1.0` explicitly.
**Warning signs:** Test file imports `APP_ENV` or sets `Deno.env` — a red flag that purity was broken.

### Pitfall 2: `_shared/` directory path in Deno test imports
**What goes wrong:** Import path `'../_shared/formulas.ts'` from `supabase/functions/tests/` resolves to `supabase/functions/_shared/formulas.ts` — correct. But if test files are placed directly in `supabase/functions/` (not a subfolder), the path becomes `'./_shared/formulas.ts'`.
**How to avoid:** Confirm directory is `supabase/functions/tests/` (as per locked decision), import path is `'../_shared/formulas.ts'`.

### Pitfall 3: AsyncNotifier stub missing `overrideWith(() => ...)` arrow function
**What goes wrong:** Using `overrideWith(MyNotifier.new)` instead of `overrideWith(() => MyNotifier())` when the notifier constructor takes arguments (e.g. mock data list).
**Why it happens:** Confusing the two overrideWith signatures.
**How to avoid:** For parameterized stubs, use `overrideWith(() => MyNotifier(data))`. For zero-argument stubs, `MyNotifier.new` works. The existing `dev_toolbar_test.dart` uses `_NullCityNotifier.new` — correct for zero-arg.

### Pitfall 4: `GodModeWorldNotifier.isRefreshing` / `lastUpdated` accessed in `GodModeDashboardScreen` build
**What goes wrong:** `GodModeDashboardScreen` calls `ref.read(godmodeWorldProvider.notifier)` then accesses `notifier.isRefreshing` and `notifier.lastUpdated`. In tests, the stub notifier may not have these getters if it's a plain `AsyncNotifier` subclass.
**How to avoid:** The stub notifier for `godmodeWorldProvider` must declare `bool get isRefreshing => false;` and `DateTime get lastUpdated => DateTime(2026, 3, 18);` to satisfy the `GodModeWorldNotifier` interface.

### Pitfall 5: `ProviderScope` not wrapping `Scaffold` for widgets that call `ScaffoldMessenger`
**What goes wrong:** `PlayerRow._togglePause()` calls `ScaffoldMessenger.of(context).showSnackBar(...)`. Even though we do not test tap handlers, if `ScaffoldMessenger` is not available, `build()` alone may fail in edge cases.
**How to avoid:** Always wrap test widget in `MaterialApp(home: Scaffold(body: WidgetUnderTest()))` — the `createScaffoldApp` helper in `test/helpers/test_helpers.dart` does this.

### Pitfall 6: `ElapsedTimerText` timer fires during test causing "setState after dispose"
**What goes wrong:** `ElapsedTimerText` starts a `Timer.periodic` in `initState`. If the test disposes the widget tree before all timers are cancelled, Flutter reports "setState called after dispose".
**How to avoid:** Call `await tester.pumpWidget(Container())` at the end of the test to dispose the widget tree and cancel the timer before the test completes. Or use `addTearDown(() => tester.pumpWidget(Container()))`.

### Pitfall 7: `EventFeed` uses `Expanded` — requires bounded height in tests
**What goes wrong:** `EventFeed` contains an `Expanded` widget inside a `Column`. If the test wraps it in a `Scaffold(body: EventFeed())`, Flutter gives it infinite height and `Expanded` works. But if wrapped in an unbounded container, layout fails.
**How to avoid:** Always wrap in `Scaffold(body: WidgetUnderTest())` or `SizedBox(height: 600, child: WidgetUnderTest())`.

---

## Code Examples

Verified patterns from existing codebase:

### AsyncNotifier Override (from dev_toolbar_test.dart — existing pattern)
```dart
// Source: test/widget/dev_toolbar_test.dart
ProviderScope(
  overrides: [
    cityProvider.overrideWith(_NullCityNotifier.new),
  ],
  child: const MaterialApp(
    home: DevToolbarWrapper(
      child: Scaffold(body: Text('Game')),
    ),
  ),
)

class _NullCityNotifier extends CityNotifier {
  @override
  Future<Map<String, dynamic>?> build() async => null;
}
```

### FutureProvider.overrideWith (from world_map_smoke_test.dart)
```dart
// Source: test/widget/world_map_smoke_test.dart
allIslandsProvider.overrideWith((ref) async => fakeIslands),
```

### Deno test with @std/assert
```typescript
// Deno 2.x pattern — JSR import
import { assertEquals, assertExists } from 'jsr:@std/assert';

Deno.test('calcUpgradeCost level 0', () => {
  const cost = calcUpgradeCost('town_hall', 0);
  assertEquals(cost['gold'], 100);
  assertEquals(cost['wood'], 200);
});
```

### Existing formula in upgrade-building/index.ts (extraction source)
```typescript
// Source: supabase/functions/upgrade-building/index.ts lines 65-78
function calcUpgradeCost(buildingType: string, currentLevel: number): Record<string, number> {
  const baseCost = BASE_COSTS[buildingType];
  const multiplier = Math.pow(COST_GROWTH_FACTOR, currentLevel);
  const result: Record<string, number> = {};
  for (const [resource, amount] of Object.entries(baseCost)) {
    result[resource] = Math.ceil(amount * multiplier);
  }
  return result;
}

function calcUpgradeDurationMinutes(buildingType: string, currentLevel: number): number {
  return Math.ceil(BASE_TIMES[buildingType] * Math.pow(TIME_GROWTH_FACTOR, currentLevel));
}
```

### Training cost in train-units/index.ts (extraction source)
```typescript
// Source: supabase/functions/train-units/index.ts lines 215-230
// Total cost = base_cost * quantity (per resource)
const baseCosts = UNIT_BASE_COSTS[unit_type];
for (const [resourceType, baseAmount] of Object.entries(baseCosts)) {
  const totalAmount = baseAmount * quantity;
  // ...
}
// Duration = base_time * quantity * DEV_SPEED_MULTIPLIER
const durationMinutes = UNIT_BASE_TIMES[unit_type] * quantity * DEV_SPEED_MULTIPLIER;
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `https://deno.land/std@0.x/testing/asserts.ts` | `jsr:@std/assert` | Deno 2.x / JSR launch | Old URL still resolves but JSR is canonical |
| `StateProvider` for simple state | `NotifierProvider` | Riverpod 3.x | `StateProvider` removed — codebase already uses `NotifierProvider` (confirmed in Phase 22) |
| `overrideWith(MyNotifier())` instance | `overrideWith(MyNotifier.new)` or `overrideWith(() => MyNotifier())` | Riverpod 2+ | Constructor ref or factory function |

**Deprecated/outdated:**
- `Deno.env.get` inside extracted pure functions: must not appear in `_shared/formulas.ts`
- `StateProvider`: confirmed removed in this codebase, `NotifierProvider` used

---

## Open Questions

1. **`godmodeRepositoryProvider` in `PlayerRow`/`PlayerTable` tests**
   - What we know: both widgets call `ref.read(godmodeRepositoryProvider)` only inside `onPressed` callbacks (not in `build()`). `godmodeRepositoryProvider` calls `Supabase.instance.client` which throws if Supabase not initialized.
   - What's unclear: Does `ProviderScope` lazily initialize providers? If so, and since tap handlers are not tested, the provider may never be created, and no override is needed.
   - Recommendation: Try without override first. If test fails with Supabase initialization error during pump (not tap), add `godmodeRepositoryProvider.overrideWithValue(FakeGodmodeRepository())`.

2. **`deno.json` test task**
   - What we know: Context says this is Claude's discretion.
   - Recommendation: Add a `supabase/functions/deno.json` with `"tasks": { "test": "deno test tests/" }` so `deno task test` works from the functions directory. Low cost, useful for CI (Phase 24).

---

## Validation Architecture

> `workflow.nyquist_validation` is `true` in `.planning/config.json` — this section is required.

### Test Framework
| Property | Value |
|----------|-------|
| Flutter framework | flutter_test (sdk: flutter) |
| Deno framework | Deno built-in (`Deno.test`) |
| Flutter config file | none — `flutter test` discovers test/ automatically |
| Deno config file | none yet — `deno test supabase/functions/tests/` run directly |
| Flutter quick run | `flutter test test/widget/godmode/` |
| Flutter full suite | `flutter test test/` |
| Deno quick run | `deno test supabase/functions/tests/` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TEST-01 | `calcUpgradeCost` returns correct cost at level 0, 5, 20 | unit (Deno) | `deno test supabase/functions/tests/upgrade_building_test.ts` | ❌ Wave 0 |
| TEST-01 | `calcUpgradeDurationMinutes` grows exponentially | unit (Deno) | `deno test supabase/functions/tests/upgrade_building_test.ts` | ❌ Wave 0 |
| TEST-01 | `calcTrainingCost` returns base_cost × quantity | unit (Deno) | `deno test supabase/functions/tests/train_units_test.ts` | ❌ Wave 0 |
| TEST-01 | `calcTrainingDurationMinutes` with devMode=true (0.2x) | unit (Deno) | `deno test supabase/functions/tests/train_units_test.ts` | ❌ Wave 0 |
| TEST-01 | `calcTrainingDurationMinutes` with devMode=false (1.0x) | unit (Deno) | `deno test supabase/functions/tests/train_units_test.ts` | ❌ Wave 0 |
| TEST-02 | BotBadge renders 'BOT' text | widget (Flutter) | `flutter test test/widget/godmode/bot_badge_test.dart` | ❌ Wave 0 |
| TEST-02 | ElapsedTimerText renders 'Xs ago' text | widget (Flutter) | `flutter test test/widget/godmode/elapsed_timer_text_test.dart` | ❌ Wave 0 |
| TEST-02 | EventTile renders summary + icon per event type | widget (Flutter) | `flutter test test/widget/godmode/event_tile_test.dart` | ❌ Wave 0 |
| TEST-02 | EventFeed: loading/error/data states | widget (Flutter) | `flutter test test/widget/godmode/event_feed_test.dart` | ❌ Wave 0 |
| TEST-02 | PlayerRow normal mode renders player name + stats | widget (Flutter) | `flutter test test/widget/godmode/player_row_test.dart` | ❌ Wave 0 |
| TEST-02 | PlayerTable renders header + player rows | widget (Flutter) | `flutter test test/widget/godmode/player_table_test.dart` | ❌ Wave 0 |
| TEST-02 | GodModeDashboardScreen: loading/error/data states | widget (Flutter) | `flutter test test/widget/godmode/godmode_dashboard_screen_test.dart` | ❌ Wave 0 |
| TEST-02 | GodModePlaceholderScreen renders text | widget (Flutter) | `flutter test test/widget/godmode/godmode_placeholder_screen_test.dart` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit (Deno):** `deno test supabase/functions/tests/`
- **Per task commit (Flutter):** `flutter test test/widget/godmode/`
- **Per wave merge:** `flutter test test/` (full Flutter suite)
- **Phase gate:** Both `deno test` and `flutter test test/` pass with zero failures before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `supabase/functions/_shared/formulas.ts` — shared pure functions (prerequisite for Deno tests)
- [ ] `supabase/functions/tests/upgrade_building_test.ts` — covers TEST-01 upgrade formulas
- [ ] `supabase/functions/tests/train_units_test.ts` — covers TEST-01 training formulas
- [ ] `test/widget/godmode/godmode_test_helpers.dart` — shared mock fixtures (prerequisite for Flutter tests)
- [ ] `test/widget/godmode/bot_badge_test.dart` — covers TEST-02 BotBadge
- [ ] `test/widget/godmode/elapsed_timer_text_test.dart` — covers TEST-02 ElapsedTimerText
- [ ] `test/widget/godmode/event_tile_test.dart` — covers TEST-02 EventTile
- [ ] `test/widget/godmode/event_feed_test.dart` — covers TEST-02 EventFeed
- [ ] `test/widget/godmode/player_row_test.dart` — covers TEST-02 PlayerRow
- [ ] `test/widget/godmode/player_table_test.dart` — covers TEST-02 PlayerTable
- [ ] `test/widget/godmode/godmode_dashboard_screen_test.dart` — covers TEST-02 DashboardScreen
- [ ] `test/widget/godmode/godmode_placeholder_screen_test.dart` — covers TEST-02 PlaceholderScreen

All gaps are new files — no existing files need modification except `upgrade-building/index.ts` and `train-units/index.ts` (import updates).

---

## Sources

### Primary (HIGH confidence)
- Direct code inspection: `supabase/functions/upgrade-building/index.ts` — exact formulas and constants to extract
- Direct code inspection: `supabase/functions/train-units/index.ts` — training formulas and DEV_SPEED_MULTIPLIER pattern
- Direct code inspection: `test/widget/dev_toolbar_test.dart` — canonical ProviderScope override pattern
- Direct code inspection: `test/widget/world_map_smoke_test.dart` — `overrideWith((ref) async => ...)` pattern
- Direct code inspection: `lib/features/godmode/` — all 8 widget files, 2 provider files, 2 model files, repository
- Direct code inspection: `pubspec.yaml` — flutter_riverpod 3.3.1, mocktail 1.0.4 confirmed installed
- `deno --version` output: Deno 2.4.5 confirmed installed

### Secondary (MEDIUM confidence)
- Deno JSR standard library pattern: `jsr:@std/assert` — consistent with Deno 2.x documentation and JSR launch
- STATE.md: "Deno pinned to 2.2.x in CI" — local Deno is 2.4.5; Supabase Edge Runtime constraint applies to CI/production deployment only, not local test execution

### Tertiary (LOW confidence)
- `godmodeRepositoryProvider` lazy initialization behavior in ProviderScope without Supabase.initialize — needs empirical verification in test run

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries confirmed in pubspec.yaml and Deno installed
- Architecture: HIGH — patterns confirmed via direct code inspection of existing tests
- Pitfalls: HIGH — derived from actual code (ElapsedTimerText timer, Expanded layout, env isolation)
- Deno test commands: HIGH — Deno 2.4.5 installed, standard `Deno.test()` API
- Flutter test commands: HIGH — `flutter test` standard

**Research date:** 2026-03-18
**Valid until:** 2026-04-18 (stable stack — Deno and Flutter/Riverpod APIs do not change rapidly)
