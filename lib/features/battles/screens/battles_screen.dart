// Battles tab screen — lists all active and completed battles for the current user.
// Read-only: no mutations from Flutter code (CMBT-05).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/providers/auth_state_provider.dart';
import '../../../features/city/widgets/countdown_timer_widget.dart';
import '../models/battle.dart';
import '../providers/battles_provider.dart';

/// Screen displaying all battles (active and completed) for the current user.
///
/// Active battles appear first with a countdown to the next turn resolution.
/// Completed battles are listed below with their final result.
/// Tapping any battle navigates to [BattleDetailScreen] at /battle-detail.
class BattlesScreen extends ConsumerWidget {
  const BattlesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final battles = ref.watch(allMyBattlesProvider);
    final user = ref.watch(currentUserProvider);

    final activeBattles = battles.where((b) => b.isActive).toList();
    final pastBattles = battles.where((b) => !b.isActive).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Battles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility),
            tooltip: 'Spy Log',
            onPressed: () => context.push('/spy-log'),
          ),
        ],
      ),
      body: battles.isEmpty
          ? const _EmptyBattles()
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (activeBattles.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'Active Battles',
                    count: activeBattles.length,
                  ),
                  ...activeBattles.map(
                    (b) => _BattleTile(
                      battle: b,
                      isAttacker: b.attackerId == (user?.id ?? ''),
                    ),
                  ),
                ],
                if (pastBattles.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'Past Battles',
                    count: pastBattles.length,
                  ),
                  ...pastBattles.map(
                    (b) => _BattleTile(
                      battle: b,
                      isAttacker: b.attackerId == (user?.id ?? ''),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyBattles extends StatelessWidget {
  const _EmptyBattles();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withAlpha(80),
          ),
          const SizedBox(height: 16),
          Text(
            'No battles yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(140),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Dispatch units to an enemy city to start a battle',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(100),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        '$label ($count)',
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Battle list tile
// ---------------------------------------------------------------------------

class _BattleTile extends StatelessWidget {
  const _BattleTile({
    required this.battle,
    required this.isAttacker,
  });

  final Battle battle;
  final bool isAttacker;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final roleIcon = isAttacker
        ? Icons.gps_fixed_outlined
        : Icons.shield_outlined;

    final statusText = _statusLabel(battle.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(
          roleIcon,
          color: isAttacker
              ? theme.colorScheme.error
              : theme.colorScheme.primary,
        ),
        title: Text(
          isAttacker
              ? 'Attack on city ${_shortId(battle.defenderCityId)}'
              : 'Defense of city ${_shortId(battle.defenderCityId)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: battle.isActive
            ? Row(
                children: [
                  Text(
                    'Turn ${battle.turnNumber}  •  Next: ',
                    style: theme.textTheme.bodySmall,
                  ),
                  CountdownTimerWidget(
                    finishAt: battle.nextTurnAt,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              )
            : Text(
                statusText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _statusColor(battle.status, theme.colorScheme),
                ),
              ),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurface.withAlpha(120),
        ),
        onTap: () => context.push('/battle-detail?battleId=${battle.id}'),
      ),
    );
  }

  String _shortId(String cityId) {
    return cityId.length > 8 ? cityId.substring(0, 8) : cityId;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'attacker_won':
        return 'Attacker Won';
      case 'defender_won':
        return 'Defender Won';
      case 'active':
        return 'Active';
      default:
        return status;
    }
  }

  Color _statusColor(String status, ColorScheme cs) {
    switch (status) {
      case 'attacker_won':
        return cs.error;
      case 'defender_won':
        return Colors.blue.shade700;
      default:
        return cs.onSurface.withAlpha(160);
    }
  }
}
