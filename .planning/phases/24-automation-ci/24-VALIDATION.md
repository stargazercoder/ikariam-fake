---
phase: 24
slug: automation-ci
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-18
---

# Phase 24 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework (Flutter)** | flutter_test (built-in SDK) |
| **Framework (Deno)** | Deno.test (built-in runtime) |
| **Config file** | `analysis_options.yaml` (Flutter lint); no deno.json needed |
| **Quick run command (Deno)** | `deno test supabase/functions/tests/` |
| **Quick run command (Flutter)** | `flutter test` |
| **Full suite command** | `bash scripts/test_all.sh` (after this phase: includes all 3 steps) |
| **Estimated runtime** | ~60 seconds (Deno ~5s, Flutter test ~30s, analyze ~25s) |

---

## Sampling Rate

- **After every task commit:** Run `deno test supabase/functions/tests/` + `flutter analyze`
- **After every plan wave:** Run `bash scripts/test_all.sh` (full: db reset + deno test + flutter test)
- **Before `/gsd:verify-work`:** CI workflow green on a push to main
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 24-01-01 | 01 | 1 | AUTO-01 | smoke/manual | `bash scripts/dev_setup.sh` | ❌ W0 | ⬜ pending |
| 24-01-02 | 01 | 1 | AUTO-01 | smoke/manual | `.\scripts\dev_setup.ps1` | ❌ W0 | ⬜ pending |
| 24-01-03 | 01 | 1 | AUTO-01 | integration | `bash scripts/test_all.sh` (updated) | ✅ | ⬜ pending |
| 24-02-01 | 02 | 1 | AUTO-02 | CI integration | Push to main / open PR | ❌ W0 | ⬜ pending |
| 24-02-02 | 02 | 1 | AUTO-02 | manual-only | Introduce lint error, verify non-zero exit | ❌ manual | ⬜ pending |
| 24-02-03 | 02 | 1 | AUTO-02 | manual-only | Introduce failing Deno test, verify non-zero exit | ❌ manual | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/dev_setup.sh` — new file for AUTO-01 (bash)
- [ ] `scripts/dev_setup.ps1` — new file for AUTO-01 (PowerShell)
- [ ] `.github/workflows/ci.yml` — new file for AUTO-02
- [ ] Updated `scripts/test_all.sh` — insert deno test step between db reset and flutter test
- [ ] Updated `scripts/test_all.ps1` — insert deno test step between db reset and flutter test

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| flutter analyze failure blocks CI | AUTO-02 | Requires intentional lint error + CI run | 1. Add unused import 2. Push 3. Verify CI fails |
| deno test failure blocks CI | AUTO-02 | Requires intentional test failure + CI run | 1. Add failing assertion 2. Push 3. Verify CI fails |
| dev_setup.sh runs on clean clone | AUTO-01 | Requires clean environment | 1. Clone fresh 2. Run script 3. Verify all steps complete |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
