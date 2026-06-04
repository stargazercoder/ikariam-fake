import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/providers/auth_state_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/city/screens/city_screen.dart';
import '../../features/map/providers/islands_provider.dart';
import '../../features/map/screens/island_screen.dart';
import '../../features/map/screens/main_shell_screen.dart';
import '../../features/map/screens/world_map_screen.dart';
import '../../features/battles/screens/battle_detail_screen.dart';
import '../../features/battles/screens/battles_screen.dart';
import '../../features/movements/screens/movements_screen.dart';
import '../../features/military/screens/dispatch_screen.dart';
import '../../features/map/screens/enemy_city_view_screen.dart';
import '../../features/espionage/screens/spy_log_screen.dart';
import '../../features/godmode/screens/godmode_dashboard_screen.dart';
import '../../features/profile/providers/profile_provider.dart';
import '../../features/profile/screens/create_profile_screen.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../core/debug/log_store.dart' as debug;

// Navigator keys for each StatefulShellBranch — must be file-level constants
// so they are created once per app lifetime (not recreated on rebuilds).
final _worldNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'worldNav');
final _islandNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'islandNav');
final _cityNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'cityNav');
final _battlesNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'battlesNav');
final _movementsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'movementsNav');

/// Bridges Riverpod provider changes to GoRouter's [ChangeNotifier] system.
///
/// GoRouter evaluates its [redirect] callback whenever [notifyListeners] is
/// called.  We watch both [authStateChangesProvider] and [profileProvider] so
/// the router re-evaluates after a sign-in, sign-out, or profile update.
///
/// The [GoRouter] instance is created ONCE and never recreated; only the
/// redirect logic runs again on each notification.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    // Watch auth state — notifies router on sign-in / sign-out.
    // Invalidate profile on auth change so it re-fetches for the new user
    // and doesn't show stale loading/null state from a previous session.
    _ref.listen<Object?>(authStateChangesProvider, (prev, next) {
      _ref.invalidate(profileProvider);
      notifyListeners();
    });

    // Watch profile state — notifies router once profile loads / updates.
    _ref.listen<Object?>(profileProvider, (prev, next) {
      notifyListeners();
    });
  }

  final Ref _ref;
}

/// Redirect logic evaluated on every navigation and every notifier event.
///
/// Precedence (evaluated in order):
///   1. No session and not on an auth route → redirect to /login
///   2. Session exists but profile is still loading → redirect to /loading
///      (avoids a brief flash of /map before profile check completes)
///   3. Session exists, profile loaded, display_name is null
///      → redirect to /create-profile
///   4. Session exists, profile complete, on auth route
///      → redirect to /map
///   5. All other cases → no redirect (return null)
String? _redirect(Ref ref, GoRouterState state) {
  final session = Supabase.instance.client.auth.currentSession;
  final location = state.matchedLocation;

  const authRoutes = {'/login', '/signup'};
  final isAuthRoute = authRoutes.contains(location);

  // Rule 1: Not authenticated.
  if (session == null) {
    // Clear stale island selection so the Island tab starts fresh on next login.
    ref.read(selectedIslandIdProvider.notifier).clear();
    return isAuthRoute ? null : '/login';
  }

  // User is authenticated beyond this point.

  // Rule 2: Profile still loading — stay on loading route or hold.
  // We avoid redirecting to /map until we know profile completeness.
  final profileState = ref.read(profileProvider);
  if (profileState.isLoading) {
    // While loading, do not redirect authenticated users away from non-auth
    // routes (e.g., /create-profile itself).  Only send to /create-profile
    // if on an auth route, so they leave the login/signup pages immediately.
    return isAuthRoute ? '/create-profile' : null;
  }

  // Rule 3: Profile loaded but display_name is null.
  final profileNotifier = ref.read(profileProvider.notifier);
  final hasProfile = profileNotifier.hasCompletedProfile;

  if (!hasProfile && location != '/create-profile') {
    return '/create-profile';
  }

  // Rule 4: Session + complete profile but still on an auth screen.
  if (isAuthRoute) {
    return '/map';
  }

  // Rule 4b: Non-admin accessing /godmode → redirect to /map
  if (location == '/godmode' && !profileNotifier.isAdmin) {
    return '/map';
  }

  // Rule 5: No redirect needed.
  return null;
}

/// GoRouter provider.
///
/// The router is created once per app lifetime.  Auth and profile state
/// changes are communicated via [_RouterNotifier] which calls
/// [notifyListeners], causing GoRouter to re-evaluate [redirect] without
/// recreating the router object.
final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/create-profile',
        builder: (context, state) => const CreateProfileScreen(),
      ),
      // Enemy city view — full-screen detail overlay (no bottom nav).
      GoRoute(
        path: '/city-view',
        builder: (context, state) => EnemyCityViewScreen(
          cityId: state.uri.queryParameters['cityId'] ?? '',
          cityName: Uri.decodeComponent(
              state.uri.queryParameters['cityName'] ?? 'City'),
          ownerName: Uri.decodeComponent(
              state.uri.queryParameters['ownerName'] ?? 'Unknown'),
        ),
      ),
      // GodMode admin dashboard — full-screen, no bottom nav.
      GoRoute(
        path: '/godmode',
        builder: (context, state) => const GodModeDashboardScreen(),
      ),
      GoRoute(
        path: '/debug-logs',
        builder: (context, state) => const debug.DebugLogsPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShellScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _worldNavigatorKey,
            routes: [
              GoRoute(
                path: '/map',
                builder: (context, state) => const WorldMapScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _islandNavigatorKey,
            routes: [
              GoRoute(
                path: '/island',
                builder: (context, state) => const IslandScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _cityNavigatorKey,
            routes: [
              GoRoute(
                path: '/city',
                builder: (context, state) => const CityScreen(),
              ),
              GoRoute(
                path: '/dispatch',
                builder: (context, state) => DispatchScreen(
                  originCityId: state.uri.queryParameters['cityId'] ?? '',
                  initialTargetCityId: state.uri.queryParameters['targetCityId'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _battlesNavigatorKey,
            routes: [
              GoRoute(
                path: '/battles',
                builder: (context, state) => const BattlesScreen(),
              ),
              GoRoute(
                path: '/battle-detail',
                builder: (context, state) => BattleDetailScreen(
                  battleId: state.uri.queryParameters['battleId'] ?? '',
                ),
              ),
              // Spy log nested inside battles branch — bottom nav stays visible.
              GoRoute(
                path: '/spy-log',
                builder: (context, state) => const SpyLogScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _movementsNavigatorKey,
            routes: [
              GoRoute(
                path: '/movements',
                builder: (context, state) => const MovementsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
