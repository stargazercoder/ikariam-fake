import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';

/// Thrown when a chosen display_name already exists in the profiles table
/// (Postgres unique constraint violation code 23505).
class DisplayNameTakenException implements Exception {
  const DisplayNameTakenException();

  @override
  String toString() => 'DisplayNameTakenException: that display name is already taken.';
}

/// Repository for profile-related database operations.
///
/// [updateProfile] performs a direct client-side write to the profiles table.
/// This is an intentional exception to the "all game mutations go through Edge
/// Functions" constraint: the profiles table is a player-preferences table
/// (display_name, avatar_id), not a game-state table.  The
/// `profiles_update_own` RLS policy explicitly permits client-side updates
/// restricted to the authenticated user's own row.
class ProfileRepository {
  const ProfileRepository();

  /// Fetches the profile row for [userId], or null if not found.
  Future<Map<String, dynamic>?> fetchProfile(String userId) {
    return supabaseClient
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
  }

  /// Updates the display name and avatar for [userId].
  ///
  /// Throws [DisplayNameTakenException] when another user already owns
  /// [displayName] (Postgres error code 23505).
  Future<void> updateProfile({
    required String userId,
    required String displayName,
    required int avatarId,
  }) async {
    log('ProfileRepository.updateProfile: userId=$userId, displayName=$displayName, avatarId=$avatarId', level: 'info');
    try {
      final result = await supabaseClient
          .from('profiles')
          .update({'display_name': displayName, 'avatar_id': avatarId})
          .eq('id', userId)
          .select()
          .maybeSingle();
      log('ProfileRepository.updateProfile: result=$result', level: 'debug');
    } on PostgrestException catch (e) {
      log('ProfileRepository.updateProfile: PostgrestException code=${e.code}', level: 'error');
      if (e.code == '23505') {
        throw const DisplayNameTakenException();
      }
      rethrow;
    }
  }
}

/// Riverpod provider for [ProfileRepository].
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return const ProfileRepository();
});
