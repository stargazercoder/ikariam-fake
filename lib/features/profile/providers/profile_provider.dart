import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/profile_repository.dart';

/// Holds the current user's profile row fetched from Supabase.
///
/// On initialization (and after [refresh] is called) it queries the profiles
/// table for the authenticated user.  The state is [AsyncLoading] while the
/// query is in flight, [AsyncData<null>] if no row is found, and
/// [AsyncData<Map>] when the profile is loaded.
///
/// An [AsyncNotifier] is used (manual definition, no code-gen) to expose the
/// [hasCompletedProfile] getter and the [refresh] method alongside the data.
class ProfileNotifier extends AsyncNotifier<Map<String, dynamic>?> {
  @override
  Future<Map<String, dynamic>?> build() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;
    final repo = ref.read(profileRepositoryProvider);
    return repo.fetchProfile(userId);
  }

  /// Returns true when the loaded profile has a non-null display_name,
  /// indicating the player has completed the profile creation screen.
  bool get hasCompletedProfile {
    return state.whenOrNull(
          data: (profile) =>
              profile != null && profile['display_name'] != null,
        ) ??
        false;
  }

  /// Returns true when the current user's account is flagged as a bot.
  /// Always false for real players; only true for server-managed bot accounts.
  bool get isBot {
    return state.whenOrNull(
          data: (profile) => (profile?['is_bot'] as bool?) ?? false,
        ) ??
        false;
  }

  /// Returns true when the current user has admin (GodMode) access.
  /// Used by GoRouter redirect guard and future GodMode screen.
  bool get isAdmin {
    return state.whenOrNull(
          data: (profile) => (profile?['is_admin'] as bool?) ?? false,
        ) ??
        false;
  }

  /// Re-fetches the profile from the database.
  /// Call this after a successful profile update.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }
}

/// Provider for [ProfileNotifier].
final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, Map<String, dynamic>?>(
  ProfileNotifier.new,
);
