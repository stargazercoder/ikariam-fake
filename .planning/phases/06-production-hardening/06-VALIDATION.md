---
phase: 6
slug: production-hardening
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-12
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built-in SDK) |
| **Config file** | none — flutter test discovers test/ automatically |
| **Quick run command** | `flutter test test/unit/ --reporter=compact` |
| **Full suite command** | `flutter test --reporter=compact` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/unit/ --reporter=compact`
- **After every plan wave:** Run `flutter test --reporter=compact`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 6-01-01 | 01 | 1 | INFR-01 | unit (file content) | `flutter test test/unit/infr_splash_test.dart` | ❌ W0 | ⬜ pending |
| 6-01-02 | 01 | 1 | INFR-01 | manual | N/A — browser visual check | N/A | ⬜ pending |
| 6-02-01 | 02 | 1 | INFR-02 | manual (grep) | `grep -rn "\.insert\b\|\.update\b\|\.delete\b" lib/ --include="*.dart"` | N/A | ⬜ pending |
| 6-02-02 | 02 | 1 | INFR-03 | manual (SQL) | SQL query on pg_tables | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/unit/infr_splash_test.dart` — file-content check for splash bootstrap pattern (INFR-01)

*Existing infrastructure covers remaining phase requirements (manual audits).*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Splash screen visible before CanvasKit loads | INFR-01 | Requires browser visual rendering | 1. `flutter build web --release` 2. Serve `build/web` locally 3. Open in browser, verify splash visible before Flutter paints |
| No client direct-write to game tables | INFR-02 | Code audit via grep | Run `grep -rn "\.insert\b\|\.update\b\|\.delete\b" lib/ --include="*.dart"` — only ProfileRepository allowed |
| All public tables have RLS enabled | INFR-03 | Requires production SQL access | Run `SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public'` — all must be true |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
