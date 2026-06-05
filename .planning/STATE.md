---
gsd_state_version: 1.0
milestone: v1.4
milestone_name: UI Consistency
status: complete
stopped_at: Milestone archived
last_updated: "2026-06-05T00:00:00Z"
last_activity: 2026-06-05 — v1.4 milestone archived, git tag v1.4 created
progress:
  total_phases: 4
  completed_phases: 4
  total_plans: 5
  completed_plans: 5
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-05)

**Core value:** Players can build and manage cities, gather resources, and engage in real-time turn-based warfare — the core loop of build, expand, and conquer must feel satisfying and strategically meaningful.
**Current focus:** v1.4 COMPLETE — archived 2026-06-05. Start v1.5 with `/gsd-new-milestone`.

## Current Position

**Milestone:** v1.4 UI Consistency — SHIPPED
**Status:** All 4 phases complete, milestone archived
**Next:** `/gsd-new-milestone` to define v1.5

```
v1.4 Progress: [████████████████████] 100%  (4/4 phases complete)
```

## Performance Metrics

**Cumulative (all milestones):**
- v0.1.0: 9 phases, 27 plans in 2 days
- v1.1: 3 phases, 8 plans in 3 days
- v1.2: 5 phases, 11 plans in 2 days
- v1.3: 7 phases, 11 plans in 2 days
- v1.4: 4 phases, 5 plans in 3 days
- **Total shipped: 28 phases, 62 plans**

**v1.4 (archived):**
| Phase | Plan | Duration | Tasks | Files |
|-------|------|----------|-------|-------|
| 25-visual-constants | 01 | 25m | 2 | 10 |
| 26-building-detail-sheet | 01 | 4m | 2 | 10 |
| 26-building-detail-sheet | 02 | 9m | 2 | 15 |
| 27-battle-ui-improvements | 01 | 15m | 2 | 5 |
| 28-city-screen-cleanup | 01 | 10m | 2 | 2 |

## Accumulated Context

### Decisions

All decisions logged in PROJECT.md Key Decisions table.

**v1.4 Key Decisions:**
- Wine uses Icon(Icons.wine_bar) not CircleAvatar+letter — per locked PROJECT.md decision
- Wine letter 'V' (Vinum) avoids clash with Wood's 'W'
- Wine color Color(0xFF8E24AA) = purple.shade600
- Sheet stays open after upgrade (SnackBar feedback only, no Navigator.pop)
- go_router removed from city_grid_screen.dart after barracks/shipyard context.push replaced
- downgradeRefund uses floor(50%) — player loses fractional resources on downgrade
- Downgrade is instant — not gated by construction queue
- Refund via negative p_amount to deduct_resource (adds resources)
- cargoCapacityPerShip=500 constant in unit_constants.dart synced with SQL v_cargo_cap formula
- _CargoCapacityRow hides entirely when maxShips==0; orange warning when 0 selected but ships available
- Keep cityName/ownerName params on EnemyCityViewScreen for router compatibility even though no longer displayed
- displayName derivation removed entirely from CityScreen.build() since no widget consumes it

### Pending Todos

None.

### Blockers/Concerns

Carried tech debt (pre-v1.5):
- cityProvider not refreshed after island donation — stale island multiplier in production rate labels
- JSONB cast inconsistency: older models use `v as int`, newer use `(v as num).toInt()`
- hideoutProtectionFloor() Dart helper not surfaced in any UI
- Bot archetype weight values need balance tuning after first week of bot operation
- Deno pinned to 2.2.x — track supabase/supabase#33093 for upgrade

## Session Continuity

Last session: 2026-06-05T00:00:00Z
Stopped at: Milestone v1.4 archived
Resume file: None
Next action: `/gsd-new-milestone` to start v1.5
