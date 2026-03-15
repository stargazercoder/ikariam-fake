---
phase: 12
slug: combat-depth
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-15
---

# Phase 12 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter integration_test (SDK) + flutter_test |
| **Config file** | none — tests in test/ directory |
| **Quick run command** | `flutter test test/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 12-01-01 | 01 | 1 | CMBT-01 | manual-only | n/a (requires live Supabase + pg_cron) | n/a | ⬜ pending |
| 12-01-02 | 01 | 1 | CMBT-02 | unit | `flutter test test/hideout_protection_test.dart` | ❌ W0 | ⬜ pending |
| 12-02-01 | 02 | 1 | CMBT-03 | unit (widget) | `flutter test test/battle_loss_chart_test.dart` | ❌ W0 | ⬜ pending |
| 12-02-02 | 02 | 1 | CMBT-04 | unit | `flutter test test/unit_type_colors_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/hideout_protection_test.dart` — unit tests for `hideoutProtectionFloor(level)` formula (CMBT-02)
- [ ] `test/battle_loss_chart_test.dart` — widget test for `BattleLossChart` renders N bars for N turns (CMBT-03)
- [ ] `test/unit_type_colors_test.dart` — asserts all 13 unit types have a distinct color entry (CMBT-04)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Attacker wins → pillage_result populated on battles row, resources transferred via cargo | CMBT-01 | Requires running Supabase + pg_cron; SQL function resolve_battles() runs server-side | 1. Start two battles where attacker wins 2. Verify `pillage_result` JSONB on `battles` row 3. Verify cargo delivered on return movement arrival |
| Hideout protection floor applied during pillage (SQL side) | CMBT-02 | SQL logic in resolve_battles() requires live DB | 1. Set defender hideout to level 5 2. Attack and win 3. Verify resources not pillaged below floor |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
