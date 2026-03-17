---
phase: 22
slug: godmode-flutter-dashboard
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-17
---

# Phase 22 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK bundled) + mocktail ^1.0.4 |
| **Config file** | None — tests discovered by `flutter test` convention |
| **Quick run command** | `flutter test test/widget/godmode_dashboard_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/unit/godmode_models_test.dart`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 22-01-01 | 01 | 1 | GOD-01 | unit | `flutter test test/unit/godmode_models_test.dart` | ❌ W0 | ⬜ pending |
| 22-01-02 | 01 | 1 | GOD-03 | unit | `flutter test test/unit/godmode_models_test.dart` | ❌ W0 | ⬜ pending |
| 22-02-01 | 02 | 1 | GOD-01 | widget | `flutter test test/widget/godmode_dashboard_test.dart` | ❌ W0 | ⬜ pending |
| 22-02-02 | 02 | 1 | GOD-02 | widget | `flutter test test/widget/godmode_dashboard_test.dart` | ❌ W0 | ⬜ pending |
| 22-03-01 | 03 | 1 | GOD-03 | widget | `flutter test test/widget/godmode_events_test.dart` | ❌ W0 | ⬜ pending |
| 22-04-01 | 04 | 2 | GOD-04 | widget | `flutter test test/widget/godmode_player_row_test.dart` | ❌ W0 | ⬜ pending |
| 22-04-02 | 04 | 2 | GOD-04 | widget | `flutter test test/widget/godmode_player_row_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/unit/godmode_models_test.dart` — stubs for GOD-01, GOD-03 model parsing
- [ ] `test/widget/godmode_dashboard_test.dart` — stubs for GOD-01, GOD-02 table + controls
- [ ] `test/widget/godmode_events_test.dart` — stubs for GOD-03 filter chips + list
- [ ] `test/widget/godmode_player_row_test.dart` — stubs for GOD-04 inline edit mode
- [ ] `test/helpers/test_helpers.dart` — enable `createTestProviderScope` helper with ProviderScope for GodMode widget tests

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| AppBar "Last updated: Xs ago" counts up in real time | GOD-01 | Timer.periodic visual behavior not testable via widget test without fakeAsync complexity | Open /godmode, wait 5s, verify counter shows "5s ago" |
| Stale data stays visible during 30s refresh cycle | GOD-01 | Requires real network latency simulation | Open dashboard, trigger refresh, verify table doesn't blank out |
| Bot badge visible only to admin | GOD-01 | Requires multi-user visual verification | Log in as admin (see badge), log in as regular user (no badge) |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
