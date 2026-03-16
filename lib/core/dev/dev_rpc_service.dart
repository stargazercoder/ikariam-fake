import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service that calls SECURITY DEFINER dev RPC functions on the Supabase backend.
///
/// These functions bypass RLS and are only available in development seeds
/// (migration 20260312000008_dev_rpc_helpers.sql). Each call wraps the
/// Supabase RPC invocation in try/catch so toolbar buttons never crash the app
/// on error.
///
/// DEV ONLY — not imported from any production code path.
class DevRpcService {
  DevRpcService({SupabaseClient? client}) : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  /// Returns the Supabase client, accessed lazily so that tests that
  /// never invoke RPC actions do not trigger Supabase initialization.
  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  /// Injects [amount] of each resource type into [cityId].
  ///
  /// Calls: dev_inject_resources(p_city_id, p_wood, p_marble, p_crystal,
  ///                              p_sulfur, p_gold)
  Future<void> injectResources(String cityId, {int amount = 5000}) async {
    try {
      await _client.rpc('dev_inject_resources', params: {
        'p_city_id': cityId,
        'p_wood': amount,
        'p_marble': amount,
        'p_crystal': amount,
        'p_sulfur': amount,
        'p_gold': amount,
      });
    } catch (e) {
      debugPrint('[DevRpcService] injectResources error: $e');
      rethrow;
    }
  }

  /// Levels up [buildingType] in [cityId] to the next level.
  ///
  /// Calls: dev_level_up_building(p_city_id, p_building_type, p_target_level)
  /// Target level is determined by the DB function (current level + 1).
  Future<void> levelUpBuilding(
    String cityId,
    String buildingType, {
    int targetLevel = 2,
  }) async {
    try {
      await _client.rpc('dev_level_up_building', params: {
        'p_city_id': cityId,
        'p_building_type': buildingType,
        'p_target_level': targetLevel,
      });
    } catch (e) {
      debugPrint('[DevRpcService] levelUpBuilding error: $e');
      rethrow;
    }
  }

  /// Spawns [quantity] units of [unitType] in [cityId].
  ///
  /// Calls: dev_spawn_units(p_city_id, p_unit_type, p_quantity)
  Future<void> spawnUnits(
    String cityId,
    String unitType, {
    int quantity = 50,
  }) async {
    try {
      await _client.rpc('dev_spawn_units', params: {
        'p_city_id': cityId,
        'p_unit_type': unitType,
        'p_quantity': quantity,
      });
    } catch (e) {
      debugPrint('[DevRpcService] spawnUnits error: $e');
      rethrow;
    }
  }

  /// Triggers an immediate battle between [attackerCityId] and [defenderCityId].
  ///
  /// Calls: dev_trigger_battle(p_attacker_city_id, p_defender_city_id)
  /// Returns the new battle UUID, or null on error.
  Future<String?> triggerBattle(
    String attackerCityId,
    String defenderCityId,
  ) async {
    try {
      final result = await _client.rpc('dev_trigger_battle', params: {
        'p_attacker_city_id': attackerCityId,
        'p_defender_city_id': defenderCityId,
      });
      return result?.toString();
    } catch (e) {
      debugPrint('[DevRpcService] triggerBattle error: $e');
      rethrow;
    }
  }

  /// Spawns multiple unit types at once in [cityId].
  ///
  /// [units] is a map of unit_type -> quantity (e.g. {'hoplite': 100, 'archer': 50}).
  /// Calls: dev_bulk_spawn_units(p_city_id, p_units)
  Future<void> bulkSpawnUnits(String cityId, Map<String, int> units) async {
    try {
      await _client.rpc('dev_bulk_spawn_units', params: {
        'p_city_id': cityId,
        'p_units': units,
      });
    } catch (e) {
      debugPrint('[DevRpcService] bulkSpawnUnits error: $e');
      rethrow;
    }
  }

  /// Instantly completes all training queue and construction queue entries for [cityId].
  ///
  /// Calls: dev_instant_complete(p_city_id)
  Future<void> instantComplete(String cityId) async {
    try {
      await _client.rpc('dev_instant_complete', params: {
        'p_city_id': cityId,
      });
    } catch (e) {
      debugPrint('[DevRpcService] instantComplete error: $e');
      rethrow;
    }
  }
}
