import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../models/island.dart';
import '../models/island_city_slot.dart';

/// Repository for world map database queries.
///
/// All queries are read-only — the islands and cities tables have
/// SELECT-only RLS for authenticated users.
class MapRepository {
  const MapRepository();

  /// Fetches all islands ordered by grid position (left-to-right, top-to-bottom).
  Future<List<Island>> fetchAllIslands() async {
    final rows = await supabaseClient
        .from('islands')
        .select()
        .order('grid_x', ascending: true)
        .order('grid_y', ascending: true);

    return (rows as List<dynamic>)
        .map((row) => Island.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Fetches the detail for a single island, including all its city slots.
  Future<IslandDetail> fetchIslandDetail(String islandId) async {
    final islandRow = await supabaseClient
        .from('islands')
        .select()
        .eq('id', islandId)
        .single();

    final island = Island.fromJson(islandRow as Map<String, dynamic>);

    final cityRows = await supabaseClient
        .from('cities')
        .select('id, slot_number, name, owner_id')
        .eq('island_id', islandId);

    final slots = (cityRows as List<dynamic>)
        .map((row) => CitySlot.fromJson(row as Map<String, dynamic>))
        .toList();

    return IslandDetail(island: island, citySlots: slots);
  }
}

/// Riverpod provider for [MapRepository].
final mapRepositoryProvider = Provider<MapRepository>((ref) {
  return const MapRepository();
});
