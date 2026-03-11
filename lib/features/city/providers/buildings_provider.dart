// Riverpod StreamProvider for real-time city building levels.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/buildings_repository.dart';
import '../models/city_building.dart';

/// StreamProvider.family that emits live [CityBuilding] snapshots for [cityId].
///
/// Uses [BuildingsRepository.watchCityBuildings] which subscribes to the
/// city_buildings Realtime publication.  The snapshot emits automatically
/// when pg_cron's complete_building_upgrades() increments a building level.
///
/// autoDispose releases the Realtime subscription when no widget is watching.
final buildingsStreamProvider =
    StreamProvider.autoDispose.family<List<CityBuilding>, String>(
  (ref, cityId) {
    final stream =
        ref.read(buildingsRepositoryProvider).watchCityBuildings(cityId);
    return stream;
  },
);
