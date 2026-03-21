---
phase: 28-city-screen-cleanup
plan: 01
subsystem: ui
tags: [flutter, city-screen, enemy-city, appbar, cleanup]

# Dependency graph
requires:
  - phase: 27-battle-ui-improvements
    provides: Carry capacity dispatch widget; battle UI improvements
provides:
  - Own city screen AppBar shows avatar icon only (no display name text)
  - Own city screen body starts directly with Island Info card (no title block)
  - Enemy city view banner shows generic "Viewing enemy city — read only" text
affects: [city-screen, enemy-city-view, v1.4-ui-consistency]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "City screens present only gameplay content; name/title texts deferred to future milestone with proper design"
    - "EnemyCityViewScreen preserves constructor params (cityName, ownerName) for router compatibility even when not displayed"

key-files:
  created: []
  modified:
    - lib/features/city/screens/city_screen.dart
    - lib/features/map/screens/enemy_city_view_screen.dart

key-decisions:
  - "Keep cityName and ownerName constructor params on EnemyCityViewScreen — removing them would require router + 3 call-site changes, out of scope for a cosmetic text removal phase"
  - "displayName derivation removed entirely from CityScreen.build() since no widget consumes it after AppBar cleanup"

patterns-established:
  - "AppBar avatar-only pattern: Padding(padding: EdgeInsets.only(right: 8), child: AvatarWidget(avatarId: avatarId, size: 32))"

requirements-completed: [CLNP-01]

# Metrics
duration: 10min
completed: 2026-03-21
---

# Phase 28 Plan 01: City Screen Title Text Removal Summary

**Removed standalone city name and player name title texts from own-city and enemy-city screens, leaving AppBar avatar-only and body starting directly with Island Info card.**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-03-21T13:48:35Z
- **Completed:** 2026-03-21T14:00:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Own city AppBar now shows avatar icon only (no display name text beside it)
- Own city body column begins with Island Info card — no city name headline, no Governor text above it
- Enemy city view banner text changed from `Viewing $cityName ($ownerName) — read only` to `Viewing enemy city — read only`
- Dead code cleaned: `displayName` variable, `_CityBody.displayName` field/param, and `cityName` variable all removed
- `flutter analyze` passes clean on both files — zero errors, zero warnings

## Task Commits

Each task was committed atomically:

1. **Task 1: Remove title texts from own city screen + dead code cleanup** - `9acf635` (feat)
2. **Task 2: Replace enemy city view banner text with generic message** - `988ab6c` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified
- `lib/features/city/screens/city_screen.dart` - Removed city name headline, Governor text, displayName in AppBar; dead code removed
- `lib/features/map/screens/enemy_city_view_screen.dart` - Banner text replaced with generic message; doc comment updated

## Decisions Made
- `cityName` and `ownerName` constructor params on `EnemyCityViewScreen` kept as-is — they are still passed from `app_router.dart` and 3 navigation call sites; removing them is out of scope for a cosmetic change
- `displayName` derivation removed entirely from `CityScreen.build()` since no widget consumes it after the AppBar cleanup

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness
- CLNP-01 requirement satisfied: all city screens have city/player name title texts removed
- v1.4 UI Consistency milestone complete for city screen cleanup phase
- Name/title texts can be re-added with proper design in a future milestone without structural changes needed

---
*Phase: 28-city-screen-cleanup*
*Completed: 2026-03-21*
