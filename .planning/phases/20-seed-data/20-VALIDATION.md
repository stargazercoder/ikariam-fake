---
phase: 20
slug: seed-data
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-17
---

# Phase 20 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | SQL verification queries (psql / supabase db reset) |
| **Config file** | none — seed runs via supabase db reset |
| **Quick run command** | `supabase db reset` |
| **Full suite command** | `supabase db reset && supabase db reset` (double-run idempotency) |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `supabase db reset`
- **After every plan wave:** Run `supabase db reset && supabase db reset`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 20-01-01 | 01 | 1 | SEED-01 | integration | `supabase db reset` then count query | ✅ | ⬜ pending |
| 20-01-02 | 01 | 1 | SEED-02 | integration | `supabase db reset && supabase db reset` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. Seed runs as Postgres superuser via `supabase db reset` — no additional test framework needed.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Bot distribution across 8+ islands | SEED-01 | Trigger places on random islands | After reset, run: `SELECT COUNT(DISTINCT i.id) FROM cities c JOIN islands i ON c.island_id = i.id JOIN profiles p ON c.owner_id = p.id WHERE p.is_bot = true;` — result must be >= 8 |
| 3 development tiers visible | SEED-01 | Visual inspection of building levels | After reset, run: `SELECT p.display_name, MAX(cb.level) as max_building FROM profiles p JOIN cities c ON c.owner_id = p.id JOIN city_buildings cb ON cb.city_id = c.id WHERE p.is_bot = true GROUP BY p.display_name ORDER BY max_building;` — should show 3 distinct tiers |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
