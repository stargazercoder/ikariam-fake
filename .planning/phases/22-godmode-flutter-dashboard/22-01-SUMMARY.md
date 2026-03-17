---
phase: 22-godmode-flutter-dashboard
plan: "01"
subsystem: godmode-data-layer
tags: [godmode, rpc, repository, riverpod, polling]
dependency_graph:
  requires: [21-godmode-backend]
  provides: [godmode-data-layer]
  affects: [22-02-godmode-ui]
tech_stack:
  added: []
  patterns: [AsyncNotifier, NotifierProvider, stale-while-refresh, 30s-polling]
key_files:
  created:
    - supabase/migrations/20260317000006_admin_set_army.sql
    - lib/features/godmode/models/godmode_player.dart
    - lib/features/godmode/models/godmode_event.dart
    - lib/features/godmode/data/godmode_repository.dart
    - lib/features/godmode/providers/godmode_world_provider.dart
    - lib/features/godmode/providers/godmode_events_provider.dart
  modified: []
decisions:
  - "StateProvider removed in riverpod 3.x — used NotifierProvider<GodmodeEventFilterNotifier, String?> instead"
  - "GodmodeEventFilterNotifier exposes setFilter() method for UI filter chips"
metrics:
  duration: ~5 minutes
  completed: 2026-03-17
  tasks_completed: 2
  tasks_total: 2
  files_created: 6
  files_modified: 0
---

# Phase 22 Plan 01: GodMode Data Layer Summary

**One-liner:** admin_set_army SECURITY DEFINER RPC with 13 unit types plus riverpod 3.x data layer (repository, world provider, events provider) with 30s polling and stale-while-refresh.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | admin_set_army RPC migration + GodMode models | 3ef88ec | 20260317000006_admin_set_army.sql, godmode_player.dart, godmode_event.dart |
| 2 | GodMode repository and providers with polling | 6af6ac7 | godmode_repository.dart, godmode_world_provider.dart, godmode_events_provider.dart |

## What Was Built

### Task 1: admin_set_army RPC + Models

**Migration (`20260317000006_admin_set_army.sql`):**
- SECURITY DEFINER function `public.admin_set_army` following exact `admin_set_resources` pattern
- 14 parameters: `p_player_id uuid` + 13 nullable integer unit types (hoplite, phalanx, archer, cavalry, catapult, mortar, medic, cook, cargo_ship, ram_ship, catapult_ship, mortar_ship, diving_boat)
- Admin guard with `is_admin` check; raises `insufficient_privilege` if not admin
- City lookup via `owner_id`; raises `no_data_found` if city missing
- Per-unit-type `IF param IS NOT NULL THEN ... INSERT ... ON CONFLICT DO UPDATE` blocks
- `GRANT EXECUTE ... TO authenticated`

**GodmodePlayer model:**
- Parses `godmode_get_world_state()` JSONB response
- Fields: id, displayName, isBot, isPaused, resources map, landCount, navalCount, buildingCount, activeBattleCount, activeBattles list, buildings map
- `int get totalResources` sums all resource values

**GodmodeEvent model:**
- Parses `godmode_get_events()` JSONB array
- Fields: eventType, timestamp, detail map
- `String get summary` extracts human-readable summary from detail

### Task 2: Repository + Providers

**GodmodeRepository:**
- 6 RPC methods: getWorldState, setBotPaused, forceAction, setResources, setArmy, getEvents
- All methods follow `DevRpcService` try/catch/debugPrint/rethrow pattern
- `godmodeRepositoryProvider` singleton via `Provider<GodmodeRepository>`

**GodmodeWorldNotifier:**
- `AsyncNotifier<List<GodmodePlayer>>`
- 30s `Timer.periodic` polling with `ref.onDispose` cleanup
- Stale-while-refresh: existing `AsyncData` kept visible during background refresh
- `sortBy(String column, bool ascending)` for 6 columns: displayName, totalResources, landCount, navalCount, buildingCount, activeBattleCount
- `isRefreshing` and `lastUpdated` flags for UI display

**GodmodeEventsNotifier:**
- `AsyncNotifier<List<GodmodeEvent>>`
- 30s polling with `ref.onDispose` cleanup
- `ref.watch(godmodeEventFilterProvider)` in `build()` causes automatic rebuild on filter change
- `refresh()` reads current filter via `ref.read`
- `godmodeEventFilterProvider` is a `NotifierProvider<GodmodeEventFilterNotifier, String?>` (null = All)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] StateProvider replaced with NotifierProvider**
- **Found during:** Task 2 — dart analyze
- **Issue:** `StateProvider` is removed in riverpod 3.x (project uses flutter_riverpod 3.3.1); dart analyze reported `undefined_function`
- **Fix:** Replaced `StateProvider<String?>` with `GodmodeEventFilterNotifier extends Notifier<String?>` + `NotifierProvider`. Added `setFilter()` method which the UI plan (Plan 02) can call to change filter chips.
- **Files modified:** lib/features/godmode/providers/godmode_events_provider.dart
- **Commit:** 6af6ac7

**2. [Rule 2 - Doc comment] Fixed angle bracket warning in doc comment**
- **Found during:** Task 2 — dart analyze info warning
- **Fix:** Wrapped `p_{unit_type}` in backticks in repository doc comment
- **Files modified:** lib/features/godmode/data/godmode_repository.dart
- **Commit:** 6af6ac7

## Verification Results

```
dart analyze lib/features/godmode/
Analyzing godmode...
No issues found!
```

All 6 RPC method names present in godmode_repository.dart.
Both providers contain `Timer.periodic(const Duration(seconds: 30)` and `ref.onDispose(() => _pollTimer?.cancel())`.

## Self-Check: PASSED

All 6 created files verified to exist:
- supabase/migrations/20260317000006_admin_set_army.sql: FOUND
- lib/features/godmode/models/godmode_player.dart: FOUND
- lib/features/godmode/models/godmode_event.dart: FOUND
- lib/features/godmode/data/godmode_repository.dart: FOUND
- lib/features/godmode/providers/godmode_world_provider.dart: FOUND
- lib/features/godmode/providers/godmode_events_provider.dart: FOUND

Both commits verified in git log:
- 3ef88ec: feat(22-01): admin_set_army RPC migration and GodMode models
- 6af6ac7: feat(22-01): GodMode repository and providers with 30s polling
