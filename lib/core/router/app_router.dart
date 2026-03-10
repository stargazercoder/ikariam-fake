import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/providers/auth_state_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/city/screens/city_screen.dart';
import '../../features/profile/providers/profile_provider.dart';
import '../../features/profile/screens/create_profile_screen.dart';

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
    _ref.listen<Object?>(authStateChangesProvider, (prev, next) {
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
///      (avoids a brief flash of /city before profile check completes)
///   3. Session exists, profile loaded, display_name is null
///      → redirect to /create-profile
///   4. Session exists, profile complete, on auth route
///      → redirect to /city
///   5. All other cases → no redirect (return null)
String? _redirect(Ref ref, GoRouterState state) {
  final session = Supabase.instance.client.auth.currentSession;
  final location = state.matchedLocation;

  const authRoutes = {'/login', '/signup'};
  final isAuthRoute = authRoutes.contains(location);

  // Rule 1: Not authenticated.
  if (session == null) {
    return isAuthRoute ? null : '/login';
  }

  // User is authenticated beyond this point.

  // Rule 2: Profile still loading — stay on loading route or hold.
  // We avoid redirecting to /city until we know profile completeness.
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
    return '/city';
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
      GoRoute(
        path: '/city',
        builder: (context, state) => const CityScreen(),
      ),
    ],
  );
});
