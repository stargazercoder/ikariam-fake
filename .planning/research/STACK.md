# Stack Research

**Domain:** Browser-based multiplayer strategy game — v1.3 Bots, Testing & Automation additions
**Researched:** 2026-03-17
**Confidence:** HIGH (verified via pub.dev, Supabase docs, Riverpod docs, Deno docs, official GitHub)

---

## Context: What This Research Covers

v1.3 adds five capability areas to an existing Flutter + Supabase + Riverpod codebase.
This document covers ONLY what is new or changed for v1.3. The base stack
(Flutter 3.29, Supabase 2.12.0 via supabase_flutter, Riverpod 3.3.1, Flame 1.35.1,
go_router 17.1.0, fl_chart 1.2.0, mocktail 1.0.4) is validated — see previous STACK.md files.

Feature areas and their stack implications:

| Feature Area | New Stack Needed? | Verdict |
|---|---|---|
| AI bot players (pg_cron behaviors) | No new packages | Pure PostgreSQL PL/pgSQL + existing pg_cron infrastructure |
| GodMode admin dashboard | **data_table_2 ^2.7.2** | Sortable, paginated tables for all-players view |
| Rich seed data (20 bot accounts) | No new packages | Extended seed.sql — existing auth.users insert pattern |
| Unit tests: Flutter widgets | No new packages | flutter_test (SDK), mocktail 1.0.4 (already in pubspec), Riverpod 3.3.1 ProviderContainer.test |
| Unit tests: Edge Functions (Deno) | No new packages | Deno built-in test runner + jsr:@std/assert (zero install) |
| Automation scripts (CI/CD) | **GitHub Actions** | .github/workflows/ci.yml — ubuntu-latest, subosito/flutter-action@v2 |

**Summary:** Only one new Dart package is justified for v1.3: `data_table_2`. Every other
feature is implemented with existing stack capabilities or zero-cost built-in tooling.

---

## Recommended Stack

### New Library for v1.3

| Library | Version | Purpose | Why Recommended |
|---------|---------|---------|-----------------|
| data_table_2 | ^2.7.2 | GodMode admin dashboard — sortable, sticky-header paginated tables showing all players, armies, and battles | Drop-in replacement for Flutter's `DataTable` / `PaginatedDataTable` with sticky column headers (critical for wide admin tables), built-in row sorting, `AsyncPaginatedDataTable2` for stream-fed data, and `DataRow2` for row-level tap. MIT license, actively maintained (last update Nov 2025). No Syncfusion license required. |

### Existing Stack — How Each Feature Uses It

| Technology | Version | v1.3 Usage |
|------------|---------|------------|
| PostgreSQL (via Supabase) | 17 | New tables: `bots` (tracks 20 bot accounts + behavior state), `bot_action_log` (audit trail). New columns on `profiles`: `is_bot boolean DEFAULT false`. New PL/pgSQL functions: `run_bot_tick()`, `bot_attack_target()`, `bot_train_units()`, `bot_upgrade_building()`. |
| pg_cron | built-in | New cron job: `SELECT cron.schedule('bot-tick', '*/15 * * * *', 'SELECT run_bot_tick()')` — every 15 minutes. Bot tick runs decision logic (attack/train/upgrade) per bot based on resource thresholds. Existing 5-minute resource tick continues unchanged. |
| Supabase Edge Functions (Deno/TypeScript) | — | New function: `godmode-action` — handles admin-only mutations (pause/resume bot, force action, set resources). Calls existing game mutation functions via service-role client. Bot behaviors are PL/pgSQL (no round-trip latency), not Edge Functions. |
| Supabase Auth | built-in | `is_admin` claim in JWT `app_metadata` gates GodMode. Set via `supabase.auth.admin.updateUserById()` in seed script. RLS policies check `(auth.jwt()->'app_metadata'->>'is_admin')::boolean`. |
| flutter_riverpod | 3.3.1 | New `StreamProvider`s for GodMode: all-players list, all battles, bot status. `ProviderContainer.test()` (new in Riverpod 3.0) for unit test isolation — replaces manual container setup + dispose. |
| go_router | 17.1.0 | New `/admin` route with `redirect` guard: checks `isAdmin` claim on current session, redirects to `/` if false. Existing redirect pattern from auth guard reused. |
| Flutter Material widgets | SDK | GodMode screens use `Scaffold` + `data_table_2` tables. Bot status page uses existing `ListView.builder` pattern. No additional widget packages. |
| Deno test runner | built-in | `Deno.test()` for Edge Function unit tests. Import `assertEquals`, `assertRejects` from `jsr:@std/assert`. Run via `deno test --allow-all supabase/functions/tests/`. Zero install — Deno ships with test runner. |
| flutter_test | SDK | Existing framework for Flutter unit + widget tests. `ProviderContainer.test()` utility (Riverpod 3.3.1) simplifies provider test setup. `tester.container()` extension accesses container in widget tests. |
| mocktail | 1.0.4 | Already in devDependencies. Used for mocking Supabase client in Flutter widget tests. Pattern: `class MockSupabaseClient extends Mock implements SupabaseClient {}`. |
| GitHub Actions | — | `.github/workflows/ci.yml` — ubuntu-latest runner. Steps: `supabase db reset`, `flutter analyze`, `flutter test`, `flutter build web`. Uses `subosito/flutter-action@v2` for Flutter setup. |

---

## Installation

```bash
# Add to existing Flutter project — only new package for v1.3
flutter pub add data_table_2
```

```bash
# Verify no version conflict after add
flutter pub deps | grep data_table_2
# Expected: data_table_2 2.7.x
```

No new Deno dependencies — Deno's built-in test runner and `jsr:@std/assert` require zero installation.

Edge Function test runner invocation (local):
```bash
deno test --allow-all supabase/functions/tests/
```

GitHub Actions CI file is created manually at `.github/workflows/ci.yml` — no npm install needed.

---

## Feature-by-Feature Implementation Stack

### 1. AI Bot Players (pg_cron Periodic Behaviors)

**Stack:** Pure PostgreSQL PL/pgSQL + existing pg_cron. Zero new packages.

**Why PL/pgSQL not Edge Functions for bot logic:**
- Bot behaviors are DB-internal operations (read resources, insert training queue, insert unit_movements)
- PL/pgSQL runs inside the same transaction — no HTTP latency, no retry overhead
- Edge Functions add unnecessary round-trip for operations that don't need external calls
- Existing pg_cron jobs (`resource-tick`, `battle-resolution`) already use this pattern

**Bot decision tree (pseudocode for `run_bot_tick()`):**
```sql
-- For each active bot city:
-- 1. If gold > 500 AND barracks exists AND no active training: train units
-- 2. If wood > 300 AND construction queue empty: upgrade cheapest building
-- 3. If army size > threshold AND nearby enemy city: dispatch attack
-- 4. Respect GodMode pause flag: skip if bots.is_paused = true
```

**Schema additions:**
```sql
ALTER TABLE profiles ADD COLUMN is_bot boolean NOT NULL DEFAULT false;

CREATE TABLE bot_configs (
  profile_id   uuid PRIMARY KEY REFERENCES profiles(id),
  behavior     text NOT NULL DEFAULT 'balanced', -- 'aggressive', 'defensive', 'economic'
  is_paused    boolean NOT NULL DEFAULT false,
  last_tick_at timestamptz
);
```

**Cron job (added in migration):**
```sql
SELECT cron.schedule('bot-tick', '*/15 * * * *', 'SELECT run_bot_tick()');
```

**Local dev note:** pg_cron jobs registered in migrations run automatically in `supabase db reset`. The known issue of scheduling in `seed.sql` (schema not available) is avoided by registering cron jobs in migration files, which is the existing project pattern.

### 2. GodMode Admin Dashboard

**Stack:** `data_table_2 ^2.7.2` + go_router redirect guard + `is_admin` JWT claim. One new Dart package.

**Why data_table_2 over Flutter's built-in DataTable:**
- Built-in `PaginatedDataTable` has no sticky headers — admin tables with 20+ bot rows lose context when scrolling horizontally
- `PaginatedDataTable2` adds sticky headers with zero API change (same `DataColumn`/`DataRow` API)
- `AsyncPaginatedDataTable2` accepts a `AsyncDataTableSource` that refreshes from Supabase Realtime — eliminates manual stream-to-table wiring
- Built-in `DataTable` has no row-level tap events on the row itself (only on individual cells) — `DataRow2` adds `onTap` at row level for drill-down navigation

**Route guard pattern (existing go_router pattern extended):**
```dart
GoRoute(
  path: '/admin',
  redirect: (context, state) {
    final isAdmin = ref.read(currentUserProvider)?.appMetadata['is_admin'] == true;
    return isAdmin ? null : '/';
  },
  builder: (context, state) => const GodModeScreen(),
),
```

**Admin JWT claim (set once in seed script via service role):**
```typescript
// In seed or dev script — service role only
await supabase.auth.admin.updateUserById(adminUserId, {
  appMetadata: { is_admin: true }
});
```

**RLS policy for admin reads:**
```sql
-- Policy allowing admin to read all profiles (bypasses normal user restriction)
CREATE POLICY "admin_read_all_profiles"
ON profiles FOR SELECT
USING ((auth.jwt()->'app_metadata'->>'is_admin')::boolean = true);
```

### 3. Rich Seed Data (20 Bot Accounts)

**Stack:** Extended `seed.sql` + PL/pgSQL DO block. Zero new packages.

**Pattern:** Same as existing 7 test accounts — `INSERT INTO auth.users` triggers `handle_new_user()` which auto-creates profile + city. The 20 bots are inserted in the same seed file, with varied resource levels patched in a second pass.

**Why seed.sql not a separate script:**
- `supabase db reset` runs `seed.sql` automatically — single command resets the entire world including bots
- No separate script invocation needed in CI or local dev
- Existing automation scripts (`scripts/test_all.sh`) already call `supabase db reset --local`

**Bot diversity strategy (in seed DO block):**
```sql
-- After inserting 20 bot auth.users + letting trigger fire:
-- Pass 2: Set varied resource levels so bots have different game states
UPDATE city_resources SET amount =
  CASE (bot_index % 4)
    WHEN 0 THEN 2000   -- wealthy
    WHEN 1 THEN 500    -- poor
    WHEN 2 THEN 1200   -- average
    WHEN 3 THEN 3500   -- very wealthy
  END
WHERE city_id IN (SELECT id FROM cities WHERE owner_id = ANY(bot_ids));
```

### 4. Unit Tests: Flutter Widgets and Providers

**Stack:** `flutter_test` (SDK) + `mocktail 1.0.4` (already in pubspec) + Riverpod 3.3.1's `ProviderContainer.test()`. Zero new packages.

**Riverpod 3.3.1 testing improvements (verified — released Sept 2025):**
- `ProviderContainer.test()` — creates a container that auto-disposes after test ends; replaces manual `addTearDown(container.dispose)` boilerplate
- `WidgetTester.container` extension — accesses the `ProviderContainer` inside widget test tree without manual extraction
- `NotifierProvider.overrideWithBuild` — mock only `Notifier.build`, preserve real mutation logic; useful for GodMode notifiers

**Provider unit test pattern:**
```dart
test('botConfigProvider returns paused state', () async {
  final container = ProviderContainer.test(
    overrides: [
      supabaseClientProvider.overrideWithValue(mockSupabaseClient),
    ],
  );
  // container auto-disposes — no tearDown needed
  final state = await container.read(botConfigProvider.future);
  expect(state.isPaused, false);
});
```

**Widget test pattern with Riverpod 3.3.1:**
```dart
testWidgets('GodMode screen shows player table', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [allPlayersProvider.overrideWith((ref) => mockPlayers)],
      child: const MaterialApp(home: GodModeScreen()),
    ),
  );
  await tester.pumpAndSettle();
  // tester.container is available in Riverpod 3.3.1
  expect(find.byType(PaginatedDataTable2), findsOneWidget);
});
```

### 5. Unit Tests: Supabase Edge Functions (Deno)

**Stack:** Deno built-in test runner + `jsr:@std/assert`. Zero install required.

**Official Supabase recommendation (verified with supabase.com/docs/guides/functions/unit-test):**
- Test files in `supabase/functions/tests/` named `{function-name}-test.ts`
- Import assertions from `jsr:@std/assert` (JSR registry — Deno 2.x standard)
- Use `Deno.test()` with async functions
- Run with `deno test --allow-all supabase/functions/tests/`

**Why not mock the Supabase client in Edge Function tests:**
- Mocking ESM imports in Deno is difficult — modules are immutable once loaded
- Integration-style tests (call the actual function with a local Supabase instance) are more reliable
- Pattern: spin up local Supabase via `supabase start`, invoke function via `supabase.functions.invoke()`, assert on DB state
- Unit-level logic (pure functions like `calcUpgradeCost`, `calcBotDecision`) is extracted to separate modules and tested in isolation without mocking

**Pure function extraction pattern (key decision):**
```typescript
// supabase/functions/_shared/bot_logic.ts — pure, testable
export function decideBotAction(resources: BotResources, config: BotConfig): BotAction {
  if (resources.gold > 500 && config.behavior !== 'defensive') return 'train';
  if (resources.wood > 300) return 'upgrade';
  return 'idle';
}

// Test file — no mocking needed:
import { decideBotAction } from '../_shared/bot_logic.ts';
import { assertEquals } from 'jsr:@std/assert';

Deno.test('bot with high gold and non-defensive config trains units', () => {
  const action = decideBotAction({ gold: 600, wood: 100 }, { behavior: 'balanced' });
  assertEquals(action, 'train');
});
```

### 6. Automation Scripts and CI/CD

**Stack:** GitHub Actions + existing shell scripts. Zero new Dart/npm packages.

**Why GitHub Actions over alternatives:**
- Repo already on GitHub (implied by git history); no additional service account needed
- `subosito/flutter-action@v2` is the canonical Flutter action — maintained by Flutter community, handles SDK caching
- Supabase CLI available via `npx supabase` — no separate installation action needed
- Free tier sufficient for a small community project

**CI pipeline structure (`.github/workflows/ci.yml`):**
```yaml
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.29.0'
          cache: true
      - name: Install Supabase CLI
        run: npm install -g supabase
      - name: Flutter analyze
        run: flutter analyze
      - name: Flutter test
        run: flutter test --reporter expanded
      - name: Flutter build web
        run: flutter build web --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}
```

**Local automation scripts (extend existing `scripts/`):**
- `scripts/reset_and_seed.sh` — `supabase db reset --local` (already done by `test_all.sh`)
- `scripts/run_local.sh` — already exists, unchanged
- `scripts/test_all.sh` — already exists; extend to also run `deno test` for Edge Functions
- `scripts/lint.sh` — new: runs `flutter analyze` + `dart format --output=none --set-exit-if-changed .`

**Supabase CLI version:** 2.79.0 (latest as of 2026-03-17, published daily). No version pin needed for CI — `npm install -g supabase` gets latest, which is backward-compatible with existing migrations.

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Edge Functions for bot AI tick | HTTP round-trip per bot per tick adds latency and cold-start overhead; bot logic only needs DB access | PL/pgSQL function called by pg_cron — zero network latency, runs inside DB transaction |
| Separate bot server / Node.js process | Adds infrastructure outside Supabase; violates project constraint "Supabase only" | pg_cron-scheduled PL/pgSQL — same infrastructure already running |
| `syncfusion_flutter_datagrid` | Requires Syncfusion license agreement even for community tier; heavy dependency | `data_table_2 ^2.7.2` (MIT, no license agreement) |
| `advanced_datatable` pub.dev package | Lower adoption (vs data_table_2), no async source support out of box | `data_table_2 ^2.7.2` with `AsyncPaginatedDataTable2` |
| Jest / Vitest for Edge Function tests | Node.js test runners don't run in Deno's runtime; incompatible with JSR imports | Deno built-in test runner + `jsr:@std/assert` |
| Mocking Supabase client in Deno tests | ESM module mocking in Deno is unsupported without transpilation tricks; test becomes fragile | Extract pure functions to `_shared/` modules, test them in isolation; integration-test via `supabase.functions.invoke()` |
| `riverpod_generator` / build_runner for new providers | Still blocked: Dart 3.10.1's analyzer version conflicts with riverpod_generator ^4.0.x (see PROJECT.md Key Decisions) | Manual provider definitions matching existing project pattern |
| `flutter_driver` integration tests for GodMode | Heavy setup, slow, requires running emulator; overkill for admin screens | Widget tests with `ProviderScope` overrides — covers same screen behavior at 10x speed |
| CircleCI / Bitrise / Codemagic | Adds new service accounts and billing; GitHub Actions is already available and free | GitHub Actions with `subosito/flutter-action@v2` |
| `faker` or `factory_bot` style package for seed data | No mature Dart seed/faker packages on pub.dev; adds dependency for a one-file SQL script | PL/pgSQL DO block with hardcoded diverse values — simpler, no dependency, visible in migrations |

---

## Alternatives Considered

| Recommended | Alternative | Why Not |
|-------------|-------------|---------|
| `data_table_2 ^2.7.2` | Flutter built-in `PaginatedDataTable` | No sticky headers, no row-level tap, no async source. Admin tables with 20+ columns need sticky headers or they're unusable. |
| `data_table_2 ^2.7.2` | Custom `ListView.builder` table | Would require implementing sort, pagination, sticky header from scratch — 300+ lines. data_table_2 provides all of that in 50 lines. |
| pg_cron PL/pgSQL for bot tick | Supabase Edge Function scheduled via pg_cron + pg_net | pg_net HTTP invoke adds cold-start latency (50-200ms per function). For a game tick that needs to process 20 bots, PL/pgSQL is 10-100x faster. Reserve Edge Functions for operations needing TypeScript expressiveness or external HTTP calls. |
| `jsr:@std/assert` (Deno built-in) | `@supabase/functions-js` test helpers | Functions-js is designed for invoking deployed functions, not unit testing internal logic. @std/assert is the correct tool for pure function unit tests. |
| GitHub Actions | Local-only `scripts/test_all.sh` | test_all.sh exists and is valuable for local dev, but gives no automated gate on PRs/commits. GitHub Actions adds CI without replacing local scripts. |
| `is_admin` in JWT `app_metadata` | Separate `admin_users` table | JWT claim check in RLS policies requires no extra DB query per request — `auth.jwt()->'app_metadata'` is evaluated in memory. A separate table would require a subquery in every RLS policy. |

---

## Version Compatibility

| Package | Version | Compatible With | Notes |
|---------|---------|-----------------|-------|
| data_table_2 | ^2.7.2 | Flutter 3.x (our env: 3.29 — compatible) | Only dependency is `async ^2.10.0` + `flutter`. No conflict with existing packages confirmed. |
| data_table_2 | ^2.7.2 | flutter_riverpod 3.3.1 | No conflict — data_table_2 has no state management dependency. Use with StreamProvider for real-time tables. |
| data_table_2 | ^2.7.2 | fl_chart 1.2.0 | No conflict — both are pure UI packages. |
| flutter_riverpod | 3.3.1 | ProviderContainer.test() | Available in Riverpod 3.0+ (released Sept 2025). Already at 3.3.1 in pubspec — no upgrade needed. |
| mocktail | 1.0.4 | flutter_riverpod 3.3.1 | Compatible — already in pubspec.yaml devDependencies, used in existing tests. |
| Deno (for Edge Function tests) | 2.0–2.2.x | Supabase Edge Runtime | Supabase currently supports Deno lock file v4 only (Deno 2.0–2.2.x). Deno 2.3+ introduced lock file v5 which Supabase does not yet support as of 2026-03-17. Pin Deno to 2.2.x in CI if running `deno test` in GitHub Actions. |
| subosito/flutter-action | v2 | GitHub Actions ubuntu-latest | Current canonical Flutter action. `cache: true` reduces CI time significantly. |

Run after adding data_table_2:
```bash
flutter pub deps
# Confirm no version conflicts in dependency tree
flutter analyze
# Confirm no breaking changes
```

---

## New Database Objects Summary

| Object | Type | Purpose |
|--------|------|---------|
| `profiles.is_bot` | column (boolean) | Marks account as AI bot — used in GodMode filter and bot tick targeting |
| `bot_configs` | table | Per-bot behavior config: behavior type, pause state, last_tick_at |
| `run_bot_tick()` | PL/pgSQL function | Core bot AI loop — called by pg_cron every 15 minutes |
| `bot_attack_target(bot_city_id)` | PL/pgSQL function | Finds nearest human city and dispatches attack if army threshold met |
| `bot_train_units(bot_city_id)` | PL/pgSQL function | Trains most cost-efficient unit if resources sufficient |
| `bot_upgrade_building(bot_city_id)` | PL/pgSQL function | Upgrades cheapest available building if queue empty |
| `bot-tick` | pg_cron job | `cron.schedule('bot-tick', '*/15 * * * *', 'SELECT run_bot_tick()')` |
| `godmode-action` | Edge Function | Admin-only mutations: pause/resume bots, force resource values, trigger actions |
| `_shared/bot_logic.ts` | Deno module | Pure TypeScript functions extracted for unit testability |
| `supabase/functions/tests/` | directory | Deno test files for Edge Functions |
| `.github/workflows/ci.yml` | GitHub Actions | CI pipeline: analyze + test + build |
| `scripts/lint.sh` | shell script | `flutter analyze` + `dart format` check |

---

## Sources

- [pub.dev/packages/data_table_2](https://pub.dev/packages/data_table_2) — Version 2.7.2, last updated Nov 2025, MIT license — HIGH confidence
- [supabase.com/docs/guides/functions/unit-test](https://supabase.com/docs/guides/functions/unit-test) — Official Deno test runner pattern for Edge Functions, `supabase/functions/tests/` directory convention — HIGH confidence
- [docs.deno.com/runtime/reference/std/assert/](https://docs.deno.com/runtime/reference/std/assert/) — `jsr:@std/assert` is current Deno 2.x standard for assertions — HIGH confidence
- [riverpod.dev/docs/whats_new](https://riverpod.dev/docs/whats_new) — `ProviderContainer.test()` and `WidgetTester.container` confirmed in Riverpod 3.0 (Sept 2025) — HIGH confidence
- [pub.dev/packages/flutter_riverpod/versions](https://pub.dev/packages/flutter_riverpod/versions) — Latest stable: 3.3.1, requires Dart SDK 3.7 — HIGH confidence
- [pub.dev/packages/mocktail](https://pub.dev/packages/mocktail) — Latest stable: 1.0.4, published by felangel.dev — HIGH confidence
- [supabase.com/docs/guides/database/extensions/pg_cron](https://supabase.com/docs/guides/database/extensions/pg_cron) — `cron.schedule()` syntax, pg_cron in migrations pattern — HIGH confidence
- [github.com/orgs/supabase/discussions/39966](https://github.com/orgs/supabase/discussions/39966) — Deno lock file v5 not yet supported by Supabase Edge Runtime; pin Deno 2.0–2.2.x in CI — MEDIUM confidence (GitHub Discussion, not official docs)
- [github.com/orgs/supabase/issues/28966](https://github.com/orgs/supabase/issues/28966) — Known issue: `cron.schedule()` fails in seed.sql; use migrations instead — HIGH confidence
- [npmjs.com/package/supabase](https://www.npmjs.com/package/supabase) — Supabase CLI latest: 2.79.0 as of 2026-03-17 — HIGH confidence
- [github.com/subosito/flutter-action](https://github.com/subosito/flutter-action) — `subosito/flutter-action@v2` canonical GitHub Action for Flutter; `cache: true` supported — HIGH confidence
- [medium.com/implementing-role-based-access-control-in-flutter-ui-with-gorouter](https://medium.com/@m.goudjal.y/implementing-role-based-access-control-in-flutter-ui-with-gorouter-df4551c4930f) — go_router redirect guard for admin routes — MEDIUM confidence (community article, pattern verified against go_router docs)

---

*Stack research for: Ikariam clone v1.3 — Bots, Testing & Automation (AI bot players, GodMode dashboard, seed data, unit tests, CI/CD)*
*Researched: 2026-03-17*
