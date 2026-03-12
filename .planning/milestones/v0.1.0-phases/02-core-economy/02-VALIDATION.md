---
phase: 2
slug: core-economy
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-03-11
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter test (built-in) + integration_test |
| **Config file** | pubspec.yaml dev_dependencies (already configured) |
| **Quick run command** | `flutter test test/unit/ --reporter compact` |
| **Full suite command** | `flutter test --reporter compact` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/unit/ --reporter compact`
- **After every plan wave:** Run `flutter test --reporter compact`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 2-00-01 | 00 | 0 | RSRC-01, RSRC-03, RSRC-04, BLDG-02, BLDG-03, BLDG-04 | Scaffolds | `flutter test --reporter compact` | Created in Plan 02-00 | ⬜ pending |
| 2-01-01 | 01 | 1 | RSRC-01 | DB integration | `supabase db reset && psql check city_resources count` | ❌ W0 | ⬜ pending |
| 2-01-02 | 01 | 1 | RSRC-02 | DB integration | `psql check cron.job for resource-tick` | ❌ W0 | ⬜ pending |
| 2-01-03 | 01 | 1 | RSRC-03 | Unit (SQL) | `psql call process_resource_tick() + verify amounts` | ❌ W0 | ⬜ pending |
| 2-01-04 | 01 | 1 | RSRC-04 | Unit (SQL) | `psql set amount near cap, call tick, verify LEAST` | ❌ W0 | ⬜ pending |
| 2-02-01 | 02 | 2 | BLDG-01 | DB integration | `psql check city_buildings count = 14` | ❌ W0 | ⬜ pending |
| 2-02-02 | 02 | 2 | BLDG-02 | Integration | `flutter test integration_test/building_upgrade_test.dart` | Created in Plan 02-00 | ⬜ pending |
| 2-02-03 | 02 | 2 | BLDG-03 | Unit (Dart) | `flutter test test/unit/building_time_test.dart` | Created in Plan 02-00 | ⬜ pending |
| 2-02-04 | 02 | 2 | BLDG-04 | Integration | `flutter test integration_test/building_upgrade_test.dart` | Created in Plan 02-00 | ⬜ pending |
| 2-02-05 | 02 | 2 | BLDG-05 | DB integration | `psql insert past finish_at, call function, verify level` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/unit/building_time_test.dart` — stubs for BLDG-03: finish_at duration formula — **Created by Plan 02-00**
- [ ] `integration_test/building_upgrade_test.dart` — stubs for BLDG-02, BLDG-04 — **Created by Plan 02-00**
- [ ] `integration_test/resource_production_test.dart` — stubs for RSRC-01, RSRC-03, RSRC-04 — **Created by Plan 02-00**

*No additional framework install needed — integration_test already in dev_dependencies.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| pg_cron tick fires every 5 min | RSRC-02 | Cron scheduling requires real time passage | Wait 5 min after db reset, query city_resources for increased amounts |
| Realtime stream updates Flutter UI | RSRC-01 | Requires running Flutter app with Supabase connection | Open city screen, trigger tick manually, observe UI updates |
| Construction countdown display | BLDG-03 | Visual timer verification | Queue upgrade, observe countdown timer in UI |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references — Plan 02-00 creates all 3 stub files
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
