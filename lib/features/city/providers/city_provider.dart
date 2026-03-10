import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/city_repository.dart';

/// Notifier that loads the current user's city on initialisation.
///
/// State is [AsyncLoading] while the query is in-flight, [AsyncData<null>]
/// if no city row is found, and [AsyncData<Map>] when city + island data
/// are loaded.
///
/// The map shape (from Supabase with island join) is:
/// ```json
/// {
///   "id": "...",
///   "name": "Athenai",
///   "owner_id": "...",
///   "island_id": "...",
///   "slot_number": 3,
///   "islands": {
///     "id": "...",
///     "grid_x": 4,
///     "grid_y": 7,
///     "luxury_type": "marble"
///   }
/// }
/// ```
///
/// Manual AsyncNotifier used (no @riverpod code-gen) because
/// riverpod_generator is still incompatible with Dart 3.10.1.
class CityNotifier extends AsyncNotifier<Map<String, dynamic>?> {
  @override
  Future<Map<String, dynamic>?> build() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;
    final repo = ref.read(cityRepositoryProvider);
    return repo.fetchPlayerCity(userId);
  }

  /// Re-fetches the city from the database.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }
}

/// Provider for [CityNotifier].
final cityProvider =
    AsyncNotifierProvider<CityNotifier, Map<String, dynamic>?>(
  CityNotifier.new,
);
