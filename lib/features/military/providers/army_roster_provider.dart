// Riverpod StreamProvider for real-time army roster.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/military_repository.dart';
import '../models/city_unit.dart';

/// StreamProvider.family that emits live [CityUnit] snapshots for [cityId].
///
/// Uses [MilitaryRepository.watchArmyRoster] which subscribes to the
/// city_units Realtime publication. The snapshot emits automatically when
/// pg_cron's complete_training() inserts or updates unit rows after training
/// completes.
///
/// autoDispose releases the Realtime subscription when no widget watches it.
final armyRosterProvider =
    StreamProvider.autoDispose.family<List<CityUnit>, String>(
  (ref, cityId) =>
      ref.read(militaryRepositoryProvider).watchArmyRoster(cityId),
);
