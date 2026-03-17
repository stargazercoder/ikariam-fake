# Phase 20: Seed Data - Research

**Researched:** 2026-03-17
**Domain:** PostgreSQL seed data / Supabase auth bootstrapping / idempotent SQL
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **Phase boundary:** Extend `supabase/seed.sql` only. No Flutter code, no new migrations.
- **Bot count:** 20 bots with Greek/historical themed names.
- **Email pattern:** `bot{N}@bot.local`
- **UUID pattern:** `b{NN}00000-0000-0000-0000-000000000000` (e.g. b0100000 through b2000000)
- **Island spread:** Distributed across at least 8 distinct islands via round-robin slot assignment across the 25-island grid.
- **Low tier (7 bots):** Building levels 1-2, army 5-15 land units, resources 500-1500 per type
- **Mid tier (7 bots):** Building levels 3-4, army 20-50 land units, resources 2000-5000 per type
- **High tier (6 bots):** Building levels 5-6, army 50-100+ land units, resources 5000-15000 per type
- **Within-tier variety:** Varied building focus (military-heavy, economy-heavy, balanced). Low tier: hoplites/archers only. Mid tier adds phalanx/cavalry. High tier: full unit mix.
- **Aggression distribution:** 5 bots at each of 0/1/2/3 aggression; roughly correlated with tier.
- **bot_schedules:** `is_paused = false`, `next_action_at = NOW() + (bot_index * INTERVAL '45 seconds')`
- **Idempotency:** `ON CONFLICT (id) DO NOTHING` for auth.users and auth.identities; `ON CONFLICT DO UPDATE` for bot_schedules; UPDATE statements for all game data.
- **Seed file location:** Append to `supabase/seed.sql` after the 7 human test accounts.
- **Section header:** `-- Bot accounts (20 bots for v1.3)`
- **Admin account:** `UPDATE profiles SET is_admin = true WHERE id = 'a1111111-...'` (Leonidas)

### Claude's Discretion

- Exact bot names (Greek/historical theme established)
- Exact building level values within tier ranges
- Exact resource amounts within tier ranges
- Exact unit quantities and type mix within tier constraints
- Which specific islands each bot lands on (as long as 8+ distinct islands covered)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SEED-01 | Project init creates 20 bot accounts with diverse game states (varied resources, buildings, armies) | Trigger-based user creation pattern confirmed; UPDATE idiom for overwriting defaults established; tier design fully specified |
| SEED-02 | Seed script is idempotent — can be re-run without conflicts or duplicate data | ON CONFLICT syntax verified against existing table DDL; all PRIMARY KEY and UNIQUE constraints mapped |
</phase_requirements>

---

## Summary

Phase 20 is a pure SQL authoring task. The entire implementation lives in `supabase/seed.sql` — no migrations, no application code. The trigger chain already handles the mechanical work: inserting into `auth.users` fires `handle_new_user()`, which creates a `profiles` row and a `cities` row. Then `on_city_created()` fires and inserts 14 `city_buildings` rows (town_hall=1 and four production buildings=1, rest=0) plus 5 `city_resources` rows (wood=500, gold=500, others=0). The seed then uses UPDATE statements to overwrite those defaults to the tier-appropriate levels, and INSERT statements for `city_units` and `bot_schedules`.

The main technical challenge is idempotency (SEED-02). The existing 7 human accounts use plain INSERT without ON CONFLICT — this works because `supabase db reset` drops and recreates all tables, making duplicates impossible on first run. However the CONTEXT.md decision requires bots to use `ON CONFLICT (id) DO NOTHING` on `auth.users` and `auth.identities`, and `ON CONFLICT (bot_id) DO UPDATE` on `bot_schedules`. UPDATE statements for game tables are inherently idempotent (they overwrite whatever value is currently there). The `city_units` INSERT needs `ON CONFLICT (city_id, unit_type) DO UPDATE SET quantity = EXCLUDED.quantity` because the UNIQUE constraint on that pair would fail on re-run.

The island placement is driven by `handle_new_user()`, which picks the island with the most empty slots. With 25 islands (max_city_slots=16 or 17) and only 7 existing accounts before bots, the trigger will naturally distribute 20 bots across many islands. The round-robin coverage requirement (8+ distinct islands) is fulfilled automatically because the trigger balances placement by available slots. No explicit island targeting is needed in the seed.

**Primary recommendation:** Author the 20 bot INSERTs in groups by tier, using the established 3-step pattern (auth.users INSERT → auth.identities INSERT → profile/game data UPDATEs), with ON CONFLICT guards on every auth table insert.

---

## Standard Stack

### Core

| Component | Version/Location | Purpose | Why Standard |
|-----------|-----------------|---------|--------------|
| `supabase/seed.sql` | Existing file (445 lines) | Seed data entry point | Loaded automatically by `supabase db reset` |
| PostgreSQL `ON CONFLICT` | Postgres 9.5+ syntax | Idempotency guard | Native UPSERT, no extra logic needed |
| `auth.users` table | Supabase internal schema | Bot account identity | Same table as real users; trigger fires on INSERT |
| `auth.identities` table | Supabase internal schema | Email login capability | Required alongside auth.users for email provider |
| `crypt('test1234', gen_salt('bf'))` | pgcrypto (already used) | Password hash | Matches existing human account pattern |
| `handle_new_user()` trigger | `20260311000003` | Auto-creates profile + city | Runs automatically on auth.users INSERT |
| `on_city_created()` trigger | `20260311000007` | Auto-creates buildings + resources | Runs automatically on cities INSERT |

### Supporting

| Component | Location | Purpose | When Used |
|-----------|----------|---------|-----------|
| `public.bot_schedules` | `20260317000001_bot_schema.sql` | Bot tick scheduling | INSERT after all 20 bot users are created |
| `public.city_units` | `20260311000011` | Army roster | INSERT per bot with UPSERT conflict handling |
| `public.profiles` | `20260311000001` | Display name, is_bot flag | UPDATE after trigger creates the row |

---

## Architecture Patterns

### Recommended Seed Structure (within seed.sql)

```
supabase/seed.sql
├── [existing] Islands (25 rows)
├── [existing] 7 human test accounts
│   ├── auth.users batch INSERT
│   ├── auth.identities batch INSERT
│   ├── profiles display_name UPDATEs
│   └── city_buildings / city_resources / city_units UPDATEs
│
└── [NEW] Bot accounts (20 bots for v1.3)
    ├── -- Admin flag for Leonidas
    ├── -- Low tier bots (7): auth.users INSERTs with ON CONFLICT
    ├── -- Mid tier bots (7): auth.users INSERTs with ON CONFLICT
    ├── -- High tier bots (6): auth.users INSERTs with ON CONFLICT
    ├── -- auth.identities for all 20 bots with ON CONFLICT
    ├── -- profiles UPDATEs: display_name + is_bot = true
    ├── -- city_buildings UPDATEs per bot (by building_type + owner subquery)
    ├── -- city_resources UPDATEs per bot (by resource_type + owner subquery)
    ├── -- city_units UPSERTs per bot (ON CONFLICT DO UPDATE)
    └── -- bot_schedules: INSERT all 20 with ON CONFLICT DO UPDATE
```

### Pattern 1: Bot auth.users INSERT (idempotent)

```sql
-- Source: supabase/seed.sql existing pattern + ON CONFLICT addition
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  confirmation_token, raw_app_meta_data, raw_user_meta_data
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  'b0100000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated',
  'bot1@bot.local',
  crypt('test1234', gen_salt('bf')),
  NOW(), NOW(), NOW(), '',
  '{"provider":"email","providers":["email"]}',
  '{}'
) ON CONFLICT (id) DO NOTHING;
```

Note: `auth.users` has a PRIMARY KEY on `id`. ON CONFLICT (id) DO NOTHING skips the row if it already exists. The trigger does NOT fire on conflict — only on successful INSERT.

### Pattern 2: auth.identities INSERT (idempotent)

```sql
-- Source: supabase/seed.sql existing pattern + ON CONFLICT addition
INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
VALUES (
  'b0100000-0000-0000-0000-000000000000',
  'b0100000-0000-0000-0000-000000000000',
  jsonb_build_object('sub', 'b0100000-0000-0000-0000-000000000000', 'email', 'bot1@bot.local'),
  'email',
  'b0100000-0000-0000-0000-000000000000',
  NOW(), NOW(), NOW()
) ON CONFLICT (id) DO NOTHING;
```

### Pattern 3: profiles UPDATE (inherently idempotent)

```sql
-- Source: supabase/seed.sql existing UPDATE pattern
UPDATE public.profiles
  SET display_name = 'Achilles', is_bot = true
  WHERE id = 'b0100000-0000-0000-0000-000000000000';
```

UPDATE does nothing if row doesn't exist (0 rows affected, no error). Safe to re-run.

**CRITICAL:** profiles row is created by the handle_new_user() trigger. On second `db reset` run, if `auth.users` INSERT hits ON CONFLICT DO NOTHING, the trigger does NOT fire, but the profiles row from the previous run was deleted by `db reset` (full table truncate). This means on re-run, the trigger fires fresh (new auth.users INSERT succeeds since tables are wiped clean on `db reset`). ON CONFLICT is only needed to protect against a seed script being run twice WITHOUT a db reset in between.

### Pattern 4: city_buildings UPDATE (inherently idempotent)

```sql
-- Source: supabase/seed.sql existing UPDATE pattern
UPDATE public.city_buildings
  SET level = 5
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0100000-0000-0000-0000-000000000000')
    AND building_type = 'town_hall';
```

### Pattern 5: city_units UPSERT (idempotency via ON CONFLICT)

```sql
-- Source: city_units table DDL — UNIQUE(city_id, unit_type) exists
INSERT INTO public.city_units (city_id, unit_type, quantity)
VALUES
  ((SELECT id FROM public.cities WHERE owner_id = 'b0100000-0000-0000-0000-000000000000'), 'hoplite', 10),
  ((SELECT id FROM public.cities WHERE owner_id = 'b0100000-0000-0000-0000-000000000000'), 'archer',  5)
ON CONFLICT (city_id, unit_type) DO UPDATE SET quantity = EXCLUDED.quantity;
```

### Pattern 6: bot_schedules INSERT with UPSERT

```sql
-- Source: bot_schedules DDL — PRIMARY KEY on bot_id
INSERT INTO public.bot_schedules (bot_id, is_paused, aggression, next_action_at)
VALUES (
  'b0100000-0000-0000-0000-000000000000',
  false,
  0,
  NOW() + (0 * INTERVAL '45 seconds')
) ON CONFLICT (bot_id) DO UPDATE SET
  aggression     = EXCLUDED.aggression,
  is_paused      = EXCLUDED.is_paused,
  next_action_at = NOW() + (0 * INTERVAL '45 seconds');
```

### Anti-Patterns to Avoid

- **Generating random UUIDs for bot IDs:** Use hardcoded deterministic UUIDs only. Random UUIDs break ON CONFLICT detection and produce orphan rows on re-run.
- **Using `INSERT ... SELECT` for auth.users:** Complex subqueries in auth schema inserts are fragile. Use explicit VALUES with hardcoded UUIDs.
- **Relying on subquery in ON CONFLICT:** `ON CONFLICT (id) DO NOTHING` must reference a column with a constraint on it. `auth.users.id` is the PRIMARY KEY — confirmed safe.
- **Skipping auth.identities:** Without a matching `auth.identities` row, the bot user cannot authenticate via email provider. Required even for bots.
- **Assuming trigger fires on conflict:** `ON CONFLICT DO NOTHING` silently skips both the INSERT and the trigger. On clean `db reset`, this is not a problem — tables are wiped first.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| City + profile creation | Manual INSERT into profiles and cities | `handle_new_user()` trigger | Trigger handles island selection, slot assignment, city name |
| Default buildings per city | Manual INSERT 14 rows per bot | `on_city_created()` trigger | Trigger seeds all 14 building types + 5 resources automatically |
| Duplicate detection | Custom EXISTS checks | `ON CONFLICT` clause | Native Postgres UPSERT; no race conditions, no extra queries |
| Island distribution | Explicit island_id targeting | `handle_new_user()` round-robin logic | Trigger already picks least-populated island; bots spread naturally |

**Key insight:** The trigger chain does the structural work. The seed only needs to overwrite default values with tier-appropriate values via UPDATE.

---

## Common Pitfalls

### Pitfall 1: `supabase db reset` semantics vs. double-run

**What goes wrong:** Developer confuses "idempotent" with "survives db reset twice." `supabase db reset` drops and recreates all tables — meaning all data is gone before seed runs. ON CONFLICT is needed for the case where someone runs the seed SQL directly twice without resetting. CONTEXT.md decision specifies ON CONFLICT anyway, which is the safe default.

**Why it happens:** The existing human test accounts have no ON CONFLICT — they only work because db reset wipes data first.

**How to avoid:** Add ON CONFLICT to all bot INSERTs regardless. This covers both the re-run-without-reset case and is a clear signal of intent.

**Warning signs:** If running `psql -f seed.sql` twice produces duplicate key errors on `auth.users` — the constraint is violated and ON CONFLICT is missing.

### Pitfall 2: Trigger not firing when ON CONFLICT suppresses INSERT

**What goes wrong:** When `ON CONFLICT DO NOTHING` activates (bot already exists), `handle_new_user()` does NOT fire. This means no profile row is created. On a clean `db reset`, this doesn't matter (tables wiped). On a direct re-run of seed without reset, all subsequent UPDATE statements silently affect 0 rows (no error, no profile, no city).

**Why it happens:** PostgreSQL triggers only fire on actual row changes, not suppressed conflicts.

**How to avoid:** Accept this behavior as-is. `supabase db reset` is the primary workflow. Direct seed re-run without reset is an edge case; silent no-ops are acceptable.

**Warning signs:** After a non-reset re-run, bot profiles have NULL display_name — the UPDATE found no row. This is expected behavior, not a bug.

### Pitfall 3: city_units INSERT without ON CONFLICT fails on re-run

**What goes wrong:** `city_units` has `UNIQUE(city_id, unit_type)`. Plain INSERT on second run produces duplicate key error.

**Why it happens:** Unlike profiles (no data without trigger), city_units data persists from the trigger. The existing human account seeds avoid this by only inserting units not created by the trigger (the trigger creates no unit rows — only buildings and resources).

**How to avoid:** Use `ON CONFLICT (city_id, unit_type) DO UPDATE SET quantity = EXCLUDED.quantity` for all bot city_units INSERTs.

**Warning signs:** `ERROR: duplicate key value violates unique constraint "city_units_city_id_unit_type_key"` on second seed run.

### Pitfall 4: Updating is_bot via authenticated client (security)

**What goes wrong:** The `REVOKE UPDATE (is_bot, is_admin) ON public.profiles FROM authenticated` migration means no client can set `is_bot = true`. The seed runs as the Supabase service role (superuser context), which bypasses this restriction.

**Why it happens:** The seed SQL runs during `db reset` with full superuser privileges.

**How to avoid:** No special handling needed — UPDATE in seed runs as superuser. This is correct behavior.

**Warning signs:** None in seed context. Would only matter if someone tried to update `is_bot` from a client-side call.

### Pitfall 5: bot_schedules RLS blocks seed access

**What goes wrong:** `bot_schedules` has RLS enabled with zero policies (deny-all for authenticated clients). Seed runs as superuser — superusers bypass RLS by default in PostgreSQL.

**Why it happens:** RLS is not applied to superuser connections. Supabase `db reset` runs as the postgres superuser.

**How to avoid:** No action needed. INSERT into `bot_schedules` in seed will work correctly.

**Warning signs:** None expected. Confirmed by PostgreSQL RLS documentation: superusers bypass all RLS.

### Pitfall 6: Batch INSERT vs. individual INSERT for auth.users

**What goes wrong:** The existing seed uses batch INSERT for the first 3 accounts (`VALUES (...)` with multiple rows). Batch INSERT with ON CONFLICT behaves differently: if ANY row in the batch conflicts, only that row is skipped (with DO NOTHING). The other rows in the batch still insert. This is safe for bot accounts.

**Why it happens:** This is correct PostgreSQL behavior — ON CONFLICT applies per-row, not per-statement.

**How to avoid:** Grouping bots by tier in batch INSERTs is fine. Each row conflict is handled independently.

---

## Code Examples

Verified patterns from the existing codebase:

### Building type reference (all 14 valid values)

```sql
-- Source: supabase/migrations/20260311000005_create_city_buildings.sql
-- All valid building_type CHECK values:
'town_hall', 'warehouse', 'barracks', 'shipyard', 'academy',
'embassy', 'trading_port', 'town_wall', 'hideout', 'tavern',
'sawmill', 'quarry', 'glassblower', 'sulfur_pit'
```

### Unit type reference (all 13 valid values)

```sql
-- Source: supabase/migrations/20260311000011_create_city_units.sql
-- All valid unit_type CHECK values:
'hoplite', 'phalanx', 'archer', 'cavalry', 'catapult', 'mortar', 'medic', 'cook',
'cargo_ship', 'ram_ship', 'catapult_ship', 'mortar_ship', 'diving_boat'
```

### Resource type reference (all 5 valid values)

```sql
-- Source: supabase/migrations/20260311000007_on_city_created_trigger.sql
'wood', 'marble', 'crystal', 'sulfur', 'gold'
```

### Barracks level unlock requirements for units

```sql
-- Source: supabase/migrations/20260317000002_bot_helper_functions.sql
-- Unit unlock levels (min barracks level required):
-- cook:     barracks >= 1
-- hoplite:  barracks >= 1
-- archer:   barracks >= 2
-- phalanx:  barracks >= 2
-- medic:    barracks >= 3
-- cavalry:  barracks >= 3
-- catapult: barracks >= 4
-- mortar:   barracks >= 5
```

This means low-tier bots (barracks=0 or 1) can only have hoplites and cooks. Mid-tier (barracks=2-3) adds archers, phalanx, cavalry. High-tier (barracks=4+) adds catapult and mortar.

### Default values created by triggers (what seed must OVERRIDE)

```sql
-- Source: on_city_created() trigger output
-- city_resources defaults:
--   wood=500, gold=500, marble=0, crystal=0, sulfur=0
-- city_buildings defaults (level):
--   town_hall=1, sawmill=1, quarry=1, glassblower=1, sulfur_pit=1
--   warehouse=0, barracks=0, shipyard=0, academy=0, embassy=0
--   trading_port=0, town_wall=0, hideout=0, tavern=0
```

### Admin flag for Leonidas

```sql
-- Source: CONTEXT.md — set after existing human account UPDATEs
UPDATE public.profiles
  SET is_admin = true
  WHERE id = 'a1111111-1111-1111-1111-111111111111';
```

### bot_schedules staggered timing formula

```sql
-- Source: CONTEXT.md decisions
-- bot_index = 0 through 19 (insertion order)
-- Results in: bot 0 fires at NOW()+0s, bot 1 at NOW()+45s, ..., bot 19 at NOW()+855s (~14.25 min)
next_action_at = NOW() + (bot_index * INTERVAL '45 seconds')
```

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Manual SQL verification (no automated test framework for seed data) |
| Config file | None |
| Quick run command | `supabase db reset` |
| Full suite command | `supabase db reset && supabase db reset` (double-run idempotency test) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SEED-01 | 20 bot profiles exist with varied game states after db reset | Smoke (SQL query) | `supabase db reset` then manual count query | ❌ Wave 0 — verification queries |
| SEED-01 | Bots distributed across 8+ distinct islands | Smoke (SQL query) | Manual: `SELECT COUNT(DISTINCT island_id) FROM cities JOIN profiles ON...` | ❌ Wave 0 |
| SEED-01 | 3 distinct development profiles present | Smoke (SQL query) | Manual: verify tier building levels via city_buildings query | ❌ Wave 0 |
| SEED-02 | Second `supabase db reset` exits with code 0, no duplicate key errors | Idempotency smoke | `supabase db reset && supabase db reset` | ❌ Wave 0 |
| SEED-02 | All 20 bots have bot_schedules rows with varied aggression | Smoke (SQL query) | Manual: `SELECT aggression, COUNT(*) FROM bot_schedules GROUP BY aggression` | ❌ Wave 0 |

### Wave 0 Gaps

- [ ] Verification SQL queries to run after `supabase db reset` to confirm SEED-01 and SEED-02 — can be embedded as comments at the end of seed.sql or in a separate `supabase/verify-seed.sql` file.

**Framework install:** None needed. Seed verification is manual SQL via `supabase db reset`.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual profile INSERT | Trigger-based: INSERT into auth.users fires handle_new_user() | Phase 1 of project | Seed must not INSERT into profiles directly — trigger owns it |
| Bare INSERT for test data | INSERT with ON CONFLICT for bot data | Phase 20 decision | Enables re-run safety |
| Separate migration for seed accounts | Everything in seed.sql | Project convention | db reset always applies migrations then seed in order |

**Deprecated/outdated:**
- Direct INSERT into `public.profiles` without going through `auth.users`: handle_new_user trigger expects to CREATE the profile stub itself. Bypassing auth.users would cause the trigger to either fail or create duplicates.

---

## Open Questions

1. **Do existing human accounts (7) need ON CONFLICT retrofitting?**
   - What we know: They currently have no ON CONFLICT. They work because db reset wipes tables.
   - What's unclear: Whether the planner should add ON CONFLICT to existing human inserts as cleanup.
   - Recommendation: CONTEXT.md says "existing 7 human test accounts remain unchanged." Do not modify human account inserts. Only bots get ON CONFLICT.

2. **Should city_units for bots use INSERT with ON CONFLICT, or direct UPDATE?**
   - What we know: `city_units` is not pre-populated by triggers (unlike city_buildings). Must INSERT.
   - What's unclear: Nothing — UNIQUE(city_id, unit_type) means ON CONFLICT DO UPDATE is required.
   - Recommendation: Use `ON CONFLICT (city_id, unit_type) DO UPDATE SET quantity = EXCLUDED.quantity` on all bot city_units INSERTs.

3. **Does `supabase db reset` run seed.sql as superuser?**
   - What we know: Supabase local dev uses the postgres superuser for migrations and seed. RLS is bypassed for superuser.
   - What's unclear: Whether any edge case exists where seed runs as an authenticated role.
   - Recommendation: Treat as HIGH confidence that seed runs as superuser. bot_schedules and is_bot/is_admin updates will work without SECURITY DEFINER wrappers.

---

## Sources

### Primary (HIGH confidence)

- `supabase/seed.sql` (local, 445 lines) — Established INSERT/UPDATE patterns for auth.users, auth.identities, profiles, city_buildings, city_resources, city_units
- `supabase/migrations/20260317000001_bot_schema.sql` — bot_schedules table DDL: PRIMARY KEY (bot_id), aggression CHECK (0-3), is_paused, next_action_at
- `supabase/migrations/20260311000007_on_city_created_trigger.sql` — Trigger default values: what the seed must override
- `supabase/migrations/20260311000003_handle_new_user_trigger.sql` — Trigger behavior: island selection, slot assignment, profile creation
- `supabase/migrations/20260311000005_create_city_buildings.sql` — All 14 valid building_type values and UNIQUE(city_id, building_type) constraint
- `supabase/migrations/20260311000011_create_city_units.sql` — All 13 valid unit_type values and UNIQUE(city_id, unit_type) constraint
- `supabase/migrations/20260311000002_create_cities.sql` — UNIQUE(island_id, slot_number) constraint; slot_number range 1-17
- `supabase/migrations/20260317000002_bot_helper_functions.sql` — Unit unlock levels per barracks level; building cost reference

### Secondary (MEDIUM confidence)

- `.planning/phases/20-seed-data/20-CONTEXT.md` — All implementation decisions (locked and discretionary)
- `.planning/REQUIREMENTS.md` — SEED-01 and SEED-02 requirement text

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all tables, constraints, and trigger behavior confirmed from local migration files
- Architecture patterns: HIGH — all INSERT/UPDATE idioms verified against existing seed.sql
- Pitfalls: HIGH — based on actual DDL constraints (UNIQUE, CHECK, RLS) in migration files
- Idempotency strategy: HIGH — ON CONFLICT syntax confirmed against PostgreSQL behavior and local table PKs

**Research date:** 2026-03-17
**Valid until:** 2026-04-17 (stable schema — no migrations expected for Phase 20)
