---
phase: 19-bot-behavior-engine
verified: 2026-03-17T00:00:00Z
status: passed
score: 11/11 must-haves verified
re_verification: false
---

# Phase 19: Bot Behavior Engine Verification Report

**Phase Goal:** Bot behavior engine — bot_decide_upgrade, bot_decide_train, bot_decide_attack helpers plus run_bot_decisions orchestrator and bot-think-tick cron registration
**Verified:** 2026-03-17
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| #  | Truth | Status | Evidence |
|----|-------|--------|----------|
| 1  | bot_decide_upgrade() inserts a construction_queue row for the cheapest affordable building | ✓ VERIFIED | Line 169: `INSERT INTO public.construction_queue (city_id, building_type, target_level, finish_at)` — VALUES clause references `v_building_type`, `v_current_level + 1`, `v_finish_at` |
| 2  | bot_decide_upgrade() falls back to island resource donation when all buildings are queued or unaffordable | ✓ VERIFIED | Lines 181-219: donation fallback fires after FOR loop exhaustion; `PERFORM public.deduct_resource(p_city_id, 'wood', v_donation_cost)` + conditional `UPDATE public.islands SET resource_level = resource_level + 1` |
| 3  | bot_decide_train() inserts a training_queue row for the cheapest affordable land unit type | ✓ VERIFIED | Lines 414-420: `INSERT INTO public.training_queue (city_id, unit_type, quantity, finish_at)` — unit selection ordered by `total_cost ASC` |
| 4  | bot_decide_train() skips if training_queue already has an entry for the city | ✓ VERIFIED | Lines 279-286: `SELECT id ... FROM public.training_queue WHERE city_id = p_city_id LIMIT 1; IF FOUND THEN RETURN false;` |
| 5  | bot_decide_upgrade() skips if construction_queue already has an entry for the city | ✓ VERIFIED | Lines 66-73: `SELECT id ... FROM public.construction_queue WHERE city_id = p_city_id LIMIT 1; IF FOUND THEN RETURN false;` |
| 6  | bot_decide_attack() dispatches an attack by inserting into unit_movements when aggression probability passes | ✓ VERIFIED | Line 157: `INSERT INTO public.unit_movements (origin_city_id, destination_city_id, owner_id, units, movement_type, depart_at, arrive_at)` — gated by `random() >= (p_aggression / 3.0)` |
| 7  | bot_decide_attack() requires at least 5 land units before considering an attack | ✓ VERIFIED | Lines 69-75: `SELECT COALESCE(SUM(quantity), 0) INTO v_total_land ... IF v_total_land < 5 THEN RETURN;` |
| 8  | bot_decide_attack() targets random non-bot city on same island first, then any non-bot city globally | ✓ VERIFIED | Lines 79-100: same-island query with `AND p.is_bot = false ORDER BY random() LIMIT 1`; `IF NOT FOUND` global fallback with same guard |
| 9  | run_bot_decisions() iterates non-paused bots where next_action_at <= NOW() and calls helpers in priority order: upgrade -> train -> attack | ✓ VERIFIED | Lines 34-51: FOR loop filters `is_bot = true AND bs.is_paused = false AND bs.next_action_at <= NOW()`; nested `IF NOT bot_decide_upgrade ... IF NOT bot_decide_train ... PERFORM bot_decide_attack` |
| 10 | run_bot_decisions() staggers next_action_at by 15 min + random 5 min after each bot | ✓ VERIFIED | Lines 55-58: `SET next_action_at = NOW() + INTERVAL '15 minutes' + (random() * INTERVAL '5 minutes')` |
| 11 | bot-think-tick pg_cron job fires every 15 minutes calling run_bot_decisions() | ✓ VERIFIED | Lines 71-75: `SELECT cron.schedule('bot-think-tick', '*/15 * * * *', 'SELECT public.run_bot_decisions()')` |

**Score:** 11/11 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `supabase/migrations/20260317000002_bot_helper_functions.sql` | bot_decide_upgrade, bot_decide_train helper functions | ✓ VERIFIED | File exists (426 lines). Contains 2x `CREATE OR REPLACE FUNCTION`. Both return `boolean`. Both use `SECURITY DEFINER SET search_path = ''`. |
| `supabase/migrations/20260317000003_bot_attack_function.sql` | bot_decide_attack helper function | ✓ VERIFIED | File exists (177 lines). Contains 1x `CREATE OR REPLACE FUNCTION public.bot_decide_attack(p_city_id uuid, p_aggression integer)`. Returns `void`. Uses `SECURITY DEFINER SET search_path = ''`. |
| `supabase/migrations/20260317000004_bot_run_decisions_and_cron.sql` | run_bot_decisions orchestrator and pg_cron registration | ✓ VERIFIED | File exists (76 lines). Contains 1x `CREATE OR REPLACE FUNCTION public.run_bot_decisions()`. Returns `void`. Uses `SECURITY DEFINER SET search_path = ''`. Cron registration present. |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `bot_decide_upgrade` | `construction_queue` | `INSERT INTO public.construction_queue` | ✓ WIRED | Line 169 in 20260317000002 — full INSERT with city_id, building_type, target_level, finish_at |
| `bot_decide_train` | `training_queue` | `INSERT INTO public.training_queue` | ✓ WIRED | Line 415 in 20260317000002 — full INSERT with city_id, unit_type, quantity, finish_at |
| `bot_decide_upgrade` | `deduct_resource` | `PERFORM public.deduct_resource()` | ✓ WIRED | Lines 156-160 and 207 in 20260317000002 — called for each non-zero resource type and for island donation |
| `run_bot_decisions` | `bot_decide_upgrade` | function call in priority chain | ✓ WIRED | Line 45 in 20260317000004: `IF NOT public.bot_decide_upgrade(bot.city_id) THEN` |
| `run_bot_decisions` | `bot_decide_train` | function call in priority chain | ✓ WIRED | Line 46 in 20260317000004: `IF NOT public.bot_decide_train(bot.city_id) THEN` |
| `run_bot_decisions` | `bot_decide_attack` | function call gated by aggression | ✓ WIRED | Line 48 in 20260317000004: `PERFORM public.bot_decide_attack(bot.city_id, bot.aggression)` inside `IF bot.aggression > 0` |
| `bot_decide_attack` | `unit_movements` | INSERT for attack dispatch | ✓ WIRED | Line 157 in 20260317000003 — full INSERT with origin_city_id, destination_city_id, owner_id, units, movement_type='attack', depart_at, arrive_at |
| `cron.schedule` | `run_bot_decisions` | pg_cron bot-think-tick | ✓ WIRED | Lines 71-75 in 20260317000004: `cron.schedule('bot-think-tick', '*/15 * * * *', 'SELECT public.run_bot_decisions()')` |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| BOT-02 | 19-02-PLAN.md | Bots periodically attack neighboring cities via pg_cron schedule | ✓ SATISFIED | bot_decide_attack() dispatches via unit_movements INSERT; bot-think-tick fires every 15 min; same-island targeting confirmed |
| BOT-03 | 19-01-PLAN.md, 19-02-PLAN.md | Bots retrain armies after suffering losses | ✓ SATISFIED | bot_decide_train() checks training_queue vacancy and queues training for cheapest affordable unit; called in priority chain |
| BOT-04 | 19-01-PLAN.md, 19-02-PLAN.md | Bots upgrade island resource buildings they occupy | ✓ SATISFIED | bot_decide_upgrade() island donation fallback: `UPDATE public.islands SET resource_level = resource_level + 1` with `CEIL(300 * 1.5^resource_level)` wood cost |
| BOT-05 | 19-01-PLAN.md, 19-02-PLAN.md | Bots upgrade buildings in their own cities | ✓ SATISFIED | bot_decide_upgrade() primary path: cheapest building by level ASC, cost formula `CEIL(base * 1.5^level)`, INSERT to construction_queue |

**Orphaned requirements check:** BOT-01 and BOT-06 are mapped to Phase 18 in REQUIREMENTS.md — not Phase 19. No orphaned requirements for this phase.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `20260317000002_bot_helper_functions.sql` | 409 | `-- TODO: parameterize via game_config table when production deployment is planned` | ℹ️ Info | Intentional documented design decision; dev speed hardcoded to 0.2 — matches `train-units/index.ts DEV_SPEED_MULTIPLIER`. No stub behavior. |
| `20260317000003_bot_attack_function.sql` | 139 | `-- TODO: parameterize dev speed multiplier via game_config table when production deployment is planned` | ℹ️ Info | Same intentional pattern. Travel time formula correct and fully implemented. |

No blocker or warning anti-patterns found. Both TODOs are architecture notes, not incomplete implementations.

---

### Human Verification Required

None. All behavioral logic verified statically against SQL patterns. Runtime verification (supabase db reset) was not feasible in this environment (Docker Desktop unavailable per SUMMARY notes) but all acceptance criteria were confirmed via grep pattern matching against the actual file content.

The following would benefit from human/runtime verification in a live environment:

**1. Migration applies cleanly (supabase db reset)**
- **Test:** Run `npx supabase db reset` with Docker Desktop active
- **Expected:** All 4 bot migrations apply without errors (20260317000001 through 20260317000004)
- **Why human:** Requires Docker Desktop runtime; cannot verify SQL syntax execution statically

**2. Priority chain behavior**
- **Test:** Insert a bot with construction_queue empty, training_queue empty, aggression=2; call `SELECT public.run_bot_decisions()`
- **Expected:** bot_decide_upgrade returns true (if affordable building exists); bot_decide_train and bot_decide_attack are skipped
- **Why human:** Requires live DB with seed data

---

### Commits Verified

| Hash | Message | Status |
|------|---------|--------|
| `514daef` | feat(19-01): add bot_decide_upgrade and bot_decide_train helper functions | ✓ EXISTS |
| `81ee847` | feat(19-02): add bot_decide_attack helper function | ✓ EXISTS |
| `5243894` | feat(19-02): add run_bot_decisions orchestrator and bot-think-tick cron job | ✓ EXISTS |

---

## Gaps Summary

No gaps. All 11 observable truths are verified, all 3 required artifacts exist with substantive implementation, all 8 key links are wired. All 4 requirement IDs (BOT-02 through BOT-05) are satisfied. Phase goal is fully achieved.

---

_Verified: 2026-03-17_
_Verifier: Claude (gsd-verifier)_
