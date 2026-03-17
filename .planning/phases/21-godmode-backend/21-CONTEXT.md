# Phase 21: GodMode Backend - Context

**Gathered:** 2026-03-17
**Status:** Ready for planning

<domain>
## Phase Boundary

SECURITY DEFINER RPCs that expose full world state and bot/player controls to admin users only. Includes a go_router admin route guard in Flutter. The service_role key never appears in any Flutter file — all admin access goes through RPCs that check `is_admin` at the Postgres layer. This phase delivers the backend APIs only; the Flutter dashboard UI is Phase 22.

</domain>

<decisions>
## Implementation Decisions

### RPC Response Shape
- `godmode_get_world_state()` returns a single JSONB aggregate with a players array — each entry contains resources, army counts (land total / naval total), building levels, bot status (`is_bot`, `is_paused`), and active battles summary
- Single RPC for entire world state — simpler for Phase 22 dashboard consumption; split later only if performance requires it
- Army sizes represented as total land unit count and total naval unit count (summary, not per-unit-type breakdown)
- Active battles include battle ID, attacker/defender names, and current turn number only — Battle detail screen already exists for drill-down
- All RPCs are `SECURITY DEFINER SET search_path = ''` with an explicit `is_admin` check on `auth.uid()` at the top — return error/empty if non-admin

### Admin Route Guard
- `/godmode` route is a top-level GoRoute outside the StatefulShellRoute — GodMode is a separate full-page experience, not part of the game shell with bottom nav
- Non-admin users hitting `/godmode` are redirected to `/map` via the existing `_redirect()` function in app_router.dart
- Defense in depth: client-side route guard is UX-only; every RPC independently rejects non-admin callers at the Postgres layer
- Route guard reads `isAdmin` from the `ProfileNotifier` getter (already implemented in Phase 18)

### Bot Control RPCs
- `godmode_set_bot_paused(p_bot_id UUID, p_paused BOOLEAN)` — sets `is_paused` on `bot_schedules` row; the next bot-think-tick skips that bot (Phase 19 already checks `is_paused`)
- `godmode_force_action(p_bot_id UUID)` — triggers one immediate `run_bot_decisions()` cycle for the specified bot only, without waiting for the cron schedule
- Pause only prevents NEW decisions — in-flight movements and ongoing battles continue unaffected
- Speed adjustment (manipulating `next_action_at`) deferred to Phase 22 UI implementation

### Resource Modification RPC
- `admin_set_resources(p_player_id UUID, p_wood NUMERIC, p_marble NUMERIC, p_crystal NUMERIC, p_sulfur NUMERIC, p_gold NUMERIC)` — sets any player's resource balances
- Values clamped to 0 minimum — no negative resources allowed
- Non-admin callers rejected at Postgres layer (same `is_admin` check pattern)

### Event Feed RPC
- `godmode_get_events(p_limit INTEGER DEFAULT 50, p_event_type TEXT DEFAULT NULL)` returns JSONB array of recent events
- Queries `battles`, `trade_routes`, and `spy_reports` tables, unions them sorted by timestamp
- Each event includes: event type, timestamp, involved player names, and a one-line summary
- Optional `p_event_type` filter: 'battle', 'trade', 'espionage', or NULL for all types

### Claude's Discretion
- Exact JSONB structure and key naming within RPC responses
- Whether to use CTE vs subquery for the event feed union
- Index strategy on event tables for the feed query (likely not needed at current scale)
- Error message wording for non-admin rejection
- Whether godmode_force_action should return void or a result summary

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Admin schema
- `supabase/migrations/20260317000001_bot_schema.sql` — `is_admin` and `is_bot` column definitions, RLS policies, REVOKE UPDATE on sensitive columns
- `supabase/seed.sql` — Test account a1111111 has `is_admin = true`; bot accounts use deterministic UUID pattern

### Bot behavior (integration points)
- `supabase/migrations/20260317000002_bot_helper_functions.sql` — `bot_decide_upgrade()`, `bot_decide_train()` — called by `run_bot_decisions()`
- `supabase/migrations/20260317000003_bot_attack_function.sql` — `bot_decide_attack()` — called by `run_bot_decisions()`

### Existing SECURITY DEFINER pattern
- `supabase/migrations/20260311000008_resource_production_functions.sql` — Established `SECURITY DEFINER SET search_path = ''` pattern used throughout the project

### Flutter routing
- `lib/core/router/app_router.dart` — GoRouter with `_redirect()` function, `StatefulShellRoute`, `profileProvider` integration
- `lib/features/profile/providers/profile_provider.dart` — `isAdmin` getter already available on `ProfileNotifier`

### Game tables for world state query
- `supabase/migrations/20260311000004_create_city_resources.sql` — Resource balances per city
- `supabase/migrations/20260311000005_create_city_buildings.sql` — Building levels per city
- `supabase/migrations/20260311000001_create_profiles.sql` — Player profiles with `is_bot`, `is_admin`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ProfileNotifier.isAdmin` getter — already reads `is_admin` from profile map; route guard can use it directly
- `SECURITY DEFINER SET search_path = ''` pattern — used in resource_production_functions and construction_functions; follow same pattern for GodMode RPCs
- `run_bot_decisions()` function — can be called with a single bot filter for `godmode_force_action`

### Established Patterns
- All game state mutations are server-side via Edge Functions or PL/pgSQL functions — GodMode RPCs follow this same pattern
- RLS with deny-all for sensitive tables (bot_schedules) — GodMode RPCs use SECURITY DEFINER to bypass RLS
- Migration naming: `YYYYMMDDNNNNNN_description.sql`
- Profile model is raw `Map<String, dynamic>` — no typed Dart class

### Integration Points
- `app_router.dart` `_redirect()` function — extend with `/godmode` route check using `profileProvider.notifier.isAdmin`
- `bot_schedules.is_paused` column — `godmode_set_bot_paused` updates this; `run_bot_decisions()` already respects it
- `city_resources`, `city_buildings`, `unit_movements`, `battles`, `trade_routes`, `spy_reports` tables — queried by world state and event feed RPCs

</code_context>

<specifics>
## Specific Ideas

- GodMode RPCs are the only path to admin data — no Edge Function HTTP endpoints for admin (avoids service_role key in Flutter)
- `godmode_force_action` calls the existing `run_bot_decisions()` logic for one bot — no separate bot action implementation
- The `/godmode` route is a placeholder in this phase (empty screen or redirect) — Phase 22 builds the actual dashboard UI

</specifics>

<deferred>
## Deferred Ideas

- Bot speed adjustment UI — Phase 22 (GodMode Flutter Dashboard)
- GodMode world map overlay — v1.3+ future requirement (GOD-F01)
- Time-travel replay — v1.3+ future requirement (GOD-F02)
- Economy analytics dashboard — v1.3+ future requirement (GOD-F03)

</deferred>

---

*Phase: 21-godmode-backend*
*Context gathered: 2026-03-17*
