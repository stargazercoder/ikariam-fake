---
phase: 1
slug: foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-11
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test + integration_test |
| **Config file** | pubspec.yaml (dev_dependencies) |
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
| 1-01-01 | 01 | 1 | INFR-02 | unit | `flutter test` | ❌ W0 | ⬜ pending |
| 1-01-02 | 01 | 1 | INFR-03 | unit | `flutter test` | ❌ W0 | ⬜ pending |
| 1-02-01 | 02 | 1 | AUTH-01 | unit | `flutter test` | ❌ W0 | ⬜ pending |
| 1-02-02 | 02 | 1 | AUTH-02 | unit | `flutter test` | ❌ W0 | ⬜ pending |
| 1-03-01 | 03 | 2 | AUTH-03 | unit | `flutter test` | ❌ W0 | ⬜ pending |
| 1-03-02 | 03 | 2 | AUTH-04 | unit | `flutter test` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/` directory — create test directory structure
- [ ] `test/helpers/` — shared test fixtures and mocks
- [ ] `flutter_test` — included in Flutter SDK
- [ ] `mocktail` — for mocking Supabase client

*If none: "Existing infrastructure covers all phase requirements."*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Email confirmation delivery | AUTH-01 | Requires actual email service | Sign up → check inbox → click link |
| Session persists after browser refresh | AUTH-02 | Requires real browser environment | Log in → refresh page → verify still logged in |
| City appears on island map after first login | AUTH-04 | Requires visual verification | Sign up → complete profile → verify city visible |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
