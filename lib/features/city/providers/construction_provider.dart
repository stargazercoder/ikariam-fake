// Riverpod StreamProvider for real-time construction queue state.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../models/construction_queue_entry.dart';

/// StreamProvider.family that emits the active [ConstructionQueueEntry] for
/// [cityId], or null if the queue is empty.
///
/// The UNIQUE(city_id) constraint on construction_queue guarantees at most one
/// row per city.  The stream maps the first row (if any) to a
/// [ConstructionQueueEntry]; when the row is deleted by
/// complete_building_upgrades(), the stream emits null automatically.
///
/// autoDispose releases the Realtime subscription when no widget watches it.
final constructionQueueProvider = StreamProvider.autoDispose
    .family<ConstructionQueueEntry?, String>((ref, cityId) {
  final stream = supabaseClient
      .from('construction_queue')
      .stream(primaryKey: ['id'])
      .eq('city_id', cityId)
      .map(
        (rows) => rows.isEmpty
            ? null
            : ConstructionQueueEntry.fromJson(rows.first),
      );
  return stream;
});
