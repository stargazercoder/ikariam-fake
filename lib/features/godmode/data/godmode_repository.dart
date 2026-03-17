import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/godmode_event.dart';
import '../models/godmode_player.dart';

/// Repository that wraps all GodMode SECURITY DEFINER RPC calls.
///
/// All methods follow the DevRpcService try/catch/debugPrint/rethrow pattern.
/// The caller (provider or widget) is responsible for error handling beyond logging.
///
/// Six RPCs exposed:
///   1. getWorldState  — godmode_get_world_state()
///   2. setBotPaused   — godmode_set_bot_paused(bot_id, paused)
///   3. forceAction    — godmode_force_action(bot_id) → action label
///   4. setResources   — admin_set_resources(player_id, ...)
///   5. setArmy        — admin_set_army(player_id, ...)
///   6. getEvents      — godmode_get_events(limit, event_type)
class GodmodeRepository {
  GodmodeRepository(this._client);

  final SupabaseClient _client;

  /// Fetches the full world state: all players with resources, army counts,
  /// buildings, bot status, and active battle lists.
  ///
  /// Calls: godmode_get_world_state()
  Future<List<GodmodePlayer>> getWorldState() async {
    try {
      final result = await _client.rpc('godmode_get_world_state');
      final map = result as Map<String, dynamic>;
      final players = map['players'] as List<dynamic>;
      return players
          .map((p) => GodmodePlayer.fromJson(p as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[GodmodeRepository] getWorldState error: $e');
      rethrow;
    }
  }

  /// Pauses or unpauses a bot's scheduled decision cycle.
  ///
  /// Calls: godmode_set_bot_paused(p_bot_id, p_paused)
  Future<void> setBotPaused(String botId, bool paused) async {
    try {
      await _client.rpc('godmode_set_bot_paused', params: {
        'p_bot_id': botId,
        'p_paused': paused,
      });
    } catch (e) {
      debugPrint('[GodmodeRepository] setBotPaused error: $e');
      rethrow;
    }
  }

  /// Runs one bot decision cycle immediately (out-of-band; does not update
  /// next_action_at). Returns the action label: 'upgrade', 'train', 'attack',
  /// or 'none'.
  ///
  /// Calls: godmode_force_action(p_bot_id)
  Future<String> forceAction(String botId) async {
    try {
      final result = await _client.rpc('godmode_force_action', params: {
        'p_bot_id': botId,
      });
      return result as String;
    } catch (e) {
      debugPrint('[GodmodeRepository] forceAction error: $e');
      rethrow;
    }
  }

  /// Sets resource balances for a player's city (clamped to 0 minimum).
  ///
  /// Calls: admin_set_resources(p_player_id, p_wood, p_marble, p_crystal,
  ///                            p_sulfur, p_gold)
  Future<void> setResources(
    String playerId, {
    required double wood,
    required double marble,
    required double crystal,
    required double sulfur,
    required double gold,
  }) async {
    try {
      await _client.rpc('admin_set_resources', params: {
        'p_player_id': playerId,
        'p_wood': wood,
        'p_marble': marble,
        'p_crystal': crystal,
        'p_sulfur': sulfur,
        'p_gold': gold,
      });
    } catch (e) {
      debugPrint('[GodmodeRepository] setResources error: $e');
      rethrow;
    }
  }

  /// Sets army unit quantities for a player's city.
  /// [units] is a map of `unit_type -> quantity` (e.g. `{'hoplite': 100}`).
  /// Only provided unit types are updated; others are left unchanged.
  ///
  /// Calls: `admin_set_army(p_player_id, p_{unit_type}...)`
  Future<void> setArmy(String playerId, Map<String, int> units) async {
    try {
      await _client.rpc('admin_set_army', params: {
        'p_player_id': playerId,
        ...units.map((k, v) => MapEntry('p_$k', v)),
      });
    } catch (e) {
      debugPrint('[GodmodeRepository] setArmy error: $e');
      rethrow;
    }
  }

  /// Fetches recent events (battles, trades, espionage), ordered newest first.
  /// Pass [eventType] to filter to a single type ('battle', 'trade', 'espionage').
  ///
  /// Calls: godmode_get_events(p_limit, p_event_type)
  Future<List<GodmodeEvent>> getEvents({
    int limit = 50,
    String? eventType,
  }) async {
    try {
      final params = <String, dynamic>{'p_limit': limit};
      if (eventType != null) params['p_event_type'] = eventType;
      final result = await _client.rpc('godmode_get_events', params: params);
      final list = result as List<dynamic>;
      return list
          .map((e) => GodmodeEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[GodmodeRepository] getEvents error: $e');
      rethrow;
    }
  }
}

/// Provider for [GodmodeRepository].
/// Uses Supabase.instance.client — safe to call after Supabase.initialize().
final godmodeRepositoryProvider = Provider<GodmodeRepository>(
  (ref) => GodmodeRepository(Supabase.instance.client),
);
