---
phase: 26
slug: building-detail-sheet
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-20
---

# Phase 26 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — project has no automated test infrastructure |
| **Config file** | None |
| **Quick run command** | Manual smoke test on device/emulator |
| **Full suite command** | Full 14-building sweep on device/emulator |
| **Estimated runtime** | ~5 minutes (manual) |

---

## Sampling Rate

- **After every task commit:** Manual smoke test — tap modified building(s), verify sheet opens with correct content
- **After every plan wave:** Full building type sweep (all 14 types), verify upgrade + downgrade actions
- **Before `/gsd:verify-work`:** All 14 buildings confirmed working
- **Max feedback latency:** ~5 minutes (manual testing)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 26-01-01 | 01 | 1 | BLDG-01, BLDG-03 | manual smoke | Tap building → sheet opens with header/stats/actions | N/A | ⬜ pending |
| 26-01-02 | 01 | 1 | BLDG-03 | manual smoke | Verify drag handle, close button, scroll behavior | N/A | ⬜ pending |
| 26-02-01 | 02 | 2 | BLDG-02 | manual smoke | Tap tavern → wine controls visible | N/A | ⬜ pending |
| 26-02-02 | 02 | 2 | BLDG-02 | manual smoke | Tap barracks → training queue visible | N/A | ⬜ pending |
| 26-02-03 | 02 | 2 | BLDG-02 | manual smoke | Tap resource building → production rate visible | N/A | ⬜ pending |
| 26-02-04 | 02 | 2 | BLDG-01, BLDG-02 | manual smoke | All 14 buildings open sheet, show upgrade/downgrade | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. Project uses manual verification as established pattern — no automated test framework to install.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| All 14 buildings open bottom sheet on tap | BLDG-01 | No widget test infra in project | Tap each building type on city grid, verify sheet appears |
| Dynamic content per building type | BLDG-02 | UI content varies per type, needs visual check | Tap tavern (wine controls), barracks (training queue), resource buildings (production rate) |
| Consistent header/stats/actions layout | BLDG-03 | Layout consistency is visual | Compare header structure across 3+ building types |
| Scroll behavior with long content | BLDG-03 | Interaction behavior | Open barracks sheet with many units, scroll to bottom |
| Upgrade/downgrade actions work | BLDG-02 | Backend interaction | Tap upgrade on a building, verify level changes |

---

## Validation Sign-Off

- [ ] All tasks have manual verify instructions
- [ ] Sampling continuity: manual smoke after every task commit
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5 minutes
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
