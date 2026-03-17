import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/city/providers/city_provider.dart';
import '../data/map_repository.dart';
import '../models/island.dart';

/// FutureProvider that fetches the full list of islands from Supabase.
final allIslandsProvider = FutureProvider<List<Island>>((ref) async {
  final repository = ref.read(mapRepositoryProvider);
  return repository.fetchAllIslands();
});

/// Notifier holding the currently selected island ID.
///
/// Used for cross-tab communication: tapping an island on the World tab
/// updates this provider so the Island tab can display the correct island.
/// Null means no island has been selected yet (Island tab shows player's own island).
class SelectedIslandNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String islandId) => state = islandId;

  void clear() => state = null;
}

/// Provider for [SelectedIslandNotifier].
final selectedIslandIdProvider =
    NotifierProvider<SelectedIslandNotifier, String?>(
  SelectedIslandNotifier.new,
);

/// Provider that returns the player's own island ID from their city data.
///
/// Used by IslandScreen as a fallback when no island has been explicitly
/// selected via the World Map tab.
final playerIslandIdProvider = Provider<String?>((ref) {
  final cityAsync = ref.watch(cityProvider);
  return cityAsync.whenOrNull(
    data: (city) => city?['island_id'] as String?,
  );
});

/// Returns ownership status per island: 'own', 'enemy', or absent (empty).
///
/// Own city takes priority — if the player has ANY city on the island, it
/// is marked 'own' regardless of other cities present.
final islandOwnershipProvider = FutureProvider<Map<String, String>>((ref) async {
  final currentUserId = Supabase.instance.client.auth.currentUser?.id;
  if (currentUserId == null) return {};

  final rows = await Supabase.instance.client
      .from('cities')
      .select('island_id, owner_id');

  final result = <String, String>{};
  for (final row in rows as List<dynamic>) {
    final islandId = row['island_id'] as String;
    final ownerId = row['owner_id'] as String;
    if (ownerId == currentUserId) {
      result[islandId] = 'own'; // own takes priority over enemy
    } else if (!result.containsKey(islandId) || result[islandId] != 'own') {
      result[islandId] = 'enemy';
    }
  }
  return result;
});
