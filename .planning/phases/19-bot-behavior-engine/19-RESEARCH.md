# Phase 19: Bot Behavior Engine - Research

**Researched:** 2026-03-17
**Domain:** PL/pgSQL bot decision engine — pg_cron + SECURITY DEFINER functions writing to game tables
**Confidence:** HIGH (all key facts verified directly from codebase migrations, Edge Functions, and prior ARCHITECTURE.md research)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Decision priority chain:**
- One action per tick per bot — no multi-action ticks
- Priority order: upgrade building → train units → attack (aggression-gated)
- If a higher-priority action succeeds (e.g., upgrade queued), skip lower priorities
- Fall through chain if action is not possible (e.g., no resources for upgrade → try train → try attack)

**Building upgrade logic:**
- Bot selects the lowest-level building in its city that it can afford to upgrade
- Skip if construction_queue already has a pending entry for this city
- Include island resource donations: if all city buildings are at max level or queue is full, donate wood to island resource building instead
- Check city_resources before attempting — skip if insufficient resources

**Unit training logic:**
- Train the cheapest affordable land unit type to fill gaps in army
- Skip if training_queue already has a pending entry for this city
- Check city_resources before attempting — skip if insufficient resources
- No preference for specific unit compositions — simple "fill cheapest first" approach

**Attack behavior:**
- Bot must have at least 5 land units before considering an attack
- Target selection: random non-bot city on the same island; if no valid target on same island, pick from neighboring islands
- Send 50-75% of available land units (random within range)
- No cooldown or anti-repeat logic — keep simple for v1.3
- Writes directly to unit_movements table (same as dispatch-units Edge Function)

**Aggression mapping:**
- Aggression 0 = never attack (passive bot)
- Aggression 1 = attack ~33% of eligible ticks (random() < 1/3.0)
- Aggression 2 = attack ~66% of eligible ticks (random() < 2/3.0)
- Aggression 3 = attack every eligible tick
- Aggression only gates attack probability — does not affect upgrade or training behavior
- Probability check: `random() < (aggression / 3.0)` before calling bot_decide_attack

**Tick scheduling:**
- Single `bot-think-tick` pg_cron job at `*/15 * * * *` calling `run_bot_decisions()`
- After each bot is processed, stagger next_action_at: `NOW() + INTERVAL '15 minutes' + (random() * INTERVAL '5 minutes')` to avoid all bots firing simultaneously
- Only process bots where `is_paused = false AND next_action_at <= NOW()`

**Resource awareness:**
- All actions check city_resources before attempting — skip if insufficient
- No resource saving or hoarding logic — bots act whenever they can afford to
- Fall-through priority chain naturally handles "too poor to upgrade but can train" scenarios

### Claude's Discretion
- Exact SQL implementation details for helper functions
- Whether to use CTEs or subqueries in bot decision functions
- Index strategy on bot_schedules.next_action_at (may or may not be needed for 20 bots)
- Error handling within run_bot_decisions (EXCEPTION blocks, logging)
- Exact unit count calculation for "cheapest affordable unit"

### Deferred Ideas (OUT OF SCOPE)
- Bot archetypes (militarist, economist, builder) with weighted decision-making — v1.3+ (BOT-F01)
- Bot difficulty scaling based on player progression — v1.3+ (BOT-F03)
- Bot-to-bot diplomacy and coordinated attacks — requires alliance system (BOT-F02)
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| BOT-02 | Bots periodically attack neighboring cities via pg_cron schedule | bot_decide_attack() inserts to unit_movements; process_arrivals() handles delivery without modification |
| BOT-03 | Bots retrain armies after suffering losses | bot_decide_train() checks city_units totals vs threshold; inserts to training_queue; complete_training() handles completion |
| BOT-04 | Bots upgrade island resource buildings they occupy | bot_decide_upgrade() fallback: donate wood to islands.resource_level; mirrors donate-island-wood Edge Function logic |
| BOT-05 | Bots upgrade buildings in their own cities | bot_decide_upgrade() primary path: selects cheapest affordable building; inserts to construction_queue; complete_building_upgrades() handles completion |
</phase_requirements>

---

## Summary

Phase 19 implements the Bot Behavior Engine entirely in PL/pgSQL with three helper functions
(`bot_decide_upgrade`, `bot_decide_train`, `bot_decide_attack`) orchestrated by a top-level
`run_bot_decisions()` function called every 15 minutes via pg_cron. All bot actions write directly
to the same game tables (`construction_queue`, `training_queue`, `unit_movements`) that Edge
Functions write to — the existing processing ticks handle bot completions without any modification.

The implementation is pure server-side SQL with no Flutter code changes. The critical design
principle is that bot decision functions are SECURITY DEFINER, bypassing RLS the same way all
existing cron functions do. Business rule validation (cost checks, queue checks) must mirror
the equivalent Edge Function logic to maintain game integrity.

Phase 18 (already complete) provides the required foundation: `profiles.is_bot`, `profiles.is_admin`,
and the `bot_schedules` table (with `is_paused`, `aggression`, `next_action_at` columns) are all
live in migration `20260317000001_bot_schema.sql`.

**Primary recommendation:** Write three migrations — one for the three helper functions, one for
`run_bot_decisions()`, one for the pg_cron job registration. Keep each helper function narrowly
focused: SELECT data, check preconditions, INSERT/UPDATE, return boolean.

---

## Standard Stack

### Core
| Component | Version/Location | Purpose | Why Standard |
|-----------|-----------------|---------|--------------|
| PL/pgSQL | Postgres (Supabase local) | All bot decision logic | Already used for all cron tick functions |
| pg_cron | `pg_catalog` schema (enabled in migration `20260311000010`) | Scheduling `bot-think-tick` at `*/15 * * * *` | Same extension used for all 5 existing game ticks |
| SECURITY DEFINER SET search_path = '' | Pattern | Bypass RLS in bot functions | Used in every existing cron function; bot functions follow identical pattern |

### Existing Tables Bot Functions Write To
| Table | Migration | Constraint to Respect |
|-------|-----------|----------------------|
| `construction_queue` | `20260311000009` | `UNIQUE(city_id)` — one build per city at a time |
| `training_queue` | `20260311000012` | `UNIQUE(city_id)` — one training per city at a time |
| `unit_movements` | `20260311000013` | `CHECK(origin_city_id <> destination_city_id)`; requires `owner_id`, `units` JSONB, `depart_at`, `arrive_at` |
| `city_resources` | existing | Use `deduct_resource()` / `deduct_resources()` RPC to deduct; do not UPDATE directly |
| `city_units` | existing | Use `deduct_units()` RPC to deduct for attacks |
| `bot_schedules` | `20260317000001_bot_schema.sql` | Update `next_action_at` after each bot is processed |

### Supporting
| Component | Purpose | When to Use |
|-----------|---------|-------------|
| `deduct_resource(p_city_id, p_resource_type, p_amount)` | Atomic resource deduction with insufficient-guard | bot_decide_upgrade and bot_decide_train resource deduction |
| `deduct_units(p_city_id, p_unit_type, p_quantity)` | Atomic unit deduction | bot_decide_attack unit deduction before unit_movements INSERT |
| `random()` | PostgreSQL built-in | Aggression probability check; unit send ratio (50-75%); next_action_at stagger |

**No new extensions needed.** All required extensions are already installed.

---

## Architecture Patterns

### Migration Structure (three files)

```
supabase/migrations/
├── 2026031X000001_bot_helper_functions.sql   -- bot_decide_upgrade, bot_decide_train, bot_decide_attack
├── 2026031X000002_bot_run_decisions.sql       -- run_bot_decisions() orchestrator
└── 2026031X000003_bot_cron_job.sql            -- cron.schedule('bot-think-tick', ...)
```

Splitting into three migrations allows independent replacement of helper functions without
touching the orchestrator or cron registration.

### Pattern: SECURITY DEFINER Cron Function (from existing codebase)

All existing cron functions follow this exact pattern:

```sql
-- Source: supabase/migrations/20260311000009_construction_functions.sql
CREATE OR REPLACE FUNCTION public.complete_building_upgrades()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  q RECORD;
BEGIN
  FOR q IN
    SELECT id, city_id, building_type, target_level
    FROM public.construction_queue
    WHERE finish_at <= NOW()
  LOOP
    -- DML here
  END LOOP;
END;
$$;
```

Bot functions MUST follow this same signature pattern.

### Pattern: pg_cron Job Registration (from existing codebase)

```sql
-- Source: supabase/migrations/20260311000010_pg_cron_jobs.sql
SELECT cron.schedule(
  'resource-tick',
  '*/5 * * * *',
  'SELECT public.process_resource_tick()'
);
```

Bot cron job registration:
```sql
SELECT cron.schedule(
  'bot-think-tick',
  '*/15 * * * *',
  'SELECT public.run_bot_decisions()'
);
```

### run_bot_decisions() Orchestrator (near-complete reference from ARCHITECTURE.md)

```sql
-- Source: .planning/research/ARCHITECTURE.md
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
    -- Stagger next action to avoid thundering herd
    UPDATE public.bot_schedules
      SET next_action_at = NOW() + INTERVAL '15 minutes'
                           + (random() * INTERVAL '5 minutes')
      WHERE bot_id = bot.bot_id;
  END LOOP;
END;
$$;
```

### bot_decide_upgrade() Logic Map

The function mirrors the validation logic of `upgrade-building/index.ts` and the
fallback mirrors `donate-island-wood/index.ts`:

```
bot_decide_upgrade(p_city_id uuid) RETURNS boolean

1. Check construction_queue: does any row exist for this city?
   → YES: RETURN false (busy)

2. SELECT city_buildings ordered by level ASC to find cheapest upgradeable building
   Cost formula (from upgrade-building/index.ts):
     cost[resource] = CEIL(base_cost[resource] * 1.5^current_level)
   Building base costs (wood, marble, gold, crystal, sulfur) — must match Edge Function
   BASE_COSTS table exactly.

3. Check city_resources: can the city afford cost for the chosen building?
   → NO for all buildings: fall through to island donation check

4. Island donation fallback:
   SELECT islands.resource_level WHERE id = (SELECT island_id FROM cities WHERE id = p_city_id)
   Island donation cost: CEIL(300 * 1.5^resource_level) [from donate-island-wood/index.ts]
   Check city wood resource >= donation cost AND resource_level < 10
   → YES: deduct wood via deduct_resource(), UPDATE islands SET resource_level = resource_level + 1
          RETURN true
   → NO: RETURN false

5. If affordable building found:
   → deduct resources via deduct_resource() for each resource type
   → calculate finish_at: NOW() + CEIL(base_time * 1.2^current_level) minutes
   → INSERT construction_queue (city_id, building_type, target_level, finish_at)
   → RETURN true
```

**Building base costs (must match upgrade-building/index.ts BASE_COSTS exactly):**
```
town_hall:    gold: 100, wood: 200
warehouse:    wood: 100, marble: 50
barracks:     wood: 150, gold: 100
shipyard:     wood: 200, marble: 100, gold: 150
academy:      wood: 100, crystal: 100, gold: 200
embassy:      wood: 80, marble: 80, gold: 100
trading_port: wood: 150, gold: 120
town_wall:    wood: 200, marble: 150
hideout:      wood: 100, gold: 80
tavern:       wood: 120, gold: 100
sawmill:      wood: 50, gold: 50
quarry:       wood: 80, marble: 30
glassblower:  wood: 80, crystal: 30
sulfur_pit:   wood: 80, sulfur: 30
```

**Building base times (minutes, must match upgrade-building/index.ts BASE_TIMES):**
```
All buildings: 1 minute base (reduced to 1/10 for testing)
Duration formula: CEIL(1 * 1.2^current_level)
```

### bot_decide_train() Logic Map

Mirrors `train-units/index.ts` validation:

```
bot_decide_train(p_city_id uuid) RETURNS boolean

1. Check training_queue: does any row exist for this city?
   → YES: RETURN false (busy)

2. Determine cheapest affordable land unit:
   Land units only (barracks): hoplite, phalanx, archer, cavalry, catapult, mortar, medic, cook
   Sort by total cost ascending (sum of all resources * 1 unit)
   Check barracks level for unlock requirement (UNIT_UNLOCK_LEVELS from train-units/index.ts)
   Check city_resources can afford 1 unit of that type

3. No affordable land unit found → RETURN false

4. Calculate quantity: train as many as affordable (up to MAX_QUANTITY = 50)
   quantity = MIN(50, FLOOR(min_resource / per_unit_cost_for_limiting_resource))

5. Deduct resources via deduct_resource() for each resource type * quantity

6. Calculate finish_at:
   duration = CEIL(base_time[unit_type] * quantity * dev_speed_multiplier)
   Dev: DEV_SPEED_MULTIPLIER = 0.2 (1/5)  [from train-units/index.ts]
   Production: DEV_SPEED_MULTIPLIER = 1.0

7. INSERT training_queue (city_id, unit_type, quantity, finish_at)
   RETURN true
```

**Unit unlock requirements (must match train-units/index.ts UNIT_UNLOCK_LEVELS):**
```
hoplite: barracks >= 1    phalanx: barracks >= 2
archer:  barracks >= 2    cavalry: barracks >= 3
catapult: barracks >= 4   mortar: barracks >= 5
medic:   barracks >= 3    cook:    barracks >= 1
```

**Land unit costs per unit (must match UNIT_BASE_COSTS):**
```
hoplite:  wood: 40, gold: 30         (cheapest — 70 total)
cook:     wood: 20, gold: 20         (cheapest — 40 total)
phalanx:  wood: 60, marble: 20, gold: 50
archer:   wood: 50, crystal: 20, gold: 40
cavalry:  wood: 80, gold: 100
catapult: wood: 120, sulfur: 30, gold: 80
mortar:   wood: 100, sulfur: 50, gold: 120
medic:    wood: 30, crystal: 30, gold: 60
```

Note: cook (40 total) is cheapest, requires barracks >= 1. hoplite (70 total) is second cheapest.
"Cheapest affordable" should order by sum of resource costs and check affordability per type.

### bot_decide_attack() Logic Map

Mirrors `dispatch-units/index.ts` logic:

```
bot_decide_attack(p_city_id uuid, p_aggression integer) RETURNS void

1. Aggression probability gate:
   IF random() >= (p_aggression / 3.0) THEN RETURN (no attack this tick)

2. Count total land units available:
   SELECT SUM(quantity) FROM city_units WHERE city_id = p_city_id
     AND unit_type IN ('hoplite','phalanx','archer','cavalry','catapult','mortar','medic','cook')
   IF total < 5 THEN RETURN (not enough army)

3. Target selection:
   First try: random non-bot city on same island
     SELECT c.id FROM cities c
     JOIN profiles p ON p.id = c.owner_id
     WHERE c.island_id = (SELECT island_id FROM cities WHERE id = p_city_id)
       AND c.id <> p_city_id
       AND p.is_bot = false
     ORDER BY random() LIMIT 1

   If no result: random non-bot city on neighboring islands
     SELECT c.id FROM cities c
     JOIN profiles p ON p.id = c.owner_id
     JOIN cities origin ON origin.id = p_city_id
     JOIN islands i ON i.id = c.island_id
     JOIN islands origin_i ON origin_i.id = origin.island_id
     WHERE p.is_bot = false
       AND c.id <> p_city_id
     ORDER BY random() LIMIT 1

   If still no result: RETURN (no valid target)

4. Calculate units to send: 50-75% of land units
   send_count = FLOOR(total * (0.50 + random() * 0.25))
   Distribute proportionally across unit types, or send all of cheapest type

5. Get island coordinates for travel time:
   SELECT grid_x, grid_y FROM islands WHERE id = (bot's island_id)
   SELECT grid_x, grid_y FROM islands WHERE id = (target's island_id)
   Travel formula (from dispatch-units/index.ts):
     distance = sqrt(dx^2 + dy^2)
     travel_minutes = MAX(1, CEIL(distance * 2))  -- base 2 min/grid in production
     In dev: travel_minutes = MAX(1, CEIL(distance * 2 * 0.2))

6. Deduct units via deduct_units() for each unit type being sent

7. INSERT unit_movements:
   (origin_city_id, destination_city_id, owner_id, units JSONB, depart_at, arrive_at)
   owner_id = (SELECT owner_id FROM cities WHERE id = p_city_id)  -- the bot's profile ID
   units JSONB format: '{"hoplite": 10, "archer": 5}'
```

**Travel time formula (must match dispatch-units/index.ts calcTravelMinutes):**
```
distance = sqrt(dx^2 + dy^2)  where dx/dy are grid coordinate differences
raw_minutes = MAX(1, CEIL(distance * BASE_MINUTES_PER_GRID_UNIT))
BASE_MINUTES_PER_GRID_UNIT = 2
dev_multiplier = 0.2  (when APP_ENVIRONMENT != 'production')
final_minutes = MAX(1, CEIL(raw_minutes * dev_multiplier))
```

### Anti-Patterns to Avoid

- **Do NOT use pg_net HTTP calls from bot functions to call Edge Functions.** Adds latency, failure modes, and JWT complexity. Existing cron functions never use HTTP — neither should bot functions.
- **Do NOT run bot decisions on the 1-minute tick.** 15-minute interval is locked; putting bots on existing ticks adds performance regression and creates "inhuman reaction time" feel.
- **Do NOT build a separate bot auth role or schema.** Bots are real `auth.users` with `is_bot = true`. SECURITY DEFINER bypasses RLS the same way all other server-side code does.
- **Do NOT SELECT FOR UPDATE inside the bot loop without SKIP LOCKED.** At 20 bots this is fine, but adding `SKIP LOCKED` prevents any future issues if bots and GodMode try to read bot_schedules simultaneously.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Resource deduction with insufficient-guard | Custom UPDATE with CASE | `deduct_resource(p_city_id, p_resource_type, p_amount)` RPC | Already exists in migration 20260311000008; handles race condition atomically |
| Unit deduction with insufficient-guard | Custom UPDATE | `deduct_units(p_city_id, p_unit_type, p_quantity)` RPC | Already exists in migration 20260311000014 |
| Cost formula computation in SQL | Reimplementing `base * 1.5^level` in PL/pgSQL | Hardcode the precomputed costs as SQL CASE expressions or a VALUES table | Edge Function already defines all base costs; bots use same values |
| Queue occupancy check | SELECT COUNT(*) | `SELECT id FROM construction_queue WHERE city_id = p_city_id` then check FOUND | UNIQUE(city_id) constraint enforces at DB level; check is just a skip gate |
| Training queue race condition | Custom locking | Let UNIQUE(city_id) constraint on training_queue raise 23505 and catch in EXCEPTION block | DB-level guarantee; no custom locking needed |

**Key insight:** The entire bot behavior engine is a matter of replicating the business logic
already in Edge Functions into PL/pgSQL form. Every validation step has a direct counterpart in
`upgrade-building/index.ts`, `train-units/index.ts`, or `dispatch-units/index.ts`.

---

## Common Pitfalls

### Pitfall 1: Construction Queue INSERT Race Condition

**What goes wrong:** Two concurrent mechanisms (a real player via Edge Function AND the bot tick)
could simultaneously see an empty construction_queue for the same city and both try to INSERT.
**Why it happens:** The queue check and the INSERT are two separate statements, not atomic.
**How to avoid:** Catch `unique_violation (SQLSTATE 23505)` in an EXCEPTION block. If caught,
the bot simply skips (another process beat it). The UNIQUE(city_id) constraint on
construction_queue guarantees at most one entry.
**Warning signs:** `ERROR: duplicate key value violates unique constraint "construction_queue_city_id_key"` in pg_cron logs.

### Pitfall 2: NULL owner_id in unit_movements INSERT

**What goes wrong:** bot_decide_attack inserts to unit_movements but forgets to set `owner_id`.
**Why it happens:** The field is NOT NULL in the schema; an INSERT without it fails silently if
caught in a broad EXCEPTION.
**How to avoid:** Always SELECT the bot's profile id from the `cities` row (c.owner_id) and pass
it explicitly: `owner_id = (SELECT owner_id FROM cities WHERE id = p_city_id)`.

### Pitfall 3: Building Cost in SQL Doesn't Match Edge Function

**What goes wrong:** Bot upgrades buildings for the wrong cost, deducting too little or too much.
**Why it happens:** Developer reimplements the cost table differently from `upgrade-building/index.ts BASE_COSTS`.
**How to avoid:** The research section above contains the verbatim cost table from the Edge Function.
Copy it exactly into the SQL migration. Add a comment with the source file name.
**Warning signs:** Bot cities run out of resources faster than expected, or bot upgrades while
appearing to have insufficient resources.

### Pitfall 4: Bot Attacks Trigger movement_type CHECK Violation

**What goes wrong:** unit_movements has a `movement_type` column with CHECK constraint
`IN ('attack', 'return', 'trade')` (added in migration `20260316000002`).
**Why it happens:** Developer either omits movement_type in the INSERT (NULL violates NOT NULL if
it's NOT NULL, or triggers CHECK if default is wrong), or uses an unlisted value.
**How to avoid:** Explicitly set `movement_type = 'attack'` in bot_decide_attack's INSERT.
Verify the unit_movements schema has this column and the CHECK constraint.

### Pitfall 5: "Cheapest Land Unit" Logic Selects Naval Units

**What goes wrong:** bot_decide_train accidentally includes naval units in its cheapest-unit search.
**Why it happens:** The unit cost table includes naval units; if the WHERE clause doesn't filter
to land units only, a cargo_ship might be "cheaper" per-unit than cavalry.
**How to avoid:** Filter explicitly: `unit_type IN ('hoplite','phalanx','archer','cavalry','catapult','mortar','medic','cook')`.
Bots send land units only (per CONTEXT.md: "at least 5 land units" and "cheapest affordable land unit").

### Pitfall 6: Stagger Update Runs Even When No Action Taken

**What goes wrong:** `next_action_at` is updated even when the bot had no resources to act.
This means a broke bot that can do nothing will still wait 15-20 minutes before being checked again.
**Why it happens:** The UPDATE is outside the IF chain in run_bot_decisions.
**How to decide:** Per CONTEXT.md decisions, this is acceptable: "no resource saving or hoarding logic — bots act whenever they can afford to." The stagger update ALWAYS runs. A broke bot that does nothing still advances its next_action_at — this is the intended behavior (prevents the tick from hammering broke bots every 15 minutes when nothing will succeed).

### Pitfall 7: Island Donation Race Condition

**What goes wrong:** Two bots on the same island both see resource_level = 5, both compute cost
for level 5→6, both deduct wood successfully, but only one UPDATE succeeds — the other loses wood.
**Why it happens:** The donate-island-wood Edge Function already documents this as an accepted edge
case for v1 (its comment: "The wood has already been deducted — this is an edge case the design accepts for v1.").
**How to avoid:** Mirror the Edge Function's approach: use conditional UPDATE:
`UPDATE islands SET resource_level = resource_level + 1 WHERE id = p_island_id AND resource_level = p_expected_level`.
Check `GET DIAGNOSTICS v_rows = ROW_COUNT`. If 0 rows updated, the wood was still deducted — accept
this as a v1 known edge case. No recovery needed.

---

## Code Examples

Verified patterns from existing codebase:

### Queue Check Pattern (from upgrade-building/index.ts translated to SQL)
```sql
-- Source: supabase/functions/upgrade-building/index.ts (steps 6-7 translated)
DECLARE
  v_queue_id uuid;
  v_building_level integer;
BEGIN
  -- Check construction queue vacancy
  SELECT id INTO v_queue_id
  FROM public.construction_queue
  WHERE city_id = p_city_id
  LIMIT 1;

  IF FOUND THEN
    RETURN false;  -- busy
  END IF;
```

### Resource Check and Deduct Pattern
```sql
-- Source: deduct_resource() in migration 20260311000008
-- Check before deducting (bot uses this to skip when insufficient)
SELECT amount INTO v_wood
FROM public.city_resources
WHERE city_id = p_city_id AND resource_type = 'wood';

IF v_wood < p_wood_cost THEN
  RETURN false;  -- insufficient
END IF;

-- Deduct via existing RPC
PERFORM public.deduct_resource(p_city_id, 'wood', p_wood_cost);
```

### Building Cost Formula in SQL
```sql
-- Source: upgrade-building/index.ts calcUpgradeCost()
-- CEIL(base_cost * 1.5^current_level)
v_wood_cost := CEIL(150.0 * POWER(1.5, v_current_level));  -- barracks example
v_gold_cost := CEIL(100.0 * POWER(1.5, v_current_level));
```

### Island Donation Insert (from donate-island-wood/index.ts translated to SQL)
```sql
-- Source: supabase/functions/donate-island-wood/index.ts steps 7-9
-- island donation cost: CEIL(300 * 1.5^current_level)
v_island_cost := CEIL(300.0 * POWER(1.5, v_island_level));

-- Conditional UPDATE prevents race condition double-increment
UPDATE public.islands
SET resource_level = resource_level + 1
WHERE id = v_island_id
  AND resource_level = v_island_level;  -- guard: level hasn't changed

GET DIAGNOSTICS v_rows = ROW_COUNT;
-- v_rows = 0 means race condition; wood already deducted (accepted v1 edge case)
```

### unit_movements INSERT (from dispatch-units/index.ts steps 9-10 translated to SQL)
```sql
-- Source: supabase/functions/dispatch-units/index.ts
INSERT INTO public.unit_movements (
  origin_city_id,
  destination_city_id,
  owner_id,
  units,               -- JSONB: '{"hoplite": 10}'
  movement_type,       -- CRITICAL: must be 'attack' for bot attacks
  depart_at,
  arrive_at
) VALUES (
  p_city_id,
  v_target_city_id,
  v_bot_owner_id,
  jsonb_build_object(v_unit_type, v_send_count),
  'attack',
  NOW(),
  NOW() + (v_travel_minutes * INTERVAL '1 minute')
);
```

### Travel Time Formula in SQL (from dispatch-units/index.ts calcTravelMinutes())
```sql
-- Source: supabase/functions/dispatch-units/index.ts
-- BASE_MINUTES_PER_GRID_UNIT = 2, DEV_SPEED_MULTIPLIER = 0.2
v_distance := sqrt(POWER(v_dest_x - v_origin_x, 2.0) + POWER(v_dest_y - v_origin_y, 2.0));
v_raw_minutes := GREATEST(1, CEIL(v_distance * 2.0));
-- Apply dev speed multiplier (0.2 in dev, 1.0 in production)
-- Bot functions run server-side; use same multiplier as Edge Functions
v_travel_minutes := GREATEST(1, CEIL(v_raw_minutes * 0.2));  -- dev mode
```

Note: For bot functions, dev/production mode cannot be detected via `APP_ENVIRONMENT` env var
(pg_cron has no env var injection). Options:
1. Hardcode dev multiplier (0.2) during Phase 19 development since this is a dev-mode system
2. Read from a `game_config` table if one exists
3. Use a PostgreSQL GUC (custom setting) set in the migration

The simplest approach for 20 bots in dev: hardcode 0.2 and add a comment.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Bot behaviors as multiple pg_cron jobs | Single `bot-think-tick` at */15 | Architecture decision (v1.3) | Avoids worker pool exhaustion; single job to monitor |
| HTTP round-trips via pg_net for bot mutations | Direct PL/pgSQL INSERT/UPDATE | Architecture decision (v1.3) | Eliminates latency, failure modes, JWT complexity |
| Bot accounts with separate schema | Bots as real auth.users with is_bot flag | Architecture decision (v1.3) | Bots participate in all game systems transparently |

**Deprecated/outdated:**
- DO NOT create `bot_attack_cooldowns` table — v1.3 explicitly has no cooldown (per CONTEXT.md)
- DO NOT implement bot archetypes with weighted decision-making — deferred to BOT-F01
- DO NOT use `pg_net` for any bot function calls

---

## Open Questions

1. **Dev speed multiplier in PL/pgSQL**
   - What we know: Edge Functions read `APP_ENVIRONMENT` env var; PL/pgSQL cron functions have no env var access
   - What's unclear: Should bot attacks use 0.2x or 1.0x travel time? The dev environment currently uses 0.2x for all player-initiated attacks.
   - Recommendation: Hardcode 0.2 (dev speed) for Phase 19. Add a comment `-- TODO: parameterize via game_config table when production deployment is planned`. This ensures bot attacks arrive at consistent speed with player attacks in the dev environment.

2. **Unit distribution for attack (50-75% of army)**
   - What we know: Bot sends 50-75% of total land units. CONTEXT.md doesn't specify how to split across unit types.
   - What's unclear: Proportional split across all unit types, or send all of one type?
   - Recommendation: Proportional split is more complex; send all units of the cheapest/most numerous type up to the target count. Simplest SQL: iterate unit types, accumulate count until send_count is reached.

3. **movement_type column on unit_movements**
   - What we know: Migration `20260316000002` added CHECK constraint `IN ('attack', 'return', 'trade')`. The `dispatch-units` Edge Function does NOT set movement_type in its INSERT (the INSERT in step 10 doesn't include it).
   - What's unclear: Is movement_type nullable or has a default? The original schema creation (`20260311000013`) doesn't include the column — it was added in migration `20260312000001_add_movement_type_to_unit_movements.sql`.
   - Recommendation: Check the column's DEFAULT in the migration that added it. Bot functions should explicitly set `movement_type = 'attack'` to be safe.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Flutter test (dart) — existing `test/unit/` infrastructure |
| Config file | none (flutter test default) |
| Quick run command | `flutter test test/unit/ --reporter compact` |
| Full suite command | `flutter test --reporter expanded` |

Note: Phase 19 is pure PL/pgSQL — no Flutter code changes. Bot behavior validation is via
SQL query verification after `supabase db reset`, not Flutter unit tests. The validation
architecture here focuses on SQL-side verification.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BOT-02 | bot_decide_attack inserts to unit_movements | SQL smoke — verify row appears after tick | `supabase db reset && supabase sql "SELECT COUNT(*) FROM unit_movements WHERE owner_id IN (SELECT id FROM profiles WHERE is_bot = true)"` | ❌ Wave 0 |
| BOT-03 | bot_decide_train inserts to training_queue | SQL smoke — verify row appears after tick | `supabase db reset && supabase sql "SELECT COUNT(*) FROM training_queue"` | ❌ Wave 0 |
| BOT-04 | Island resource_level increases via bot action | SQL smoke — islands.resource_level change | Query `SELECT resource_level FROM islands` before and after tick | ❌ Wave 0 |
| BOT-05 | bot_decide_upgrade inserts to construction_queue | SQL smoke — verify row appears after tick | `supabase db reset && supabase sql "SELECT COUNT(*) FROM construction_queue"` | ❌ Wave 0 |

Note: Because bots fire on a 15-minute cron schedule, automated test validation requires either:
(a) Calling `run_bot_decisions()` directly via SQL: `SELECT public.run_bot_decisions()`, or
(b) Waiting for the next 15-minute tick

The preferred approach is (a): the planner should include a verification SQL step that calls
`run_bot_decisions()` directly and checks resulting table states.

### Sampling Rate
- **Per task commit:** `flutter test test/unit/ --reporter compact` (existing Dart tests — passes by default since no Dart changes)
- **Per wave merge:** `flutter test --reporter expanded` + manual SQL verification
- **Phase gate:** `supabase db reset && psql -c "SELECT public.run_bot_decisions()" && psql -c "SELECT COUNT(*) FROM unit_movements WHERE owner_id IN (SELECT id FROM profiles WHERE is_bot = true)"` — must return > 0

### Wave 0 Gaps
- [ ] SQL smoke test script: `scripts/test_bot_tick.sql` — calls `run_bot_decisions()` and asserts at least one action per table
- [ ] Bot seed data must exist before validation (Phase 20 dependency; Wave 0 can use a minimal test bot INSERT)

---

## Sources

### Primary (HIGH confidence)
- Codebase direct examination: `supabase/migrations/20260317000001_bot_schema.sql` — confirmed Phase 18 schema is live
- Codebase direct examination: `supabase/functions/upgrade-building/index.ts` — confirmed cost formulas, queue logic, construction_queue INSERT signature
- Codebase direct examination: `supabase/functions/train-units/index.ts` — confirmed unit costs, unlock levels, training_queue INSERT signature, DEV_SPEED_MULTIPLIER = 0.2
- Codebase direct examination: `supabase/functions/dispatch-units/index.ts` — confirmed travel time formula, unit deduction via deduct_units(), unit_movements INSERT signature
- Codebase direct examination: `supabase/functions/donate-island-wood/index.ts` — confirmed island donation cost formula CEIL(300 * 1.5^level), conditional UPDATE race condition handling
- Codebase direct examination: `supabase/migrations/20260311000009_construction_functions.sql` — confirmed SECURITY DEFINER pattern, FOR LOOP pattern
- Codebase direct examination: `supabase/migrations/20260311000014_training_functions.sql` — confirmed deduct_units() exists and signature
- Codebase direct examination: `supabase/migrations/20260311000015_movement_functions.sql` — confirmed process_arrivals() handles bot arrivals without modification
- Codebase direct examination: `supabase/migrations/20260316000002_trade_movement_type_and_deduct_resources.sql` — confirmed movement_type CHECK constraint includes 'attack'
- `.planning/research/ARCHITECTURE.md` — run_bot_decisions() skeleton, bot-as-player pattern, no pg_net anti-pattern documentation

### Secondary (MEDIUM confidence)
- `.planning/research/PITFALLS.md` — pg_cron worker pool exhaustion, bot targeting, race condition patterns

### Tertiary (LOW confidence)
- None — all findings verified from codebase or prior HIGH-confidence research

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all tables, functions, and patterns verified directly from codebase migrations
- Architecture: HIGH — run_bot_decisions() skeleton from ARCHITECTURE.md verified against existing cron function patterns
- Cost formulas: HIGH — extracted verbatim from Edge Function source files
- Pitfalls: HIGH — verified against actual schema constraints (UNIQUE, CHECK, NOT NULL) in migration files
- Dev speed multiplier in PL/pgSQL: MEDIUM — known gap, mitigation recommended

**Research date:** 2026-03-17
**Valid until:** 2026-04-17 (30 days — stable PL/pgSQL patterns; Edge Function business logic unlikely to change)
