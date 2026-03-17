# Phase 18: Bot Schema Foundation - Context

**Gathered:** 2026-03-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Add database columns (`is_bot`, `is_admin`) to profiles table, create `bot_schedules` table, and update the Profile Dart model. This phase is schema-only — no bot behavior logic, no GodMode UI, no seed data. Everything else depends on this schema being in place first.

</domain>

<decisions>
## Implementation Decisions

### Schema columns
- `is_bot BOOLEAN NOT NULL DEFAULT false` added to `profiles` table — marks bot accounts
- `is_admin BOOLEAN NOT NULL DEFAULT false` added to `profiles` table — gates GodMode access
- Both columns default to false so existing rows are unaffected (no data migration needed)

### Bot schedules table
- New `bot_schedules` table with FK to profiles(id) WHERE is_bot = true
- Columns: `aggression INTEGER NOT NULL DEFAULT 1 CHECK (aggression BETWEEN 0 AND 3)` — controls attack frequency
- `is_paused BOOLEAN NOT NULL DEFAULT false` — GodMode pause control
- `next_action_at TIMESTAMPTZ` — when bot_tick should next process this bot
- RLS enabled; no client-facing SELECT policy (only SECURITY DEFINER functions and admin RPCs read this)

### RLS policy
- Bots remain visible in profiles SELECT (existing `profiles_select_all` policy unchanged) — bots are real participants in the game world, players see them on islands and world map
- `bot_schedules` has NO authenticated user policy — only server-side SECURITY DEFINER functions access it
- is_admin is readable by all (needed for future GodMode route guard in Flutter) but only the DB can set it (no UPDATE policy for is_admin column)

### Profile Dart model
- Add `bool isBot` and `bool isAdmin` fields to Profile model with `false` defaults
- Use `(json['is_bot'] as bool?) ?? false` pattern for backwards compatibility with existing cached data
- ProfileNotifier and profileProvider remain unchanged — just reads additional fields

### Claude's Discretion
- Exact migration filename timestamp
- Whether to add a database index on `is_bot` (low cardinality — probably not needed for 20 bots)
- Column ordering in the migration

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing schema
- `supabase/migrations/20260311000001_create_profiles.sql` — Current profiles table definition, RLS policies
- `supabase/migrations/20260311000003_handle_new_user_trigger.sql` — Trigger that creates profile + city on signup (bots will go through this same trigger)

### Existing Dart model
- `lib/features/profile/data/profile_repository.dart` — ProfileRepository with fetchProfile and updateProfile
- `lib/features/profile/providers/profile_provider.dart` — ProfileNotifier AsyncNotifier

### Research
- `.planning/research/ARCHITECTURE.md` — Bot-as-Player pattern, SECURITY DEFINER approach
- `.planning/research/PITFALLS.md` — Seed idempotency, service_role key exposure risks

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `supabase/seed.sql` — Existing 7 test accounts pattern (auth.users + auth.identities + profile UPDATE) — Phase 20 will extend this for 20 bots
- `handle_new_user()` trigger — Auto-creates profile + city; bots use the same path

### Established Patterns
- Migration naming: `YYYYMMDDNNNNNN_description.sql` — continue this pattern
- Profile model is a raw `Map<String, dynamic>` (not a typed class) — ProfileNotifier returns `Map<String, dynamic>?`
- RLS policy naming: `tablename_action_scope` (e.g., `profiles_select_all`, `profiles_update_own`)

### Integration Points
- `ProfileNotifier.build()` fetches from profiles table — will automatically include new columns
- `ProfileNotifier.hasCompletedProfile` checks display_name — no change needed
- `ProfileRepository.fetchProfile()` returns all columns via `.select()` — new columns auto-included
- `ProfileRepository.updateProfile()` only updates display_name and avatar_id — is_bot/is_admin not client-writable

</code_context>

<specifics>
## Specific Ideas

- Profile model is currently a raw Map — no typed Dart class. Keep it as Map for this phase (typed class is a separate refactoring concern).
- Bot accounts go through the same handle_new_user trigger as real players, so they automatically get a city placed on an island.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 18-bot-schema-foundation*
*Context gathered: 2026-03-17*
