import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/map_repository.dart';
import '../models/island.dart';

/// FutureProvider that fetches the full list of islands from Supabase.
final allIslandsProvider = FutureProvider<List<Island>>((ref) async {
  final repository = ref.read(mapRepositoryProvider);
  return repository.fetchAllIslands();
});

/// StateProvider holding the currently selected island ID.
///
/// Used for cross-tab communication: tapping an island on the World tab
/// updates this provider so the Island tab can display the correct island.
/// Null means no island has been selected yet (Island tab shows player's own island).
final selectedIslandIdProvider = StateProvider<String?>((ref) => null);
