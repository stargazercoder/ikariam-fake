import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/map_repository.dart';
import '../models/island_city_slot.dart';

/// FutureProvider.family that fetches the detail for a single island by ID.
///
/// Usage: `ref.watch(islandDetailProvider(islandId))`
final islandDetailProvider =
    FutureProvider.family<IslandDetail, String>((ref, islandId) async {
  final repository = ref.read(mapRepositoryProvider);
  return repository.fetchIslandDetail(islandId);
});
