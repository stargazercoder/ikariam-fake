# Phase 8: Bug Fixes & Timer Guards — Research

**Researched:** 2026-03-12
**Domain:** Dart/Flutter bug fixes, TypeScript Edge Function constants, PostgreSQL environment-gated migrations, turn-based combat engagement fractions
**Confidence:** HIGH

---

## Summary

Phase 8 closes four concrete bugs identified during the v1.0 milestone audit. Each bug is fully diagnosable from the existing codebase — no external library research is required. The fixes are surgical and file-count is small.

**Bug 1 — dispatch-units undefined constant (MIL-05):** The Edge Function `supabase/functions/dispatch-units/index.ts` calls `calcTravelMinutes(originIsland, destIsland)` which references `baseMinutesPerUnit = BASE_MINUTES_PER_GRID_UNIT` as a default parameter, but `BASE_MINUTES_PER_GRID_UNIT` is never declared in that file. Only `BASE_SECONDS_PER_GRID_UNIT = 10` is declared. At runtime in Deno this resolves to `undefined`, making `distance * undefined = NaN`, and `Math.ceil(NaN) = NaN`, so `arrive_at` becomes `NaN` and `process_arrivals()` never picks up the row (NaN is not <= NOW()).

**Bug 2 — speed-up migration runs unconditionally (CMBT-01, RSRC-02):** Migration `20260312000007_speed_up_all_timers.sql` reschedules pg_cron jobs to 1-minute/10-second cadence and rewrites `resolve_battles()` / `process_arrivals()` with dev-speed timers. This migration runs in every environment including production, violating CMBT-01 (5-minute battle turns in production) and RSRC-02 (5-minute resource ticks in production). The fix is an environment guard: check `current_setting('app.environment', true)` at the top of the migration and skip the timer changes when the value is `'production'`.

**Bug 3 — partial army engagement per turn (CMBT-02):** CMBT-02 requires "each turn a portion of armies engage (e.g., 30%), with survivors carrying to next turn." The current `resolve_battles()` function engages ALL units every turn — loss_ratio is computed from the full army attack/defense totals and applied to the full unit counts. No sub-sampling step exists. The fix adds an engagement fraction (e.g., 30%) applied before computing attack/defense totals, so only `floor(qty * engagement_fraction)` units participate each turn while the rest survive and carry forward.

**Bug 4 — dev toolbar Trigger Battle dispose error (Flutter):** In `lib/core/dev/dev_toolbar.dart`, the `_triggerBattle()` method calls `controller.dispose()` on line 250, then reads `controller.text` on line 251. After `dispose()`, accessing `.text` throws a `FlutterError: A TextEditingController was used after being disposed`. The fix is to capture the text before disposing: `final defenderCityId = controller.text.trim(); controller.dispose();`.

**Primary recommendation:** Fix all four bugs in a single phase with four plans: (1) dispatch-units constant fix + test, (2) environment guard migration + test, (3) partial engagement in resolve_battles + test, (4) dev toolbar dispose ordering fix + widget test.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| MIL-05 | Troops can be dispatched to other cities with travel time based on distance | Bug 1 fix: declare `BASE_MINUTES_PER_GRID_UNIT = 2` in dispatch-units Edge Function; unit test verifies `arrive_at` is a valid ISO timestamp |
| CMBT-01 | Battles resolve in turns, each turn lasting 5 minutes | Bug 2 fix: environment guard in speed-up migration ensures production uses 5-minute turns; the base `resolve_battles()` in migration 20260312000004 uses `INTERVAL '5 minutes'` |
| CMBT-02 | Each turn a portion of armies engage, survivors carry to next turn | Bug 3 fix: add engagement fraction constant and sub-sampling step to `resolve_battles()`; unit test verifies fraction logic |
</phase_requirements>

---

## Standard Stack

### Core (no new dependencies — all fixes are in-place)

| Layer | File(s) | Change Type |
|-------|---------|-------------|
| TypeScript (Deno) | `supabase/functions/dispatch-units/index.ts` | Add missing constant |
| SQL migration | New migration file | Environment guard wrapping speed-up changes |
| SQL function | `resolve_battles()` in new migration | Add engagement fraction |
| Dart | `lib/core/dev/dev_toolbar.dart` | Swap 2 lines (dispose after read) |

### No New Packages Required

All fixes use existing project tools: Supabase Edge Functions (Deno), PostgreSQL plpgsql, Flutter/Dart. No pubspec changes needed.

---

## Architecture Patterns

### Pattern 1: Declare Missing Constant in Edge Function

The `dispatch-units` function already declares `BASE_SECONDS_PER_GRID_UNIT = 10` for internal use, but `calcTravelMinutes` uses a different constant name `BASE_MINUTES_PER_GRID_UNIT` which is never defined. The Dart side uses `baseMinutesPerGridUnit = 2` (from `unit_constants.dart` line 176).

**Fix:**
```typescript
// Add alongside BASE_SECONDS_PER_GRID_UNIT
const BASE_MINUTES_PER_GRID_UNIT = 2;
```

The `calcTravelMinutes` function signature already passes this as the default: `baseMinutesPerUnit = BASE_MINUTES_PER_GRID_UNIT`. Once declared, all calls pick it up automatically. The sync comment on line 27 documents the Dart counterpart.

### Pattern 2: Environment Guard in SQL Migration

Supabase local dev uses `app.environment = 'development'` (set in `config.toml` or via seed). Production instances leave this unset or set to `'production'`.

**Pattern for guard:**
```sql
DO $$
BEGIN
  -- Only apply speed-up timers in non-production environments
  IF current_setting('app.environment', true) IS DISTINCT FROM 'production' THEN
    -- all speed-up changes go here
    PERFORM cron.unschedule('resource-tick');
    PERFORM cron.schedule('resource-tick', '* * * * *', 'SELECT public.process_resource_tick()');
    -- ... resolve_battles and process_arrivals rewrites ...
  END IF;
END;
$$;
```

The `true` argument to `current_setting` suppresses the error when the setting is absent (returns NULL instead of raising). `IS DISTINCT FROM 'production'` treats NULL as non-production (dev-safe default).

**Alternative approach — separate dev migration file:** Instead of guarding inline, create a new migration that explicitly reverts the speed-up changes when `app.environment = 'production'`. This is cleaner because the speed-up migration already ran on all environments; a guard-migration can undo it on production. This is the preferred approach because migrations are append-only — you cannot retroactively guard an already-applied migration.

### Pattern 3: Engagement Fraction in resolve_battles()

CMBT-02 requires sub-army engagement. The standard Ikariam-style pattern is to apply a fraction to each unit type's quantity before summing attack/defense totals.

**Algorithm:**
1. Define `v_engagement_fraction CONSTANT numeric := 0.30;`
2. For each unit type when computing attack/defense totals, use `FLOOR(v_att_qty * v_engagement_fraction)` as the effective quantity for damage calculation.
3. For casualty application, apply losses only to the engaged fraction — survivors = full army minus casualties on engaged portion.
4. Update `battles.attacker_units` / `battles.defender_units` with surviving totals (full army minus casualties).

**Key constraint:** The engagement fraction applies to damage calculation only. The full army still "exists" between turns — only dead units are removed from the JSONB snapshot. This is what CMBT-02 means by "survivors carry to next turn."

**SQL sketch:**
```sql
-- When summing attack totals for the naval phase:
v_att_qty := COALESCE((v_att_units ->> v_unit_type)::numeric, 0);
v_att_engaged := FLOOR(v_att_qty * v_engagement_fraction);
IF v_att_engaged > 0 THEN
  v_att_naval_attack  := v_att_naval_attack  + v_att_engaged * COALESCE((v_unit_attack  ->> v_unit_type)::numeric, 0);
  v_att_naval_defense := v_att_naval_defense + v_att_engaged * COALESCE((v_unit_defense ->> v_unit_type)::numeric, 0);
END IF;
```

Casualties are then computed against the engaged subset but removed from the full unit count.

### Pattern 4: TextEditingController Dispose Ordering (Flutter)

The standard Flutter lifecycle rule: read `.text` before calling `.dispose()`. After dispose, the controller's internal `_value` is nulled and any access throws.

**Current (buggy) ordering in `_triggerBattle()`:**
```dart
controller.dispose();                                    // line 250 — WRONG ORDER
if (confirmed != true || controller.text.trim().isEmpty) return;  // line 251 — reads disposed controller
```

**Fixed ordering:**
```dart
final defenderCityId = controller.text.trim();  // capture BEFORE dispose
controller.dispose();
if (confirmed != true || defenderCityId.isEmpty) return;
// use defenderCityId below instead of controller.text
```

### Recommended Project Structure (no changes)

```
supabase/
├── functions/dispatch-units/index.ts   # Bug 1: add constant
├── migrations/
│   └── 202603XXXXXX_fix_timers_prod_guard.sql   # Bug 2: env guard
│   └── 202603XXXXXX_partial_engagement.sql       # Bug 3: engagement fraction
lib/
└── core/dev/dev_toolbar.dart           # Bug 4: dispose ordering
test/
├── unit/dispatch_travel_test.dart      # Bug 1 test
├── unit/combat_engagement_test.dart    # Bug 3 test (partial engagement formula)
└── widget/dev_toolbar_trigger_test.dart # Bug 4 test (no crash after dialog close)
```

### Anti-Patterns to Avoid

- **Re-using migration 20260312000007 by editing it in place:** Migrations are immutable once applied. Always create a new migration file with a later timestamp.
- **Guarding only the cron reschedules but not the function rewrites:** Both the cron schedule AND the `resolve_battles()` / `process_arrivals()` bodies were changed in the speed-up migration. The production guard must cover the function rewrites too.
- **Applying engagement fraction to casualty clamping incorrectly:** The `LEAST(loss, qty)` clamp must use the full unit quantity (`v_att_qty`), not the engaged subset, since you cannot lose more than you have in total.
- **Setting engagement_fraction as a session variable instead of a constant:** Use a `CONSTANT` plpgsql variable to avoid any injection risk and to make the value visible in the function body.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Environment detection in SQL | Custom schema or config table | `current_setting('app.environment', true)` | Built-in Postgres; Supabase sets this in config.toml |
| Engagement randomization | RNG per unit per turn | Fixed fraction constant | Predictable, testable, matches Ikariam design; RNG adds non-determinism to tests |
| TextEditingController lifecycle | Custom wrapper | Standard Flutter dispose ordering | Framework pattern; no abstraction needed |

---

## Common Pitfalls

### Pitfall 1: NaN propagates silently in TypeScript/JavaScript

**What goes wrong:** `undefined * number = NaN`, `Math.ceil(NaN) = NaN`, `new Date(NaN).toISOString()` returns `"Invalid Date"`. The Edge Function returns `{ arrive_at: "Invalid Date" }` with HTTP 200, so the caller sees success. The `unit_movements` row is inserted with a NULL or garbage `arrive_at`, and `process_arrivals()` never picks it up.

**Why it happens:** JavaScript does not throw on arithmetic with `undefined` — it silently produces `NaN`.

**How to avoid:** After the `calcTravelMinutes` call, assert the result is a finite number: `if (!Number.isFinite(travelMinutes)) throw new Error(...)`. This turns a silent data corruption into a visible 500 error.

**Warning signs:** `unit_movements` rows accumulate without being deleted by `process_arrivals()`; `arrive_at` column shows NULL or `Invalid Date`.

### Pitfall 2: Migration guards that only wrap cron — not function bodies

**What goes wrong:** The production guard wraps `cron.unschedule` / `cron.schedule` calls but the `CREATE OR REPLACE FUNCTION resolve_battles()` body with 10-second intervals is unconditional. Production gets corrected cron schedules but still runs the fast-mode function.

**How to avoid:** The entire `CREATE OR REPLACE FUNCTION` statement must be inside the `IF NOT production THEN` block (or the revert migration must replace the function with the 5-minute version unconditionally in production).

### Pitfall 3: Engagement fraction applied to both attack calculation AND loss application double-counts

**What goes wrong:** If you multiply the loss_ratio by `engaged_qty` for the casualty count, and then subtract from `total_qty`, the math is consistent. But if you accidentally use `total_qty` in the loss_ratio denominator while using `engaged_qty` for the casualty count, the fraction effect is applied twice.

**How to avoid:** Use engaged_qty consistently: engaged attack/defense → loss_ratio computed from engaged totals → casualties applied to engaged subset → subtract casualties from full qty.

### Pitfall 4: TextEditingController disposed inside showDialog callback before dialog closes

**What goes wrong:** Flutter's `showDialog` returns a Future. The dialog builder captures the controller. If you call `controller.dispose()` before the Future resolves (e.g., in a premature cleanup path), the dialog's `TextField` references a disposed controller and throws on the next rebuild.

**How to avoid:** Only dispose after `await showDialog<bool>(...)` returns. This is already the pattern in `_triggerBattle()` — the bug is just the order of the two statements after the await.

---

## Code Examples

Verified from codebase inspection:

### Bug 1 — Correct constant declaration in dispatch-units/index.ts

```typescript
// Source: lib/core/constants/unit_constants.dart line 176 (sync source of truth)
// Declared alongside BASE_SECONDS_PER_GRID_UNIT at top of file:
const BASE_MINUTES_PER_GRID_UNIT = 2;
const BASE_SECONDS_PER_GRID_UNIT = 10; // existing — keep for documentation

// calcTravelMinutes already uses BASE_MINUTES_PER_GRID_UNIT as default — no other changes needed
```

### Bug 2 — Environment guard migration pattern

```sql
-- New migration: 202603XXXXXX_revert_timers_for_production.sql
DO $$
BEGIN
  IF current_setting('app.environment', true) = 'production' THEN
    -- Restore 5-minute resource tick
    PERFORM cron.unschedule('resource-tick');
    PERFORM cron.schedule(
      'resource-tick',
      '*/5 * * * *',
      'SELECT public.process_resource_tick()'
    );

    -- Restore 5-minute battle turns in resolve_battles()
    -- (full CREATE OR REPLACE FUNCTION body with INTERVAL '5 minutes' instead of '10 seconds')
    -- ...
  END IF;
END;
$$;
```

### Bug 3 — Engagement fraction in resolve_battles()

```sql
-- In DECLARE block:
v_engagement_fraction CONSTANT numeric := 0.30;
v_att_engaged         numeric;
v_def_engaged         numeric;

-- In naval phase attack/defense summation loop:
v_att_qty := COALESCE((v_att_units ->> v_unit_type)::numeric, 0);
v_att_engaged := FLOOR(v_att_qty * v_engagement_fraction);
IF v_att_engaged > 0 THEN
  v_att_naval_attack  := v_att_naval_attack  + v_att_engaged * COALESCE((v_unit_attack  ->> v_unit_type)::numeric, 0);
  v_att_naval_defense := v_att_naval_defense + v_att_engaged * COALESCE((v_unit_defense ->> v_unit_type)::numeric, 0);
END IF;
```

### Bug 4 — Correct dispose ordering in _triggerBattle()

```dart
// Source: lib/core/dev/dev_toolbar.dart — _triggerBattle() method
// BEFORE (buggy):
//   controller.dispose();
//   if (confirmed != true || controller.text.trim().isEmpty) return;

// AFTER (fixed):
final defenderCityId = controller.text.trim();
controller.dispose();
if (confirmed != true || defenderCityId.isEmpty) return;
try {
  final battleId = await _devRpc.triggerBattle(cityId, defenderCityId);
  _showSnack('Battle started: $battleId');
} catch (_) {
  _showSnack('Failed to trigger battle');
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Full-army-per-turn combat | Fraction-based engagement | Phase 8 (now) | Battles last multiple meaningful turns; CMBT-02 satisfied |
| Dev-speed timers unconditional | Environment-gated speed-up | Phase 8 (now) | Production uses correct 5-minute intervals |
| Missing constant (NaN arrive_at) | Constant declared | Phase 8 (now) | MIL-05 dispatch actually works end-to-end |
| Dispose before read | Read before dispose | Phase 8 (now) | Dev toolbar Trigger Battle no longer crashes |

---

## Open Questions

1. **Engagement fraction value: 30% vs configurable**
   - What we know: Phase description says "e.g., 30%"
   - What's unclear: Should it be hardcoded or a DB setting?
   - Recommendation: Hardcode as a `CONSTANT` in the function body for v1. Same pattern as unit stats (JSONB constants inside function body per Phase 5 decision). A DB config table is v2 scope.

2. **Production environment guard: new migration vs conditionally-applied patch**
   - What we know: Migration 20260312000007 already applied speed-up to all envs including prod
   - What's unclear: Is production already running with 10-second turns?
   - Recommendation: Create a new migration that reverts timers when `app.environment = 'production'`. This is safe even if production was never hit (guard is a no-op on dev).

3. **dispatch-units: should a NaN guard be added in addition to the constant fix?**
   - What we know: Declaring the constant is sufficient to fix the root cause
   - What's unclear: Whether defensive runtime checks add value
   - Recommendation: Add a `Number.isFinite(travelMinutes)` assert after the call. Low cost, catches future regressions. Return a 500 instead of silently inserting bad data.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (bundled with Flutter SDK) |
| Config file | none — standard `flutter test` discovery |
| Quick run command | `flutter test test/unit/dispatch_travel_test.dart test/unit/combat_engagement_test.dart test/widget/dev_toolbar_trigger_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MIL-05 | `calcTravelMinutes` returns finite positive integer; `BASE_MINUTES_PER_GRID_UNIT` is 2 | unit | `flutter test test/unit/dispatch_travel_test.dart -x` | Wave 0 |
| MIL-05 | dispatch-units function does not produce NaN arrive_at | unit (formula test) | `flutter test test/unit/dispatch_travel_test.dart -x` | Wave 0 |
| CMBT-01 | Base `resolve_battles()` uses 5-minute interval (env-gated check) | unit (SQL constant check via formula) | `flutter test test/unit/combat_timer_guard_test.dart -x` | Wave 0 |
| CMBT-02 | Partial engagement: 30% of army engages per turn; survivors carry forward | unit | `flutter test test/unit/combat_engagement_test.dart -x` | Wave 0 |
| CMBT-02 | Dev toolbar Trigger Battle completes without dispose error | widget | `flutter test test/widget/dev_toolbar_trigger_test.dart -x` | Wave 0 |

### Sampling Rate

- **Per task commit:** `flutter test test/unit/ --name "dispatch|engagement|timer"`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `test/unit/dispatch_travel_test.dart` — covers MIL-05 (formula + constant verification)
- [ ] `test/unit/combat_engagement_test.dart` — covers CMBT-02 (engagement fraction formula)
- [ ] `test/unit/combat_timer_guard_test.dart` — covers CMBT-01 (documents production timer values as constants)
- [ ] `test/widget/dev_toolbar_trigger_test.dart` — covers dev toolbar dispose fix (verifies Trigger Battle dialog completes without error)

Note: Existing `test/unit/combat_formula_test.dart` already covers CMBT-02 combat formula math and `test/widget/dev_toolbar_test.dart` covers basic FAB rendering. New tests extend these rather than replace them.

---

## Sources

### Primary (HIGH confidence)

- Direct codebase inspection — `supabase/functions/dispatch-units/index.ts` lines 21, 32: `BASE_MINUTES_PER_GRID_UNIT` used but never declared; only `BASE_SECONDS_PER_GRID_UNIT` is defined
- Direct codebase inspection — `lib/core/constants/unit_constants.dart` line 176: `const int baseMinutesPerGridUnit = 2` is the Dart-side source of truth
- Direct codebase inspection — `lib/core/dev/dev_toolbar.dart` lines 250-251: `controller.dispose()` precedes `controller.text` access
- Direct codebase inspection — `supabase/migrations/20260312000007_speed_up_all_timers.sql`: no environment guard present; rewrites resolve_battles and process_arrivals unconditionally
- Direct codebase inspection — `supabase/migrations/20260312000004_battle_functions.sql` and `20260312000005_modify_process_arrivals.sql`: base functions use `INTERVAL '5 minutes'`
- PostgreSQL docs — `current_setting(name, missing_ok)` builtin: standard mechanism for runtime config values

### Secondary (MEDIUM confidence)

- STATE.md decisions log: `[04-01]: process_arrivals() uses jsonb_each_text()` and `[Phase 05-combat]: Unit stats as JSONB constants inside resolve_battles() body` — confirms pattern for engagement fraction placement
- STATE.md decisions log: `[Phase 05-combat]: Naval gate-keeper: attacker naval wiped -> defender_won immediately` — confirms resolve_battles() architecture to extend with engagement fraction

### Tertiary (LOW confidence)

- None — all findings are directly verified from codebase.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all fixes are in-place edits to known files
- Architecture: HIGH — patterns confirmed by existing project decisions in STATE.md
- Pitfalls: HIGH — bugs directly observed in source code, not inferred

**Research date:** 2026-03-12
**Valid until:** 2026-04-12 (stable codebase; no external dependencies changing)
