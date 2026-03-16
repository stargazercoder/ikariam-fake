// Riverpod providers for the global Movements screen.
//
// Exposes a live stream of all player unit movements (not filtered by city),
// plus a city name lookup helper for rendering movement rows.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../auth/providers/auth_state_provider.dart';
import '../../military/data/military_repository.dart';
import '../../military/models/unit_movement.dart';

/// StreamProvider that emits live snapshots of all [UnitMovement] rows owned
/// by the current user, sorted by arriveAt ascending (soonest arrival first).
///
/// Delegates to [MilitaryRepository.watchAllMovements] which subscribes to
/// Supabase Realtime without any per-city filter.
///
/// autoDispose releases the Realtime subscription when no widget watches it.
final allMovementsStreamProvider =
    StreamProvider.autoDispose<List<UnitMovement>>(
  (ref) => ref.read(militaryRepositoryProvider).watchAllMovements(),
);

/// Provider.autoDispose that exposes the current player's movement list as a
/// plain [List<UnitMovement>].
///
/// Returns an empty list when:
/// - The user is not authenticated.
/// - The stream has not emitted its first value yet.
/// - The stream emits an error.
///
/// Mirrors the [allMyBattlesProvider] pattern from battles_provider.dart.
final allMovementsProvider = Provider.autoDispose<List<UnitMovement>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.watch(allMovementsStreamProvider).asData?.value ?? [];
});

/// FutureProvider.family that resolves a city UUID to its display name.
///
/// Fetches the 'name' column from the 'cities' table via a single Supabase
/// query. Returns null if no city with the given [cityId] exists.
///
/// Used by movement list rows to display human-readable city names instead
/// of raw UUIDs.
final cityNameProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, cityId) async {
  final row = await supabaseClient
      .from('cities')
      .select('name')
      .eq('id', cityId)
      .maybeSingle();
  return row?['name'] as String?;
});
