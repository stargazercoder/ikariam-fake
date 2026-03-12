# Phase 5: Combat - Research

**Researched:** 2026-03-12
**Domain:** Turn-based battle engine — pg_cron resolution, two-phase naval/land combat, Supabase Realtime battle reports, Flutter Battles tab
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Battle Resolution Mechanics
- All-in engagement: all surviving units fight every turn (no front-line/reserve system in v1, but design should allow adding front-line later)
- Simple ratio damage: total attack vs total defense determines casualty ratio per side
- Each unit type contributes its own attack/defense stats to the side total
- Naval gate-keeper: if defender wins naval phase, attacker's land units cannot land — battle ends, attacker retreats
- Naval phase resolves first each turn, then land phase (if attacker has surviving naval or defender has no naval)
- Town Wall defense bonus: defender's land units get +X% defense per Town Wall level (flat multiplier)

#### Battle Lifecycle
- Battle starts immediately when process_arrivals() detects army arriving at enemy city
- First turn resolves at arrival_time + 5 minutes
- Battle ends only on wipeout: one side has zero units remaining
- No retreat mechanic in v1
- After attacker wins: surviving units automatically travel back to origin city (travel time applies)
- After defender wins: attacker's units are gone, defender keeps survivors
- One battle at a time per city: if a city is already in battle, new arriving armies are rejected/queued

#### Battle Report UI
- Battles list screen (no push notifications or banners) — players check manually
- Turn-by-turn display: each turn shown as a card/row with Naval phase casualties then Land phase casualties
- 4th bottom navigation tab: "Battles" added to existing World Map / Island / City tabs
- Active battles show live countdown timer to next turn (reuse CountdownTimerWidget pattern)
- Battle history: completed battles remain viewable as past reports

#### Battle Data Model
- Two new tables: `battles` (active battle state) and `battle_turns` (per-turn results)
- `battles` table: attacker/defender info, army JSONB snapshots (per unit type), status, next_turn_at, turn_number, city reference
- `battle_turns` table: turn number, naval/land phase results, casualties per side (JSONB with per-unit-type breakdown), survivors
- Army snapshots use full JSONB unit breakdown: `{hoplite: 20, archer: 15, ...}` — consistent with unit_movements.units pattern
- resolve_battles() pg function called by new 'battle-tick' pg_cron job (every minute, checks next_turn_at <= NOW())
- process_arrivals() modified: if destination city owner != army owner, create battle instead of upserting units
- Add movement_type column to unit_movements ('attack' only in v1, column exists for future 'reinforce')
- Both tables Realtime-enabled (REPLICA IDENTITY FULL + supabase_realtime publication)
- RLS: both attacker and defender can read their own battles/turns

### Claude's Discretion
- Exact damage formula coefficients and casualty calculation
- Town Wall defense bonus percentage per level
- battle_turns table exact schema design
- How to handle edge case: attacker has no naval but defender does (skip naval phase or auto-lose naval?)
- Battle list UI layout and styling
- How rejected/queued armies are handled when city is already in battle
- Return trip travel time calculation for victorious attacker

### Deferred Ideas (OUT OF SCOPE)
- Reinforcements during active battles — CMBT-06 (v2)
- Pillage (steal resources on victory) — CMBT-07 (v2)
- Occupation (city takeover) — CMBT-08 (v2)
- Front-line/reserve engagement system — future enhancement to v1's all-in system
- Unit-type matchups (rock-paper-scissors) — future enhancement to damage calculation
- Push notifications for battle events — future UX improvement
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CMBT-01 | Battles resolve in turns, each turn lasting 5 minutes | `battles.next_turn_at` field + `resolve_battles()` pg function called by `battle-tick` cron job every minute checking `next_turn_at <= NOW()` |
| CMBT-02 | Each turn a portion of armies engage, survivors carry to next turn | `battles.attacker_units` and `battles.defender_units` JSONB mutated in-place each turn; `battle_turns` records snapshots; wipeout check triggers status update |
| CMBT-03 | Naval battle phase occurs before land battle phase | `resolve_battles()` runs two sub-phases per turn: naval first (naval unit types only), then land; if defender naval wins gate-keeper check, battle ends; each phase result recorded in `battle_turns` |
| CMBT-04 | Battle reports sent to both attacker and defender via Supabase Realtime | `battles` and `battle_turns` with `REPLICA IDENTITY FULL` + `supabase_realtime` publication; both tables streamed in `BattleRepository`; RLS allows both participants to read |
| CMBT-05 | All battle calculations run server-side (Edge Function or pg function) | `resolve_battles()` SECURITY DEFINER pg function handles all arithmetic; client only receives turn results as rows; no Flutter write paths to battles or battle_turns |
</phase_requirements>

---

## Summary

Phase 5 introduces the combat engine — the capstone of the v1 game loop. The entire battle lifecycle runs server-side: `process_arrivals()` detects an enemy arrival and creates a `battles` row instead of delivering units. A new `battle-tick` pg_cron job calls `resolve_battles()` every minute, which checks `next_turn_at <= NOW()`, runs naval then land phase arithmetic, writes the result to `battle_turns`, updates live unit counts in `battles`, and sets the next turn's timestamp 5 minutes forward. Both participants receive updates via Supabase Realtime on both tables. The Flutter client adds a 4th "Battles" tab that streams active and completed battles and renders them as turn cards.

The combat formula follows the locked "simple ratio damage" model: each side's total attack and defense are summed across all unit types. Casualties are computed as `floor(enemy_total_attack / own_total_defense * own_total_units)`, clamped to [0, surviving units]. The naval gate-keeper is a binary check: if the attacker's naval units are wiped in the naval phase, the battle ends immediately with defender victory (attacker's land units never engage). Town Wall adds a flat percentage bonus to defender land defense per building level.

The engineering pattern is a direct extension of the pg_cron + Realtime stack already used in Phases 2–4. No new libraries are needed. The `process_arrivals()` function requires a one-line ownership check to branch between "deliver troops" (friendly) and "create battle" (enemy). The Flutter side needs a new `BattleRepository`, a `BattlesScreen`, per-battle `BattleDetailScreen`, a `BattleTurnCard` widget, and a 4th branch in the `StatefulShellRoute`.

**Primary recommendation:** Write `resolve_battles()` as a single SECURITY DEFINER pg function that handles both phases atomically per battle row. Keep unit stats (attack/defense) in TypeScript/Dart constants — the pg function reads them from a constant array inside the function body, not a DB table. This avoids a schema change if stats are rebalanced.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Supabase PostgreSQL | (hosted) | `battles`, `battle_turns` tables with RLS | All game tables follow this pattern; already established |
| pg_cron | already enabled (migration 20260311000010) | `battle-tick` cron job calls `resolve_battles()` every minute | Same extension powers resource-tick, construction-tick, training-tick, arrivals-tick |
| Supabase Realtime | already enabled | Live updates to `battles` and `battle_turns` for both players | Already used for all game tables; `REPLICA IDENTITY FULL` + `ADD TABLE` pattern |
| flutter_riverpod ^3.3.1 | already in pubspec | `StreamProvider.autoDispose.family` for battles and battle_turns | Consistent with all existing providers |
| supabase_flutter ^2.12.0 | already in pubspec | DB queries and Realtime `.stream()` subscriptions | Already in use throughout the project |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| CountdownTimerWidget | existing widget (city/widgets/) | Countdown to next battle turn | Reuse exactly — accepts `finishAt: DateTime`, shows HH:MM:SS |
| `deduct_units()` pg function | existing (migration 20260311000014) | Remove casualties from `city_units` (NOT used here — battles use JSONB snapshots) | Note: casualties are applied to the JSONB snapshot inside `battles` directly, not `city_units`; `deduct_units` is only called when returning surviving attacker units |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| pg function for battle resolution | Edge Function | Edge Functions have HTTP overhead + cold start; pg functions run in DB transaction context, lower latency, better for every-minute tick |
| JSONB snapshots in `battles` | Separate `battle_units` join table | JSONB is simpler, consistent with `unit_movements.units`, already understood by team; join table adds complexity for no v1 benefit |
| Storing unit stats in DB table | Constants in pg function body | DB table requires migration to rebalance; constants in function body are deployable via migration file without a separate table |

**Installation:** No new packages needed. All required libraries are already in `pubspec.yaml` or Supabase-side.

---

## Architecture Patterns

### Recommended Project Structure

```
supabase/
├── migrations/
│   ├── 20260312000001_add_movement_type_to_unit_movements.sql
│   ├── 20260312000002_create_battles.sql
│   ├── 20260312000003_create_battle_turns.sql
│   ├── 20260312000004_battle_functions.sql          # resolve_battles() pg function
│   ├── 20260312000005_modify_process_arrivals.sql   # Add ownership check
│   └── 20260312000006_battle_cron_job.sql           # Register battle-tick

lib/
├── features/
│   └── battles/
│       ├── data/
│       │   └── battle_repository.dart               # watchActiveBattles, watchBattleTurns
│       ├── models/
│       │   ├── battle.dart                          # Battle.fromJson
│       │   └── battle_turn.dart                     # BattleTurn.fromJson
│       ├── providers/
│       │   ├── battles_provider.dart                # StreamProvider for battles list
│       │   └── battle_turns_provider.dart           # StreamProvider.family for turns
│       └── screens/
│           ├── battles_screen.dart                  # 4th tab — list of active + past battles
│           └── battle_detail_screen.dart            # Per-battle turn-by-turn report
│               └── widgets/
│                   └── battle_turn_card.dart        # Card per turn: naval + land casualties
```

### Pattern 1: battles Table Schema

**What:** Central battle state. JSONB snapshots updated each turn by `resolve_battles()`. Realtime-enabled so both players receive row UPDATEs.

```sql
-- Source: follows unit_movements pattern (migration 20260311000013)
CREATE TABLE public.battles (
  id                   uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  defender_city_id     uuid        NOT NULL REFERENCES public.cities(id),
  attacker_city_id     uuid        NOT NULL REFERENCES public.cities(id),
  attacker_id          uuid        NOT NULL REFERENCES auth.users(id),
  defender_id          uuid        NOT NULL REFERENCES auth.users(id),
  -- Live army snapshots mutated each turn: {"hoplite": 20, "archer": 15}
  attacker_units       jsonb       NOT NULL,
  defender_units       jsonb       NOT NULL,
  status               text        NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active', 'attacker_won', 'defender_won')),
  turn_number          integer     NOT NULL DEFAULT 0,
  next_turn_at         timestamptz NOT NULL,  -- set to arrival_time + 5 min on creation
  created_at           timestamptz NOT NULL DEFAULT NOW(),
  updated_at           timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (defender_city_id)  -- one battle per city at a time
);

ALTER TABLE public.battles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.battles REPLICA IDENTITY FULL;

-- Both attacker and defender can read the battle
CREATE POLICY "battles_select_participant"
  ON public.battles FOR SELECT TO authenticated
  USING (attacker_id = auth.uid() OR defender_id = auth.uid());

-- No INSERT/UPDATE/DELETE policies — all mutations via SECURITY DEFINER functions
ALTER PUBLICATION supabase_realtime ADD TABLE public.battles;
```

### Pattern 2: battle_turns Table Schema

**What:** Immutable per-turn result record. One row per turn per battle. INSERT-only by `resolve_battles()`. Both players stream for the live report.

```sql
CREATE TABLE public.battle_turns (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  battle_id        uuid        NOT NULL REFERENCES public.battles(id) ON DELETE CASCADE,
  turn_number      integer     NOT NULL,
  -- Naval phase results (null if no naval units on either side)
  naval_attacker_casualties  jsonb,   -- {"ram_ship": 3, "catapult_ship": 1}
  naval_defender_casualties  jsonb,
  naval_outcome              text CHECK (naval_outcome IN ('attacker_won', 'defender_won', 'ongoing', 'skipped')),
  -- Land phase results (null if naval gate-keeper blocked land)
  land_attacker_casualties   jsonb,
  land_defender_casualties   jsonb,
  land_outcome               text CHECK (land_outcome IN ('attacker_won', 'defender_won', 'ongoing', 'blocked')),
  -- Survivors snapshot at end of this turn
  attacker_survivors         jsonb NOT NULL,
  defender_survivors         jsonb NOT NULL,
  resolved_at                timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (battle_id, turn_number)
);

ALTER TABLE public.battle_turns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.battle_turns REPLICA IDENTITY FULL;

-- Both participants read turn results
CREATE POLICY "battle_turns_select_participant"
  ON public.battle_turns FOR SELECT TO authenticated
  USING (
    battle_id IN (
      SELECT id FROM public.battles
      WHERE attacker_id = auth.uid() OR defender_id = auth.uid()
    )
  );

ALTER PUBLICATION supabase_realtime ADD TABLE public.battle_turns;
```

### Pattern 3: resolve_battles() pg Function

**What:** Called by `battle-tick` cron every minute. For each `battles` row where `next_turn_at <= NOW()` and `status = 'active'`, runs naval phase then land phase, applies casualties, inserts a `battle_turns` row, updates `battles`, and handles end-of-battle conditions.

**Structure:**

```sql
-- Source: follows process_arrivals() pattern (migration 20260311000015)
CREATE OR REPLACE FUNCTION public.resolve_battles()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  b                      RECORD;
  -- Unit stats constants (attack / defense per unit type)
  -- NOTE: Keep in sync with lib/core/constants/unit_constants.dart unitStats
  v_unit_attack          CONSTANT jsonb := '{
    "hoplite":10,"phalanx":15,"archer":20,"cavalry":30,
    "catapult":40,"mortar":50,"medic":0,"cook":0,
    "cargo_ship":5,"ram_ship":25,"catapult_ship":35,
    "mortar_ship":45,"diving_boat":15
  }'::jsonb;
  v_unit_defense         CONSTANT jsonb := '{
    "hoplite":20,"phalanx":30,"archer":15,"cavalry":20,
    "catapult":10,"mortar":10,"medic":5,"cook":5,
    "cargo_ship":10,"ram_ship":20,"catapult_ship":15,
    "mortar_ship":15,"diving_boat":25
  }'::jsonb;
  v_naval_types          CONSTANT text[] := ARRAY[
    'cargo_ship','ram_ship','catapult_ship','mortar_ship','diving_boat'
  ];
  -- Working variables
  v_att_naval_atk        numeric; v_att_naval_def  numeric;
  v_def_naval_atk        numeric; v_def_naval_def  numeric;
  v_att_land_atk         numeric; v_att_land_def   numeric;
  v_def_land_atk         numeric; v_def_land_def   numeric;
  v_att_naval_loss_ratio numeric; v_def_naval_loss_ratio numeric;
  v_att_land_loss_ratio  numeric; v_def_land_loss_ratio  numeric;
  v_new_att_units        jsonb;   v_new_def_units  jsonb;
  v_naval_outcome        text;    v_land_outcome   text;
  v_naval_att_cas        jsonb;   v_naval_def_cas  jsonb;
  v_land_att_cas         jsonb;   v_land_def_cas   jsonb;
  v_wall_level           integer;
  v_wall_bonus           numeric;
  v_att_total_units      bigint;  v_def_total_units bigint;
BEGIN
  FOR b IN
    SELECT id, attacker_id, defender_id,
           defender_city_id, attacker_city_id,
           attacker_units, defender_units,
           turn_number
    FROM public.battles
    WHERE next_turn_at <= NOW()
      AND status = 'active'
  LOOP
    -- [1] Compute naval phase totals
    -- [2] Apply naval casualties; check gate-keeper condition
    -- [3] If naval gate-keeper not triggered, compute land phase totals
    -- [4] Apply land casualties
    -- [5] Check wipeout conditions; update status if battle ended
    -- [6] INSERT battle_turns row
    -- [7] UPDATE battles: new unit counts, turn_number+1, next_turn_at += 5 min
    -- [8] If attacker won: restore surviving units, create return movement
    -- (Full implementation in migration file)
    NULL; -- placeholder — see migration
  END LOOP;
END;
$$;
```

**Key arithmetic (Claude's discretion — recommended values):**

```
-- Loss ratio formula (ratio damage model):
-- attacker_loss_ratio = defender_total_attack / attacker_total_defense
-- casualties for each unit type = floor(quantity * loss_ratio), clamped to [0, quantity]

-- Town Wall bonus (Claude's discretion — 5% per level):
-- defender_land_def_total *= (1.0 + 0.05 * wall_level)

-- Naval gate-keeper: if attacker has no surviving naval after naval phase → battle ends, defender wins
-- Edge case (attacker has no naval, defender has no naval): skip naval phase entirely (naval_outcome = 'skipped')
-- Edge case (attacker has no naval, defender has naval): skip naval phase (naval_outcome = 'skipped') —
--   attacker's land units still fight because there is no naval conflict to resolve
```

### Pattern 4: Modified process_arrivals()

**What:** Add an ownership check before upserting units. If destination city is owned by a different player AND no battle already exists for that city, create a `battles` row.

```sql
-- In process_arrivals(), replace the upsert with a branch:
-- Source: migration 20260311000015_movement_functions.sql (existing function)

-- Pseudocode inside the FOR loop:
IF movement.owner_id = destination_owner_id THEN
  -- Friendly arrival: existing upsert logic
  INSERT INTO city_units ... ON CONFLICT DO UPDATE ...
ELSE
  -- Enemy arrival: check for existing battle
  IF NOT EXISTS (SELECT 1 FROM battles WHERE defender_city_id = m.destination_city_id AND status = 'active') THEN
    -- Create new battle
    INSERT INTO battles (
      defender_city_id, attacker_city_id, attacker_id, defender_id,
      attacker_units, defender_units,
      next_turn_at, status, turn_number
    )
    SELECT
      m.destination_city_id,
      m.origin_city_id,
      m.owner_id,
      c.owner_id,             -- defender owner from cities table
      m.units,                -- attacker army snapshot from movement row
      (SELECT jsonb_object_agg(unit_type, quantity) FROM city_units WHERE city_id = m.destination_city_id),
      NOW() + INTERVAL '5 minutes',
      'active',
      0
    FROM cities c
    WHERE c.id = m.destination_city_id;
  END IF;
  -- If battle already exists: attacker army is lost (rejected — per locked decision)
END IF;

DELETE FROM unit_movements WHERE id = m.id;
```

### Pattern 5: Flutter BattleRepository

**What:** Streams `battles` for the current user (both as attacker and defender) and `battle_turns` for a specific battle. Mirrors `MilitaryRepository` structure.

```dart
// Source: mirrors military_repository.dart pattern

class BattleRepository {
  const BattleRepository();

  /// Stream all battles where current user is attacker or defender.
  /// Realtime .stream() only supports one eq filter — stream by attacker_id,
  /// then also stream by defender_id, merge client-side (or use two providers).
  /// Simpler approach: stream all battles the user participates in via owner_id filter trick.
  ///
  /// NOTE: .stream() does not support OR conditions — use two separate streams
  /// merged via StreamCombineLatest, OR stream by user_id column if added.
  /// Recommended: add user_id index approach — see Architecture note below.
  Stream<List<Battle>> watchMyBattles(String userId) {
    // Stream battles where user is the attacker
    // Client-side filter for defender role (same pattern as watchOutgoingMovements)
    return supabaseClient
        .from('battles')
        .stream(primaryKey: ['id'])
        .eq('attacker_id', userId)  // stream attacker battles
        .map((rows) => rows.map(Battle.fromJson).toList());
    // NOTE: Defender-side battles require a second stream — see Pitfall 3 below.
  }

  Stream<List<BattleTurn>> watchBattleTurns(String battleId) {
    return supabaseClient
        .from('battle_turns')
        .stream(primaryKey: ['id'])
        .eq('battle_id', battleId)
        .order('turn_number')
        .map((rows) => rows.map(BattleTurn.fromJson).toList());
  }
}
```

**Architecture note on the OR-filter problem:** Supabase Realtime `.stream()` does not support compound OR filters (confirmed by Phase 4 decision: "watchOutgoingMovements filters client-side by originCityId after owner_id stream"). The cleanest solution for battles is to create TWO `StreamProvider`s — one keyed by `attacker_id` and one by `defender_id` — and merge them in a computed provider using `StreamZip` or simply maintain two lists client-side and deduplicate.

### Pattern 6: 4th Navigation Tab (Battles)

**What:** Add a `_battlesNavigatorKey` and a 4th `StatefulShellBranch` to `app_router.dart`, and add a 4th `NavigationDestination` to `main_shell_screen.dart`.

```dart
// In app_router.dart — add alongside existing navigator keys:
final _battlesNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'battlesNav');

// In StatefulShellRoute.indexedStack branches list — add as 4th branch:
StatefulShellBranch(
  navigatorKey: _battlesNavigatorKey,
  routes: [
    GoRoute(
      path: '/battles',
      builder: (context, state) => const BattlesScreen(),
    ),
    GoRoute(
      path: '/battle-detail',
      builder: (context, state) => BattleDetailScreen(
        battleId: state.uri.queryParameters['battleId'] ?? '',
      ),
    ),
  ],
),
```

```dart
// In main_shell_screen.dart NavigationBar destinations list — add 4th:
NavigationDestination(
  icon: Icon(Icons.shield_outlined),
  selectedIcon: Icon(Icons.shield),
  label: 'Battles',
),
```

### Anti-Patterns to Avoid

- **Storing unit stats (attack/defense) in the `battles` table:** Stats are game balance constants. Define them inside `resolve_battles()` as local CONSTANT variables (jsonb literals). DB stores counts only; stats live in code (same decision established in Phase 4 research).
- **Triggering battle resolution from the Flutter client:** CMBT-05 — all calculations are server-side. The client never calls an Edge Function to resolve a turn. Only `battle-tick` pg_cron triggers `resolve_battles()`.
- **Writing battle results directly to `city_units` during resolution:** Casualties are tracked in JSONB snapshots inside `battles`. Only when the battle ENDS does `resolve_battles()` call `deduct_units()` (for the final removal) or re-insert attacker's survivors via a new `unit_movements` row for the return trip.
- **Streaming all battles without RLS scoping:** The RLS policy must include both `attacker_id = auth.uid()` AND `defender_id = auth.uid()`. Without this, players would only see battles where they attacked.
- **Forgetting to snapshot defender_units at battle creation:** `process_arrivals()` must capture `city_units` as a JSONB snapshot when creating the battle row. After the battle starts, the `city_units` table for the defender is NOT decremented — the battle snapshot is authoritative until battle end.
- **Defender's city_units not decremented at battle start:** The defender's units are "engaged" in the battle snapshot. After battle end, if the defender wins, their `city_units` must be updated to match the surviving snapshot. If the attacker wins, the defender's units are already zero in `city_units` (they were snapshotted at start but the table row was not touched — so `city_units` must be wiped for the defender city after attacker victory).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Battle turn timer | Flutter Dart Timer that fires an Edge Function every 5 min | `battle-tick` pg_cron every minute checking `next_turn_at <= NOW()` | Client may be offline; server must be authoritative; same rationale as construction-tick |
| Real-time battle updates | HTTP polling from Flutter every N seconds | Supabase Realtime `.stream()` on `battles` + `battle_turns` | Already established pattern for all game tables; zero-polling push updates |
| Naval/land unit classification | Runtime string matching in resolution function | `v_naval_types CONSTANT text[]` in pg function + `UnitType.isNaval` in Dart | Classification is a constant; define once in each context |
| Return trip after attacker wins | Custom distance query in resolution function | Reuse `calcTravelMinutes` constants and insert a `unit_movements` row | `process_arrivals()` already handles delivery on the other end; no new infrastructure needed |
| Casualty calculation | Custom damage table in DB | Simple ratio formula in `resolve_battles()` pg function body | Formula is 3 lines of SQL arithmetic; no table needed |

**Key insight:** The battle system is a new pg_cron tick + two new Realtime tables. The hard part (pg_cron, JSONB, Realtime streams, StreamProvider patterns) is already battle-tested in Phases 2–4.

---

## Common Pitfalls

### Pitfall 1: Defender city_units not updated after battle ends

**What goes wrong:** `resolve_battles()` correctly updates `battles.attacker_units` and `battles.defender_units` each turn, but when the battle ends (one side wiped), the actual `city_units` table still shows pre-battle counts for the defender.

**Why it happens:** Battles operate on JSONB snapshots, not live `city_units` rows. The snapshot and the table diverge from turn 1.

**How to avoid:** When `resolve_battles()` detects battle end (status becomes 'attacker_won' or 'defender_won'):
- **Attacker won:** Zero out defender's `city_units` for the battle's unit types (UPDATE SET quantity = 0 for engaged types) OR just delete defender rows for types that are now 0.
- **Defender won:** Update defender's `city_units` to match the surviving snapshot. Insert a return `unit_movements` row for the attacker? No — attacker units are already gone (defender won).
- **Attacker won:** Insert a new `unit_movements` row for the surviving attacker units to travel home.

**Warning signs:** After a battle, defender's army roster in-game shows the pre-battle count.

### Pitfall 2: UNIQUE(defender_city_id) on battles blocks concurrent battle creation

**What goes wrong:** `process_arrivals()` is called by pg_cron every minute. If two different armies arrive at the same enemy city in the same minute, both try to INSERT into `battles` for the same `defender_city_id`. The second INSERT fails with a unique violation.

**Why it happens:** The UNIQUE constraint is correct and desired (one battle at a time per city). But `process_arrivals()` must handle this gracefully.

**How to avoid:** Use `INSERT ... ON CONFLICT (defender_city_id) DO NOTHING` when creating battles, OR check for existing active battle before inserting. Per the locked decision: "new arriving armies are rejected/queued" — the movement row is deleted (army lost) if a battle is already active. The conflict handling is: delete the movement row, do not create a second battle.

**Warning signs:** pg_cron logs showing unique_violation errors from process_arrivals.

### Pitfall 3: Realtime .stream() cannot filter battles for both attacker and defender

**What goes wrong:** `.stream().eq('attacker_id', userId)` only returns battles where the user attacked. A defending player would see no battles in their "Battles" tab.

**Why it happens:** Supabase Realtime `.stream()` does not support OR conditions — this is an established project limitation (decision [04-03]: "watchOutgoingMovements filters client-side by originCityId after owner_id stream").

**How to avoid:** Use TWO separate `StreamProvider`s:
- `attackerBattlesProvider(userId)` — streams `battles` eq('attacker_id', userId)
- `defenderBattlesProvider(userId)` — streams `battles` eq('defender_id', userId)

Merge in a `combiningProvider` or render both lists in `BattlesScreen`. The RLS policy allows both reads; it's purely a client-side stream issue.

**Warning signs:** Player attacks someone but never sees the battle in the defender's "Battles" tab.

### Pitfall 4: Snapshot stale — defender trains units during a battle

**What goes wrong:** After battle creation snapshots `defender_units`, the defender continues training units. The new units appear in `city_units` but NOT in the battle. The attacker wins based on a stale, smaller defender army.

**Why it happens:** The battle snapshot is immutable at creation time. This is by design for v1 (no reinforcements — CMBT-06 is v2). However, the defender's `city_units` must not be decremented at battle start, or new training completions would add units to `city_units` that are "phantom" (not in the battle).

**How to avoid:** This is an accepted v1 limitation (no reinforcements). The battle snapshot is the source of truth for the battle. The player-facing design note: units trained during a battle stay in the garrison but cannot affect the ongoing battle.

**Warning signs:** None — this is by design. Document it in the battle UI as "Units trained during battle will reinforce your garrison but not the active battle."

### Pitfall 5: pg function CONSTANT jsonb for unit stats is case-sensitive

**What goes wrong:** Unit type strings in `city_units` are snake_case ('ram_ship') but a typo in the pg function's CONSTANT jsonb ('ram_Ship') silently returns NULL when looked up, making those units contribute 0 attack/defense.

**Why it happens:** PostgreSQL `jsonb -> key` lookup is case-sensitive. A mismatched key returns NULL.

**How to avoid:** Unit type keys in the pg function CONSTANT jsonb MUST exactly match the `city_units.unit_type` CHECK constraint values (enforced in migration 20260311000011). Add a comment referencing the constraint. Test with a known unit type to verify the lookup returns a non-null value.

**Warning signs:** Battles resolve but certain unit types always show 0 casualties regardless of quantity.

### Pitfall 6: battle-tick cron resolves the same battle twice in the same minute

**What goes wrong:** `battle-tick` runs every minute. If `resolve_battles()` takes >0 seconds to process a battle and a second cron firing catches a battle row that hasn't been updated yet (race condition), the same turn could be processed twice.

**Why it happens:** Very unlikely with a 1-minute cron interval since PostgreSQL serializes concurrent writes. But if the cron job is run manually while another tick is in progress, or if clock skew causes a tick to fire within the same second, a duplicate could occur.

**How to avoid:** Inside the FOR loop in `resolve_battles()`, use `SELECT ... FOR UPDATE SKIP LOCKED`. This is the same advisory lock pattern used in `process_arrivals()` style functions. Any concurrent call to `resolve_battles()` will skip rows already being processed.

**Warning signs:** `battle_turns` showing duplicate rows with the same `(battle_id, turn_number)` (caught by the UNIQUE constraint which would raise an error).

---

## Code Examples

Verified patterns from existing project code:

### Battle model (mirrors UnitMovement.fromJson pattern)

```dart
// Source: mirrors lib/features/military/models/unit_movement.dart
class Battle {
  const Battle({
    required this.id,
    required this.defenderCityId,
    required this.attackerCityId,
    required this.attackerId,
    required this.defenderId,
    required this.attackerUnits,   // Map<String, int>
    required this.defenderUnits,
    required this.status,
    required this.turnNumber,
    required this.nextTurnAt,
    required this.createdAt,
  });

  final String id;
  final String defenderCityId;
  final String attackerCityId;
  final String attackerId;
  final String defenderId;
  final Map<String, int> attackerUnits;
  final Map<String, int> defenderUnits;
  final String status;  // 'active' | 'attacker_won' | 'defender_won'
  final int turnNumber;
  final DateTime nextTurnAt;
  final DateTime createdAt;

  bool get isActive => status == 'active';

  factory Battle.fromJson(Map<String, dynamic> json) {
    return Battle(
      id:               json['id'] as String,
      defenderCityId:   json['defender_city_id'] as String,
      attackerCityId:   json['attacker_city_id'] as String,
      attackerId:       json['attacker_id'] as String,
      defenderId:       json['defender_id'] as String,
      attackerUnits:    (json['attacker_units'] as Map<String, dynamic>)
                          .map((k, v) => MapEntry(k, v as int)),
      defenderUnits:    (json['defender_units'] as Map<String, dynamic>)
                          .map((k, v) => MapEntry(k, v as int)),
      status:           json['status'] as String,
      turnNumber:       json['turn_number'] as int,
      nextTurnAt:       DateTime.parse(json['next_turn_at'] as String).toUtc(),
      createdAt:        DateTime.parse(json['created_at'] as String).toUtc(),
    );
  }
}
```

### BattleTurn model

```dart
class BattleTurn {
  const BattleTurn({
    required this.id,
    required this.battleId,
    required this.turnNumber,
    this.navalAttackerCasualties,
    this.navalDefenderCasualties,
    this.navalOutcome,
    this.landAttackerCasualties,
    this.landDefenderCasualties,
    this.landOutcome,
    required this.attackerSurvivors,
    required this.defenderSurvivors,
    required this.resolvedAt,
  });

  final String id;
  final String battleId;
  final int turnNumber;
  final Map<String, int>? navalAttackerCasualties;
  final Map<String, int>? navalDefenderCasualties;
  final String? navalOutcome;  // 'attacker_won'|'defender_won'|'ongoing'|'skipped'
  final Map<String, int>? landAttackerCasualties;
  final Map<String, int>? landDefenderCasualties;
  final String? landOutcome;   // 'attacker_won'|'defender_won'|'ongoing'|'blocked'
  final Map<String, int> attackerSurvivors;
  final Map<String, int> defenderSurvivors;
  final DateTime resolvedAt;

  static Map<String, int>? _parseUnits(dynamic raw) {
    if (raw == null) return null;
    return (raw as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int));
  }

  factory BattleTurn.fromJson(Map<String, dynamic> json) {
    return BattleTurn(
      id:                       json['id'] as String,
      battleId:                 json['battle_id'] as String,
      turnNumber:               json['turn_number'] as int,
      navalAttackerCasualties:  _parseUnits(json['naval_attacker_casualties']),
      navalDefenderCasualties:  _parseUnits(json['naval_defender_casualties']),
      navalOutcome:             json['naval_outcome'] as String?,
      landAttackerCasualties:   _parseUnits(json['land_attacker_casualties']),
      landDefenderCasualties:   _parseUnits(json['land_defender_casualties']),
      landOutcome:              json['land_outcome'] as String?,
      attackerSurvivors:        _parseUnits(json['attacker_survivors'])!,
      defenderSurvivors:        _parseUnits(json['defender_survivors'])!,
      resolvedAt:               DateTime.parse(json['resolved_at'] as String).toUtc(),
    );
  }
}
```

### Dual-stream provider pattern for battles (attacker + defender)

```dart
// Source: established StreamProvider.autoDispose.family pattern in project
// Merges attacker and defender battle streams client-side

final attackerBattlesProvider =
    StreamProvider.autoDispose.family<List<Battle>, String>(
  (ref, userId) => ref.read(battleRepositoryProvider).watchBattlesAsAttacker(userId),
);

final defenderBattlesProvider =
    StreamProvider.autoDispose.family<List<Battle>, String>(
  (ref, userId) => ref.read(battleRepositoryProvider).watchBattlesAsDefender(userId),
);

// Combined provider: merge both streams into a deduplicated list
final allMyBattlesProvider =
    Provider.autoDispose<AsyncValue<List<Battle>>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const AsyncValue.data([]);

  final attackerAsync = ref.watch(attackerBattlesProvider(userId));
  final defenderAsync = ref.watch(defenderBattlesProvider(userId));

  return attackerAsync.whenData((attBattles) {
    return defenderAsync.whenData((defBattles) {
      final seen = <String>{};
      return [...attBattles, ...defBattles]
          .where((b) => seen.add(b.id))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }).valueOrNull ?? attBattles;
  });
});
```

### process_arrivals() modification — ownership branch

```sql
-- Source: extends migration 20260311000015_movement_functions.sql
-- Inside the FOR loop, replace the unconditional upsert with:

DECLARE
  v_dest_owner_id  uuid;
  v_def_units_snap jsonb;
BEGIN
  -- [existing loop setup]

  -- Get destination city owner
  SELECT owner_id INTO v_dest_owner_id
  FROM public.cities WHERE id = m.destination_city_id;

  IF m.owner_id = v_dest_owner_id THEN
    -- Friendly arrival: upsert units (existing logic unchanged)
    FOR v_type, v_qty_txt IN SELECT key, value FROM jsonb_each_text(m.units) LOOP
      v_qty := v_qty_txt::integer;
      INSERT INTO public.city_units (city_id, unit_type, quantity, updated_at)
      VALUES (m.destination_city_id, v_type, v_qty, NOW())
      ON CONFLICT (city_id, unit_type)
      DO UPDATE SET quantity = public.city_units.quantity + EXCLUDED.quantity,
                   updated_at = NOW();
    END LOOP;
  ELSE
    -- Enemy arrival: create battle if none active for this city
    IF NOT EXISTS (
      SELECT 1 FROM public.battles
      WHERE defender_city_id = m.destination_city_id AND status = 'active'
    ) THEN
      -- Snapshot defender's current army
      SELECT COALESCE(jsonb_object_agg(unit_type, quantity), '{}'::jsonb)
      INTO v_def_units_snap
      FROM public.city_units
      WHERE city_id = m.destination_city_id AND quantity > 0;

      INSERT INTO public.battles (
        defender_city_id, attacker_city_id,
        attacker_id, defender_id,
        attacker_units, defender_units,
        next_turn_at, status, turn_number
      ) VALUES (
        m.destination_city_id, m.origin_city_id,
        m.owner_id, v_dest_owner_id,
        m.units, v_def_units_snap,
        NOW() + INTERVAL '5 minutes',
        'active', 0
      );
    END IF;
    -- If battle already active: army is lost (rejected per locked decision)
  END IF;

  DELETE FROM public.unit_movements WHERE id = m.id;
END;
```

### battle-tick cron registration

```sql
-- Source: follows migration 20260311000016_military_cron_jobs.sql pattern
-- pg_cron extension already enabled — do NOT create again

SELECT cron.schedule(
  'battle-tick',
  '* * * * *',
  'SELECT public.resolve_battles()'
);
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Storing unit stats in DB table | Constants in pg function body + Dart constants | Phase 4 research decision | Stats rebalanceable without DB migration; pg function reads them as local constants |
| Client-side battle resolution | Server-only `resolve_battles()` pg function | INFR-02 from Phase 1 | CMBT-05 compliance; no cheat path |
| Polling for battle updates | Supabase Realtime on `battles` + `battle_turns` | Phase 2 pattern established | Zero-polling live UI; updates push to both players simultaneously |
| Separate join table for battle armies | JSONB snapshot in `battles` | Phase 4 JSONB snapshot decision | Consistent with `unit_movements.units`; simpler resolution queries |

**Deprecated/outdated:**
- Anything that writes to `battles` or `battle_turns` from Flutter: all writes are SECURITY DEFINER pg functions only.

---

## Open Questions

1. **Defender city_units write-back after battle ends**
   - What we know: `battles.defender_units` is the authoritative count during battle; `city_units` table is not touched during the battle.
   - What's unclear: How precisely to reconcile `city_units` after battle ends — UPDATE surviving unit counts vs DELETE all and re-insert.
   - Recommendation: At battle end in `resolve_battles()`, iterate over `battles.defender_units` survivors JSONB and UPDATE `city_units` for each unit type (SET quantity = survivor_count). For unit types with 0 survivors, UPDATE SET quantity = 0 (the CHECK constraint allows 0). This avoids DELETE/re-INSERT complexity.

2. **Attacker has no naval, defender has naval — gate-keeper behavior**
   - What we know: Naval gate-keeper: "if defender wins naval phase, attacker retreats." If attacker has no naval units, there is no naval phase to win.
   - What's unclear: Should this count as "defender wins naval" (attacker can't land) or "naval phase skipped" (land units engage freely)?
   - Recommendation (Claude's discretion): If attacker has no naval AND defender has naval, treat as "naval phase skipped" — the attacker's land units still engage. The naval gate-keeper only activates if both sides have naval units and the defender's naval force survives. Rationale: the gate-keeper is about naval combat, not naval presence. An attacker with no ships can still land troops if the defender never contests the sea.

3. **How are rejected armies (city already in battle) handled in the UI?**
   - What we know: Movement row is deleted, army is lost per the locked decision.
   - What's unclear: Does the attacker receive any notification?
   - Recommendation (Claude's discretion): When `unit_movements` row is deleted by `process_arrivals()`, Realtime fires a DELETE event to the attacker's client (already subscribed via `unit_movements_provider`). The UI can detect the disappearance of the movement and infer the army was rejected. No special notification needed in v1 — the army simply disappears from the "in transit" list. Optionally add a "battle_rejected" status to `unit_movements` before deletion, but this is a UX polish item.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK, Dart 3.10.1) |
| Config file | none (uses default flutter test runner) |
| Quick run command | `flutter test test/unit/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CMBT-01 | Battle.fromJson parses next_turn_at correctly; isActive returns true for 'active' status | unit | `flutter test test/unit/battle_models_test.dart` | ❌ Wave 0 |
| CMBT-02 | BattleTurn.fromJson parses attacker/defender survivors JSONB correctly | unit | `flutter test test/unit/battle_models_test.dart` | ❌ Wave 0 |
| CMBT-03 | BattleTurn.fromJson parses navalOutcome and landOutcome correctly; 'skipped' and 'blocked' values parse without error | unit | `flutter test test/unit/battle_models_test.dart` | ❌ Wave 0 |
| CMBT-04 | BattleRepository.watchBattleTurns returns correct stream type; Battle.fromJson round-trips without loss | unit | `flutter test test/unit/battle_models_test.dart` | ❌ Wave 0 |
| CMBT-05 | No Flutter write paths exist to battles or battle_turns tables (no direct .insert/.update/.delete calls in BattleRepository) | unit | `flutter test test/unit/battle_models_test.dart` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/unit/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/unit/battle_models_test.dart` — covers CMBT-01 through CMBT-05: Battle.fromJson, BattleTurn.fromJson, status checks, JSONB map parsing, nullable phase fields

*(No new framework install needed — flutter_test already in use)*

---

## Sources

### Primary (HIGH confidence)
- Project codebase (directly read):
  - `supabase/migrations/20260311000015_movement_functions.sql` — process_arrivals() base function to modify
  - `supabase/migrations/20260311000013_create_unit_movements.sql` — JSONB snapshot pattern to replicate
  - `supabase/migrations/20260311000011_create_city_units.sql` — city_units schema (unit type CHECK constraint)
  - `supabase/migrations/20260311000016_military_cron_jobs.sql` — cron job registration pattern
  - `supabase/migrations/20260311000010_pg_cron_jobs.sql` — pg_cron extension registration (do not repeat)
  - `supabase/functions/dispatch-units/index.ts` — Edge Function structure and auth pattern
  - `lib/core/constants/unit_constants.dart` — UnitType enum, isNaval getter, existing stats
  - `lib/features/military/data/military_repository.dart` — StreamProvider + Edge Function invocation pattern
  - `lib/core/router/app_router.dart` — StatefulShellRoute + navigator key pattern for 4th tab
  - `lib/features/map/screens/main_shell_screen.dart` — NavigationBar destinations for 4th tab
  - `lib/features/city/widgets/countdown_timer_widget.dart` — CountdownTimerWidget reuse pattern
  - `.planning/phases/05-combat/05-CONTEXT.md` — all locked decisions
  - `.planning/STATE.md` — project-wide decisions (non-atomic deductions, RLS pattern, Realtime compound filter limitation)

### Secondary (MEDIUM confidence)
- Phase 4 RESEARCH.md — unit stats design decision (store stats as constants, not DB rows); JSONB snapshot rationale
- PostgreSQL docs: `SELECT ... FOR UPDATE SKIP LOCKED` — advisory locking pattern for concurrent cron jobs

### Tertiary (LOW confidence — validate in implementation)
- Unit attack/defense stat values (hoplite: 10 atk / 20 def, etc.) — Claude's discretion; no locked values in requirements; the exact numbers are placeholder estimates requiring game balance testing
- Town Wall bonus: 5% per level — Claude's discretion; reasonable starting estimate
- Naval gate-keeper edge case resolution (attacker no naval + defender has naval = skip, not auto-lose) — Claude's discretion per CONTEXT.md

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all technologies already in use; no new libraries
- Architecture (battles table + battle_turns table): HIGH — direct extension of existing JSONB + Realtime pattern
- Architecture (resolve_battles() pg function): HIGH — pattern matches process_arrivals() and complete_training() exactly
- Architecture (modified process_arrivals()): HIGH — ownership check is a simple branch on an existing function
- Architecture (4th navigation tab): HIGH — StatefulShellBranch pattern is fully understood from Phase 3/4
- Unit stats (attack/defense values): LOW — game balance values; reasonable estimates, need iteration
- Casualty formula coefficients: LOW — Claude's discretion; ratio damage formula is correct; coefficients need playtesting
- Town Wall bonus: LOW — 5%/level is reasonable; needs playtesting

**Research date:** 2026-03-12
**Valid until:** 2026-04-11 (all technologies stable; pg_cron, Supabase Realtime, Flutter APIs unchanged)
