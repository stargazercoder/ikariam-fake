---
phase: 13
slug: dev-acceleration
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-16
---

# Phase 13 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — project uses static analysis only |
| **Config file** | none |
| **Quick run command** | `flutter analyze` |
| **Full suite command** | `flutter analyze && dart format --output=none --set-exit-if-changed lib/` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter analyze`
- **After every plan wave:** Run `flutter analyze && dart format --output=none --set-exit-if-changed lib/`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 13-01-01 | 01 | 1 | DEVT-01 | manual-only | — | N/A | pending |
| 13-01-02 | 01 | 1 | DEVT-01 | manual-only | — | N/A | pending |
| 13-02-01 | 02 | 1 | DEVT-02 | manual-only | — | N/A | pending |
| 13-02-02 | 02 | 1 | DEVT-03 | manual-only | — | N/A | pending |

*Status: pending · green · red · flaky*

---

## Wave 0 Requirements

- [ ] Verify building construction queue table name — read construction-related migration files
- [ ] Confirm `APP_ENVIRONMENT` secret availability in local Supabase dev setup

*Existing infrastructure covers static analysis. No test framework setup needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Bulk spawn dialog opens with 13 unit checkboxes | DEVT-01 | Requires live Flutter + Supabase | Open dev toolbar → Bulk Spawn → verify all 13 types listed with checkboxes and quantity fields |
| `dev_bulk_spawn_units` RPC inserts units | DEVT-01 | Requires live Supabase DB | Select 3+ unit types → Spawn → check `city_units` table in Supabase dashboard |
| Training `finish_at` is ~1/5 normal | DEVT-02 | Requires live Edge Function runtime | Train 10 hoplites → check `training_queue.finish_at` is ~1/5 of expected duration |
| `arrive_at` is ~1/5 normal travel | DEVT-03 | Requires live Edge Function runtime | Dispatch to nearby city → check `unit_movements.arrive_at` is ~1/5 of expected time |
| Instant complete finishes training + construction | N/A (bonus) | Requires live Supabase DB | Start training + construction → press Instant Complete → verify both queues cleared |
| Production builds have no dev UI | DEVT-01/02/03 | Requires release build | Build with `--release` → verify no dev toolbar FAB visible |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
