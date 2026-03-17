# Phase 19: Bot Behavior Engine - Context

**Gathered:** 2026-03-17
**Status:** Ready for planning

<domain>
## Phase Boundary

PL/pgSQL `run_bot_decisions()` function with helper functions (`bot_decide_upgrade`, `bot_decide_train`, `bot_decide_attack`) and a `bot-think-tick` pg_cron job firing every 15 minutes. Bots autonomously upgrade buildings, retrain armies, and attack neighbors. Pure server-side — no Flutter code. Seed data (Phase 20) and GodMode controls (Phase 21-22) are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Decision priority chain
- One action per tick per bot — no multi-action ticks
- Priority order: upgrade building → train units → attack (aggression-gated)
- If a higher-priority action succeeds (e.g., upgrade queued), skip lower priorities
- Fall through chain if action is not possible (e.g., no resources for upgrade → try train → try attack)

### Building upgrade logic
- Bot selects the lowest-level building in its city that it can afford to upgrade
- Skip if construction_queue already has a pending entry for this city
- Include island resource donations: if all city buildings are at max level or queue is full, donate wood to island resource building instead
- Check city_resources before attempting — skip if insufficient resources

### Unit training logic
- Train the cheapest affordable land unit type to fill gaps in army
- Skip if training_queue already has a pending entry for this city
- Check city_resources before attempting — skip if insufficient resources
- No preference for specific unit compositions — simple "fill cheapest first" approach

### Attack behavior
- Bot must have at least 5 land units before considering an attack
- Target selection: random non-bot city on the same island; if no valid target on same island, pick from neighboring islands
- Send 50-75% of available land units (random within range)
- No cooldown or anti-repeat logic — keep simple for v1.3
- Writes directly to unit_movements table (same as dispatch-units Edge Function)

### Aggression mapping
- Aggression 0 = never attack (passive bot)
- Aggression 1 = attack ~33% of eligible ticks (random() < 1/3.0)
- Aggression 2 = attack ~66% of eligible ticks (random() < 2/3.0)
- Aggression 3 = attack every eligible tick
- Aggression only gates attack probability — does not affect upgrade or training behavior
- Probability check: `random() < (aggression / 3.0)` before calling bot_decide_attack

### Tick scheduling
- Single `bot-think-tick` pg_cron job at `*/15 * * * *` calling `run_bot_decisions()`
- After each bot is processed, stagger next_action_at: `NOW() + INTERVAL '15 minutes' + (random() * INTERVAL '5 minutes')` to avoid all bots firing simultaneously
- Only process bots where `is_paused = false AND next_action_at <= NOW()`

### Resource awareness
- All actions check city_resources before attempting — skip if insufficient
- No resource saving or hoarding logic — bots act whenever they can afford to
- Fall-through priority chain naturally handles "too poor to upgrade but can train" scenarios

### Claude's Discretion
- Exact SQL implementation details for helper functions
- Whether to use CTEs or subqueries in bot decision functions
- Index strategy on bot_schedules.next_action_at (may or may not be needed for 20 bots)
- Error handling within run_bot_decisions (EXCEPTION blocks, logging)
- Exact unit count calculation for "cheapest affordable unit"

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Bot schema (Phase 18 output)
- `supabase/migrations/20260317000001_bot_schema.sql` — bot_schedules table definition, is_bot/is_admin columns, RLS deny-all policy
- `.planning/phases/18-bot-schema-foundation/18-CONTEXT.md` — Schema decisions: aggression 0-3, next_action_at, is_paused

### Existing game tables (bot actions write to these)
- `supabase/migrations/20260311000009_construction_functions.sql` — Construction queue processing, building upgrade cost formulas
- `supabase/migrations/20260311000014_training_functions.sql` — Training queue processing, unit training cost/time formulas
- `supabase/migrations/20260311000015_movement_functions.sql` — Unit movement dispatch, travel time calculation
- `supabase/migrations/20260311000013_create_unit_movements.sql` — unit_movements table schema
- `supabase/migrations/20260311000012_create_training_queue.sql` — training_queue table schema

### Existing pg_cron pattern
- `supabase/migrations/20260311000010_pg_cron_jobs.sql` — pg_cron extension setup, existing cron job pattern
- `supabase/migrations/20260311000016_military_cron_jobs.sql` — Military cron jobs registration pattern

### Architecture research
- `.planning/research/ARCHITECTURE.md` — Bot-as-Player pattern, run_bot_decisions() skeleton, SECURITY DEFINER approach
- `.planning/research/PITFALLS.md` — pg_cron worker pool exhaustion risk, seed idempotency

### Edge Functions (reference for what bot SQL must replicate)
- `supabase/functions/upgrade-building/index.ts` — Building upgrade validation logic (bot SQL must match)
- `supabase/functions/train-units/index.ts` — Unit training validation logic (bot SQL must match)
- `supabase/functions/dispatch-units/index.ts` — Unit dispatch logic (bot SQL must match for attacks)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `run_bot_decisions()` skeleton in ARCHITECTURE.md — near-complete reference implementation with priority chain
- `SECURITY DEFINER SET search_path = ''` pattern used in all existing cron functions — reuse for bot functions
- `complete_building_upgrades()`, `complete_training()`, `process_arrivals()` — existing tick functions as pattern reference

### Established Patterns
- pg_cron jobs call top-level PL/pgSQL functions that iterate over eligible rows with FOR loops
- All game mutations use SELECT FOR UPDATE to prevent race conditions with concurrent ticks
- Cost formulas: `base_cost * 1.5^level` for buildings, unit costs defined in unit_types table
- Travel time: distance-based calculation in movement functions

### Integration Points
- `construction_queue` table — bot_decide_upgrade INSERTs here (same as upgrade-building Edge Function)
- `training_queue` table — bot_decide_train INSERTs here (same as train-units Edge Function)
- `unit_movements` table — bot_decide_attack INSERTs here (same as dispatch-units Edge Function)
- `city_resources` table — all actions must check/deduct resources here
- `city_buildings` table — bot reads building levels to decide upgrades
- `city_units` table — bot reads unit counts to decide training and attacks
- `bot_schedules` table — run_bot_decisions reads/updates next_action_at

</code_context>

<specifics>
## Specific Ideas

- Bots write directly to game tables (training_queue, construction_queue, unit_movements) — same tables as Edge Functions. No pg_net HTTP round-trips from pg_cron.
- Bot actions must match the same validation logic as Edge Functions (cost checks, queue checks) to maintain game integrity.
- Bot accounts go through the same handle_new_user trigger as real players, so they already have cities and resources.

</specifics>

<deferred>
## Deferred Ideas

- Bot archetypes (militarist, economist, builder) with weighted decision-making — v1.3+ (BOT-F01)
- Bot difficulty scaling based on player progression — v1.3+ (BOT-F03)
- Bot-to-bot diplomacy and coordinated attacks — requires alliance system (BOT-F02)

</deferred>

---

*Phase: 19-bot-behavior-engine*
*Context gathered: 2026-03-17*
