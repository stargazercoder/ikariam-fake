---
phase: 5
slug: combat
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-12
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK, Dart 3.10.1) |
| **Config file** | none (uses default flutter test runner) |
| **Quick run command** | `flutter test test/unit/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/unit/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 05-00-01 | 00 | 0 | CMBT-01..05 | unit | `flutter test test/unit/battle_models_test.dart` | ❌ W0 | ⬜ pending |
| 05-01-01 | 01 | 1 | CMBT-01, CMBT-05 | unit | `flutter test test/unit/battle_models_test.dart` | ❌ W0 | ⬜ pending |
| 05-01-02 | 01 | 1 | CMBT-02, CMBT-03, CMBT-05 | unit | `flutter test test/unit/battle_models_test.dart` | ❌ W0 | ⬜ pending |
| 05-02-01 | 02 | 2 | CMBT-04 | unit | `flutter test test/unit/battle_models_test.dart` | ❌ W0 | ⬜ pending |
| 05-03-01 | 03 | 3 | CMBT-01, CMBT-04 | widget | `flutter test test/widget/` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/unit/battle_models_test.dart` — stubs for CMBT-01 through CMBT-05: Battle.fromJson, BattleTurn.fromJson, status checks, JSONB map parsing, nullable phase fields, no direct client writes
- [ ] Shared mock helpers in existing `test/helpers/mocks.dart` if needed

*No new framework install needed — flutter_test already in use*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Battle starts when army arrives at enemy city | CMBT-01 | Requires 2 users + pg_cron tick + Realtime | Dispatch army to enemy city, wait for arrival tick, verify battle appears in Battles tab |
| Turn resolves every 5 minutes with casualties | CMBT-02 | Requires pg_cron battle-tick + Realtime | Watch active battle, wait for turn resolution, verify casualties update in UI |
| Naval resolves before land (visible in report) | CMBT-03 | Requires full battle flow | Send mixed army, check battle turn report shows Naval then Land phases |
| Both players see real-time updates | CMBT-04 | Requires 2 browser sessions | Open attacker and defender views, verify both update after turn resolves |
| Client cannot submit battle results | CMBT-05 | RLS + no write paths | Verify no .insert/.update/.delete on battles/battle_turns in Flutter code |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
