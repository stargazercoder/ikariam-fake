import 'package:flutter_riverpod/flutter_riverpod.dart';

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
