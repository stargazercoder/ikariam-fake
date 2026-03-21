---
phase: 27
slug: battle-ui-improvements
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-21
---

# Phase 27 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built-in) + Deno test |
| **Config file** | `pubspec.yaml` (dev_dependencies: flutter_test) |
| **Quick run command** | `flutter test test/widget/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/widget/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 27-01-01 | 01 | 1 | BTUI-01 | widget | `flutter test test/widget/pillage_result_card_test.dart` | ❌ W0 | ⬜ pending |
| 27-01-02 | 01 | 1 | BTUI-02 | unit | `flutter test test/unit/unit_constants_test.dart` | ✅ | ⬜ pending |
| 27-01-03 | 01 | 1 | BTUI-02 | widget | `flutter test test/widget/dispatch_capacity_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/widget/pillage_result_card_test.dart` — stubs for BTUI-01 (verify existing PillageResultCard renders attacker/defender labels)
- [ ] `test/widget/dispatch_capacity_test.dart` — stubs for BTUI-02 (verify carry capacity display with 0 and N cargo ships)

*Existing `test/unit/unit_constants_test.dart` covers new constant addition.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live capacity update on unit selection | BTUI-02 | Requires interactive gesture input | Select cargo ships in dispatch screen, verify capacity number changes |
| Pillage display in real battle report | BTUI-01 | Requires completed battle with pillage | Trigger a battle via dev tools, check battle detail screen |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
