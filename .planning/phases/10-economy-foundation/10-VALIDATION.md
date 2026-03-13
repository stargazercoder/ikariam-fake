---
phase: 10
slug: economy-foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-13
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (existing) |
| **Config file** | pubspec.yaml (flutter test section) |
| **Quick run command** | `flutter test test/unit/economy_formulas_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/unit/economy_formulas_test.dart`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 10-01-01 | 01 | 1 | ECON-01 | unit | `flutter test test/unit/economy_formulas_test.dart` | ❌ W0 | ⬜ pending |
| 10-01-02 | 01 | 1 | ECON-02 | unit | `flutter test test/unit/economy_formulas_test.dart` | ❌ W0 | ⬜ pending |
| 10-01-03 | 01 | 1 | ECON-03 | unit | `flutter test test/unit/economy_formulas_test.dart` | ❌ W0 | ⬜ pending |
| 10-01-04 | 01 | 1 | ECON-05 | unit | `flutter test test/unit/economy_formulas_test.dart` | ❌ W0 | ⬜ pending |
| 10-02-01 | 02 | 1 | ECON-04 | widget | `flutter test test/widget/tavern_wine_slider_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/unit/economy_formulas_test.dart` — stubs for ECON-01, ECON-02, ECON-03, ECON-05 (happiness formula, population growth, tax proration, wine consumption cap)
- [ ] `test/widget/tavern_wine_slider_test.dart` — stubs for ECON-04 (slider UI, debounce behavior, display values)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Wine slider visual feedback | ECON-04 | Visual styling/layout needs human judgment | Open tavern → move slider → verify emoji, numbers, color update in real-time |
| Resource bar happiness display | ECON-01 | Layout/positioning check | Open city → verify happiness emoji + number appears in resource bar area |
| Population summary row | ECON-02 | Visual formatting check | Open city → verify "👥 X (+Y/tick) 🪙 Tax: +Z/hr" appears below resource bar |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
