---
phase: 08-bug-fixes-timer-guards
plan: 02
subsystem: database
tags: [postgresql, pg_cron, supabase, combat, battle, migrations, flutter-test]

requires:
  - phase: 05-combat
    provides: resolve_battles() function with full-army per turn
  - phase: 08-01
    provides: dispatch-units bug fix (preceding plan in same phase)

provides:
  - Environment-gated production timer revert (current_setting guard)
  - 30% partial army engagement fraction in resolve_battles()
  - Dart documentary tests for both timer contract and engagement formula

affects:
  - 09-phase2-verification (combat requirements CMBT-01, CMBT-02 now closed)

tech-stack:
  added: []
  patterns:
    - "Append-only migration with current_setting guard: new migration overrides function
       only when app.environment = 'production', leaving dev speed-up intact otherwise"
    - "Dual-environment function: single CREATE OR REPLACE handles both prod and dev by
       resolving v_turn_interval from current_setting at runtime"
    - "Engagement fraction via GREATEST(1, FLOOR(qty * fraction)): ensures minimum 1 unit
       engages per unit type, prevents zero-damage stall states"

key-files:
  created:
    - supabase/migrations/20260312000008_env_guard_timers.sql
    - supabase/migrations/20260312000009_partial_engagement.sql
    - test/unit/combat_timer_guard_test.dart
    - test/unit/combat_engagement_test.dart
  modified: []

key-decisions:
  - "[08-02] Engagement fraction applied only in attack/defense summation loops, NOT in casualty loops — double-applying would over-count the fraction"
  - "[08-02] v_turn_interval resolved once per function call via current_setting — avoids repeated setting lookups in the per-battle loop"
  - "[08-02] Migration 20260312000009 wraps both environments in a single function — avoids needing separate production/dev function copies"

patterns-established:
  - "Environment guard pattern: DO $$ BEGIN IF current_setting('app.environment', true) = 'production' THEN ... END IF; END; $$ for any future timer or behavior guards"
  - "Engagement fraction sync: Dart constant mirrors SQL CONSTANT — both must be updated together; sync comment enforces this"

requirements-completed: [CMBT-01, CMBT-02]

duration: 4min
completed: 2026-03-12
---

# Phase 08 Plan 02: Bug Fixes - Timer Guards Summary

**Environment-gated production timer revert (5-min turns) and 30% partial army engagement fraction added to resolve_battles() via two append-only SQL migrations**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-12T14:57:18Z
- **Completed:** 2026-03-12T15:01:00Z
- **Tasks:** 2 completed
- **Files modified:** 4

## Accomplishments

- Created migration 20260312000008 that guards timer revert behind `current_setting('app.environment', true) = 'production'` — production uses 5-minute battle turns and `*/5` cron tick; dev retains 10-second speed-up from migration 20260312000007
- Created migration 20260312000009 that replaces resolve_battles() with 30% engagement fraction (`v_engagement_fraction CONSTANT numeric := 0.30`) applied in naval and land summation phases; handles both dev and production turn intervals in a single function
- Unskipped combat_timer_guard_test.dart (3 tests) and combat_engagement_test.dart (4 tests) — all 7 pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Env guard migration + timer contract tests** - `04e1e6b` (feat)
2. **Task 2: Partial engagement migration + formula tests** - `d425679` (feat)

**Plan metadata:** (docs commit to follow)

## Files Created/Modified

- `supabase/migrations/20260312000008_env_guard_timers.sql` - DO block with current_setting guard; restores 5-min resolve_battles() and process_arrivals() for production
- `supabase/migrations/20260312000009_partial_engagement.sql` - resolve_battles() with 30% engagement fraction, dual-environment turn interval
- `test/unit/combat_timer_guard_test.dart` - 3 documentary tests for production timer contract (unskipped)
- `test/unit/combat_engagement_test.dart` - 4 formula tests for engagement fraction (unskipped)

## Decisions Made

- Engagement fraction applied only in attack/defense summation, not in the casualty loops — applying it twice would double-count and produce incorrect loss ratios
- `v_turn_interval` resolved once at function entry via `current_setting` — cleaner than querying inside the per-battle loop
- Migration 20260312000009 handles both environments in one function body (via `v_turn_interval`) rather than using another conditional DO block — simpler and avoids duplication

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - both migrations and tests created cleanly without issues.

## User Setup Required

**Production environment configuration required.**
To activate production timers, set the following in Supabase project settings (Database → Configuration → Custom Config):

```
app.environment = production
```

Without this setting, `current_setting('app.environment', true)` returns NULL and the dev speed-up timers remain active (which is correct for local development).

## Next Phase Readiness

- CMBT-01 and CMBT-02 are now closed — timer guard and partial engagement both implemented
- Phase 9 verification can now confirm these requirements against production behavior
- Both test files are fully unskipped; no remaining skips for combat timer/engagement requirements

---
*Phase: 08-bug-fixes-timer-guards*
*Completed: 2026-03-12*
