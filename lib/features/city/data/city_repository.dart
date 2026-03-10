import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';

/// Repository for city-related database queries.
///
/// Queries are read-only — the cities table has SELECT-only RLS for
/// authenticated users.  No client-side mutations are allowed; the
/// handle_new_user trigger creates the city at sign-up time.
class CityRepository {
  const CityRepository();

  /// Fetches the city owned by [ownerId], including its island data.
  ///
  /// Returns null if no city exists for the given owner (should not happen
  /// after a successful sign-up because the trigger guarantees city creation,
  /// but null is handled gracefully in the UI).
  Future<Map<String, dynamic>?> fetchPlayerCity(String ownerId) {
    return supabaseClient
        .from('cities')
        .select('*, islands(*)')
        .eq('owner_id', ownerId)
        .maybeSingle();
  }
}

/// Riverpod provider for [CityRepository].
final cityRepositoryProvider = Provider<CityRepository>((ref) {
  return const CityRepository();
});
