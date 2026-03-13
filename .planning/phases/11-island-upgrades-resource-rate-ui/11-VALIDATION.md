---
phase: 11
slug: island-upgrades-resource-rate-ui
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-13
---

# Phase 11 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — no test infrastructure in project |
| **Config file** | none |
| **Quick run command** | `flutter test` (if tests added) |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | N/A — all validation is manual |

---

## Sampling Rate

- **After every task commit:** Manual smoke test via app + Supabase Studio
- **After every plan wave:** Full manual verification of all success criteria
- **Before `/gsd:verify-work`:** All success criteria manually confirmed
- **Max feedback latency:** N/A (manual)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 11-01-01 | 01 | 1 | RSRC-01 | manual smoke | — | N/A | ⬜ pending |
| 11-01-02 | 01 | 1 | RSRC-01 | manual smoke | — | N/A | ⬜ pending |
| 11-01-03 | 01 | 1 | RSRC-02 | manual smoke | — | N/A | ⬜ pending |
| 11-02-01 | 02 | 2 | RSRC-03 | manual visual | — | N/A | ⬜ pending |
| 11-02-02 | 02 | 2 | RSRC-04 | manual visual | — | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No test framework setup needed — all validation is manual smoke testing via the app and Supabase Studio SQL queries.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Wood deduction + island level increment | RSRC-01 | Edge Function mutation requires running app | Donate wood on island view, verify level increases in Supabase Studio |
| Max level 10 enforcement (race-safe) | RSRC-01 | Requires concurrent donation simulation | Set island to level 9 via SQL, donate from two cities, verify max 10 |
| Production tick uses island multiplier | RSRC-02 | Requires waiting for tick cycle | Upgrade island, wait for tick, verify resource amounts increased proportionally |
| "+X/hr" appears in resource bar | RSRC-03 | Visual UI verification | Open city screen, verify "+X/hr" label next to each resource |
| Breakdown sheet shows all 4 components | RSRC-04 | Visual UI verification | Tap resource chip, verify breakdown: base rate, building bonus, island bonus, research bonus |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < N/A (manual)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
