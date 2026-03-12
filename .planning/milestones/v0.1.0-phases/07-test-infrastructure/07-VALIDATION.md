---
phase: 7
slug: test-infrastructure
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-12
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK built-in) |
| **Config file** | none — discovered via `test/` directory convention |
| **Quick run command** | `flutter test test/unit/ --reporter expanded` |
| **Full suite command** | `flutter test --reporter expanded` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/unit/ --reporter expanded`
- **After every plan wave:** Run `flutter test --reporter expanded`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 7-01-01 | 01 | 1 | TEST-01 | smoke/manual | `npx supabase db reset --local` then verify user count | ❌ W0 | ⬜ pending |
| 7-01-02 | 01 | 1 | TEST-03 | unit | `flutter test test/unit/seed_scenarios_test.dart` | ❌ W0 | ⬜ pending |
| 7-02-01 | 02 | 1 | TEST-02 | widget | `flutter test test/widget/dev_toolbar_test.dart` | ❌ W0 | ⬜ pending |
| 7-03-01 | 03 | 2 | TEST-04 | integration/manual | `bash scripts/test_all.sh` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/widget/dev_toolbar_test.dart` — stub for TEST-02 (DevToolbarWrapper renders/hidden)
- [ ] `test/unit/seed_scenarios_test.dart` — stub for TEST-03 (data integrity assertions)
- [ ] `scripts/test_all.sh` — artifact for TEST-04 (bash reset+test script)
- [ ] `scripts/test_all.ps1` — artifact for TEST-04 (PowerShell equivalent for Windows 11)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| 6+ seed accounts exist with varied game states | TEST-01 | Requires running Supabase locally and querying DB | Run `npx supabase db reset --local`, then `docker exec supabase_db_ikariam psql -U postgres -c "SELECT COUNT(*) FROM auth.users"` — expect 6+ |
| Dev toolbar hidden in release build | TEST-02 | Requires building in release mode | Run `flutter build web --release`, serve output, verify no toolbar FAB visible |
| Seed world has active interactions | TEST-03 | Requires inspecting DB state after seed | After reset, query `battles` for `status='active'`, `unit_movements` for dispatched troops, `building_upgrades` for active queues |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
