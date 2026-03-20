// Repository for streaming real-time city building data and invoking the
// upgrade-building and downgrade-building Edge Functions.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../models/city_building.dart';

/// Exception thrown when the upgrade-building Edge Function returns an error.
class BuildingUpgradeException implements Exception {
  const BuildingUpgradeException(this.message);

  final String message;

  @override
  String toString() => 'BuildingUpgradeException: $message';
}

/// Repository for city building data access and upgrade/downgrade mutations.
///
/// Reads use Supabase Realtime streams; writes go through Edge Functions
/// (never direct client mutations — INFR-02).
class BuildingsRepository {
  const BuildingsRepository();

  /// Returns a live stream of all building rows for [cityId].
  ///
  /// Uses .stream(primaryKey: ['id']) for Supabase Realtime — the stream
  /// emits a new snapshot whenever any building row changes (e.g., when
  /// complete_building_upgrades() fires and increments a level).
  Stream<List<CityBuilding>> watchCityBuildings(String cityId) {
    return supabaseClient
        .from('city_buildings')
        .stream(primaryKey: ['id'])
        .eq('city_id', cityId)
        .order('building_type')
        .map((rows) => rows.map((r) => CityBuilding.fromJson(r)).toList());
  }

  /// Invokes the upgrade-building Edge Function to start a building upgrade.
  ///
  /// On success (HTTP 200) returns the response data map (contains finish_at,
  /// duration_minutes, target_level).
  ///
  /// On non-200 status, parses the error JSON and throws a
  /// [BuildingUpgradeException] with the server's error message.
  Future<Map<String, dynamic>> upgradeBuilding({
    required String cityId,
    required String buildingType,
  }) async {
    final response = await supabaseClient.functions.invoke(
      'upgrade-building',
      body: {
        'city_id': cityId,
        'building_type': buildingType,
      },
    );

    if (response.status != 200) {
      final data = response.data;
      String errorMessage = 'Upgrade failed';
      if (data is Map<String, dynamic>) {
        errorMessage = (data['error'] as String?) ?? errorMessage;
      }
      throw BuildingUpgradeException(errorMessage);
    }

    return (response.data as Map<String, dynamic>?) ?? {};
  }

  /// Invokes the downgrade-building Edge Function to reduce a building level
  /// by 1 and refund 50% of the upgrade cost.
  ///
  /// On success (HTTP 200) returns the response data map (contains new_level
  /// and refund map).
  ///
  /// On non-200 status, parses the error JSON and throws a
  /// [BuildingUpgradeException] with the server's error message.
  Future<Map<String, dynamic>> downgradeBuilding({
    required String cityId,
    required String buildingType,
  }) async {
    final response = await supabaseClient.functions.invoke(
      'downgrade-building',
      body: {
        'city_id': cityId,
        'building_type': buildingType,
      },
    );

    if (response.status != 200) {
      final data = response.data;
      String errorMessage = 'Downgrade failed';
      if (data is Map<String, dynamic>) {
        errorMessage = (data['error'] as String?) ?? errorMessage;
      }
      throw BuildingUpgradeException(errorMessage);
    }

    return (response.data as Map<String, dynamic>?) ?? {};
  }
}

/// Riverpod provider for [BuildingsRepository].
final buildingsRepositoryProvider = Provider<BuildingsRepository>(
  (ref) => const BuildingsRepository(),
);
