---
phase: 14-movement-visibility
verified: 2026-03-16T13:00:00Z
status: passed
score: 9/9 must-haves verified
re_verification: false
human_verification:
  - test: "Movements tab visible and tappable in running app"
    expected: "Fifth tab 'Movements' with swap_horiz icon appears in bottom nav; tapping navigates to Movements screen"
    why_human: "NavigationBar rendering and tap behavior cannot be verified statically"
  - test: "Real-time card disappearance on movement arrival"
    expected: "Card removes itself from the list automatically when the army arrives (Supabase Realtime DELETE event)"
    why_human: "Realtime subscription behaviour requires a live Supabase connection to observe"
  - test: "City name resolves from UUID in a movement card"
    expected: "Destination column shows a human-readable name (e.g., 'Athens') instead of a raw UUID"
    why_human: "Requires a live DB row in the cities table; cannot verify from static code alone"
---

# Phase 14: Movement Visibility Verification Report

**Phase Goal:** Players can see all their armies and cargo currently in transit with full context (destination, ETA, composition)
**Verified:** 2026-03-16T13:00:00Z
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | UnitMovement model includes movementType field parsed from DB movement_type column | VERIFIED | `unit_movement.dart` line 41: `final String movementType;` / line 60: `json['movement_type'] as String? ?? 'attack'` / constructor default `'attack'` at line 16 |
| 2 | watchAllMovements() streams all owner movements globally without per-city filter | VERIFIED | `military_repository.dart` lines 97-110: queries `unit_movements` filtered only by `owner_id`, no `.where((m) => m.originCityId ==` present; sorted by arriveAt ascending via cascade |
| 3 | allMovementsProvider returns a sorted list (soonest ETA first) of all player movements | VERIFIED | `movements_provider.dart` line 34-38: guards on `currentUserProvider`, unwraps stream via `.asData?.value ?? []`; sorting delegated to `watchAllMovements()` upstream |
| 4 | cityNameProvider resolves a city UUID to its display name | VERIFIED | `movements_provider.dart` line 47-55: `FutureProvider.autoDispose.family` querying `cities` table with `.select('name').eq('id', cityId).maybeSingle()` |
| 5 | Player sees a list of all outgoing army movements with destination city name, arrival ETA countdown, and unit composition | VERIFIED | `movements_screen.dart` lines 22-76: `allMovementsStreamProvider` consumed via `.when()`; `_MovementCard` renders city name via `cityNameProvider`, units via `unitTypeFromDbName`, ETA via `CountdownTimerWidget` |
| 6 | Player sees returning cargo ships with carried resource amounts displayed inline | VERIFIED | `movements_screen.dart` lines 145-158: `if (movement.cargo != null && movement.cargo!.isNotEmpty)` guard with `Wrap` of `'${e.key}: ${e.value}'` text items |
| 7 | Movement list updates in real-time as dispatches are sent and arrivals are confirmed | VERIFIED | `movements_provider.dart` uses `StreamProvider.autoDispose` wrapping `watchAllMovements()` which is a Supabase Realtime `.stream()` subscription; autoDispose releases when no widget subscribes |
| 8 | Movements tab is accessible from bottom navigation bar | VERIFIED | `app_router.dart` line 203-211: fifth `StatefulShellBranch` with `_movementsNavigatorKey` at `/movements` route; `main_shell_screen.dart` line 57-61: fifth `NavigationDestination` with `label: 'Movements'` and `swap_horiz` icons |
| 9 | Empty state shows 'No armies in transit' when no movements exist | VERIFIED | `movements_screen.dart` lines 41-66: `if (movements.isEmpty)` branch renders `Text('No armies in transit')` and `Text('Dispatch units from your city to see movements here.')` |

**Score:** 9/9 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/features/military/models/unit_movement.dart` | UnitMovement model with movementType field | VERIFIED | 87 lines; contains `movementType` field, constructor default, fromJson parse; no stubs |
| `lib/features/military/data/military_repository.dart` | watchAllMovements() global stream method | VERIFIED | 175 lines; method at line 97, no per-city filter, sorted by arriveAt; wired to existing `supabaseClient` |
| `lib/features/movements/providers/movements_provider.dart` | allMovementsStreamProvider, allMovementsProvider, cityNameProvider | VERIFIED | 56 lines; all three providers present, imports correct, wired to `militaryRepositoryProvider` and `currentUserProvider` |
| `lib/features/movements/screens/movements_screen.dart` | MovementsScreen with _MovementCard widget | VERIFIED | 183 lines (plan required >80); `ConsumerWidget` pattern; all required elements present |
| `lib/core/router/app_router.dart` | Fifth StatefulShellBranch for /movements route | VERIFIED | `_movementsNavigatorKey` at line 29; fifth branch at lines 203-211; `MovementsScreen` import at line 17 |
| `lib/features/map/screens/main_shell_screen.dart` | Fifth NavigationDestination for Movements tab | VERIFIED | Five `NavigationDestination` entries confirmed; `label: 'Movements'` is fifth at index 4; `Icons.swap_horiz_outlined` and `Icons.swap_horiz` present |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `movements_provider.dart` | `military_repository.dart` | `ref.read(militaryRepositoryProvider).watchAllMovements()` | WIRED | Line 22: exact pattern present |
| `movements_provider.dart` | `auth_state_provider.dart` | `ref.watch(currentUserProvider)` | WIRED | Line 35: `currentUserProvider` watched before returning movements list |
| `movements_screen.dart` | `movements_provider.dart` | `ref.watch(allMovementsStreamProvider)` | WIRED | Line 22: stream provider consumed with `.when()` |
| `movements_screen.dart` | `movements_provider.dart` | `ref.watch(cityNameProvider(movement.destinationCityId))` | WIRED | Line 115-116: nested `Consumer` watches `cityNameProvider` per card |
| `movements_screen.dart` | `countdown_timer_widget.dart` | `CountdownTimerWidget(finishAt: movement.arriveAt)` | WIRED | Line 169-170: `CountdownTimerWidget` instantiated with `movement.arriveAt` |
| `app_router.dart` | `movements_screen.dart` | `GoRoute path: '/movements' builder: MovementsScreen` | WIRED | Import at line 17; route at line 207-209 |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|---------|
| MOVE-01 | 14-01, 14-02 | User can see a list of outgoing army movements (attack, return) with destination, ETA, and unit composition | SATISFIED | `MovementsScreen` renders destination city name (via `cityNameProvider`), ETA (`CountdownTimerWidget`), unit composition (`unitTypeFromDbName`), and movement direction icons (`call_made`/`call_received`) |
| MOVE-02 | 14-01, 14-02 | User can see returning cargo ships with carried resource amounts (pillage loot and trade cargo) | SATISFIED | `_MovementCard` conditionally renders `cargo` map entries when `movement.cargo != null && movement.cargo!.isNotEmpty`; `movementType == 'return'` changes icon to `call_received` |

No orphaned requirements found — both IDs declared in both plans and confirmed mapped to Phase 14 in REQUIREMENTS.md.

---

### Anti-Patterns Found

No anti-patterns detected across all five files scanned:
- No TODO/FIXME/HACK/PLACEHOLDER comments
- No stub return values (`return null`, `return []`, `return {}`)
- No empty handlers
- No console.log equivalents (`debugPrint` not present in new files)

---

### Commits Verified

All four commits documented in summaries confirmed to exist in git history:

| Hash | Plan | Description |
|------|------|-------------|
| `98cbddc` | 14-01 | feat: add movementType field to UnitMovement model (1 file, +8/-1 lines) |
| `3629b21` | 14-01 | feat: add watchAllMovements() and create movement providers (2 files, +75 lines) |
| `05b7d39` | 14-02 | feat: add Movements route and navigation tab (2 files, +22/-1 lines) |
| `7af712e` | 14-02 | feat: create MovementsScreen with _MovementCard (1 file, +183 lines) |

---

### Human Verification Required

#### 1. Movements Tab Navigation

**Test:** Run the app, log in with a profile, observe the bottom navigation bar
**Expected:** Five tabs visible — World, Island, City, Battles, Movements — with the swap_horiz icon on the last tab; tapping navigates to the Movements screen
**Why human:** NavigationBar layout and tap routing require a running Flutter app

#### 2. Real-Time Card Disappearance

**Test:** Dispatch an army, go to the Movements tab, wait for it to arrive (or speed up via dev trigger)
**Expected:** The movement card disappears automatically without page refresh once the army arrives
**Why human:** Supabase Realtime DELETE event propagation cannot be tested statically

#### 3. City Name Resolution

**Test:** Dispatch an army to a named city; view the movement card
**Expected:** Destination shows the city's display name (e.g., "Athens") not a raw UUID; shows "..." briefly while loading
**Why human:** Requires live Supabase DB connection to verify the `cityNameProvider` round-trip

---

### Gaps Summary

No gaps. All automated checks passed:

- Data layer (Plan 01): `UnitMovement.movementType` field exists with correct `fromJson` parse and default. `watchAllMovements()` streams all owner rows without per-city filter, sorted ascending. Three providers (`allMovementsStreamProvider`, `allMovementsProvider`, `cityNameProvider`) are substantive, wired to the repository and auth providers.
- UI layer (Plan 02): `MovementsScreen` is 183 lines (above the 80-line minimum), substantively implements loading/error/empty/data states, renders all required fields. `_MovementCard` shows direction icons, city name (via nested `Consumer`), unit composition, conditional cargo, and live ETA countdown. Router has the fifth `StatefulShellBranch` at `/movements`. Shell screen has the fifth `NavigationDestination` at index 4.
- Requirements MOVE-01 and MOVE-02 are both satisfied by the implementation.
- All four commits exist in git history.

The phase goal — "Players can see all their armies and cargo currently in transit with full context (destination, ETA, composition)" — is achieved by the implemented code.

---

_Verified: 2026-03-16T13:00:00Z_
_Verifier: Claude (gsd-verifier)_
