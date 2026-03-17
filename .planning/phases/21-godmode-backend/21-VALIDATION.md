---
phase: 21
slug: godmode-backend
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-17
---

# Phase 21 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Not yet established (Phase 23 = TEST-01/TEST-02) |
| **Config file** | None — Wave 0 installs nothing |
| **Quick run command** | `supabase db reset` (schema validation) |
| **Full suite command** | Phase 23 will define formal test suite |
| **Estimated runtime** | ~15 seconds (db reset) |

---

## Sampling Rate

- **After every task commit:** Run `supabase db reset` to verify migration applies cleanly
- **After every plan wave:** Manual SQL test of each RPC as admin and non-admin user
- **Before `/gsd:verify-work`:** All 5 RPCs callable; non-admin rejection verified; route guard working
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 21-01-01 | 01 | 1 | GOD-05 | static analysis | `grep -r "service_role" lib/` returns empty | ✅ | ⬜ pending |
| 21-01-02 | 01 | 1 | GOD-05 | manual SQL | `SELECT public.godmode_get_world_state()` as non-admin → SQLSTATE 42501 | ❌ W0 | ⬜ pending |
| 21-01-03 | 01 | 1 | GOD-05 | manual SQL | `SELECT public.godmode_get_world_state()` as admin → valid JSONB | ❌ W0 | ⬜ pending |
| 21-01-04 | 01 | 1 | GOD-05 | manual SQL | `SELECT public.godmode_set_bot_paused(...)` as non-admin → rejected | ❌ W0 | ⬜ pending |
| 21-01-05 | 01 | 1 | GOD-05 | manual SQL | `SELECT public.admin_set_resources(...)` as non-admin → rejected | ❌ W0 | ⬜ pending |
| 21-01-06 | 01 | 1 | GOD-05 | manual Flutter | Navigate to /godmode as non-admin → redirected to /map | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Migration file `supabase/migrations/NNNN_godmode_rpcs.sql` — covers GOD-05 RPCs
- [ ] `lib/features/godmode/screens/godmode_placeholder_screen.dart` — minimal screen for route
- [ ] Grep check: `grep -r "service_role" lib/` must return empty

*Formal automated tests deferred to Phase 23 (TEST-01/TEST-02).*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Non-admin RPC rejection | GOD-05 | No Deno test framework yet | Call each RPC via Supabase Studio as non-admin user; verify SQLSTATE 42501 |
| Admin RPC success | GOD-05 | No Deno test framework yet | Call each RPC via Supabase Studio as a1111111 (is_admin=true); verify JSONB response |
| Route guard redirect | GOD-05 | Flutter widget tests in Phase 23 | Login as non-admin, navigate to /godmode, verify redirect to /map |
| No service_role in Flutter | GOD-05 | Static analysis | `grep -r "service_role" lib/` must return empty |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
