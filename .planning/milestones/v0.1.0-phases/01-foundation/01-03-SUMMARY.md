---
phase: 01-foundation
plan: 03
subsystem: ui
tags: [flutter, riverpod, supabase, profile, avatar, city, go_router]

# Dependency graph
requires:
  - phase: 01-foundation/01-02
    provides: ProfileRepository with updateProfile/DisplayNameTakenException, profileProvider AsyncNotifier, authRepositoryProvider, GoRouter /create-profile and /city routes, currentUserProvider
  - phase: 01-foundation/01-01
    provides: AvatarConstants with 20 Greek deity entries, AppTheme with Material 3 navy/gold palette, cities table with RLS and island join
provides:
  - AvatarWidget: coloured circle per avatar id, isSelected selection ring, 20-colour deterministic palette
  - AvatarPicker: 4/5-column responsive GridView of all 20 avatars with tap-to-select highlight and labels
  - CreateProfileScreen: mandatory profile gate with avatar picker, display name TextFormField (3-20 chars regex), LoadingOverlay, DisplayNameTakenException SnackBar, sign-out TextButton
  - CityRepository: fetchPlayerCity with island join (SELECT-only, no mutations)
  - CityNotifier: AsyncNotifier loading current user's city reactively
  - CityScreen: city name in AppBar, island coordinates + luxury type info card, Phase 2 placeholder, player avatar+name in AppBar, sign-out button
  - AppTheme.primaryColor / .secondaryColor exposed as public static consts
affects: [01-04, 02-resources, 03-map, all-phases]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - AvatarWidget uses deterministic colour palette indexed by avatarId for consistent visual identity
    - CityRepository is pure query-only (no writes) — city creation is trigger-only, matching RLS constraint
    - CityNotifier follows same AsyncNotifier.build() + refresh() pattern established in ProfileNotifier

key-files:
  created:
    - lib/shared/widgets/avatar_widget.dart
    - lib/features/profile/widgets/avatar_picker.dart
    - lib/features/profile/screens/create_profile_screen.dart
    - lib/features/city/data/city_repository.dart
    - lib/features/city/providers/city_provider.dart
    - lib/features/city/screens/city_screen.dart
  modified:
    - lib/core/theme/app_theme.dart

key-decisions:
  - "AppTheme._primaryColor and ._secondaryColor promoted to public static consts (primaryColor / secondaryColor) to allow AvatarWidget to reference them without a BuildContext"
  - "CityScreen uses cityProvider (AsyncNotifier) not a direct Supabase call — consistent with the provider-first pattern established in Plan 01-02"
  - "No build_runner run needed: riverpod_generator still incompatible with Dart 3.10.1; manual providers used (same decision as 01-02)"

patterns-established:
  - "Pattern: AvatarWidget encapsulates colour + icon rendering; consumers pass only avatarId and optional size/isSelected"
  - "Pattern: AvatarPicker is stateless — parent holds selectedAvatarId in setState, AvatarPicker only fires onAvatarSelected callback"
  - "Pattern: CityRepository mirrors ProfileRepository shape — plain Dart class with const constructor, Provider<T> wrapper"

requirements-completed: [AUTH-03]

# Metrics
duration: 4min
completed: 2026-03-11
---

# Phase 1 Plan 03: Profile Creation + City Screen Summary

**Avatar picker with 20 Greek deity options, display name validation with uniqueness error handling, and reactive city screen showing auto-assigned city name and island info — completing the full signup-to-city auth flow**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-10T23:35:14Z
- **Completed:** 2026-03-10T23:38:56Z
- **Tasks:** 3 (2 auto + 1 human-verify checkpoint approved)
- **Files modified:** 7

## Accomplishments

- Full profile creation screen: avatar picker grid (20 options), display name TextFormField with regex validation, duplicate name SnackBar error, sign-out TextButton, LoadingOverlay blocking double-taps
- City screen: city name in AppBar title, island location (grid_x, grid_y) and luxury resource type displayed, player avatar + display name in AppBar actions, sign-out button
- CityRepository + CityNotifier providing reactive city data (island join query, SELECT-only matching RLS)
- AppTheme.primaryColor exposed as public static const for use in non-BuildContext widget fields

## Task Commits

Each task was committed atomically:

1. **Task 1: Avatar widget, avatar picker, and profile creation screen** - `214e79f` (feat)
2. **Task 2: City placeholder screen and end-to-end flow wiring** - `ab19925` (feat)
3. **Task 3: Verify complete Phase 1 auth flow end-to-end** - Human-verified: APPROVED

## Files Created/Modified

- `lib/shared/widgets/avatar_widget.dart` - Reusable coloured circle avatar; isSelected ring; deterministic 20-colour palette
- `lib/features/profile/widgets/avatar_picker.dart` - Responsive 4/5-column GridView of 20 avatars with selection highlight and labels
- `lib/features/profile/screens/create_profile_screen.dart` - Full profile creation form replacing Plan 01-02 placeholder; calls updateProfile, handles DisplayNameTakenException
- `lib/features/city/data/city_repository.dart` - CityRepository with fetchPlayerCity (cities + islands join)
- `lib/features/city/providers/city_provider.dart` - CityNotifier AsyncNotifier loading city on init with refresh()
- `lib/features/city/screens/city_screen.dart` - Full city screen replacing Plan 01-02 placeholder; AppBar with city name + player info + sign-out
- `lib/core/theme/app_theme.dart` - Promoted _primaryColor / _secondaryColor to public static consts

## Decisions Made

1. **AppTheme color exposure**: `_primaryColor` was private. Rather than duplicating the hex value in AvatarWidget, promoted it to `public static const primaryColor`. This is safe — the value is a compile-time constant with no side effects.

2. **No build_runner needed**: Task 2 in the plan mentioned running `dart run build_runner build`. Because `riverpod_generator` is still excluded (see 01-02 decision), CityNotifier was written as a manual `AsyncNotifier` — no code-gen files needed.

3. **CityScreen as ConsumerWidget not ConsumerStatefulWidget**: The city screen is read-only in Phase 1 (no local mutation state). A stateless ConsumerWidget is sufficient and simpler.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed unused import and renamed double-underscore variable in city_screen.dart**
- **Found during:** Task 2 (flutter analyze)
- **Issue:** `auth_state_provider.dart` was imported but not used (the sign-out uses `authRepositoryProvider` directly); `__` pattern in error handler triggered `unnecessary_underscores` lint
- **Fix:** Removed unused import; renamed `__` to `stack` in the error handler callback
- **Files modified:** lib/features/city/screens/city_screen.dart
- **Verification:** `flutter analyze --no-fatal-infos` passes with no issues
- **Committed in:** ab19925 (Task 2 commit)

**2. [Rule 1 - Bug] Promoted AppTheme private color constants to public**
- **Found during:** Task 1 (creating AvatarWidget that needs primary colour without BuildContext)
- **Issue:** `_primaryColor` was private — AvatarWidget could not reference it. Using `Theme.of(context)` is not possible at field-declaration level.
- **Fix:** Changed `static const Color _primaryColor` → `static const Color primaryColor` (and same for `_secondaryColor`); updated all internal references in app_theme.dart
- **Files modified:** lib/core/theme/app_theme.dart
- **Verification:** `flutter analyze --no-fatal-infos` passes; theme renders correctly
- **Committed in:** 214e79f (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (Rule 1 — bugs/correctness)
**Impact on plan:** Both fixes necessary for correctness. No scope creep.

## Issues Encountered

- None. No package conflicts, no Riverpod code-gen needed, no build issues.

## Human Verification Result

**Task 3 checkpoint: APPROVED**

The user verified the complete Phase 1 auth flow end-to-end:
- Signup → profile creation → city screen flow works correctly
- Session persistence confirmed (F5 refresh stays on /city)
- Full auth chain verified as functional

## Next Phase Readiness

- `flutter analyze --no-fatal-infos` passes with zero issues
- `flutter test` passes (1 passing, 5 skipped awaiting human-verify + future plans)
- Full auth flow: signup → /create-profile → /city wired end-to-end
- Avatar picker functional with 20 options and selection highlight
- City screen shows city name + island data from Supabase
- Sign-out works in both profile and city screens
- Human verification of complete flow: APPROVED (Task 3 checkpoint)

## Self-Check: PASSED

All created files exist on disk. Commits `214e79f` and `ab19925` verified in git log.

---
*Phase: 01-foundation*
*Completed: 2026-03-11*
