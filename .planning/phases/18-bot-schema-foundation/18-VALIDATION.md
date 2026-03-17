---
phase: 18
slug: bot-schema-foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-17
---

# Phase 18 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Deno test (Edge Functions) + flutter test (Dart) |
| **Config file** | `supabase/config.toml` (Supabase), `pubspec.yaml` (Flutter) |
| **Quick run command** | `supabase db reset --debug 2>&1 | tail -5` |
| **Full suite command** | `supabase db reset && flutter test test/` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `supabase db reset --debug 2>&1 | tail -5`
- **After every plan wave:** Run `supabase db reset && flutter test test/`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 18-01-01 | 01 | 1 | BOT-01 | migration | `supabase db reset` (exit 0) | ✅ | ⬜ pending |
| 18-01-02 | 01 | 1 | BOT-06 | migration | `supabase db reset` (exit 0) | ✅ | ⬜ pending |
| 18-01-03 | 01 | 1 | BOT-01 | migration | `supabase db reset` (exit 0) | ✅ | ⬜ pending |
| 18-01-04 | 01 | 1 | BOT-06 | RLS | `supabase db reset` (exit 0) | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. Migration validation via `supabase db reset` is sufficient for schema-only changes. Dart model changes validated by flutter analyze.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| RLS bot visibility | BOT-06 | RLS policy behavior requires authenticated context | Login as non-admin, query profiles WHERE is_bot=true, verify 0 rows returned |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
