---
phase: 17
slug: ui-polish
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-17
---

# Phase 17 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter test (built-in) |
| **Config file** | `pubspec.yaml` (test dependency) |
| **Quick run command** | `flutter test --no-pub` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test --no-pub`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 17-01-01 | 01 | 1 | UIPL-01 | manual | Visual inspection | N/A | ⬜ pending |
| 17-01-02 | 01 | 1 | UIPL-01 | manual | Visual inspection | N/A | ⬜ pending |
| 17-02-01 | 02 | 1 | UIPL-02 | manual | Visual inspection | N/A | ⬜ pending |
| 17-02-02 | 02 | 1 | UIPL-02 | manual | Visual inspection | N/A | ⬜ pending |
| 17-03-01 | 03 | 1 | UIPL-03 | manual | Visual inspection | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements — visual-only changes require no new test infrastructure.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Transparent AppBar fills full vertical space | UIPL-01 | Visual layout — no widget test can verify visual fullness | Run app, navigate to city view, confirm no title bar visible |
| Ownership colors on island/world map | UIPL-02 | Color rendering requires visual inspection | Run app, view island with own/enemy cities, confirm green/red borders |
| Unit type CircleAvatar colors in military screens | UIPL-03 | Color + icon rendering requires visual inspection | Run app, open barracks/dispatch, confirm colored avatars per unit type |
| Cross-screen color consistency | UIPL-03 | Multi-screen comparison | Check same unit type shows same color across barracks, shipyard, dispatch, battles |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
