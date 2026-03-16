---
phase: 15
slug: resource-trading
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-16
---

# Phase 15 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter test (built-in) |
| **Config file** | none — standard Flutter test runner |
| **Quick run command** | `flutter test test/ --name "trade"` |
| **Full suite command** | `flutter test test/` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/features/trade/ --name "trade"`
- **After every plan wave:** Run `flutter test test/`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 15-01-01 | 01 | 1 | TRAD-01 | unit | `flutter test test/features/trade/trade_repository_test.dart` | ❌ W0 | ⬜ pending |
| 15-02-01 | 02 | 2 | TRAD-01 | widget | `flutter test test/features/trade/trade_dialog_test.dart` | ❌ W0 | ⬜ pending |
| 15-02-02 | 02 | 2 | TRAD-01 | widget | `flutter test test/features/movements/movements_screen_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/features/trade/trade_dialog_test.dart` — stubs for TRAD-01 (slider behavior, send button validation, dialog open)
- [ ] `test/features/trade/trade_repository_test.dart` — stubs for TRAD-01 (Edge Function invocation)
- [ ] `test/features/movements/movements_screen_test.dart` — stubs for TRAD-01 (trade icon display)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Edge Function rejects insufficient resources | TRAD-01 | Server-side validation in Supabase Edge Function | 1. Set resources low 2. Attempt trade 3. Verify error message |
| Edge Function rejects warehouse overflow | TRAD-01 | Server-side validation requires real DB state | 1. Fill recipient warehouse near max 2. Attempt trade exceeding capacity 3. Verify rejection |
| Cargo delivered on arrival | TRAD-01 | Requires process_arrivals() pg_cron execution | 1. Send trade 2. Wait for arrival 3. Check recipient city_resources updated |
| Real-time movement visibility for both parties | TRAD-01 | Requires two active sessions | 1. Send trade 2. Check sender movements list 3. Check recipient movements list |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
