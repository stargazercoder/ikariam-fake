// Riverpod StreamProvider for real-time battle turn streams.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/battle_repository.dart';
import '../models/battle_turn.dart';

/// StreamProvider.family that emits live [BattleTurn] snapshots for [battleId].
///
/// Uses [BattleRepository.watchBattleTurns] which subscribes to the
/// battle_turns Realtime publication filtered by battle_id. Results arrive
/// ordered by turn_number ascending for chronological turn-card display.
///
/// autoDispose releases the Realtime subscription when the detail screen is
/// popped or no widget watches the provider.
final battleTurnsProvider =
    StreamProvider.autoDispose.family<List<BattleTurn>, String>(
  (ref, battleId) =>
      ref.read(battleRepositoryProvider).watchBattleTurns(battleId),
);
