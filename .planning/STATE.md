---
gsd_state_version: 1.0
milestone: v1.4
milestone_name: UI Consistency
status: executing
stopped_at: Completed 28-01-PLAN.md
last_updated: "2026-03-21T14:12:09.277Z"
last_activity: 2026-03-19 — Phase 25 Plan 01 complete (visual_constants.dart + ResourceBadge + 6 consumer files)
progress:
  total_phases: 4
  completed_phases: 4
  total_plans: 5
  completed_plans: 5
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-19)

**Core value:** Players can build and manage cities, gather resources, and engage in real-time turn-based warfare — the core loop of build, expand, and conquer must feel satisfying and strategically meaningful.
**Current focus:** v1.4 UI Consistency — Phase 25: Visual Constants

## Current Position

Phase: 25 of 28 (Visual Constants)
Plan: 1 of 1 in current phase
Status: In progress
Last activity: 2026-03-19 — Phase 25 Plan 01 complete (visual_constants.dart + ResourceBadge + 6 consumer files)

```
v1.4 Progress: [░░░░░░░░░░░░░░░░░░░░] 0%  (0/4 phases) — Phase 25 Plan 01 done
```

## Performance Metrics

**Cumulative (prior milestones):**
- v0.1.0: 9 phases, 27 plans in 2 days
- v1.1: 3 phases, 8 plans in 3 days
- v1.2: 5 phases, 11 plans in 2 days
- v1.3: 7 phases, 11 plans in 2 days
- Total shipped: 24 phases, 57 plans

**v1.4 (current):**
| Phase | Plan | Duration | Tasks | Files |
|-------|------|----------|-------|-------|
| 25-visual-constants | 01 | 25m | 2 | 10 |
| Phase 26-building-detail-sheet P01 | 4m | 2 tasks | 10 files |
| Phase 26-building-detail-sheet P02 | 9m | 2 tasks | 15 files |
| Phase 27-battle-ui-improvements P01 | 15m | 2 tasks | 5 files |
| Phase 28-city-screen-cleanup P01 | 10m | 2 tasks | 2 files |

## Accumulated Context

### Decisions

All decisions logged in PROJECT.md Key Decisions table.

**Phase 25 Plan 01:**
- Wine uses Icon(Icons.wine_bar) not CircleAvatar+letter — per locked PROJECT.md decision
- Wine letter 'V' (Vinum) avoids clash with Wood's 'W'
- Wine color Color(0xFF8E24AA) = purple.shade600 — matches PROJECT.md locked value
- [Phase 26-01]: Sheet stays open after upgrade (SnackBar feedback only, no Navigator.pop) — preserves context for the player
- [Phase 26-01]: go_router removed from city_grid_screen.dart after barracks/shipyard context.push replaced by showBuildingDetailSheet
- [Phase 26-02]: downgradeRefund uses floor(50%) — player loses fractional resources on downgrade
- [Phase 26-02]: Downgrade is instant — not gated by construction queue
- [Phase 26-02]: Refund via negative p_amount to deduct_resource (adds resources)
- [Phase 27-01]: cargoCapacityPerShip=500 constant in unit_constants.dart synced with SQL v_cargo_cap formula
- [Phase 27-01]: _CargoCapacityRow hides entirely when maxShips==0, shows orange warning when 0 selected but ships available in roster
- [Phase 28-01]: Keep cityName/ownerName params on EnemyCityViewScreen for router compatibility even though no longer displayed
- [Phase 28-01]: displayName derivation removed entirely from CityScreen.build() since no widget consumes it after AppBar cleanup

### Pending Todos

None.

### Blockers/Concerns

Carried tech debt (pre-v1.4):
- cityProvider not refreshed after island donation — stale island multiplier in production rate labels
- JSONB cast inconsistency: older models use `v as int`, newer use `(v as num).toInt()`
- hideoutProtectionFloor() Dart helper not surfaced in any UI
- Bot archetype weight values need balance tuning after first week of bot operation
- Deno pinned to 2.2.x — track supabase/supabase#33093 for upgrade

## Session Continuity

Last session: 2026-03-21T14:12:09.269Z
Stopped at: Completed 28-01-PLAN.md
Resume file: None
Next action: Continue to next plan in Phase 25
