---
phase: 19
slug: bot-behavior-engine
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-17
---

# Phase 19 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | PL/pgSQL inline verification via psql / Supabase SQL editor |
| **Config file** | none — SQL functions tested via direct SQL calls |
| **Quick run command** | `psql -c "SELECT public.run_bot_decisions();"` |
| **Full suite command** | `psql -f .planning/phases/19-bot-behavior-engine/verify_bots.sql` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `psql -c "SELECT public.run_bot_decisions();"`
- **After every plan wave:** Run full verification SQL
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 19-01-01 | 01 | 1 | BOT-05 | integration | `SELECT public.bot_decide_upgrade(city_id)` | ❌ W0 | ⬜ pending |
| 19-01-02 | 01 | 1 | BOT-03 | integration | `SELECT public.bot_decide_train(city_id)` | ❌ W0 | ⬜ pending |
| 19-01-03 | 01 | 1 | BOT-02 | integration | `SELECT public.bot_decide_attack(city_id, aggression)` | ❌ W0 | ⬜ pending |
| 19-02-01 | 02 | 2 | BOT-02,03,04,05 | integration | `SELECT public.run_bot_decisions()` | ❌ W0 | ⬜ pending |
| 19-02-02 | 02 | 2 | BOT-04 | integration | `SELECT * FROM island_resource_levels` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Bot test accounts must exist (is_bot = true in profiles, bot_schedules rows)
- [ ] At least one bot city must have resources and buildings for upgrade/train actions

*If none: "Existing infrastructure covers all phase requirements."*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| pg_cron fires every 15 min | BOT-02 | Requires waiting for cron schedule | Insert bot, wait 15 min, check unit_movements/training_queue/construction_queue for new rows |
| Aggression frequency distribution | BOT-02 | Statistical — requires 100+ ticks | Run run_bot_decisions() 100 times, compare attack counts for aggression 1 vs 3 |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
