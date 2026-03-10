import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';

/// Repository that wraps Supabase auth operations.
///
/// All auth calls go through this class to centralise error handling
/// and to make the rest of the codebase testable via dependency injection.
class AuthRepository {
  const AuthRepository();

  /// Signs up a new user with email and password.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return supabaseClient.auth.signUp(
      email: email,
      password: password,
    );
  }

  /// Signs in an existing user with email and password.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return supabaseClient.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Signs out the current user.
  Future<void> signOut() {
    return supabaseClient.auth.signOut();
  }

  /// Returns the currently authenticated user, or null if not signed in.
  User? get currentUser => supabaseClient.auth.currentUser;

  /// Returns the current session, or null if not signed in.
  Session? get currentSession => supabaseClient.auth.currentSession;
}

/// Riverpod provider for [AuthRepository].
///
/// Using a plain [Provider] (not code-gen) because riverpod_generator is not
/// available in this project's current Dart SDK (analyzer version conflict).
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return const AuthRepository();
});
