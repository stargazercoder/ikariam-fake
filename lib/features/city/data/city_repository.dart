import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';

/// Repository for city-related database queries.
///
/// Read queries use SELECT-only RLS for authenticated users.
/// Mutations (e.g. setWineRate) are routed through Edge Functions per
/// decision INFR-02 — no client writes directly to game-state tables.
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

  /// Updates the wine spending rate for [cityId] to [wineSpendingRate].
  ///
  /// [wineSpendingRate] must be an integer between 0 and 100 inclusive.
  /// The Edge Function validates auth, city ownership, and range — this
  /// method throws if the server returns a non-200 status.
  Future<void> setWineRate({
    required String cityId,
    required int wineSpendingRate,
  }) async {
    final response = await supabaseClient.functions.invoke(
      'set-wine-rate',
      body: {
        'city_id': cityId,
        'wine_spending_rate': wineSpendingRate,
      },
    );
    if (response.status != 200) {
      throw Exception('Failed to set wine rate: ${response.data}');
    }
  }
}

/// Riverpod provider for [CityRepository].
final cityRepositoryProvider = Provider<CityRepository>((ref) {
  return const CityRepository();
});
