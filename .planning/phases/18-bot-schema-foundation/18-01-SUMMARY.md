---
phase: 18-bot-schema-foundation
plan: 01
subsystem: database
tags: [supabase, postgres, rls, migrations, riverpod, flutter, unit-tests]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: profiles table schema (id, display_name, avatar_id, RLS policies)
provides:
  - is_bot and is_admin boolean columns on profiles table (NOT NULL DEFAULT false)
  - Column-level REVOKE preventing clients from updating is_bot/is_admin
  - bot_schedules table with bot_id PK/FK, is_paused, aggression (0-3), next_action_at
  - RLS enabled on bot_schedules with zero policies (deny-all for clients)
  - ProfileNotifier.isBot and ProfileNotifier.isAdmin getters with null-safe defaults
  - 8 unit tests covering absent key, true, false, and null profile cases
affects:
  - phase-19-bot-behavior-engine
  - phase-20-seed-data
  - phase-21-godmode-ui
  - phase-22-godmode-rpcs

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "(profile?['is_bot'] as bool?) ?? false — null-safe bool accessor for Map<String,dynamic> profile rows"
    - "Column-level REVOKE from authenticated as defense-in-depth layer beyond RLS row policies"
    - "RLS enabled with zero policies as deny-all for client access to server-only tables"

key-files:
  created:
    - supabase/migrations/20260317000001_bot_schema.sql
    - test/unit/profile_bot_fields_test.dart
  modified:
    - lib/features/profile/providers/profile_provider.dart

key-decisions:
  - "is_bot and is_admin use NOT NULL DEFAULT false — PostgreSQL backfills existing rows without UPDATE migration"
  - "Column-level REVOKE on is_bot/is_admin adds defense-in-depth beyond RLS profiles_update_own policy"
  - "bot_schedules has RLS enabled with zero policies — only SECURITY DEFINER functions (pg_cron, GodMode RPCs) can read/write"
  - "isBot/isAdmin getters use state.whenOrNull pattern matching existing hasCompletedProfile — consistent NotifIer API"
  - "aggression CHECK (aggression BETWEEN 0 AND 3) enforced at DB level — 0=passive, 3=aggressive"

patterns-established:
  - "Profile boolean flags: (profile?['field'] as bool?) ?? false — safe for pre-migration cached maps"
  - "Server-only tables: CREATE TABLE + ENABLE ROW LEVEL SECURITY with no CREATE POLICY = deny-all for clients"

requirements-completed: [BOT-01, BOT-06]

# Metrics
duration: 3min
completed: 2026-03-17
---

# Phase 18 Plan 01: Bot Schema Foundation Summary

**PostgreSQL bot schema: is_bot/is_admin columns on profiles with column-level REVOKE, deny-all bot_schedules table, and null-safe ProfileNotifier getters backed by 8 passing unit tests**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-03-17T13:23:25Z
- **Completed:** 2026-03-17T13:26:11Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- SQL migration adds is_bot/is_admin to profiles with NOT NULL DEFAULT false (zero-downtime backfill) plus column-level REVOKE blocking authenticated clients from updating those flags
- bot_schedules table created with RLS enabled and no client policies — only SECURITY DEFINER functions (pg_cron bot-think tick, GodMode RPCs) can access it
- ProfileNotifier gains isBot and isAdmin getters following the existing hasCompletedProfile state.whenOrNull pattern; safely returns false for absent keys and null profiles

## Task Commits

Each task was committed atomically:

1. **Task 1: Create bot schema migration** - `9539c86` (feat)
2. **Task 2 TDD RED: isBot/isAdmin unit tests** - `6bf6081` (test)
3. **Task 2 TDD GREEN: isBot/isAdmin getters** - `d01a9ff` (feat)

**Plan metadata:** _(docs commit follows)_

_Note: TDD task split into test commit (RED) and implementation commit (GREEN)_

## Files Created/Modified

- `supabase/migrations/20260317000001_bot_schema.sql` - ALTER profiles + CREATE bot_schedules + REVOKE + RLS
- `test/unit/profile_bot_fields_test.dart` - 8 unit tests for isBot/isAdmin accessor pattern
- `lib/features/profile/providers/profile_provider.dart` - Added isBot and isAdmin getters to ProfileNotifier

## Decisions Made

- NOT NULL DEFAULT false for both columns lets PostgreSQL backfill existing rows without a separate UPDATE migration
- Column-level `REVOKE UPDATE (is_bot, is_admin) FROM authenticated` adds defense-in-depth — the existing profiles_update_own RLS policy grants row-level access but column-level REVOKE ensures clients cannot flip these flags regardless
- bot_schedules zero-policy approach (RLS on + no CREATE POLICY) is the cleanest deny-all pattern for server-only tables
- aggression 0-3 range enforced by CHECK at DB level — 0=passive, 3=aggressive, tunable for balance

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - migration will apply on next `supabase db push` or local reset.

## Next Phase Readiness

- Phase 19 (Bot Behavior Engine): bot_schedules table and is_bot column are ready for the pg_cron tick function to query and schedule bot actions
- Phase 20 (Seed Data): INSERT INTO profiles with is_bot=true now valid; INSERT INTO bot_schedules ready
- Phase 21-22 (GodMode): ProfileNotifier.isAdmin getter available for GoRouter redirect guard

---
*Phase: 18-bot-schema-foundation*
*Completed: 2026-03-17*
