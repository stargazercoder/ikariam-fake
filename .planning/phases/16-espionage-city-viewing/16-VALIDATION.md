---
phase: 16
slug: espionage-city-viewing
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-16
---

# Phase 16 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (bundled with Flutter SDK) |
| **Config file** | pubspec.yaml dev_dependencies section |
| **Quick run command** | `flutter test test/unit/espionage_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/unit/espionage_test.dart`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 16-01-01 | 01 | 1 | ESPY-01 | unit | `flutter test test/unit/espionage_test.dart` | ❌ W0 | ⬜ pending |
| 16-01-02 | 01 | 1 | ESPY-01 | manual | Manual Supabase function invoke | N/A | ⬜ pending |
| 16-02-01 | 02 | 1 | ESPY-02 | widget | `flutter test test/widget/enemy_city_view_test.dart` | ❌ W0 | ⬜ pending |
| 16-02-02 | 02 | 1 | ESPY-02 | unit | `flutter test test/unit/espionage_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/unit/espionage_test.dart` — stubs for ESPY-01 (SpyReport.fromJson) + ESPY-02 (BuildingCell readOnly)
- [ ] `test/widget/enemy_city_view_test.dart` — smoke test EnemyCityViewScreen renders without errors

*Existing infrastructure covers framework setup — only test files needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| spy-city Edge Function validates gold balance and returns report | ESPY-01 | Server-side Supabase function — requires live DB | 1. Call function with valid auth 2. Verify gold deducted 3. Verify report JSON returned |
| Spy action dialog shows loading state and error handling | ESPY-01 | UI interaction flow | 1. Tap Spy on island 2. Verify loading indicator 3. Verify report dialog appears |
| Read-only city view navigation from island menu | ESPY-02 | Full navigation flow | 1. Spy on city first 2. Tap "View City" 3. Verify read-only screen loads |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
