# Architecture Research

**Domain:** Flutter + Supabase multiplayer strategy game — v1.3 AI Bots, GodMode Dashboard, Seed Data, Testing, CI/CD
**Researched:** 2026-03-17
**Confidence:** HIGH (existing codebase examined directly; new patterns verified against official Supabase and Deno docs)

> This document is scoped to v1.3. It focuses exclusively on how the five new
> feature areas (bots, GodMode, seed data, unit tests, automation) integrate with
> the existing Supabase + Flutter architecture established in v0.1.0 through v1.2.
> Existing patterns (server authority, pg_cron ticks, Realtime, Edge Functions,
> Riverpod providers) are not re-researched — only additions and modifications are
> documented.

---

## Existing Architecture Baseline (v1.2 state)

```
┌──────────────────────────────────────────────────────────────────────┐
│  Flutter Web Client (read-only game-state consumer)                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────────┐ │
│  │  Screen  │  │  Screen  │  │  Screen  │  │  DevToolbar          │ │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  │  (kDebugMode guard) │ │
│       │             │             │         └──────────────────────┘ │
│  ┌────┴─────────────┴─────────────┴──────────────────────────────┐  │
│  │          Riverpod Providers (StreamProvider / AsyncNotifier)   │  │
│  └────────────────────────────┬───────────────────────────────────┘  │
└────────────────────────────────┼──────────────────────────────────────┘
                                 │ supabase_flutter (anon key + JWT)
┌────────────────────────────────┼──────────────────────────────────────┐
│  Supabase                      │                                      │
│  ┌─────────────────────────────▼────────────────────────────────┐    │
│  │  Edge Functions (Deno/TypeScript) — service role internally   │    │
│  │  upgrade-building  train-units  dispatch-units  spy-city      │    │
│  │  send-trade  donate-island-wood  set-wine-rate                │    │
│  └─────────────────────────────┬────────────────────────────────┘    │
│                                 │                                      │
│  ┌─────────────────────────────▼────────────────────────────────┐    │
│  │  PostgreSQL + RLS + REPLICA IDENTITY FULL                     │    │
│  │  profiles  cities  city_resources  city_buildings             │    │
│  │  city_units  training_queue  construction_queue               │    │
│  │  unit_movements  battles  battle_turns  spy_reports           │    │
│  │  islands  island_resource_levels                              │    │
│  └─────────────────────────────┬────────────────────────────────┘    │
│                                 │                                      │
│  ┌─────────────────────────────▼────────────────────────────────┐    │
│  │  pg_cron Jobs                                                 │    │
│  │  resource-tick (*/5)   training-tick (*/1)                    │    │
│  │  arrivals-tick (*/1)   construction-tick (*/1)                │    │
│  │  battle-tick (*/1)                                            │    │
│  └───────────────────────────────────────────────────────────────┘    │
│                                                                        │
│  Supabase Realtime — cities, city_resources, city_buildings,          │
│                       unit_movements, battles                          │
└────────────────────────────────────────────────────────────────────────┘
```

### Existing pg_cron Schedule

| Job Name | Schedule | Function |
|----------|----------|----------|
| `resource-tick` | `*/5 * * * *` | `process_resource_tick()` |
| `construction-tick` | `* * * * *` | `complete_building_upgrades()` |
| `training-tick` | `* * * * *` | `complete_training()` |
| `arrivals-tick` | `* * * * *` | `process_arrivals()` |
| `battle-tick` | `* * * * *` | `resolve_battles()` |

### Existing Dev RPC Pattern (template for GodMode)

`supabase/migrations/20260312000008_dev_rpc_helpers.sql` establishes the pattern:
- `SECURITY DEFINER SET search_path = ''`
- Direct DML bypassing RLS (acceptable because called only by trusted server code)
- Used by Flutter DevToolbar gated behind `kDebugMode`

This pattern is the direct precedent for GodMode RPCs — same structure, different guard.

---

## v1.3 System Overview (additions highlighted)

```
┌──────────────────────────────────────────────────────────────────────┐
│  Flutter Web Client                                                   │
│  ┌──────────┐  ┌──────────┐  ┌────────────────────┐  ┌────────────┐ │
│  │  Game    │  │  Game    │  │  GodMode Dashboard  │  │ DevToolbar │ │
│  │  Screen  │  │  Screen  │  │  [NEW, is_admin      │  │ (kDebug)  │ │
│  │          │  │          │  │   guard]             │  │           │ │
│  └────┬─────┘  └────┬─────┘  └──────────┬──────────┘  └─────┬─────┘ │
│       │             │                   │                    │       │
│  ┌────┴─────────────┴───────────────────┴────────────────────┴───┐  │
│  │  Riverpod Providers                                             │  │
│  │  [existing providers unchanged]  [NEW: adminWorldStateProvider] │  │
│  └───────────────────────────────────────┬─────────────────────────┘  │
└───────────────────────────────────────────┼────────────────────────────┘
                                            │ supabase_flutter (anon key)
┌───────────────────────────────────────────┼────────────────────────────┐
│  Supabase                                 │                            │
│  ┌────────────────────────────────────────▼──────────────────────┐    │
│  │  Edge Functions (Deno) — unchanged + new tests                 │    │
│  │  [existing functions]                                          │    │
│  └────────────────────────────────────────┬──────────────────────┘    │
│                                            │                            │
│  ┌─────────────────────────────────────────▼─────────────────────┐    │
│  │  PostgreSQL + RLS                                              │    │
│  │  [existing tables unchanged]                                   │    │
│  │                                                                │    │
│  │  profiles   + is_bot bool DEFAULT false    [NEW column]        │    │
│  │             + is_admin bool DEFAULT false  [NEW column]        │    │
│  │  bot_schedules                             [NEW table]         │    │
│  │    (bot_id, is_paused, aggression 0-3, next_action_at)        │    │
│  │                                                                │    │
│  │  godmode_get_world_state()   [NEW RPC, checks is_admin]        │    │
│  │  godmode_set_bot_paused()    [NEW RPC, checks is_admin]        │    │
│  │  godmode_force_action()      [NEW RPC, checks is_admin]        │    │
│  │  run_bot_decisions()         [NEW function]                    │    │
│  │  bot_decide_upgrade()        [NEW helper]                      │    │
│  │  bot_decide_train()          [NEW helper]                      │    │
│  │  bot_decide_attack()         [NEW helper]                      │    │
│  └─────────────────────────────────────────┬───────────────────────┘    │
│                                             │                            │
│  ┌──────────────────────────────────────────▼──────────────────────┐   │
│  │  pg_cron Jobs                                                    │   │
│  │  [existing jobs unchanged]                                       │   │
│  │  bot-think-tick  */15 * * * *  → run_bot_decisions()  [NEW]     │   │
│  └───────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘

Automation (outside Supabase):
┌──────────────────────────────────────────────────────────────────────┐
│  scripts/                                                            │
│  run_local.sh (existing)   test_all.sh (existing)                   │
│  db_reset.sh [NEW]         seed_bots.sh [NEW]  ci.sh [NEW]          │
│                                                                      │
│  supabase/functions/tests/  [NEW — Deno.test unit tests]            │
│  .github/workflows/ci.yml   [NEW — GitHub Actions]                  │
└──────────────────────────────────────────────────────────────────────┘
```

---

## New Feature Integration Map

### Feature 1: Bot System (pg_cron + PL/pgSQL)

**What it adds:** 20 AI players that autonomously upgrade buildings, train units,
and attack neighbors on a 15-minute pg_cron schedule.

**Schema changes — MODIFY `profiles`:**

```sql
ALTER TABLE public.profiles
  ADD COLUMN is_bot   boolean NOT NULL DEFAULT false,
  ADD COLUMN is_admin boolean NOT NULL DEFAULT false;
```

Both columns default false; no existing player or RLS policy is affected.

**New table — `bot_schedules`:**

```sql
CREATE TABLE public.bot_schedules (
  bot_id         uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  is_paused      boolean NOT NULL DEFAULT false,
  aggression     integer NOT NULL DEFAULT 1 CHECK (aggression BETWEEN 0 AND 3),
  next_action_at timestamptz NOT NULL DEFAULT NOW()
);

-- No RLS SELECT needed from the client; GodMode uses SECURITY DEFINER RPC
ALTER TABLE public.bot_schedules ENABLE ROW LEVEL SECURITY;
-- Only admin-check RPCs and pg_cron (SECURITY DEFINER) can access this table
-- No client policies needed
```

**New SQL functions:**

```sql
-- run_bot_decisions() — called by pg_cron every 15 minutes
-- Iterates all active (non-paused) bots, each gets one action per tick
CREATE OR REPLACE FUNCTION public.run_bot_decisions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  bot RECORD;
BEGIN
  FOR bot IN
    SELECT p.id AS bot_id, c.id AS city_id, bs.aggression
    FROM public.profiles p
    JOIN public.cities c ON c.owner_id = p.id
    JOIN public.bot_schedules bs ON bs.bot_id = p.id
    WHERE p.is_bot = true AND bs.is_paused = false
      AND bs.next_action_at <= NOW()
  LOOP
    -- Priority: upgrade → train → attack (aggression-gated)
    IF NOT public.bot_decide_upgrade(bot.city_id) THEN
      IF NOT public.bot_decide_train(bot.city_id) THEN
        IF bot.aggression > 0 THEN
          PERFORM public.bot_decide_attack(bot.city_id, bot.aggression);
        END IF;
      END IF;
    END IF;
    -- Stagger next action to avoid all bots firing simultaneously
    UPDATE public.bot_schedules
      SET next_action_at = NOW() + INTERVAL '15 minutes'
                           + (random() * INTERVAL '5 minutes')
      WHERE bot_id = bot.bot_id;
  END LOOP;
END;
$$;
```

**New pg_cron job:**

```sql
SELECT cron.schedule(
  'bot-think-tick',
  '*/15 * * * *',
  'SELECT public.run_bot_decisions()'
);
```

**Flutter integration:** None. Bots operate entirely server-side. They appear as
regular players in leaderboards, movement lists, and battle participants — the
same as real players because they are real `auth.users` rows flagged with `is_bot`.

**New RLS consideration:** No new policies needed. Bot actions run via
`SECURITY DEFINER` functions (same as all existing cron functions), which bypass
RLS. RLS SELECT policies already allow `profiles_select_all` so bot names appear
on leaderboards correctly.

---

### Feature 2: GodMode Admin Dashboard (Flutter + Supabase RPC)

**What it adds:** A full-page Flutter screen at `/godmode` showing all players,
armies, active battles, and resource states in real-time. Admin controls: pause/
resume bots, inject resources, force actions. Gated behind `profile.is_admin`.

**Access pattern — no service_role key in client:**

All GodMode data reads and writes use `SECURITY DEFINER` RPC functions that
verify `is_admin` at the Postgres layer. The Flutter client uses the standard
`anon` key. This is the same model as the existing dev RPCs but adds an explicit
`is_admin` check.

**New SQL functions:**

```sql
-- Read: aggregate world state for admin dashboard
CREATE OR REPLACE FUNCTION public.godmode_get_world_state()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_is_admin bool;
BEGIN
  SELECT is_admin INTO v_is_admin
    FROM public.profiles WHERE id = auth.uid();
  IF NOT COALESCE(v_is_admin, false) THEN
    RAISE EXCEPTION 'unauthorized' USING ERRCODE = '42501';
  END IF;

  RETURN jsonb_build_object(
    'players', (
      SELECT jsonb_agg(jsonb_build_object(
        'id', p.id, 'name', p.display_name,
        'is_bot', p.is_bot,
        'city_id', c.id, 'city_name', c.name,
        'is_paused', bs.is_paused,
        'aggression', bs.aggression
      ))
      FROM public.profiles p
      JOIN public.cities c ON c.owner_id = p.id
      LEFT JOIN public.bot_schedules bs ON bs.bot_id = p.id
    ),
    'active_battles', (
      SELECT jsonb_agg(row_to_json(b))
      FROM public.battles b WHERE b.status = 'active'
    )
    -- extend as needed for full world state
  );
END;
$$;

-- Write: pause or resume a bot
CREATE OR REPLACE FUNCTION public.godmode_set_bot_paused(
  p_bot_id  uuid,
  p_paused  boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_is_admin bool;
BEGIN
  SELECT is_admin INTO v_is_admin
    FROM public.profiles WHERE id = auth.uid();
  IF NOT COALESCE(v_is_admin, false) THEN
    RAISE EXCEPTION 'unauthorized' USING ERRCODE = '42501';
  END IF;

  UPDATE public.bot_schedules SET is_paused = p_paused WHERE bot_id = p_bot_id;
END;
$$;
```

**GoRouter changes — MODIFY `app_router.dart`:**

Add `/godmode` route inside the existing router's `routes` list. Add admin check
to the existing `_redirect` function — same pattern already used for auth and
profile guards:

```dart
// In _redirect():
if (location == '/godmode') {
  final profile = ref.read(profileProvider).valueOrNull;
  if (profile == null || !profile.isAdmin) return '/map';
}
```

**New Flutter files:**

| File | Purpose |
|------|---------|
| `lib/features/admin/models/world_state.dart` | Dart model for decoded RPC response |
| `lib/features/admin/providers/admin_provider.dart` | Calls `godmode_get_world_state()` RPC, returns `WorldState` |
| `lib/features/admin/screens/godmode_screen.dart` | Full-page dashboard: player table, battle list, bot controls |

**Profile model change — MODIFY `lib/features/profile/models/profile.dart`:**

Add `isBot` and `isAdmin` fields deserialized from the `profiles` select query.
The Flutter client already loads the current user's profile; `isAdmin` is the
gate flag read by `_redirect` and by `GodModeScreen`.

---

### Feature 3: Rich Seed Data (20 diverse bot accounts)

**What it adds:** `seed.sql` is extended to create 20 bot `auth.users` accounts
with varied game states (different building levels, army compositions, resource
amounts) using the existing dev RPC helpers.

**Approach — three-layer seed:**

```
Layer 1 (existing): Island grid — 25 islands in 5x5 grid (unchanged)
Layer 2 (NEW):      Bot auth.users + profiles.is_bot = true
Layer 3 (NEW):      Bot game-state enrichment via existing dev RPCs
```

**Layer 2 pattern (reuses existing test account pattern in seed.sql):**

```sql
-- Bot accounts use @bot.local emails, never receive email
-- handle_new_user trigger fires automatically, placing each bot on an island
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data
) VALUES
  ('00000000-0000-0000-0000-000000000000',
   'b0000001-0000-0000-0000-000000000001', 'authenticated', 'authenticated',
   'bot01@bot.local', crypt('unused_pw', gen_salt('bf')),
   NOW(), NOW(), NOW(),
   '{"provider":"email","providers":["email"]}', '{}'),
  -- ... 19 more bots
;

-- Mark all as bots and set display names
UPDATE public.profiles
  SET is_bot = true, display_name = 'BotAres'
  WHERE id = 'b0000001-0000-0000-0000-000000000001';
-- ... 19 more UPDATE statements

-- Seed bot_schedules with diverse aggression levels
INSERT INTO public.bot_schedules (bot_id, aggression)
VALUES
  ('b0000001-0000-0000-0000-000000000001', 3), -- aggressive
  ('b0000002-0000-0000-0000-000000000002', 1), -- passive
  -- ...
ON CONFLICT (bot_id) DO UPDATE SET aggression = EXCLUDED.aggression;
```

**Layer 3 pattern (uses existing dev RPCs for diverse states):**

```sql
-- Use existing dev_level_up_building, dev_inject_resources, dev_bulk_spawn_units
-- Bot 1: military-focused (high barracks, many units, low resources)
SELECT public.dev_level_up_building('bot01-city-id', 'barracks', 5);
SELECT public.dev_bulk_spawn_units('bot01-city-id', '{"swordsman":50,"archer":30}'::jsonb);

-- Bot 2: economic-focused (high sawmill/quarry, rich resources)
SELECT public.dev_level_up_building('bot02-city-id', 'sawmill', 4);
SELECT public.dev_inject_resources('bot02-city-id', 15000, 12000, 8000, 5000, 20000);
-- ... varied patterns for all 20 bots
```

**Key constraint:** `dev_*` RPCs used in seed.sql are `SECURITY DEFINER`
functions that bypass RLS. They are already present for the DevToolbar. The seed
script reuses them for bot initialization — no new functions needed for this.

**Note on city ID lookup:** Layer 3 must look up bot city IDs by owner_id since
city IDs are auto-generated by the `handle_new_user` trigger. Use a subquery:

```sql
SELECT public.dev_inject_resources(
  (SELECT id FROM public.cities WHERE owner_id = 'b0000001-0000-0000-0000-000000000001' LIMIT 1),
  15000, 12000, 8000, 5000, 20000
);
```

---

### Feature 4: Unit Tests (Flutter + Deno)

**What it adds:** Deno unit tests for critical Edge Functions; Flutter unit test
coverage for new bot-related formula code (if any Dart formulas are added).

**Supabase Edge Function tests — new directory `supabase/functions/tests/`:**

Deno's built-in test runner needs no additional tooling. Each Edge Function that
contains extractable business logic gets a companion test file.

```
supabase/functions/tests/
├── upgrade-building-test.ts   # cost formula validation, ownership check
├── train-units-test.ts        # training cost formula, queue capacity check
├── dispatch-units-test.ts     # travel time formula, army size validation
└── send-trade-test.ts         # trade route validation, resource deduction
```

**Pattern — extract pure functions, test them directly:**

```typescript
// In supabase/functions/upgrade-building/cost.ts (extracted)
export function buildingCost(baseCost: number, currentLevel: number): number {
  return Math.floor(baseCost * Math.pow(1.5, currentLevel));
}

// In supabase/functions/tests/upgrade-building-test.ts
import { assertEquals } from "jsr:@std/assert";
import { buildingCost } from "../upgrade-building/cost.ts";

Deno.test("buildingCost: level 1 → base * 1.5", () => {
  assertEquals(buildingCost(100, 1), 150);
});

Deno.test("buildingCost: level 0 → base cost", () => {
  assertEquals(buildingCost(100, 0), 100);
});
```

The handler file (`index.ts`) imports the pure function. Tests import the pure
function directly — no HTTP server or Supabase mock needed for unit tests.

**Run command:**

```bash
deno test --allow-all supabase/functions/tests/
```

**Existing Flutter tests (already in `test/unit/`):**

The existing 15+ unit test files (`building_formulas_test.dart`,
`combat_formula_test.dart`, etc.) continue unchanged. If bot decision logic is
ever extracted to Dart-side helpers, add corresponding test files to `test/unit/`.
The `test_all.sh` script already runs all Flutter tests via `flutter test`.

---

### Feature 5: Automation Scripts + CI/CD

**What it adds:** Three new shell scripts and a GitHub Actions workflow that
provide a single-command dev setup and an automated CI pipeline.

**New scripts:**

`scripts/db_reset.sh` — Reset DB and re-seed (wraps existing pattern from `test_all.sh`):

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
echo "Resetting database..."
npx supabase db reset --local
echo "Database reset complete."
```

`scripts/seed_bots.sh` — Apply bot seed separately (useful when iterating bot
game states without full DB reset):

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
echo "Applying bot seed..."
npx supabase db execute --local --file supabase/seed_bots.sql
echo "Bot seed applied."
```

`scripts/ci.sh` — Full pipeline: reset + seed + Deno tests + Flutter tests + lint:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "[1/4] Resetting database..."
npx supabase db reset --local

echo "[2/4] Running Deno Edge Function tests..."
deno test --allow-all supabase/functions/tests/

echo "[3/4] Running Flutter tests..."
flutter test --reporter expanded

echo "[4/4] Flutter analyze (lint)..."
flutter analyze

echo "CI PASSED"
```

`.github/workflows/ci.yml` — GitHub Actions CI:

```yaml
name: CI
on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: 'stable'

      - name: Setup Deno
        uses: denoland/setup-deno@v2

      - name: Setup Supabase CLI
        uses: supabase/setup-cli@v1

      - name: Start Supabase local
        run: npx supabase start

      - name: Run full CI pipeline
        run: bash scripts/ci.sh
```

**Existing scripts remain unchanged:**
- `scripts/run_local.sh` — start Supabase + run Flutter dev server
- `scripts/test_all.sh` — DB reset + Flutter tests (subset of ci.sh)

---

## Recommended Project Structure

```
ikariam/
├── lib/
│   ├── features/
│   │   ├── admin/                              [NEW feature module]
│   │   │   ├── models/
│   │   │   │   └── world_state.dart            # Decoded RPC response model
│   │   │   ├── providers/
│   │   │   │   └── admin_provider.dart         # Calls godmode_get_world_state RPC
│   │   │   └── screens/
│   │   │       └── godmode_screen.dart         # Full-page admin dashboard
│   │   └── [existing features — unchanged]
│   ├── features/profile/models/profile.dart    [MODIFIED — add isBot, isAdmin]
│   └── core/router/app_router.dart             [MODIFIED — add /godmode route + guard]
│
├── supabase/
│   ├── migrations/
│   │   ├── [existing migrations — unchanged]
│   │   ├── 202603XX000001_bot_schema.sql        # profiles.is_bot, is_admin, bot_schedules
│   │   ├── 202603XX000002_bot_functions.sql     # run_bot_decisions + helper functions
│   │   ├── 202603XX000003_bot_cron.sql          # bot-think-tick cron job
│   │   ├── 202603XX000004_godmode_rpc.sql       # godmode_get_world_state + write RPCs
│   │   └── 202603XX000005_admin_profile_seed.sql # SET is_admin=true for dev admin account
│   ├── functions/
│   │   ├── [existing functions — unchanged]
│   │   └── tests/                              [NEW — Deno unit test directory]
│   │       ├── upgrade-building-test.ts
│   │       ├── train-units-test.ts
│   │       ├── dispatch-units-test.ts
│   │       └── send-trade-test.ts
│   └── seed.sql                                [MODIFIED — add bot account layers]
│
├── scripts/
│   ├── run_local.sh                            # Existing — unchanged
│   ├── test_all.sh                             # Existing — unchanged
│   ├── db_reset.sh                             [NEW]
│   ├── seed_bots.sh                            [NEW]
│   └── ci.sh                                  [NEW]
│
└── .github/
    └── workflows/
        └── ci.yml                              [NEW — GitHub Actions]
```

---

## Data Flow Diagrams

### Bot Action Flow (pg_cron → PL/pgSQL → DB tables)

```
pg_cron: bot-think-tick fires every 15 min
    ↓
run_bot_decisions()
    ↓ for each non-paused bot
    ├── bot_decide_upgrade(city_id)
    │     SELECT construction_queue → is empty?
    │     SELECT city_resources → can afford cheapest upgrade?
    │     → INSERT construction_queue       (same table Edge Functions write to)
    │     returns true if acted, false if skipped
    │
    ├── bot_decide_train(city_id)  [if upgrade skipped]
    │     SELECT training_queue → is empty?
    │     SELECT city_resources → can afford cheapest unit?
    │     → INSERT training_queue           (same table Edge Functions write to)
    │     returns true if acted, false if skipped
    │
    └── bot_decide_attack(city_id, aggression)  [if train also skipped]
          SELECT nearby cities → find weakest non-bot neighbor
          SELECT city_units → have enough army?
          → INSERT unit_movements            (same table dispatch-units writes to)

Existing cron ticks handle bot completions (no changes needed):
  training-tick  → complete_training() → bot units appear in city_units
  arrivals-tick  → process_arrivals()  → bot army arrives at target
  battle-tick    → resolve_battles()   → bot participates in battles
```

### GodMode Data Flow (Flutter → RPC → DB, anon key only)

```
Admin navigates to /godmode
    ↓
GoRouter _redirect: checks profile.isAdmin
    → false: redirect to /map  (security gate in Flutter)
    → true: allow route
    ↓
adminProvider calls supabase.rpc('godmode_get_world_state')
    ↓
PostgreSQL: verifies auth.uid() has is_admin = true
    → false: RAISE EXCEPTION 'unauthorized'  (second security gate in DB)
    → true: execute full world-state query
    ↓
Returns JSONB → adminProvider decodes into WorldState model
    ↓
GodModeScreen renders player table + battle list
    ↓
Admin taps "Pause Bot":
    adminProvider calls supabase.rpc('godmode_set_bot_paused', {bot_id, paused: true})
    ↓
PostgreSQL: re-checks is_admin, flips bot_schedules.is_paused = true
    ↓
run_bot_decisions() skips this bot on next tick (WHERE is_paused = false)
```

### Seed Data Flow (supabase db reset → trigger → dev RPCs)

```
supabase db reset --local
    ↓
Applies all migrations (including bot_schema, bot_functions, godmode_rpc)
    ↓
Applies seed.sql:
  Layer 1: INSERT 25 islands (existing)
    ↓
  Layer 2: INSERT 20 bot auth.users
    ↓ (for each INSERT)
  handle_new_user trigger fires automatically
    → creates profiles row (display_name NULL)
    → places bot city on least-populated island
    ↓
  UPDATE profiles SET is_bot=true, display_name='BotX' (20 rows)
  INSERT bot_schedules (20 rows, diverse aggression levels)
    ↓
  Layer 3: Call dev_inject_resources / dev_level_up_building / dev_bulk_spawn_units
    → diverse game states created for each bot
    ↓
  Layer 4 (existing): INSERT 7 test accounts (unchanged)
```

### CI/CD Pipeline Flow

```
git push → GitHub Actions trigger
    ↓
[1] supabase start  (local Supabase on ubuntu runner)
    ↓
[2] supabase db reset --local  (applies migrations + seed.sql)
    ↓
[3] deno test --allow-all supabase/functions/tests/
    → tests pure formula functions extracted from Edge Functions
    ↓
[4] flutter test --reporter expanded
    → runs existing test/unit/ and test/widget/ suites
    ↓
[5] flutter analyze
    → Dart static analysis, zero warnings required
    ↓
Pass/fail reported per step
```

---

## Integration Points

### New vs Modified — Complete Reference

| Component | Type | Integrates With | Key Constraint |
|-----------|------|-----------------|----------------|
| `profiles.is_bot` | NEW column | `run_bot_decisions`, seed.sql, `profiles_select_all` RLS | Default false; no existing policy change needed |
| `profiles.is_admin` | NEW column | GoRouter `_redirect`, `godmode_*` RPCs | Default false; grant by SQL UPDATE in seed/migration |
| `bot_schedules` table | NEW table | `run_bot_decisions`, `godmode_set_bot_paused` | No client-side RLS policies; access only via SECURITY DEFINER |
| `run_bot_decisions()` | NEW function | `bot_schedules`, `bot_decide_*` helpers | SECURITY DEFINER; calls same underlying tables as Edge Functions |
| `bot_decide_upgrade()` | NEW helper | `construction_queue`, `city_resources` | Mirrors logic in `upgrade-building` Edge Function |
| `bot_decide_train()` | NEW helper | `training_queue`, `city_resources` | Mirrors logic in `train-units` Edge Function |
| `bot_decide_attack()` | NEW helper | `unit_movements`, `city_units` | Mirrors logic in `dispatch-units` Edge Function |
| `bot-think-tick` cron | NEW cron job | `run_bot_decisions()` | `*/15 * * * *`; safe to run even if no active bots |
| `godmode_get_world_state()` | NEW RPC | Called via `adminProvider`; reads all tables | is_admin check is FIRST statement; SECURITY DEFINER |
| `godmode_set_bot_paused()` | NEW RPC | `bot_schedules`, called from GodMode controls | is_admin check required; no additional RLS |
| `godmode_force_action()` | NEW RPC | Wraps existing `dev_*` functions | is_admin check + delegates to dev RPCs |
| `lib/features/admin/` | NEW feature module | `adminProvider`, GoRouter `/godmode` | Not in bottom nav; accessed via separate route |
| `profile.dart` (Dart model) | MODIFIED | `profileProvider`, GoRouter `_redirect` | Add `isBot`, `isAdmin` bool fields; nullable from DB |
| `app_router.dart` | MODIFIED | `profileProvider`, new `GodModeScreen` | Add `/godmode` route + `isAdmin` redirect guard |
| `seed.sql` | MODIFIED | `auth.users`, `profiles`, `bot_schedules`, dev RPCs | Three-layer structure; idempotent with ON CONFLICT |
| `supabase/functions/tests/` | NEW directory | Deno test runner, `ci.sh` | Pure function tests only; no DB connection needed |
| `scripts/ci.sh` | NEW script | Deno, supabase CLI, Flutter | Superset of `test_all.sh`; replaces it in CI |
| `.github/workflows/ci.yml` | NEW file | `scripts/ci.sh`, GitHub Actions | Triggers on push to main/master and PRs |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Bot AI ↔ Game tables | Direct SQL DML in SECURITY DEFINER functions | Same tables as Edge Functions; no conflict because bots write to their own city rows |
| GodMode Flutter ↔ Supabase | Standard `.rpc()` call via anon key | is_admin enforced in Postgres, not Flutter |
| GodMode controls ↔ Bot scheduler | `bot_schedules.is_paused` flag | Decoupled: control sets flag; cron reads flag; no direct call |
| Deno tests ↔ Edge Functions | Import pure extracted functions | Unit tests never need a running Supabase instance |
| `ci.sh` ↔ `test_all.sh` | `ci.sh` is a superset | `test_all.sh` remains for quick local iteration (no Deno step) |

---

## Anti-Patterns

### Anti-Pattern 1: Calling Edge Functions from Bot Cron via pg_net

**What people do:** Use `pg_net` HTTP extension to call `dispatch-units` or
`train-units` from `run_bot_decisions()` as if the bot were a real player.

**Why it's wrong:** Adds HTTP round-trips, async failure modes, and JWT
generation complexity inside a cron function. The existing cron functions
(`complete_training`, `resolve_battles`) are pure PL/pgSQL for exactly this
reason. `pg_net` is for calling external services, not for calling your own
internal Edge Functions.

**Do this instead:** Implement `bot_decide_attack`, `bot_decide_train`,
`bot_decide_upgrade` as PL/pgSQL functions that write directly to the same tables
(`unit_movements`, `training_queue`, `construction_queue`) that Edge Functions
write to. The game engine processes these rows identically regardless of origin.

### Anti-Pattern 2: service_role Key in Flutter Client for GodMode

**What people do:** Pass the Supabase `service_role` key as `--dart-define` to
give GodMode queries unrestricted access to all tables.

**Why it's wrong:** Flutter web compiles to JavaScript visible in the browser.
Any `--dart-define` value appears in the JS bundle. The `service_role` key
bypasses all RLS — exposing it grants any visitor root database access.

**Do this instead:** Use `SECURITY DEFINER` RPCs that perform an `is_admin` check
as the first statement. The client passes the standard `anon` key. Authorization
is enforced in Postgres where it cannot be bypassed by client-side manipulation.

### Anti-Pattern 3: Gating GodMode Behind kDebugMode

**What people do:** Add GodMode to the existing dev toolbar block:
`if (kDebugMode) { showGodModeButton(); }`.

**Why it's wrong:** `kDebugMode` is false in release Flutter web builds.
GodMode is a legitimate production admin feature (watching the live world), not
a debug tool. The existing dev toolbar (`dev_inject_resources`,
`dev_bulk_spawn_units`) is correctly debug-only because those bypass game logic;
GodMode only reads and controls what is already exposed to the admin via the
database.

**Do this instead:** Gate GodMode on `profile.isAdmin` (a database flag visible
only after login) checked in both the GoRouter redirect and the RPC itself.
Keep the dev toolbar gated on `kDebugMode` as today.

### Anti-Pattern 4: Separate Bot Auth Role or Schema

**What people do:** Create a dedicated `bot_role` PostgreSQL role or `bots`
schema to isolate bot data from player data.

**Why it's wrong:** Bots must be indistinguishable from real players in all game
mechanics — they appear in leaderboards, receive battle reports, hold cities on
islands, and trade with real players. A separate role or schema would require
duplicating or exempting every RLS policy and every query that currently operates
on `profiles`, `cities`, `city_units`, etc.

**Do this instead:** Bots are real `auth.users` rows with `profiles.is_bot = true`.
`run_bot_decisions()` runs as `SECURITY DEFINER` (identical to all existing cron
functions), bypassing RLS for writes. Bots participate in all game systems
transparently.

### Anti-Pattern 5: Bot Decisions Executing Every 1-Minute Tick

**What people do:** Add bot decision logic to the existing `battle-tick` or
`training-tick` cron jobs (already firing every minute).

**Why it's wrong:** Bot decisions are heavier than existing tick logic (scanning
all bot cities, evaluating priorities, potentially inserting into multiple tables).
Adding them to a 1-minute tick creates a performance regression for the existing
game engine ticks. More importantly, bots acting every minute produces unnatural
"perfect reaction time" behavior that feels unfair to human players.

**Do this instead:** Register a separate `bot-think-tick` at `*/15 * * * *`.
This keeps bot behavior perceptibly slower than a human (believable) and
isolates bot decision overhead from existing game loop timing.

---

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 20 bots + 10 human players (v1.3 target) | Single `run_bot_decisions()` at 15min, all in-DB — zero extra infrastructure |
| 100 bots + 100 players | Add `LIMIT 20 FOR UPDATE SKIP LOCKED` inside `run_bot_decisions()` loop to batch across ticks; add index on `profiles(is_bot) WHERE is_bot = true` |
| 500+ bots | Move bot decision scoring to a materialized view refreshed hourly; keep cron as executor only |

### First Bottleneck

`godmode_get_world_state()` does a full-table join scan. For v1.3 player counts
(~30 total) this is instant. At 500+ players, add pagination (`LIMIT`/`OFFSET`
params) and a Riverpod `keepAlive` cache. Not needed for v1.3.

---

## Suggested Build Order

Dependencies are strict: schema migrations must precede functions, functions must
precede cron jobs, GodMode screen requires the RPC, and CI requires the Deno tests.

**Phase 1 — Schema (unblocks everything else):**
1. Migration: `profiles.is_bot`, `profiles.is_admin` columns
2. Migration: `bot_schedules` table
3. Migration: `godmode_*` RPCs (reads only initially)

**Phase 2 — Bot backend (parallel with GodMode backend):**
4. Migration: `run_bot_decisions()` + `bot_decide_*` helper functions
5. Migration: `bot-think-tick` cron job registration
6. Test locally: verify bots start appearing in `unit_movements` and `training_queue`

**Phase 3 — GodMode backend (parallel with bot backend):**
7. Migration: `godmode_set_bot_paused()`, `godmode_force_action()` RPCs
8. Seed: mark one test account (`dummy1@test.local`) as `is_admin = true`

**Phase 4 — Seed data (depends on bot_schedules existing):**
9. Extend `seed.sql` with 20 bot accounts (Layer 2: auth.users + profiles)
10. Extend `seed.sql` with bot game-state enrichment (Layer 3: dev RPC calls)
11. Run `supabase db reset --local` to verify full seed runs cleanly

**Phase 5 — Flutter GodMode (depends on Phase 3 RPCs):**
12. Add `isBot`, `isAdmin` to `Profile` Dart model
13. Add `/godmode` route + guard to `app_router.dart`
14. `world_state.dart` model + `admin_provider.dart`
15. `godmode_screen.dart` — read-only world state table first
16. Add bot pause/resume controls to GodMode screen

**Phase 6 — Tests + Automation (independent, can start after Phase 1):**
17. Extract pure formula functions from Edge Functions (e.g., `cost.ts`, `travel.ts`)
18. Write Deno tests in `supabase/functions/tests/`
19. Write `scripts/db_reset.sh`, `scripts/ci.sh`
20. Write `.github/workflows/ci.yml`
21. Verify full CI pipeline passes end-to-end

---

## Sources

- [Supabase pg_cron documentation](https://supabase.com/docs/guides/database/extensions/pg_cron) — HIGH confidence
- [Supabase Edge Functions unit testing guide](https://supabase.com/docs/guides/functions/unit-test) — HIGH confidence
- [Supabase RLS and service role key security](https://supabase.com/docs/guides/database/postgres/row-level-security) — HIGH confidence
- [Supabase automated testing with GitHub Actions](https://supabase.com/docs/guides/deployment/ci/testing) — HIGH confidence
- Existing codebase — `supabase/migrations/20260312000008_dev_rpc_helpers.sql` (SECURITY DEFINER pattern) — direct examination, HIGH confidence
- Existing codebase — `supabase/migrations/20260312000006_battle_cron_job.sql` (pg_cron job pattern) — direct examination, HIGH confidence
- Existing codebase — `lib/core/router/app_router.dart` (GoRouter redirect guard pattern) — direct examination, HIGH confidence
- Existing codebase — `supabase/seed.sql` (test account seed pattern for bot replication) — direct examination, HIGH confidence
- Existing codebase — `scripts/test_all.sh` (CI script baseline) — direct examination, HIGH confidence

---

*Architecture research for: Ikariam Clone v1.3 — Bots, Testing & Automation*
*Researched: 2026-03-17*
