---
phase: 14
slug: movement-visibility
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-16
---

# Phase 14 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter test (built-in) |
| **Config file** | none detected at project root |
| **Quick run command** | `flutter test` |
| **Full suite command** | `flutter test --coverage` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test`
- **After every plan wave:** Run `flutter test --coverage`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 14-01-01 | 01 | 1 | MOVE-01 | unit | `flutter test test/features/military/models/unit_movement_test.dart` | ❌ W0 | ⬜ pending |
| 14-01-02 | 01 | 1 | MOVE-01 | unit (mock) | `flutter test test/features/military/data/military_repository_test.dart` | ❌ W0 | ⬜ pending |
| 14-01-03 | 01 | 1 | MOVE-01 | unit | `flutter test test/features/movements/providers/movements_provider_test.dart` | ❌ W0 | ⬜ pending |
| 14-01-04 | 01 | 1 | MOVE-02 | unit | `flutter test test/features/military/models/unit_movement_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/features/military/models/unit_movement_test.dart` — stubs for MOVE-01 (movement_type parsing), MOVE-02 (cargo parsing)
- [ ] `test/features/movements/providers/movements_provider_test.dart` — stubs for MOVE-01 (sort order, empty state)
- [ ] `test/features/military/data/military_repository_test.dart` — stubs for MOVE-01 (global stream no city filter)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Movement list updates in real-time as dispatches are sent | MOVE-01 | Requires live Supabase Realtime connection | 1. Open movements tab 2. Dispatch army from another tab 3. Verify new movement appears without refresh |
| Returning cargo ships show resource amounts | MOVE-02 | Requires end-to-end pillage flow | 1. Trigger pillage return 2. Verify cargo amounts display in movement list |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
