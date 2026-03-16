---
phase: 13-dev-acceleration
plan: 02
subsystem: ui
tags: [flutter, dev-toolbar, rpc, supabase, dart]

# Dependency graph
requires:
  - phase: 13-dev-acceleration
    provides: dev RPC helpers (dev_bulk_spawn_units, dev_instant_complete Supabase functions)
provides:
  - bulkSpawnUnits RPC client method in DevRpcService
  - instantComplete RPC client method in DevRpcService
  - Bulk Spawn checklist dialog (all 13 unit types, checkboxes, qty inputs, default 50)
  - Instant Complete button calling dev_instant_complete for current city
affects: [dev-toolbar, testing, qa]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pre-create Map<String, TextEditingController> before showDialog to prevent rebuild pitfall in ListView.builder"
    - "StatefulBuilder inside AlertDialog for dialog-local state management"

key-files:
  created: []
  modified:
    - lib/core/dev/dev_rpc_service.dart
    - lib/core/dev/dev_toolbar.dart

key-decisions:
  - "Controllers pre-created outside dialog builder (not inside itemBuilder) to avoid TextEditingController rebuild pitfall per RESEARCH.md guidance"
  - "New buttons added after Trigger Battle, preserving order of existing 4 buttons"

patterns-established:
  - "Pre-create TextEditingController map before showDialog when used inside ListView.builder"

requirements-completed: [DEVT-01]

# Metrics
duration: 2min
completed: 2026-03-16
---

# Phase 13 Plan 02: Dev Toolbar Bulk Spawn and Instant Complete Summary

**Bulk Spawn checklist dialog (13 unit types, checkboxes with default qty 50) and Instant Complete button added to Flutter dev toolbar, backed by new bulkSpawnUnits and instantComplete methods in DevRpcService**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-16T08:03:58Z
- **Completed:** 2026-03-16T08:06:13Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Added `bulkSpawnUnits(cityId, Map<String,int> units)` to DevRpcService calling `dev_bulk_spawn_units` RPC
- Added `instantComplete(cityId)` to DevRpcService calling `dev_instant_complete` RPC
- Added `_bulkSpawnUnits()` toolbar method: pre-creates 13 TextEditingControllers, shows checklist dialog with Checkbox + TextField per unit type, calls RPC with selected map
- Added `_instantComplete()` toolbar method: single RPC call with success/error snack
- Both new `_ActionButton` entries added to expanded toolbar panel

## Task Commits

Each task was committed atomically:

1. **Task 1: Add bulkSpawnUnits and instantComplete methods to DevRpcService** - `b580a8b` (feat)
2. **Task 2: Add Bulk Spawn dialog and Instant Complete button to dev toolbar** - `3075f86` (feat)

## Files Created/Modified
- `lib/core/dev/dev_rpc_service.dart` - Added bulkSpawnUnits and instantComplete methods with try/catch + debugPrint + rethrow pattern
- `lib/core/dev/dev_toolbar.dart` - Added _bulkSpawnUnits dialog method, _instantComplete method, and two new _ActionButton entries

## Decisions Made
- Controllers pre-created outside dialog builder to prevent TextEditingController rebuild pitfall when used inside ListView.builder (documented in RESEARCH.md)
- New buttons placed after Trigger Battle to preserve existing 4-button order

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Dev toolbar now has 6 action buttons: Inject Resources, Level Up Building, Spawn Units, Trigger Battle, Bulk Spawn, Instant Complete
- Server-side `dev_bulk_spawn_units` and `dev_instant_complete` RPC functions required (defined in 13-01 plan migrations)
- Ready for Phase 14 (next phase in roadmap)

---
*Phase: 13-dev-acceleration*
*Completed: 2026-03-16*

## Self-Check: PASSED

- lib/core/dev/dev_rpc_service.dart: FOUND
- lib/core/dev/dev_toolbar.dart: FOUND
- .planning/phases/13-dev-acceleration/13-02-SUMMARY.md: FOUND
- Commit b580a8b: FOUND
- Commit 3075f86: FOUND
