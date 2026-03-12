# Phase 7: Test Infrastructure - Research

**Researched:** 2026-03-12
**Domain:** Flutter test tooling, Supabase seed scripting, in-app dev overlay, CLI test automation (bash/PowerShell)
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| TEST-01 | At least 6+ test accounts with varied game states (new player, mid-game, military-ready, active battle, etc.) | Seed SQL via `auth.users` + direct table inserts; existing 3-user seed is the foundation to expand |
| TEST-02 | Dev toolbar accessible in debug mode for instant resource injection, building level-up, unit spawning, battle triggering | Flutter `kDebugMode` + `Overlay`/`Stack` widget pattern; Supabase service-role RPC calls from toolbar |
| TEST-03 | Seed scripts produce a rich, deterministic game world with troops dispatched, battles in progress, construction queues active | Single `supabase/seed.sql` expanded with deterministic UUIDs, direct table inserts bypassing triggers where needed |
| TEST-04 | Single CLI command resets the DB, re-seeds, runs all Flutter unit/widget tests, and reports pass/fail | Shell script wrapping `supabase db reset` + `flutter test --reporter expanded`; PowerShell equivalent for Windows |
</phase_requirements>

---

## Summary

This phase has no external library dependencies — everything needed already exists in the project. The work is entirely about **wiring together existing capabilities** into a coherent testing harness.

The project already has: a 3-user seed (`seed.sql`), 11 unit test files, 2 widget tests, the `supabase db reset` command, and `flutter test`. Phase 7 must expand the seed to 6+ richly-configured accounts, add a Flutter dev toolbar gated by `kDebugMode`, and produce two CLI scripts (bash for Linux/Mac/CI, PowerShell for the Windows 11 dev machine) that orchestrate the full reset-seed-test cycle.

The key architectural constraint is that **RLS blocks direct client writes to game-state tables** (INFR-02/INFR-03 from Phase 6). The dev toolbar cannot write directly — it must call Edge Functions or Supabase RPC functions that run as `SECURITY DEFINER`. The seed script runs with the service-role key (via `supabase db reset`), so it bypasses RLS and can insert directly.

**Primary recommendation:** Expand `seed.sql` for deterministic multi-account state, build a `DevToolbarWidget` gated by `kDebugMode` that calls named RPC helper functions, and produce a `scripts/test_all.sh` + `scripts/test_all.ps1` that runs `supabase db reset && flutter test --reporter expanded`.

---

## Standard Stack

### Core (already in project — no new installs needed)

| Tool/Library | Version | Purpose | Why Standard |
|-------------|---------|---------|--------------|
| `flutter_test` | SDK | Widget and unit tests | Already in pubspec, all existing tests use it |
| `mocktail` | ^1.0.4 | Mock generation | Already in dev_dependencies, used in mocks.dart |
| `supabase db reset` | Supabase CLI | DB wipe + re-seed | Runs all migrations then seed.sql deterministically |
| `flutter test` | Flutter SDK | Test runner | Built-in, produces TAP/expanded output |
| `kDebugMode` | Flutter | Gates debug-only UI | compile-time constant, tree-shaken in release |

### No New Packages Required

The phase goal is infrastructure wiring, not new library adoption. All building blocks exist:
- `flutter_riverpod` for state — already present
- `supabase_flutter` for RPC calls — already present
- `mocktail` for mocks — already present
- Shell scripting for CLI — no package needed

---

## Architecture Patterns

### Recommended Project Structure (additions only)

```
lib/
├── core/
│   └── dev/
│       ├── dev_toolbar.dart          # DevToolbarWidget (kDebugMode gate)
│       ├── dev_toolbar_notifier.dart # Riverpod notifier for toolbar state
│       └── dev_rpc_service.dart      # Service-role RPC calls for toolbar actions
scripts/
├── run_local.sh          # existing
├── run_local.ps1         # existing
├── test_all.sh           # NEW: reset + seed + flutter test (bash)
└── test_all.ps1          # NEW: reset + seed + flutter test (PowerShell)
supabase/
├── seed.sql              # EXPANDED: 6+ accounts, rich game states
└── migrations/
    └── 20260312000008_dev_rpc_helpers.sql  # NEW: service-role RPC helpers for toolbar
```

### Pattern 1: Seed SQL with Deterministic UUIDs

**What:** Expand `seed.sql` to insert 6 test accounts with explicit, fixed UUIDs so that cross-table references (city_id, owner_id) are predictable and readable.

**When to use:** Any time a feature needs a pre-configured scenario (e.g., "player already has Barracks level 3 and 50 Hoplites") without manual setup.

**Example:**
```sql
-- seed.sql additions
-- Account 4: Mid-game player with Barracks level 3, 50 hoplites in army
INSERT INTO auth.users (..., id = 'a4444444-4444-4444-4444-444444444444', email = 'midgame@test.local', ...)
-- trigger auto-creates profile + city
UPDATE public.profiles SET display_name = 'Themistocles' WHERE id = 'a4444444-...';
UPDATE public.city_buildings
  SET level = 3
  WHERE city_id = (SELECT id FROM cities WHERE owner_id = 'a4444444-...')
    AND building_type = 'barracks';
INSERT INTO public.city_units (city_id, unit_type, quantity)
  VALUES ((SELECT id FROM cities WHERE owner_id = 'a4444444-...'), 'hoplite', 50);
```

**Key insight:** The `handle_new_user` trigger fires on `auth.users` INSERT and auto-creates profile + city. The seed can then UPDATE those rows to set the desired state without re-implementing the trigger logic.

### Pattern 2: Dev Toolbar as an Overlay

**What:** A floating action button or panel visible only when `kDebugMode == true`, rendered as an `Overlay` or `Stack` in the app shell, that exposes buttons for instant game-state manipulation.

**When to use:** During local development to skip the normal game flow (e.g., instantly grant 10,000 wood rather than waiting 5 minutes for resource tick).

**Example:**
```dart
// lib/core/dev/dev_toolbar.dart
import 'package:flutter/foundation.dart';  // kDebugMode
import 'package:flutter/material.dart';

class DevToolbarWrapper extends StatelessWidget {
  const DevToolbarWrapper({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return child;  // tree-shaken in release
    return Stack(
      children: [
        child,
        const Positioned(
          bottom: 80,
          right: 16,
          child: _DevToolbarFab(),
        ),
      ],
    );
  }
}
```

**Anti-pattern to avoid:** Using `dart:io` Platform checks instead of `kDebugMode`. `kDebugMode` is a compile-time constant that the Dart compiler eliminates entirely in `--release` builds. Platform checks are runtime and can't be tree-shaken.

### Pattern 3: Toolbar Actions via Supabase RPC (SECURITY DEFINER)

**What:** Create `SECURITY DEFINER` SQL functions that the dev toolbar calls via `supabase.rpc()`. These bypass RLS for their specific operations (resource injection, building level-up, unit spawning).

**When to use:** Any toolbar action that writes to game-state tables (all writes are blocked by RLS for the anon/authenticated role).

**Example RPC helper:**
```sql
-- supabase/migrations/20260312000008_dev_rpc_helpers.sql
-- IMPORTANT: These functions must ONLY be callable in a dev context.
-- They are SECURITY DEFINER and bypass RLS — do NOT deploy to production.

CREATE OR REPLACE FUNCTION public.dev_inject_resources(
  p_city_id uuid,
  p_wood    int DEFAULT 5000,
  p_marble  int DEFAULT 5000,
  p_crystal int DEFAULT 5000,
  p_sulfur  int DEFAULT 5000,
  p_gold    int DEFAULT 5000
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  UPDATE public.city_resources
  SET amount = LEAST(amount + p_wood, 99999)
  WHERE city_id = p_city_id AND resource_type = 'wood';
  -- ... repeat for other resources
END;
$$;
```

**Dart call from toolbar:**
```dart
// lib/core/dev/dev_rpc_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class DevRpcService {
  final _client = Supabase.instance.client;

  Future<void> injectResources(String cityId) async {
    await _client.rpc('dev_inject_resources', params: {'p_city_id': cityId});
  }

  Future<void> levelUpBuilding(String cityId, String buildingType) async {
    await _client.rpc('dev_level_up_building',
        params: {'p_city_id': cityId, 'p_building_type': buildingType});
  }
}
```

### Pattern 4: Unified CLI Test Script

**What:** A shell script that wraps `supabase db reset`, then `flutter test --reporter expanded`, and exits with a non-zero code on any failure.

**bash version:**
```bash
#!/usr/bin/env bash
set -euo pipefail
echo "=== Resetting database ==="
npx supabase db reset --local

echo "=== Running Flutter tests ==="
flutter test --reporter expanded

echo "=== All done ==="
```

**PowerShell version (for Windows 11 dev machine):**
```powershell
# scripts/test_all.ps1
$ErrorActionPreference = 'Stop'

Write-Host "=== Resetting database ===" -ForegroundColor Cyan
npx supabase db reset --local
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "=== Running Flutter tests ===" -ForegroundColor Cyan
flutter test --reporter expanded
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "=== All tests passed ===" -ForegroundColor Green
```

**Usage:**
```bash
# bash (WSL or Git Bash)
bash scripts/test_all.sh

# PowerShell (Windows 11 native)
.\scripts\test_all.ps1
```

### Anti-Patterns to Avoid

- **Writing to game-state tables from toolbar without SECURITY DEFINER RPC:** RLS will block it silently or with a permissions error.
- **Using non-deterministic UUIDs in seed.sql:** `gen_random_uuid()` makes cross-table references impossible to write statically. Use hardcoded UUIDs like `'a4444444-4444-4444-4444-444444444444'`.
- **Triggering battles by manipulating `battles` table directly in seed without matching `unit_movements` cleanup:** The `process_arrivals` function expects movement rows to be cleaned up. For seeds, insert directly into `battles` and skip the movement row.
- **Dev toolbar code surviving release build:** Always gate with `kDebugMode` at the widget level, not just at button tap handlers.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| DB reset and re-seed | Custom migration runner | `supabase db reset` | Runs all migrations in order, then seed.sql; idempotent |
| Mock auth sessions in tests | Custom session factory | `mocktail` stubs on `AuthRepository` | Already established pattern in mocks.dart |
| Feature flags for debug UI | Custom flag system | `kDebugMode` compile constant | Tree-shaken by Dart compiler in release; zero runtime cost |
| Test report formatting | Custom reporter | `flutter test --reporter expanded` | Built-in; also supports `--reporter json` for CI |

---

## Common Pitfalls

### Pitfall 1: RLS Blocks Dev Toolbar Writes
**What goes wrong:** Dev toolbar calls `supabase.from('city_resources').update(...)` and gets an empty response or a 0-row update because RLS prevents authenticated users from writing arbitrary values to other users' rows.
**Why it happens:** INFR-03 — RLS is on every table, and the client uses the anon key.
**How to avoid:** All toolbar writes go through `SECURITY DEFINER` RPC functions. The client calls `supabase.rpc('dev_inject_resources', ...)`.
**Warning signs:** `supabase.rpc()` returns null data with no exception — check that the function exists and that the parameter names match exactly.

### Pitfall 2: Seed UUID Collisions on Repeated Reset
**What goes wrong:** `supabase db reset` re-runs `seed.sql` with the same fixed UUIDs. If any INSERT uses `ON CONFLICT DO NOTHING` incorrectly, rows may be silently skipped.
**Why it happens:** `supabase db reset` wipes all data first (via migrations), so the same UUIDs can be re-inserted cleanly. But if seed.sql has `INSERT OR IGNORE` instead of a plain `INSERT`, unexpected behavior can occur.
**How to avoid:** Use plain `INSERT INTO auth.users (...)` without conflict clauses — `db reset` guarantees a clean slate.

### Pitfall 3: handle_new_user Trigger Sets Random Island
**What goes wrong:** The `handle_new_user` trigger places a new user's city on a random island. The seed cannot predict which `city_id` gets created, making subsequent UPDATEs fragile unless they use `WHERE owner_id = '...'`.
**Why it happens:** Trigger uses `random()` or picks a city slot non-deterministically.
**How to avoid:** All seed UPDATEs reference cities by `owner_id`, not by `city_id`. Pattern: `WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'a4444444-...')`.

### Pitfall 4: flutter test Skips Integration Tests
**What goes wrong:** `flutter test` without arguments only runs `test/` — it does not run `integration_test/`.
**Why it happens:** Flutter separates unit/widget tests (`test/`) from integration tests (`integration_test/`), which require a running device/emulator.
**How to avoid:** The CLI script targets `test/` explicitly. Integration tests in `integration_test/` require `flutter test integration_test/` with a running device — this is out of scope for TEST-04, which only specifies unit/widget tests.

### Pitfall 5: Dev Toolbar Visible in Production Web Build
**What goes wrong:** Dev toolbar appears in the `flutter build web --release` output because the gating is done at runtime (`if (Platform.environment.containsKey('DEBUG'))`) rather than at compile time.
**Why it happens:** Runtime checks are not tree-shaken.
**How to avoid:** Use `kDebugMode` from `package:flutter/foundation.dart`. In `--release` mode, Dart's tree-shaker eliminates the entire branch.

### Pitfall 6: Active Battle State Requires Matching battles + unit_movements
**What goes wrong:** Seeding an "active battle" by inserting into `battles` directly while leaving stale rows in `unit_movements` causes `process_arrivals()` to create a duplicate battle or throw a foreign key error.
**Why it happens:** `process_arrivals()` checks for active battles before creating new ones, but it also deletes the movement row. If the row was never created, the cleanup step fails silently.
**How to avoid:** For seed "active battle" state — insert directly into `battles` with `status = 'active'` and `next_turn_at = NOW() + INTERVAL '5 minutes'`. Do NOT create a matching `unit_movements` row. The pg_cron `resolve_battles()` will pick it up naturally.

---

## Code Examples

### Test Account Scenarios (6 accounts)

```sql
-- Account 1 (existing): Leonidas — new player, just signed up
-- a1111111-1111-1111-1111-111111111111 — city auto-placed, no upgrades

-- Account 2 (existing): Xerxes — mid-game
-- a2222222-2222-2222-2222-222222222222

-- Account 3 (existing): Pericles — mid-game
-- a3333333-3333-3333-3333-333333333333

-- Account 4: Themistocles — military-ready (Barracks 3, 50 Hoplites, 10 Archers)
-- a4444444-4444-4444-4444-444444444444

-- Account 5: Alcibiades — active attacker (troops dispatched toward account 6)
-- a5555555-5555-5555-5555-555555555555

-- Account 6: Darius — active defender (battle in progress against account 5)
-- a6666666-6666-6666-6666-666666666666

-- Account 7 (optional stretch): Cleopatra — construction queue active
-- a7777777-7777-7777-7777-777777777777
```

### Widget Integration: Wrapping the App Shell

```dart
// lib/core/router/app_router.dart — wrap shell scaffold body
// Inside the ShellRoute builder:
body: kDebugMode
  ? DevToolbarWrapper(child: child)
  : child,
```

### flutter test Command with Coverage

```bash
# Full test suite, expanded output
flutter test --reporter expanded

# With coverage (optional, slower)
flutter test --coverage --reporter expanded
```

### supabase db reset Command

```bash
# Wipes all data, re-runs migrations in timestamp order, then seed.sql
npx supabase db reset --local
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual account setup before testing | Deterministic seed with 6+ pre-configured accounts | Phase 7 | Test any scenario without manual DB manipulation |
| 3 minimal dummy accounts | 6+ accounts covering all game stages | Phase 7 | Covers new player, mid-game, military, battle scenarios |
| No dev shortcuts in UI | Dev toolbar gated by `kDebugMode` | Phase 7 | Skip 20-minute setup flows; test combat in < 1 minute |
| Run tests manually step by step | Single `test_all.sh` / `test_all.ps1` | Phase 7 | One command resets + tests everything |

---

## Open Questions

1. **Should the dev toolbar call Edge Functions or direct SECURITY DEFINER RPC functions?**
   - What we know: Edge Functions add network latency but are already used for game mutations (upgrade-building, train-units, dispatch-units). SECURITY DEFINER SQL functions are faster and simpler for dev-only tooling.
   - What's unclear: Whether having dev-only SECURITY DEFINER functions in production migrations is acceptable for this project.
   - Recommendation: Use direct SECURITY DEFINER SQL functions in a clearly-named migration (`_dev_rpc_helpers.sql`). They are only reachable by authenticated users and are only dangerous if deployed to production with real user data. The project is local-only for now. Add a clear "dev only — do not deploy to production Supabase" header comment.

2. **Should `test_all.sh` also activate skipped tests?**
   - What we know: All Phase 1-6 Wave 0 tests are marked `skip: '...'` as stubs. They will show as "skipped" not "passed". TEST-04 requires "reports pass/fail status."
   - What's unclear: Whether Wave 7 should implement the skipped test stubs or leave them skipped.
   - Recommendation: Phase 7 Wave 0 plan should decide whether to implement the pending skips or explicitly document them as "intentionally deferred." The CLI script should report the skip count clearly.

3. **Active battle seed: insert into `battles` directly or trigger via `process_arrivals`?**
   - What we know: `process_arrivals()` creates battles when enemy troops arrive. Seeding via `unit_movements` with `arrive_at = NOW()` would work but requires waiting for the cron tick.
   - Recommendation: Insert directly into `battles` with `status = 'active'` and `next_turn_at = NOW() + INTERVAL '30 seconds'`. Simpler, deterministic, no cron dependency.

---

## Validation Architecture

`workflow.nyquist_validation` is `true` in `.planning/config.json` — this section is required.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK built-in) |
| Config file | none — discovered via `test/` directory convention |
| Quick run command | `flutter test test/unit/ --reporter expanded` |
| Full suite command | `flutter test --reporter expanded` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TEST-01 | 6+ seed accounts with varied game states exist after `supabase db reset` | smoke (manual verify via DB query) | `npx supabase db reset --local` then `docker exec supabase_db_ikariam psql -U postgres -c "SELECT COUNT(*) FROM auth.users"` | Wave 0 stub |
| TEST-02 | DevToolbarWrapper renders in debug mode, hidden in release | widget | `flutter test test/widget/dev_toolbar_test.dart` | Wave 0 |
| TEST-03 | Seed produces deterministic game states (building levels, units, active battle) | unit (data integrity assertions) | `flutter test test/unit/seed_scenarios_test.dart` | Wave 0 |
| TEST-04 | test_all.sh exits 0 when all unit/widget tests pass | integration/manual | `bash scripts/test_all.sh` | Wave 0 |

### Sampling Rate

- **Per task commit:** `flutter test test/unit/ --reporter expanded`
- **Per wave merge:** `flutter test --reporter expanded`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `test/widget/dev_toolbar_test.dart` — covers TEST-02 (DevToolbarWrapper renders/hidden)
- [ ] `test/unit/seed_scenarios_test.dart` — covers TEST-03 (data integrity stubs, marked skip until seed is expanded)
- [ ] `scripts/test_all.sh` — covers TEST-04 (the script itself is the artifact)
- [ ] `scripts/test_all.ps1` — covers TEST-04 (PowerShell equivalent for Windows 11)

---

## Sources

### Primary (HIGH confidence)

- Flutter `kDebugMode` — official Flutter foundation library; compile-time constant behavior is well-documented and stable since Flutter 1.0
- `supabase db reset` — verified against existing project usage in `scripts/run_local.sh` and established Phase 1-6 workflow
- `flutter test --reporter expanded` — Flutter SDK built-in; observed in existing test files
- Existing `test/` structure — read directly from the project filesystem (11 unit tests, 2 widget tests confirmed)
- Existing `seed.sql` — read directly; confirms 3-account baseline and `handle_new_user` trigger behavior
- `SECURITY DEFINER` SQL functions — observed in existing migrations (e.g., `resolve_battles()`, `process_arrivals()`)

### Secondary (MEDIUM confidence)

- Dev toolbar overlay pattern (`Stack` + `Positioned`) — standard Flutter overlay approach; no project-specific source, but consistent with Flutter Material app patterns

### Tertiary (LOW confidence)

- None — all findings grounded in project source files

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies; all tools already present in project
- Architecture: HIGH — all patterns derived directly from existing project source files
- Pitfalls: HIGH — RLS/INFR-03 behavior verified from Phase 6 audit; `kDebugMode` tree-shaking is documented Flutter behavior

**Research date:** 2026-03-12
**Valid until:** 2026-06-12 (stable Flutter/Supabase APIs; no fast-moving dependencies in this phase)
