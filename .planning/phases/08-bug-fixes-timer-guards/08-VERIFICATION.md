---
phase: 08-bug-fixes-timer-guards
verified: 2026-03-12T16:00:00Z
status: passed
score: 8/8 must-haves verified
gaps: []
---

# Phase 8: Bug Fixes & Timer Guards Verification Report

**Phase Goal:** Fix dispatch-units undefined constant, dev toolbar dispose ordering, environment timer guards for production, and partial army engagement per turn.
**Verified:** 2026-03-12T16:00:00Z
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `calcTravelMinutes` returns a finite positive integer for any island pair | VERIFIED | `BASE_MINUTES_PER_GRID_UNIT = 2` declared at line 25 of `dispatch-units/index.ts`; `Number.isFinite` guard at lines 191-193 returns 500 on bad value |
| 2 | dispatch-units Edge Function produces a valid ISO `arrive_at` timestamp | VERIFIED | Lines 211-212: `arriveAt = new Date(now + travelMinutes * 60 * 1000).toISOString()` — guarded by finite check before use |
| 3 | Dev toolbar Trigger Battle dialog completes without dispose error | VERIFIED | `dev_toolbar.dart` lines 250-252: `defenderCityId = controller.text.trim()` captured before `controller.dispose()` |
| 4 | Production environment uses 5-minute battle turns and 5-minute resource ticks | VERIFIED | Migration `20260312000008_env_guard_timers.sql` line 16: `current_setting('app.environment', true) = 'production'`; lines 22-25: `*/5 * * * *` cron; line 385: `INTERVAL '5 minutes'`; line 466: `INTERVAL '5 minutes'` |
| 5 | Development environment retains speed-up timers (10-second turns, 1-minute resource ticks) | VERIFIED | Migration 20260312000008 only executes inside `IF ... = 'production'` block; no-op for NULL/development. Migration 20260312000009 uses `v_turn_interval := INTERVAL '10 seconds'` for non-production at line 92 |
| 6 | Each battle turn only 30% of armies engage in combat | VERIFIED | Migration `20260312000009_partial_engagement.sql` line 35: `v_engagement_fraction CONSTANT numeric := 0.30`; applied in naval phase (lines 127, 136) and land phase (lines 220, 229) via `GREATEST(1, FLOOR(qty * v_engagement_fraction))` |
| 7 | Casualties are subtracted from full army; survivors carry to next turn | VERIFIED | Migration 20260312000009 casualty loops (lines 160-183, 243-269) use full `v_att_qty`/`v_def_qty` — engagement fraction is applied only in summation, not casualty application |
| 8 | Minimum 1 unit engages when army size > 0 | VERIFIED | All four engagement expressions use `GREATEST(1, FLOOR(...))` — verified at lines 127, 136, 220, 229 of migration 20260312000009 |

**Score:** 8/8 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `test/unit/dispatch_travel_test.dart` | MIL-05 travel formula tests | VERIFIED | 3 active tests (no skip), imports `unit_constants.dart`, tests `baseMinutesPerGridUnit == 2`, adjacent island result, same-island minimum |
| `test/unit/combat_timer_guard_test.dart` | CMBT-01 production timer documentation tests | VERIFIED | 3 active tests, constants `productionBattleTurnMinutes = 5`, `productionResourceTickCron = '*/5 * * * *'`, `devBattleTurnSeconds = 10` |
| `test/unit/combat_engagement_test.dart` | CMBT-02 engagement fraction formula tests | VERIFIED | 4 active tests covering fraction constant, engaged subset calculation, casualty math, minimum-1-unit clamp |
| `test/widget/dev_toolbar_trigger_test.dart` | Dev toolbar dispose fix widget test | VERIFIED | 2 active tests documenting and verifying capture-before-dispose controller lifecycle pattern |
| `supabase/functions/dispatch-units/index.ts` | Working dispatch with `BASE_MINUTES_PER_GRID_UNIT` declared | VERIFIED | Line 25: `const BASE_MINUTES_PER_GRID_UNIT = 2;`; lines 191-193: finite guard |
| `lib/core/dev/dev_toolbar.dart` | Fixed `_triggerBattle` dispose ordering | VERIFIED | Lines 250-252: `defenderCityId` captured before `controller.dispose()` |
| `supabase/migrations/20260312000008_env_guard_timers.sql` | Environment-gated revert of speed-up timers for production | VERIFIED | DO block with `current_setting` guard; restores `*/5` cron and `INTERVAL '5 minutes'` for both `resolve_battles()` and `process_arrivals()` |
| `supabase/migrations/20260312000009_partial_engagement.sql` | `resolve_battles()` with 30% engagement fraction | VERIFIED | `v_engagement_fraction CONSTANT numeric := 0.30`; `GREATEST(1, FLOOR(...))` in all 4 summation loops; `v_turn_interval` for dual-environment support |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `supabase/functions/dispatch-units/index.ts` | `lib/core/constants/unit_constants.dart` | `BASE_MINUTES_PER_GRID_UNIT = 2` matches `baseMinutesPerGridUnit = 2` | VERIFIED | TS line 25 declares `= 2`; Dart line 176 declares `= 2`; sync comment present in both files |
| `supabase/migrations/20260312000008_env_guard_timers.sql` | `supabase/migrations/20260312000007_speed_up_all_timers.sql` | Reverts speed-up when `app.environment = production` | VERIFIED | `current_setting('app.environment', true)` pattern at line 16; DO block is no-op when setting absent |
| `supabase/migrations/20260312000009_partial_engagement.sql` | `supabase/migrations/20260312000007_speed_up_all_timers.sql` | Replaces `resolve_battles()` with engagement fraction version | VERIFIED | `v_engagement_fraction` declared at line 35; applied in summation loops at lines 127, 136, 220, 229 |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| MIL-05 | 08-01-PLAN | Troops dispatched with travel time based on distance | SATISFIED | `BASE_MINUTES_PER_GRID_UNIT = 2` fixes undefined-constant crash; finite guard prevents NaN `arrive_at`; Dart constant synced; 3 passing formula tests |
| CMBT-01 | 08-02-PLAN | Battles resolve in turns, each turn lasting 5 minutes | SATISFIED | Migration 20260312000008 guards production to `INTERVAL '5 minutes'` and `*/5 * * * *` cron; 3 documentary tests pass |
| CMBT-02 | 08-02-PLAN | Each turn a portion of armies engage, survivors carry to next turn | SATISFIED | Migration 20260312000009 applies 30% engagement fraction in all summation loops with `GREATEST(1, FLOOR(...))`; full-army casualty subtraction preserves survivors; 4 formula tests pass |

**REQUIREMENTS.md traceability check:** MIL-05, CMBT-01, CMBT-02 all marked `Phase 8 | Complete` in the traceability table. No orphaned phase-8 requirements found.

---

### Commit Verification

All 4 commits from SUMMARY files verified present in git history:

| Commit | Message | Plan |
|--------|---------|------|
| `df49fed` | test(08-01): add Wave 0 test scaffolds for Phase 8 requirements | 08-01 Task 1 |
| `8539e70` | fix(08-01): fix dispatch-units undefined constant and dev toolbar dispose ordering | 08-01 Task 2 |
| `04e1e6b` | feat(08-02): add env guard migration and timer contract tests (CMBT-01) | 08-02 Task 1 |
| `d425679` | feat(08-02): implement 30% partial engagement in resolve_battles() (CMBT-02) | 08-02 Task 2 |

---

### Anti-Patterns Found

None. Scan of all 8 phase-8 artifacts returned no TODOs, FIXMEs, placeholder comments, `return null`, empty handlers, or skipped tests.

---

### Human Verification Required

#### 1. Production Timer Activation

**Test:** Deploy to Supabase with `app.environment = production` set in Database > Settings > Custom Config. Wait for a battle to advance past its `next_turn_at`. Check that `next_turn_at` increments by 5 minutes, not 10 seconds.
**Expected:** Battle turn advances on 5-minute intervals in production; dev retains 10-second intervals.
**Why human:** Cannot verify `current_setting` runtime behavior without a live Supabase deployment with the config variable set.

#### 2. Dispatch travel time end-to-end

**Test:** Dispatch units from one city to a city on a different island (e.g., grid distance ~3 units). Verify `arrive_at` in `unit_movements` is approximately `now + ceil(sqrt(dx^2+dy^2) * 2) minutes`.
**Expected:** `arrive_at` is a valid ISO timestamp roughly 6 minutes in the future for a distance-3 dispatch.
**Why human:** Requires live Supabase connection and authenticated session; finite-guard path cannot be exercised without a running Edge Function.

---

### Gaps Summary

No gaps. All 8 must-have truths verified. All 8 artifacts exist, are substantive, and are wired. All 3 requirement IDs (MIL-05, CMBT-01, CMBT-02) are satisfied. All 4 commits are confirmed in git history. Zero blocker anti-patterns found.

Phase goal — fix dispatch-units undefined constant, dev toolbar dispose ordering, environment timer guards for production, and partial army engagement per turn — is fully achieved in the codebase.

---

_Verified: 2026-03-12T16:00:00Z_
_Verifier: Claude (gsd-verifier)_
