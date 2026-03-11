// Repository for battle data access via Supabase Realtime streams.
// Read-only: all battle mutations go through SECURITY DEFINER server functions.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../models/battle.dart';
import '../models/battle_turn.dart';

/// Repository for real-time battle data streams.
///
/// Uses Supabase Realtime .stream() for live updates on battles and battle_turns.
/// Two separate stream methods are required because Supabase Realtime .stream()
/// does not support OR filters — attacker and defender battles must be streamed
/// separately and merged client-side (established decision from Phase 4).
class BattleRepository {
  const BattleRepository();

  /// Stream battles where [userId] is the attacker.
  ///
  /// Emits a new snapshot whenever any battle row owned by this user as attacker
  /// changes (e.g., when resolve_battles() updates attacker_units or status).
  Stream<List<Battle>> watchBattlesAsAttacker(String userId) {
    return supabaseClient
        .from('battles')
        .stream(primaryKey: ['id'])
        .eq('attacker_id', userId)
        .map((rows) => rows.map(Battle.fromJson).toList());
  }

  /// Stream battles where [userId] is the defender.
  ///
  /// Emits a new snapshot whenever any battle row owned by this user as defender
  /// changes (e.g., when resolve_battles() updates defender_units or status).
  Stream<List<Battle>> watchBattlesAsDefender(String userId) {
    return supabaseClient
        .from('battles')
        .stream(primaryKey: ['id'])
        .eq('defender_id', userId)
        .map((rows) => rows.map(Battle.fromJson).toList());
  }

  /// Stream turn-by-turn results for a specific battle.
  ///
  /// Emits a new snapshot each time resolve_battles() inserts a new battle_turns row.
  /// Results are ordered by turn_number ascending for chronological display.
  Stream<List<BattleTurn>> watchBattleTurns(String battleId) {
    return supabaseClient
        .from('battle_turns')
        .stream(primaryKey: ['id'])
        .eq('battle_id', battleId)
        .order('turn_number')
        .map((rows) => rows.map(BattleTurn.fromJson).toList());
  }
}

/// Riverpod provider for [BattleRepository].
final battleRepositoryProvider = Provider<BattleRepository>(
  (ref) => const BattleRepository(),
);
