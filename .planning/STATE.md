---
gsd_state_version: 1.0
milestone: v1.2
milestone_name: Espionage, Trading & Polish
status: roadmap_ready
stopped_at: Completed 17-02-PLAN.md — Phase 17 Plan 02 fully verified and complete
last_updated: "2026-03-17T00:54:32.495Z"
last_activity: 2026-03-16 — Roadmap created
progress:
  total_phases: 5
  completed_phases: 5
  total_plans: 11
  completed_plans: 11
  percent: 100
---

---
gsd_state_version: 1.0
milestone: v1.2
milestone_name: Espionage, Trading & Polish
status: roadmap_ready
stopped_at: Completed 14-02-PLAN.md — Phase 14 fully verified and complete
last_updated: "2026-03-16T12:20:00.000Z"
last_activity: 2026-03-16 — Roadmap created
progress:
  [██████████] 100%
  completed_phases: 2
  total_plans: 4
  completed_plans: 4
---

---
gsd_state_version: 1.0
milestone: v1.2
milestone_name: Espionage, Trading & Polish
status: roadmap_ready
stopped_at: "Roadmap created — ready to plan Phase 13"
last_updated: "2026-03-16T00:00:00.000Z"
last_activity: 2026-03-16 — v1.2 roadmap created (5 phases, 11 requirements)
progress:
  total_phases: 5
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-16)

**Core value:** Players can build and manage cities, gather resources, and engage in real-time turn-based warfare — the core loop of build, expand, and conquer must feel satisfying and strategically meaningful.
**Current focus:** v1.2 Espionage, Trading & Polish — roadmap ready, start Phase 13

## Current Position

Phase: 13 — Dev Acceleration (not started)
Plan: —
Status: Ready to plan
Last activity: 2026-03-16 — Roadmap created

```
v1.2 Progress: [░░░░░░░░░░░░░░░░░░░░] 0% (0/5 phases)
```

## Performance Metrics

**Cumulative:**
- v0.1.0: 9 phases, 27 plans in 2 days
- v1.1: 3 phases, 8 plans in 3 days
- Total: 12 phases, 35 plans

**v1.2 (in progress):**
- Phases: 5 defined, 0 complete
- Plans: TBD

## Accumulated Context

### Decisions

All decisions logged in PROJECT.md Key Decisions table.
- [Phase 13]: construction_queue instant-complete sets finish_at to past so existing cron handles level-up logic unchanged
- [Phase 13]: dispatch-units rawTravelMinutes rename applies multiplier while preserving Math.max(1) floor and response body
- [Phase 13-dev-acceleration]: Pre-create TextEditingController map before showDialog to prevent rebuild pitfall in ListView.builder
- [Phase 13-dev-acceleration]: New Bulk Spawn and Instant Complete buttons placed after Trigger Battle preserving existing button order
- [Phase 14-movement-visibility]: movementType uses String with 'attack' default (not enum) for DB compatibility and null-safety on legacy rows
- [Phase 14-movement-visibility]: cityNameProvider uses FutureProvider.family (single fetch) not StreamProvider — city names are static, no realtime needed
- [Phase 14-movement-visibility]: Removed dart:ui import from MovementsScreen — FontFeature re-exported by flutter/material.dart; nested Consumer per card for cityNameProvider rebuild isolation
- [Phase 15]: Migration renamed from 20260316000001 to 20260316000002 due to timestamp conflict with dev migration
- [Phase 15]: Self-trade (origin == destination) allowed in send-trade — no rejection, per TRAD-01 spec
- [Phase 15-02]: TradeRepository.sendTrade returns Map to surface travel_minutes for success SnackBar
- [Phase 15-02]: Unified _showCityActionDialog replaces both own/enemy city tap handlers on island screen
- [Phase 16-espionage-city-viewing]: testWidgets skip parameter only accepts bool? not String — used skip: true for widget tests (flutter_test API constraint)
- [Phase 16-espionage-city-viewing]: spy-city Edge Function uses Supabase aggregate query syntax for army_count and EspionageException mirrors TradeException pattern
- [Phase 16-espionage-city-viewing]: valueOrNull not in Riverpod 3.x — use whenOrNull(data: (v) => v) for AsyncValue bool checks
- [Phase 16-espionage-city-viewing]: /city-view top-level GoRoute (hides bottom nav); /spy-log nested in battles branch (bottom nav stays visible)
- [Phase 17-01]: CityScreen city name uses white color + drop shadow instead of primary color — visible over transparent AppBar
- [Phase 17-01]: EnemyCityViewScreen banner text updated to include cityName+ownerName since AppBar title removed; body uses Padding not SafeArea for correct Column expansion
- [Phase 17-02]: valueOrNull not in Riverpod 3.x — world_map_screen uses whenOrNull(data: (v) => v) instead
- [Phase 17-02]: Removed _isNaval helper from dispatch_screen — no longer needed after CircleAvatar replaces icon

### v1.2 Design Notes

- ESPY-01: Espionage is instant (no spy unit type, no travel time) — server resolves immediately on action trigger
- TRAD-01: Uses existing cargo ships with distance-based travel time; cargo JSONB column on unit_movements already present from v1.1
- DEVT-02, DEVT-03: Timer overrides are dev-mode only — must be invisible in production builds; use existing devMode guard pattern
- UIPL-02: City color scheme: own = green, ally = blue/teal, enemy = red/orange; exact palette TBD in Phase 17
- UIPL-03: unitTypeColors map already exists with 13 distinct colors — Phase 17 wires it into military screens

### Pending Todos

None.

### Blockers/Concerns

Carried from v1.1 (tech debt):
- cityProvider not refreshed after island donation — stale island multiplier in production rate labels
- Happiness formula constants are design estimates — tune via playtesting
- cities Realtime fan-out — monitor at 50+ concurrent players
- JSONB cast inconsistency: older models use `v as int`, newer use `(v as num).toInt()`
- UnitMovement.cargo parsed but no UI renders cargo in transit (MOVE-02 will fix this)
- hideoutProtectionFloor() Dart helper not surfaced in any UI

## Session Continuity

Last session: 2026-03-17T00:51:06.313Z
Stopped at: Completed 17-02-PLAN.md — Phase 17 Plan 02 fully verified and complete
Resume file: None
Next action: `/gsd:plan-phase 15` (Resource Trading)
