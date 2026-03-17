---
phase: 20-seed-data
verified: 2026-03-17T18:30:00Z
status: human_needed
score: 5/6 must-haves verified
human_verification:
  - test: "Run `npx supabase db reset` twice consecutively in the project directory"
    expected: "Both runs exit with code 0 and produce no 'duplicate key value violates unique constraint' errors"
    why_human: "Cannot execute live database commands programmatically — must be run against actual running Supabase instance"
---

# Phase 20: Seed Data Verification Report

**Phase Goal:** Running `supabase db reset` produces a world with 20 diverse bot accounts ready for gameplay testing, and running it twice produces no errors
**Verified:** 2026-03-17T18:30:00Z
**Status:** human_needed — 5/6 truths verified statically; idempotency requires live database run
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | After db reset, 20 bot profiles exist with is_bot=true | VERIFIED | 20 `UPDATE public.profiles SET ... is_bot = true` statements at lines 824-843 of seed.sql, each targeting a distinct bot UUID b01-b20 |
| 2 | Bots span at least 3 distinct development tiers (low/mid/high building levels) | VERIFIED | Low tier (bots 1-7): barracks=1, town_hall<=2; Mid tier (bots 8-14): town_hall=3-4, barracks=2-3; High tier (bots 15-20): town_hall=5-6, barracks=4-5. Code confirmed at lines 850-1130 |
| 3 | Running the seed twice without db reset produces no errors | ? UNCERTAIN | All auth.users/auth.identities use `ON CONFLICT (id) DO NOTHING` (lines 670, 818); bot_schedules uses `ON CONFLICT (bot_id) DO UPDATE` (line 1484); city_units uses `ON CONFLICT (city_id, unit_type) DO UPDATE` (lines 1293-1455); profiles/buildings/resources use UPDATE (naturally idempotent). Pattern analysis strongly supports idempotency but live db run required for definitive confirmation |
| 4 | All 20 bots have bot_schedules rows with aggression values 0-3 | VERIFIED | 20 rows in bot_schedules INSERT (lines 1462-1483); distribution confirmed: 5x aggression=0, 5x aggression=1, 5x aggression=2, 5x aggression=3 |
| 5 | Leonidas (a1111111) has is_admin=true | VERIFIED | Line 450: `UPDATE public.profiles SET is_admin = true WHERE id = 'a1111111-1111-1111-1111-111111111111';` |
| 6 | Every bot with hoplite/cook units has barracks>=1, with archer/phalanx has barracks>=2, with cavalry has barracks>=3 | VERIFIED | Cross-checked all 20 bots: Low tier (barracks=1) only has hoplite/cook. Mid tier bots 8,10,13 (barracks=3) include cavalry; bots 9,11,12,14 (barracks=2) have only archer/phalanx. High tier (barracks=3-5) includes catapult (needs 4) and mortar (needs 5) — bots 15/19 have barracks=5 and are the only ones with mortar. Bot 17/18 have barracks=4 and correctly have catapult but no mortar. No violations found. |

**Score:** 5/6 truths verified (1 needs human confirmation)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `supabase/seed.sql` | 20 bot accounts with diverse game states, idempotent inserts | VERIFIED | File exists at 1487 lines. Contains bot section header "Bot accounts (20 bots for v1.3)" at line 453. 8 sections covering auth.users, auth.identities, profiles, buildings, resources, units, and bot_schedules. Commit ca5568f confirmed real (+1042 lines). |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `supabase/seed.sql` | `auth.users` | INSERT with ON CONFLICT (id) DO NOTHING | WIRED | Pattern confirmed at line 670. Batch INSERT of all 20 bots in a single statement. |
| `supabase/seed.sql` | `public.bot_schedules` | INSERT with ON CONFLICT DO UPDATE | WIRED | Pattern confirmed at lines 1484-1487: `ON CONFLICT (bot_id) DO UPDATE SET aggression = EXCLUDED.aggression, is_paused = EXCLUDED.is_paused, next_action_at = EXCLUDED.next_action_at` |
| `supabase/seed.sql` | `public.city_units` | INSERT with ON CONFLICT DO UPDATE | WIRED | Pattern confirmed at lines 1293, 1299, 1305... through 1455. Each bot has its own INSERT with `ON CONFLICT (city_id, unit_type) DO UPDATE SET quantity = EXCLUDED.quantity` |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| SEED-01 | 20-01-PLAN.md | 20 bot accounts with diverse game states (varied resources, buildings, armies) | SATISFIED | 20 bots with 3 tiers: Low (bots 1-7, resources 500-1500, hoplite/cook only), Mid (bots 8-14, resources 2000-5000, archer/phalanx/cavalry mix), High (bots 15-20, resources 5000-15000, full unit mix including catapult/mortar/naval) |
| SEED-02 | 20-01-PLAN.md | Seed script is idempotent — can be re-run without conflicts or duplicate data | NEEDS HUMAN | All conflict clauses are present in the SQL (ON CONFLICT DO NOTHING for auth tables, ON CONFLICT DO UPDATE for mutable tables, UPDATE for naturally idempotent statements). Static analysis passes; live verification pending. |

No orphaned requirements found — both IDs declared in plan frontmatter map to REQUIREMENTS.md entries, and REQUIREMENTS.md shows both as Phase 20.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None | — | — | — | No anti-patterns detected. No TODO/FIXME/HACK/placeholder comments found. No empty implementations. No stub patterns. |

### Human Verification Required

#### 1. Idempotency Live Test

**Test:** In the project directory, run:
```
npx supabase db reset
npx supabase db reset
```
**Expected:** Both commands exit with code 0. The second run produces no errors of the form "duplicate key value violates unique constraint". After the second run, `SELECT COUNT(*) FROM public.profiles WHERE is_bot = true` returns 20.

**Why human:** Cannot execute live Supabase commands in this context. Static analysis of SQL conflict clauses is highly confident (all insert patterns use appropriate ON CONFLICT clauses) but cannot substitute for a real execution test.

### Gaps Summary

No blocking gaps found. All 6 must-have truths are either statically verified or structurally sound pending one live database run. The seed.sql file is substantive (1487 lines, 1042 added in commit ca5568f), all 20 bots are fully populated across all 8 data sections, conflict handling patterns match the plan specification exactly, and barracks-unit consistency is correct for all 20 bots.

The only outstanding item is the live idempotency test — the SQL patterns make a failure here unlikely, but it is the explicit stated goal of SEED-02 and must be confirmed by execution.

---

_Verified: 2026-03-17T18:30:00Z_
_Verifier: Claude (gsd-verifier)_
