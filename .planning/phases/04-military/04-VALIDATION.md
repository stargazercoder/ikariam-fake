---
phase: 4
slug: military
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-11
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK, Dart 3.10.1) |
| **Config file** | none (uses default flutter test runner) |
| **Quick run command** | `flutter test test/unit/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/unit/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | MIL-01 | unit | `flutter test test/unit/unit_constants_test.dart` | ❌ W0 | ⬜ pending |
| 04-01-02 | 01 | 1 | MIL-02 | unit | `flutter test test/unit/unit_constants_test.dart` | ❌ W0 | ⬜ pending |
| 04-01-03 | 01 | 1 | MIL-03 | unit | `flutter test test/unit/unit_constants_test.dart` | ❌ W0 | ⬜ pending |
| 04-02-01 | 02 | 1 | MIL-04 | unit | `flutter test test/unit/military_models_test.dart` | ❌ W0 | ⬜ pending |
| 04-02-02 | 02 | 1 | MIL-04 | unit | `flutter test test/unit/military_models_test.dart` | ❌ W0 | ⬜ pending |
| 04-03-01 | 03 | 2 | MIL-05 | unit | `flutter test test/unit/military_models_test.dart` | ❌ W0 | ⬜ pending |
| 04-03-02 | 03 | 2 | MIL-05 | unit | `flutter test test/unit/unit_constants_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/unit/unit_constants_test.dart` — stubs for MIL-01, MIL-02, MIL-03, MIL-05 (UnitType enum, unlock levels, travel time formula)
- [ ] `test/unit/military_models_test.dart` — stubs for MIL-04, MIL-05 (TrainingQueueEntry, CityUnit, UnitMovement fromJson + isComplete)

*Existing infrastructure covers framework installation.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Training queue Realtime updates | MIL-04 | Requires live Supabase connection + pg_cron trigger | 1. Start training; 2. Wait for completion; 3. Verify unit appears in roster |
| Dispatch travel countdown display | MIL-05 | Requires two cities on different islands + Realtime | 1. Train units; 2. Dispatch to another city; 3. Verify "in transit" with countdown |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
