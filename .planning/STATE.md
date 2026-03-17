---
gsd_state_version: 1.0
milestone: v1.3
milestone_name: Bots, Testing & Automation
status: planning
stopped_at: Completed 18-01-PLAN.md
last_updated: "2026-03-17T13:27:23.490Z"
last_activity: 2026-03-17 — v1.3 roadmap created; Phases 18-24 defined; ready to plan Phase 18
progress:
  total_phases: 12
  completed_phases: 6
  total_plans: 12
  completed_plans: 12
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-17)

**Core value:** Players can build and manage cities, gather resources, and engage in real-time turn-based warfare — the core loop of build, expand, and conquer must feel satisfying and strategically meaningful.
**Current focus:** Phase 18 — Bot Schema Foundation

## Current Position

Phase: 18 of 24 (Bot Schema Foundation)
Plan: 0 of TBD in current phase
Status: Ready to plan
Last activity: 2026-03-17 — v1.3 roadmap created; Phases 18-24 defined; ready to plan Phase 18

```
v1.3 Progress: [░░░░░░░░░░░░░░░░░░░░] 0%  (0/7 phases)
```

## Performance Metrics

**Cumulative:**
- v0.1.0: 9 phases, 27 plans in 2 days
- v1.1: 3 phases, 8 plans in 3 days
- v1.2: 5 phases, 11 plans in 2 days
- Total shipped: 17 phases, 46 plans

**v1.3 (in progress):**
- Phases: 7 (18-24)
- Plans: TBD

## Accumulated Context

### Decisions

All decisions logged in PROJECT.md Key Decisions table.

v1.3 architecture decisions locked in:
- Single consolidated bot-think-tick at */15 * * * * — not per-behavior cron jobs (avoids pg_cron worker pool exhaustion)
- GodMode uses SECURITY DEFINER RPCs with is_admin Postgres check — service_role key must never appear in any Flutter file
- Bot actions write directly to training_queue / construction_queue / unit_movements — same tables as Edge Functions; no pg_net HTTP round-trips from pg_cron
- All seed inserts use ON CONFLICT — seed script must survive supabase db reset run twice consecutively
- Deno pinned to 2.2.x in CI — Supabase Edge Runtime does not support Deno 2.3+ lock file v5 yet (track supabase/supabase#33093)
- [Phase 18]: is_bot/is_admin use NOT NULL DEFAULT false — PostgreSQL backfills existing rows without UPDATE migration
- [Phase 18]: bot_schedules has RLS enabled with zero policies — deny-all for clients; only SECURITY DEFINER functions access it

### Pending Todos

None.

### Blockers/Concerns

Carried from v1.2 (unresolved tech debt):
- cityProvider not refreshed after island donation — stale island multiplier in production rate labels
- JSONB cast inconsistency: older models use `v as int`, newer use `(v as num).toInt()`
- hideoutProtectionFloor() Dart helper not surfaced in any UI

v1.3 design work deferred to planning:
- Bot archetype weight values (aggression thresholds, attack frequencies) are MEDIUM confidence — treat as tunable parameters; plan balance review after first week of bot operation
- Per-bot seed state (exact building levels, army counts, resources for each of 20 bots) is design work for Phase 20 planning

## Session Continuity

Last session: 2026-03-17T13:27:23.488Z
Stopped at: Completed 18-01-PLAN.md
Resume file: None
Next action: /gsd:plan-phase 18
