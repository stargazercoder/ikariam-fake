---
phase: 21-godmode-backend
plan: 01
subsystem: database
tags: [postgres, plpgsql, security-definer, godmode, go_router, flutter, rpc]

# Dependency graph
requires:
  - phase: 20-seed-data
    provides: bot_schedules table, bot profiles seeded, run_bot_decisions function
  - phase: 19-bot-decision-engine
    provides: bot_decide_upgrade, bot_decide_train, bot_decide_attack functions
  - phase: 18-bot-schema
    provides: profiles.is_admin, profiles.is_bot, bot_schedules table schema
provides:
  - Five SECURITY DEFINER RPCs for GodMode admin operations
  - /godmode Flutter route with non-admin redirect guard
  - GodModePlaceholderScreen as foundation for Phase 22 dashboard UI
affects:
  - 22-godmode-dashboard (builds full UI on top of these RPCs)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - SECURITY DEFINER + is_admin guard pattern for all admin RPCs
    - GoRouter Rule 4b pattern for role-based route guarding

key-files:
  created:
    - supabase/migrations/20260317000005_godmode_rpcs.sql
    - lib/features/godmode/screens/godmode_placeholder_screen.dart
  modified:
    - lib/core/router/app_router.dart

key-decisions:
  - "service_role key must not appear in any Flutter file — GodMode access is via SECURITY DEFINER RPCs with is_admin check, not direct DB access"
  - "godmode_force_action does NOT update next_action_at — forced actions are out-of-band and must not disrupt the cron schedule"
  - "admin_set_resources assumes one city per player (v1.3); TODO comment added for future multi-city extension"
  - "/godmode route is a top-level GoRoute outside StatefulShellRoute — admin dashboard has no bottom nav"
  - "Rule 4b placed after profileNotifier declaration (line 99) and after Rule 4 isAuthRoute check — ensures profile is loaded before isAdmin check"

patterns-established:
  - "Admin RPC pattern: SECURITY DEFINER SET search_path = '' + v_caller_id/v_is_admin guard + ERRCODE = 'insufficient_privilege'"
  - "GoRouter role guard: Rule 4b inserted between Rule 4 (auth route redirect) and Rule 5 (no redirect) — reliable because profile already loaded"

requirements-completed: [GOD-05]

# Metrics
duration: 3min
completed: 2026-03-17
---

# Phase 21 Plan 01: GodMode Backend Summary

**Five SECURITY DEFINER RPCs delivering admin-only world state, bot controls, and resource overrides, plus Flutter /godmode route guard redirecting non-admins to /map**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-17T15:52:02Z
- **Completed:** 2026-03-17T15:54:29Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- All five GodMode RPCs written with `SECURITY DEFINER SET search_path = ''` and `is_admin` guard raising SQLSTATE 42501 for non-admins
- `godmode_get_world_state` returns full JSONB world snapshot with resources (all 6 types via `jsonb_object_agg`), army land/naval counts, building levels, and active battles per player
- `godmode_force_action` runs the bot priority chain (upgrade → train → attack) without touching `next_action_at`, keeping cron schedule intact
- `admin_set_resources` clamps all 5 resource types to 0 minimum using `GREATEST`
- `godmode_get_events` unions battles, unit_movements (trades), and spy_reports into a pageable event feed
- Flutter `/godmode` route added as top-level GoRoute with Rule 4b redirect — non-admins sent to /map

## Task Commits

Each task was committed atomically:

1. **Task 1: Create GodMode RPCs migration** - `98fbf32` (feat)
2. **Task 2: Add /godmode route guard and placeholder screen** - `1006433` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified

- `supabase/migrations/20260317000005_godmode_rpcs.sql` - All 5 GodMode RPCs with admin guard + GRANT EXECUTE
- `lib/features/godmode/screens/godmode_placeholder_screen.dart` - Minimal placeholder StatelessWidget for Phase 22
- `lib/core/router/app_router.dart` - Import added, Rule 4b redirect, /godmode GoRoute

## Decisions Made

- `godmode_force_action` omits `next_action_at` update by design — out-of-band forced actions must not shift bot cron schedules
- `admin_set_resources` uses `GREATEST(p_x, 0)` clamp per resource type; wine is intentionally omitted from this RPC (wine comes from island production, not direct admin grants)
- `/godmode` placed outside `StatefulShellRoute` so the admin dashboard has no bottom navigation bar

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- All 5 RPCs are deployed via migration and callable from authenticated admin users
- GodModePlaceholderScreen is the mount point Phase 22 replaces with the full dashboard
- `profileNotifier.isAdmin` is already available in the router — Phase 22 can expose GodMode entry point in UI (e.g., AppBar button for admin users)
- No blockers for Phase 22

---
*Phase: 21-godmode-backend*
*Completed: 2026-03-17*

## Self-Check: PASSED

- supabase/migrations/20260317000005_godmode_rpcs.sql: FOUND
- lib/features/godmode/screens/godmode_placeholder_screen.dart: FOUND
- .planning/phases/21-godmode-backend/21-01-SUMMARY.md: FOUND
- Commit 98fbf32 (Task 1): FOUND
- Commit 1006433 (Task 2): FOUND
