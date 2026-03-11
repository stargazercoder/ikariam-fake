// Riverpod StreamProvider for real-time outgoing unit movements.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/military_repository.dart';
import '../models/unit_movement.dart';

/// StreamProvider.family that emits live [UnitMovement] snapshots for the
/// given [cityId] as the origin city.
///
/// Uses [MilitaryRepository.watchOutgoingMovements] which subscribes to the
/// unit_movements Realtime publication filtered by owner_id. Movements are
/// further filtered client-side by originCityId.
///
/// autoDispose releases the Realtime subscription when no widget watches it.
final unitMovementsProvider =
    StreamProvider.autoDispose.family<List<UnitMovement>, String>(
  (ref, cityId) =>
      ref.read(militaryRepositoryProvider).watchOutgoingMovements(cityId),
);
