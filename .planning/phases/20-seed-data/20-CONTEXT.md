# Phase 20: Seed Data - Context

**Gathered:** 2026-03-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Extend the existing `supabase/seed.sql` to create 20 diverse bot accounts with varied buildings, armies, and resources. Running `supabase db reset` twice in a row must produce no errors. No Flutter code, no new migrations — pure seed data.

</domain>

<decisions>
## Implementation Decisions

### Bot identity design
- 20 bots with Greek/historical themed names (consistent with existing accounts: Leonidas, Xerxes, Pericles, etc.)
- Email pattern: `bot{N}@bot.local` (clearly distinguishable from human test accounts)
- UUID pattern: `b{NN}00000-0000-0000-0000-000000000000` (e.g., `b0100000-...` through `b2000000-...`) for easy identification
- Distributed across at least 8 distinct islands using round-robin slot assignment across the 25-island grid

### Development profiles (3 tiers)
- **Low tier (7 bots):** Building levels 1-2, army 5-15 land units, resources 500-1500 per type
- **Mid tier (7 bots):** Building levels 3-4, army 20-50 land units, resources 2000-5000 per type
- **High tier (6 bots):** Building levels 5-6, army 50-100+ land units, resources 5000-15000 per type
- Each bot within a tier should have varied building focus (some military-heavy with barracks, some economy-heavy with warehouse/academy, some balanced)
- Unit type variety: low tier gets only hoplites/archers, mid tier adds phalanx/cavalry, high tier has full unit mix

### Aggression distribution
- 5 bots at aggression 0 (passive — never attack)
- 5 bots at aggression 1 (low — ~33% attack chance)
- 5 bots at aggression 2 (medium — ~66% attack chance)
- 5 bots at aggression 3 (aggressive — always attack when eligible)
- Aggression roughly correlated with tier: high-tier bots more likely to have higher aggression

### Bot schedule initialization
- All bots get a `bot_schedules` row with `is_paused = false`
- `next_action_at` staggered across the first 15-minute window: `NOW() + (bot_index * INTERVAL '45 seconds')` so bots don't all fire at once on first tick

### Idempotency strategy
- `ON CONFLICT (id) DO NOTHING` for `auth.users` and `auth.identities` inserts — skip if already exists
- `ON CONFLICT DO UPDATE` for `bot_schedules` — always refresh aggression and paused state
- UPDATE statements for profiles, city_buildings, city_resources, city_units are naturally idempotent (overwrite current values)
- All bot UUIDs are deterministic (hardcoded), not generated — ensures ON CONFLICT works

### Seed file organization
- Append bot seed data to existing `supabase/seed.sql` after the 7 human test accounts
- Clear section comment header: `-- Bot accounts (20 bots for v1.3)`
- Mark existing 7 accounts with `is_bot = false` explicitly (no-op but documents intent)
- Set one human test account as admin: `UPDATE profiles SET is_admin = true WHERE id = 'a1111111-...'` (Leonidas = admin for GodMode testing)

### Claude's Discretion
- Exact bot names (Greek/historical theme established)
- Exact building level values within tier ranges
- Exact resource amounts within tier ranges
- Exact unit quantities and type mix within tier constraints
- Which specific islands each bot lands on (as long as 8+ distinct islands covered)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing seed pattern
- `supabase/seed.sql` — Current 7 test accounts pattern: auth.users INSERT → auth.identities INSERT → profile UPDATE → building/resource/unit UPDATEs

### Bot schema (Phase 18 output)
- `supabase/migrations/20260317000001_bot_schema.sql` — bot_schedules table definition, is_bot/is_admin columns
- `.planning/phases/18-bot-schema-foundation/18-CONTEXT.md` — Schema decisions: aggression 0-3, next_action_at, is_paused

### City creation trigger
- `supabase/migrations/20260311000003_handle_new_user_trigger.sql` — handle_new_user() trigger: auto-creates profile + city + initial buildings + resources
- `supabase/migrations/20260311000007_on_city_created_trigger.sql` — on_city_created() trigger: creates default building rows (town_hall=1, all others=0)

### Game tables
- `supabase/migrations/20260311000002_create_cities.sql` — Cities table with island_id, slot_index
- `supabase/migrations/20260311000004_create_city_buildings.sql` — city_buildings table with building_type, level
- `supabase/migrations/20260311000005_create_city_resources.sql` — city_resources table with resource_type, amount
- `supabase/migrations/20260311000006_create_city_units.sql` — city_units table with unit_type, quantity

### Bot behavior (Phase 19 output)
- `.planning/phases/19-bot-behavior-engine/19-CONTEXT.md` — Bot decision priority chain, aggression mapping, tick scheduling

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `supabase/seed.sql` (445 lines) — Complete pattern for auth.users + auth.identities + profiles + buildings + resources + units seeding
- `handle_new_user()` trigger — Auto-creates profile + city; bot auth.users INSERT triggers this automatically
- `on_city_created()` trigger — Creates default building rows for new cities

### Established Patterns
- auth.users INSERT with deterministic UUIDs, `crypt('test1234', gen_salt('bf'))` for passwords
- auth.identities INSERT matching user UUID for email login capability
- Profile display_name UPDATE after trigger creates the row
- city_buildings UPDATE by building_type + owner subquery
- city_units INSERT with (city_id, unit_type, quantity) tuples
- city_resources UPDATE by resource_type + owner subquery

### Integration Points
- `handle_new_user()` trigger fires on auth.users INSERT → creates profile + city with random island placement
- City gets random `slot_index` on a random island with available slots
- Default buildings created by `on_city_created()`: town_hall=1, all others=0
- Default resources created: all 5 types at amount=0
- After trigger creates defaults, seed UPDATEs overwrite to desired levels

</code_context>

<specifics>
## Specific Ideas

- Bot accounts go through the same handle_new_user trigger as real players — they automatically get a city on a random island. The seed then UPDATEs their buildings/resources/units to desired levels.
- Existing 7 human test accounts remain unchanged — bots are additional accounts.
- One admin account (Leonidas) needed for GodMode testing in Phases 21-22.
- No ON CONFLICT exists in current seed.sql — this phase adds it for all bot INSERTs to achieve idempotency (SEED-02).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 20-seed-data*
*Context gathered: 2026-03-17*
