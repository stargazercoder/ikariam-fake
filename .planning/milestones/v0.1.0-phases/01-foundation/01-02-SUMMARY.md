---
phase: 01-foundation
plan: 02
subsystem: auth
tags: [flutter, riverpod, go_router, supabase, auth, routing]

# Dependency graph
requires:
  - phase: 01-foundation/01-01
    provides: Flutter project with supabase_flutter, flutter_riverpod, go_router deps and feature-first folder structure
provides:
  - AuthRepository with signUp/signIn/signOut wrapping Supabase auth
  - authStateChangesProvider (StreamProvider on onAuthStateChange)
  - currentUserProvider (Provider<User?> derived from auth stream)
  - ProfileRepository with fetchProfile/updateProfile; throws DisplayNameTakenException on 23505
  - ProfileNotifier (AsyncNotifier) with hasCompletedProfile + refresh()
  - GoRouter with _RouterNotifier bridging Riverpod to refreshListenable
  - Auth redirect guards: unauthenticated -> /login, incomplete profile -> /create-profile, auth route + session -> /city
  - LoginScreen with email/password form, Material 3 Card layout, max-width 400px
  - SignupScreen with email/password/confirm form, Material 3 Card layout, max-width 400px
  - LoadingOverlay shared widget blocking double-tap during async submissions
  - main.dart updated to MaterialApp.router with ConsumerWidget
  - Placeholder CityScreen and CreateProfileScreen for router destinations
affects: [01-03, 01-04, 02-resources, all-phases]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Manual Riverpod providers (Provider/StreamProvider/AsyncNotifierProvider) — no code-gen (riverpod_generator still incompatible with Dart 3.10.1)
    - _RouterNotifier ChangeNotifier bridges Riverpod state to GoRouter refreshListenable — router never recreated on auth change
    - GoRouter redirect evaluated in priority order: no session -> /login; profile loading -> hold; no display_name -> /create-profile; auth route + session -> /city
    - DisplayNameTakenException typed exception wrapping PostgrestException code 23505
    - ConsumerWidget at app root watches appRouterProvider

key-files:
  created:
    - lib/features/auth/data/auth_repository.dart
    - lib/features/auth/providers/auth_state_provider.dart
    - lib/features/profile/data/profile_repository.dart
    - lib/features/profile/providers/profile_provider.dart
    - lib/core/router/app_router.dart
    - lib/features/auth/screens/login_screen.dart
    - lib/features/auth/screens/signup_screen.dart
    - lib/shared/widgets/loading_overlay.dart
    - lib/features/city/screens/city_screen.dart
    - lib/features/profile/screens/create_profile_screen.dart
  modified:
    - lib/main.dart
    - test/helpers/mocks.dart

key-decisions:
  - "Manual Riverpod providers used throughout (no @riverpod code-gen): riverpod_generator still requires analyzer ^9.0.0, incompatible with Dart 3.10.1. Provider/StreamProvider/AsyncNotifierProvider are direct API equivalents."
  - "GoRouter created once per app lifetime: _RouterNotifier watches both authStateChangesProvider and profileProvider, calling notifyListeners() on any change. The redirect callback is re-evaluated without recreating the router object."
  - "Profile completeness check is async-aware: when profileProvider is AsyncLoading, redirect only moves users off /login and /signup (not to /city). This prevents a brief flash to /city before profile check completes."
  - "Tasks 1 and 2 combined into one commit: login/signup screens were required for the router to compile (GoRoute builders reference them), so all auth/profile/router code ships together."

patterns-established:
  - "Pattern: Repository classes are plain Dart objects (no state); Riverpod Provider<T> wraps them as singletons"
  - "Pattern: AsyncNotifier.build() fetches from repository; refresh() sets AsyncLoading then re-awaits build() result"
  - "Pattern: GoRouter redirect in priority order — no session first, then profile completeness, then auth-route-with-session"
  - "Pattern: LoadingOverlay wraps form screens in a Stack; isLoading bool set in setState during async calls"

requirements-completed: [AUTH-01, AUTH-02]

# Metrics
duration: 4min
completed: 2026-03-11
---

# Phase 1 Plan 02: Auth System Summary

**Supabase auth with StreamProvider-driven GoRouter redirect guards, login/signup screens with Material 3 Card layout, and typed DisplayNameTakenException for profile uniqueness errors**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-10T23:27:50Z
- **Completed:** 2026-03-10T23:31:58Z
- **Tasks:** 2
- **Files modified:** 12

## Accomplishments

- Full auth state management: authStateChangesProvider streams Supabase auth changes; currentUserProvider derives User? for consumers
- GoRouter with auth-aware redirect: unauthenticated users redirected to /login; incomplete profile to /create-profile; authenticated users on auth screens to /city
- Login and signup screens with Material 3 Card layout (max-width 400px, clean spacing, error SnackBars, LoadingOverlay blocking double-taps)
- Profile repository with typed exception for unique constraint violation (DisplayNameTakenException from PostgrestException 23505)
- Session persistence across browser refresh handled automatically by supabase_flutter's SharedPreferences-based session storage

## Task Commits

Each task was committed atomically:

1. **Tasks 1+2: Auth/profile repos, GoRouter, login/signup screens** - `a5add60` (feat)

**Plan metadata:** (created after this summary)

_Note: Tasks 1 and 2 were merged into a single commit because the auth screens are imported directly by the GoRouter builder closures — they must exist together for the code to compile._

## Files Created/Modified

- `lib/features/auth/data/auth_repository.dart` - AuthRepository class + authRepositoryProvider wrapping Supabase auth operations
- `lib/features/auth/providers/auth_state_provider.dart` - authStateChangesProvider (StreamProvider) and currentUserProvider (Provider<User?>)
- `lib/features/profile/data/profile_repository.dart` - ProfileRepository with fetchProfile/updateProfile; DisplayNameTakenException typed exception
- `lib/features/profile/providers/profile_provider.dart` - ProfileNotifier AsyncNotifier with hasCompletedProfile + refresh()
- `lib/core/router/app_router.dart` - GoRouter + _RouterNotifier ChangeNotifier with auth/profile redirect logic
- `lib/features/auth/screens/login_screen.dart` - Login form with email/password fields, SnackBar error handling, navigation to /signup
- `lib/features/auth/screens/signup_screen.dart` - Signup form with email/password/confirm fields, success/error handling
- `lib/shared/widgets/loading_overlay.dart` - Reusable semi-transparent overlay with CircularProgressIndicator
- `lib/features/city/screens/city_screen.dart` - Placeholder city screen (Phase 2 fills content)
- `lib/features/profile/screens/create_profile_screen.dart` - Placeholder profile creation screen (Plan 01-03 fills content)
- `lib/main.dart` - Updated to MaterialApp.router; IkariamApp converted to ConsumerWidget watching appRouterProvider
- `test/helpers/mocks.dart` - Updated with real Mock implementations: MockSupabaseClient, MockGoRouter, MockAuthRepository, MockProfileRepository

## Decisions Made

1. **Manual Riverpod providers throughout**: `riverpod_generator` still requires `analyzer ^9.0.0` but Dart 3.10.1 pins an older analyzer. Used `Provider`, `StreamProvider`, and `AsyncNotifierProvider` directly — these are the exact API equivalents of what code-gen would emit.

2. **Single commit for Tasks 1+2**: Login and signup screens are referenced in GoRouter's route builders; they cannot exist in a separate commit from the router. Both tasks shipped together without losing any correctness.

3. **Profile loading handled in redirect**: When `profileProvider` is `AsyncLoading`, the redirect logic avoids sending authenticated users to `/city` (which would briefly flash the wrong screen). Instead, it holds them on non-auth routes until the profile check resolves.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Updated mocks.dart with real Mock classes**
- **Found during:** Task 1 (reviewing test infrastructure)
- **Issue:** mocks.dart contained placeholder stubs (classes without Mock extension) that would not function as Mocktail mocks in future tests. Now that supabase_flutter and go_router are installed, real mocks could be created.
- **Fix:** Replaced placeholder stubs with proper `extends Mock implements X` classes for SupabaseClient, GoRouter, AuthRepository, and ProfileRepository
- **Files modified:** test/helpers/mocks.dart
- **Verification:** flutter analyze passes (no import or type errors)
- **Committed in:** a5add60 (Task 1+2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 2 — missing critical test infrastructure)
**Impact on plan:** Necessary correctness fix; no scope creep.

## Issues Encountered

- None. No analyzer errors, no package conflicts, no build issues.

## User Setup Required

None — no external service configuration required. All auth screens connect to the local Supabase instance configured in Plan 01-01.

## Next Phase Readiness

- `flutter analyze --no-fatal-infos` passes with zero issues
- `flutter test` passes (1 passing, 5 skipped awaiting future plans)
- Login/signup screens are functional and connect to Supabase Auth
- GoRouter redirect logic enforces auth and profile-completeness gates
- Session persistence across browser refresh is handled by supabase_flutter automatically
- Ready for Plan 01-03: Profile creation screen with display_name/avatar selection

## Self-Check: PASSED

All created files exist on disk. Commit `a5add60` verified in git log.

---
*Phase: 01-foundation*
*Completed: 2026-03-11*
