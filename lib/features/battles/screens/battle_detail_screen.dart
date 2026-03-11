// Battle detail screen — shows header, army counts, and turn-by-turn cards.
// Read-only: no mutations from Flutter code (CMBT-05).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_state_provider.dart';
import '../../../features/city/widgets/countdown_timer_widget.dart';
import '../models/battle.dart';
import '../providers/battles_provider.dart';
import '../providers/battle_turns_provider.dart';
import 'widgets/battle_turn_card.dart';

/// Detail screen for a single battle.
///
/// Shows the battle status header, current army counts, a countdown timer
/// for active battles, and a reverse-chronological list of [BattleTurnCard]
/// widgets (newest turn first).
///
/// Real-time updates arrive via Supabase Realtime subscriptions in
/// [battleTurnsProvider] and [attackerBattlesProvider]/[defenderBattlesProvider].
class BattleDetailScreen extends ConsumerWidget {
  const BattleDetailScreen({super.key, required this.battleId});

  final String battleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final allBattles = ref.watch(allMyBattlesProvider);
    final turnsAsync = ref.watch(battleTurnsProvider(battleId));

    // Find the battle from the merged provider list.
    final Battle? battle = allBattles.cast<Battle?>().firstWhere(
          (b) => b?.id == battleId,
          orElse: () => null,
        );

    final isAttacker = battle?.attackerId == (user?.id ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Battle Report'),
      ),
      body: battle == null
          ? const _LoadingOrNotFound()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Status header card
                      _BattleStatusHeader(
                        battle: battle,
                        isAttacker: isAttacker,
                      ),
                      const SizedBox(height: 12),

                      // Countdown for active battles
                      if (battle.isActive) ...[
                        _CountdownCard(nextTurnAt: battle.nextTurnAt),
                        const SizedBox(height: 12),
                      ],

                      // Army counts
                      _ArmyCounts(
                        battle: battle,
                        isAttacker: isAttacker,
                      ),
                      const SizedBox(height: 16),

                      // Turn cards header
                      Text(
                        'Battle Turns',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 8),

                      // Turn cards
                      turnsAsync.when(
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (e, st) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Failed to load turns: $e',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ),
                        data: (turns) {
                          if (turns.isEmpty) {
                            return const _NoTurnsYet();
                          }
                          // Reverse order: newest turn first.
                          final reversed = turns.reversed.toList();
                          return Column(
                            children: reversed
                                .map((t) => BattleTurnCard(
                                      turn: t,
                                      isAttacker: isAttacker,
                                    ))
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading / not found placeholder
// ---------------------------------------------------------------------------

class _LoadingOrNotFound extends StatelessWidget {
  const _LoadingOrNotFound();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

// ---------------------------------------------------------------------------
// Battle status header
// ---------------------------------------------------------------------------

class _BattleStatusHeader extends StatelessWidget {
  const _BattleStatusHeader({
    required this.battle,
    required this.isAttacker,
  });

  final Battle battle;
  final bool isAttacker;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final statusLabel = _statusLabel(battle.status);
    final statusColor = _statusColor(battle.status, colorScheme);
    final roleLabel = isAttacker ? 'Attacker' : 'Defender';
    final roleColor = isAttacker ? colorScheme.error : colorScheme.primary;

    return Card(
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Battle Report',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _StatusChip(label: statusLabel, color: statusColor),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Your role: ',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  roleLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: roleColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Turn: ',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  '${battle.turnNumber}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Active';
      case 'attacker_won':
        return 'Attacker Won';
      case 'defender_won':
        return 'Defender Won';
      default:
        return status;
    }
  }

  Color _statusColor(String status, ColorScheme cs) {
    switch (status) {
      case 'active':
        return Colors.orange.shade700;
      case 'attacker_won':
        return cs.error;
      case 'defender_won':
        return Colors.blue.shade700;
      default:
        return cs.onSurface;
    }
  }
}

// ---------------------------------------------------------------------------
// Countdown card for active battles
// ---------------------------------------------------------------------------

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({required this.nextTurnAt});

  final DateTime nextTurnAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timer_outlined,
              size: 18,
              color: colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Text(
              'Next turn in: ',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            CountdownTimerWidget(
              finishAt: nextTurnAt,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontFeatures: [const FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Army count comparison
// ---------------------------------------------------------------------------

class _ArmyCounts extends StatelessWidget {
  const _ArmyCounts({
    required this.battle,
    required this.isAttacker,
  });

  final Battle battle;
  final bool isAttacker;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final yourUnits =
        isAttacker ? battle.attackerUnits : battle.defenderUnits;
    final enemyUnits =
        isAttacker ? battle.defenderUnits : battle.attackerUnits;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _ArmyColumn(
            label: 'Your Army',
            units: yourUnits,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ArmyColumn(
            label: 'Enemy Army',
            units: enemyUnits,
            color: theme.colorScheme.error,
          ),
        ),
      ],
    );
  }
}

class _ArmyColumn extends StatelessWidget {
  const _ArmyColumn({
    required this.label,
    required this.units,
    required this.color,
  });

  final String label;
  final Map<String, int> units;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            if (units.isEmpty)
              Text(
                'No units',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(140),
                ),
              )
            else
              ...units.entries
                  .where((e) => e.value > 0)
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _displayName(e.key),
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${e.value}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  String _displayName(String dbName) {
    try {
      return unitTypeFromDbName(dbName).displayName;
    } catch (_) {
      return dbName;
    }
  }
}

// ---------------------------------------------------------------------------
// No turns yet placeholder
// ---------------------------------------------------------------------------

class _NoTurnsYet extends StatelessWidget {
  const _NoTurnsYet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          'No turns resolved yet.\nCheck back after the next turn.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(140),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status chip
// ---------------------------------------------------------------------------

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
