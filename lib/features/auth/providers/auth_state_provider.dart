import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';

/// Streams every [AuthState] change from Supabase auth.
///
/// GoRouter watches this via [_AuthChangeNotifier] to re-evaluate redirect
/// logic whenever the user signs in or out.
///
/// Manual provider definition used because riverpod_generator is incompatible
/// with the current Dart 3.10.1 SDK's pinned analyzer version.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return supabaseClient.auth.onAuthStateChange;
});

/// Derives the current [User] from the latest [AuthState].
///
/// Returns null when the auth stream is loading or errored.
/// Falls back to [SupabaseClient.auth.currentUser] while the stream warms up
/// so the router does not flash /login on every hot-restart.
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  return authState.when(
    data: (state) => state.session?.user,
    loading: () => supabaseClient.auth.currentUser,
    error: (err, stack) => null,
  );
});
