// Riverpod providers for real-time battle streams.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_state_provider.dart';
import '../data/battle_repository.dart';
import '../models/battle.dart';

/// StreamProvider.family that emits live [Battle] snapshots where [userId]
/// is the attacker.
///
/// Uses [BattleRepository.watchBattlesAsAttacker] which subscribes to the
/// battles Realtime publication filtered by attacker_id.
///
/// autoDispose releases the Realtime subscription when no widget watches it.
final attackerBattlesProvider =
    StreamProvider.autoDispose.family<List<Battle>, String>(
  (ref, userId) =>
      ref.read(battleRepositoryProvider).watchBattlesAsAttacker(userId),
);

/// StreamProvider.family that emits live [Battle] snapshots where [userId]
/// is the defender.
///
/// Uses [BattleRepository.watchBattlesAsDefender] which subscribes to the
/// battles Realtime publication filtered by defender_id.
///
/// autoDispose releases the Realtime subscription when no widget watches it.
final defenderBattlesProvider =
    StreamProvider.autoDispose.family<List<Battle>, String>(
  (ref, userId) =>
      ref.read(battleRepositoryProvider).watchBattlesAsDefender(userId),
);

/// Provider.autoDispose that merges [attackerBattlesProvider] and
/// [defenderBattlesProvider] for the current authenticated user.
///
/// Returns the combined list deduplicated by battle ID, sorted by createdAt
/// descending (newest battle first). Returns an empty list when the user is
/// not authenticated or either stream is loading/errored.
///
/// Two separate streams are required because Supabase Realtime .stream() does
/// not support OR filters (established decision from Phase 4).
final allMyBattlesProvider = Provider.autoDispose<List<Battle>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final attackerAsync = ref.watch(attackerBattlesProvider(user.id));
  final defenderAsync = ref.watch(defenderBattlesProvider(user.id));

  final attackerBattles = attackerAsync.asData?.value ?? [];
  final defenderBattles = defenderAsync.asData?.value ?? [];

  // Deduplicate by ID in case a battle somehow appears in both streams.
  final seen = <String>{};
  final merged = <Battle>[];

  for (final battle in [...attackerBattles, ...defenderBattles]) {
    if (seen.add(battle.id)) {
      merged.add(battle);
    }
  }

  // Sort newest first.
  merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return merged;
});
