---
phase: 8
slug: bug-fixes-timer-guards
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-12
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (bundled with Flutter SDK) |
| **Config file** | none — standard `flutter test` discovery |
| **Quick run command** | `flutter test test/unit/dispatch_travel_test.dart test/unit/combat_engagement_test.dart test/widget/dev_toolbar_trigger_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/unit/ --name "dispatch|engagement|timer"`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 08-01-01 | 01 | 1 | MIL-05 | unit | `flutter test test/unit/dispatch_travel_test.dart` | ❌ W0 | ⬜ pending |
| 08-02-01 | 02 | 1 | CMBT-01 | unit | `flutter test test/unit/combat_timer_guard_test.dart` | ❌ W0 | ⬜ pending |
| 08-03-01 | 03 | 1 | CMBT-02 | unit | `flutter test test/unit/combat_engagement_test.dart` | ❌ W0 | ⬜ pending |
| 08-04-01 | 04 | 1 | CMBT-02 | widget | `flutter test test/widget/dev_toolbar_trigger_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/unit/dispatch_travel_test.dart` — covers MIL-05 (formula + constant verification)
- [ ] `test/unit/combat_engagement_test.dart` — covers CMBT-02 (engagement fraction formula)
- [ ] `test/unit/combat_timer_guard_test.dart` — covers CMBT-01 (documents production timer values as constants)
- [ ] `test/widget/dev_toolbar_trigger_test.dart` — covers dev toolbar dispose fix (verifies Trigger Battle dialog completes without error)

*Note: Existing `test/unit/combat_formula_test.dart` and `test/widget/dev_toolbar_test.dart` provide baseline coverage. New tests extend these.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Production cron schedule shows 5-minute intervals | CMBT-01 | Requires production Supabase dashboard access | Check `cron.job` table in production for `resource-tick` and `resolve-battles` schedule values |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
