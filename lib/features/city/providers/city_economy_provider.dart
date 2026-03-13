// Riverpod StreamProvider for real-time city economy data.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// StreamProvider that emits live economy data from the cities table.
///
/// Returns a [Map<String, dynamic>?] with keys:
/// - 'population': NUMERIC — current population count
/// - 'happiness': NUMERIC — current happiness score
/// - 'wine_spending_rate': INTEGER — wine spending rate 0–100
///
/// The cities table is in the supabase_realtime publication with
/// REPLICA IDENTITY FULL, so every tick update is broadcast to all
/// city-screen subscribers within ~100ms.
///
/// autoDispose ensures the Realtime subscription is released when no widget
/// is watching this provider (e.g., when the city screen is not visible).
final cityEconomyStreamProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, cityId) {
  return Supabase.instance.client
      .from('cities')
      .stream(primaryKey: ['id'])
      .eq('id', cityId)
      .map((rows) => rows.isNotEmpty ? rows.first : null);
});
