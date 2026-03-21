---
phase: 28
slug: city-screen-cleanup
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-21
---

# Phase 28 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter test (built-in) |
| **Config file** | pubspec.yaml dev_dependencies |
| **Quick run command** | `flutter analyze` |
| **Full suite command** | `flutter analyze` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter analyze`
- **After every plan wave:** Run `flutter analyze`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 28-01-01 | 01 | 1 | CLNP-01 | manual + static | `flutter analyze` | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No new test files needed — CLNP-01 is validated by manual visual inspection and `flutter analyze` ensures no compilation errors from variable/import removals.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| No city/player name text on own city screen | CLNP-01 | Purely visual — no widget test infra for city screens | Open own city screen, verify no city name headline or Governor text appears |
| No player name text in AppBar | CLNP-01 | Visual verification | Open own city screen, verify AppBar shows only avatar icon, no text label |
| Enemy city banner shows generic text | CLNP-01 | Visual verification | Open enemy city view, verify banner reads "Viewing enemy city — read only" with no names |
| Navigation still works after removal | CLNP-01 | Functional verification | Navigate to/from city screens, verify back button and route params work |
| Ownership color borders unaffected | CLNP-01 | Visual verification | Open city grid, verify ownership color borders display correctly |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
