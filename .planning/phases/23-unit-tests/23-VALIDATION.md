---
phase: 23
slug: unit-tests
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-18
---

# Phase 23 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework (Deno)** | Deno built-in (`Deno.test`) |
| **Framework (Flutter)** | flutter_test (sdk: flutter) |
| **Config file** | none — both discover tests automatically |
| **Quick run command (Deno)** | `deno test supabase/functions/tests/` |
| **Quick run command (Flutter)** | `flutter test test/widget/godmode/` |
| **Full suite command** | `deno test supabase/functions/tests/ && flutter test test/` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run relevant quick command (Deno or Flutter depending on task)
- **After every plan wave:** Run `deno test supabase/functions/tests/ && flutter test test/`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 23-01-01 | 01 | 1 | TEST-01 | unit (Deno) | `deno test supabase/functions/tests/upgrade_building_test.ts` | ❌ W0 | ⬜ pending |
| 23-01-02 | 01 | 1 | TEST-01 | unit (Deno) | `deno test supabase/functions/tests/train_units_test.ts` | ❌ W0 | ⬜ pending |
| 23-02-01 | 02 | 1 | TEST-02 | widget (Flutter) | `flutter test test/widget/godmode/bot_badge_test.dart` | ❌ W0 | ⬜ pending |
| 23-02-02 | 02 | 1 | TEST-02 | widget (Flutter) | `flutter test test/widget/godmode/elapsed_timer_text_test.dart` | ❌ W0 | ⬜ pending |
| 23-02-03 | 02 | 1 | TEST-02 | widget (Flutter) | `flutter test test/widget/godmode/event_tile_test.dart` | ❌ W0 | ⬜ pending |
| 23-02-04 | 02 | 1 | TEST-02 | widget (Flutter) | `flutter test test/widget/godmode/event_feed_test.dart` | ❌ W0 | ⬜ pending |
| 23-02-05 | 02 | 1 | TEST-02 | widget (Flutter) | `flutter test test/widget/godmode/player_row_test.dart` | ❌ W0 | ⬜ pending |
| 23-02-06 | 02 | 1 | TEST-02 | widget (Flutter) | `flutter test test/widget/godmode/player_table_test.dart` | ❌ W0 | ⬜ pending |
| 23-02-07 | 02 | 1 | TEST-02 | widget (Flutter) | `flutter test test/widget/godmode/godmode_dashboard_screen_test.dart` | ❌ W0 | ⬜ pending |
| 23-02-08 | 02 | 1 | TEST-02 | widget (Flutter) | `flutter test test/widget/godmode/godmode_placeholder_screen_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `supabase/functions/_shared/formulas.ts` — extracted pure functions (prerequisite for Deno tests)
- [ ] `supabase/functions/tests/upgrade_building_test.ts` — upgrade formula tests
- [ ] `supabase/functions/tests/train_units_test.ts` — training formula tests
- [ ] `test/widget/godmode/godmode_test_helpers.dart` — shared mock data fixtures
- [ ] `test/widget/godmode/bot_badge_test.dart` — BotBadge widget test
- [ ] `test/widget/godmode/elapsed_timer_text_test.dart` — ElapsedTimerText widget test
- [ ] `test/widget/godmode/event_tile_test.dart` — EventTile widget test
- [ ] `test/widget/godmode/event_feed_test.dart` — EventFeed widget test
- [ ] `test/widget/godmode/player_row_test.dart` — PlayerRow widget test
- [ ] `test/widget/godmode/player_table_test.dart` — PlayerTable widget test
- [ ] `test/widget/godmode/godmode_dashboard_screen_test.dart` — Dashboard widget test
- [ ] `test/widget/godmode/godmode_placeholder_screen_test.dart` — Placeholder widget test

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Tests pass in reverse order | TEST-01, TEST-02 | Order-dependent test isolation | Run `deno test` and `flutter test` with `--test-randomize-ordering-seed=random` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
