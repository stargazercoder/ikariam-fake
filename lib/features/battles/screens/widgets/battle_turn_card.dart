// Widget for displaying a single battle turn's naval and land phase results.
// Read-only display — no mutations from this widget.

import 'package:flutter/material.dart';

import '../../../../core/constants/unit_constants.dart';
import '../../models/battle_turn.dart';

/// Card widget showing the result of a single battle turn.
///
/// Displays Naval phase (before land) then Land phase, each with
/// attacker and defender casualties. Follows CMBT-03: naval phase
/// is always shown before land phase.
///
/// If [navalOutcome] is 'skipped' or null the Naval section is hidden.
/// If [landOutcome] is 'blocked' a gate-keeper message is shown instead
/// of casualty rows.
class BattleTurnCard extends StatelessWidget {
  const BattleTurnCard({
    super.key,
    required this.turn,
    required this.isAttacker,
  });

  final BattleTurn turn;

  /// True when the viewing player is the attacker; false when defender.
  final bool isAttacker;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Turn header
            Row(
              children: [
                Icon(
                  Icons.history,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Turn ${turn.turnNumber}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(turn.resolvedAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withAlpha(160),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Naval Phase — shown only when navalOutcome is not null and not 'skipped'
            if (turn.navalOutcome != null && turn.navalOutcome != 'skipped') ...[
              _PhaseSection(
                label: 'Naval Phase',
                outcome: turn.navalOutcome!,
                yourCasualties: isAttacker
                    ? turn.navalAttackerCasualties
                    : turn.navalDefenderCasualties,
                enemyCasualties: isAttacker
                    ? turn.navalDefenderCasualties
                    : turn.navalAttackerCasualties,
              ),
              const SizedBox(height: 12),
            ],

            // Land Phase — shown only when landOutcome is not null
            if (turn.landOutcome != null) ...[
              if (turn.landOutcome == 'blocked')
                _BlockedLandPhase()
              else
                _PhaseSection(
                  label: 'Land Phase',
                  outcome: turn.landOutcome!,
                  yourCasualties: isAttacker
                      ? turn.landAttackerCasualties
                      : turn.landDefenderCasualties,
                  enemyCasualties: isAttacker
                      ? turn.landDefenderCasualties
                      : turn.landAttackerCasualties,
                ),
              const SizedBox(height: 12),
            ],

            // Survivors section
            _SurvivorsSection(
              yourSurvivors: isAttacker
                  ? turn.attackerSurvivors
                  : turn.defenderSurvivors,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// Phase section (Naval or Land)
// ---------------------------------------------------------------------------

class _PhaseSection extends StatelessWidget {
  const _PhaseSection({
    required this.label,
    required this.outcome,
    required this.yourCasualties,
    required this.enemyCasualties,
  });

  final String label;
  final String outcome;
  final Map<String, int>? yourCasualties;
  final Map<String, int>? enemyCasualties;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Phase label + outcome chip
        Row(
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            _OutcomeChip(outcome: outcome),
          ],
        ),
        const SizedBox(height: 6),

        // Your losses
        if (yourCasualties != null && yourCasualties!.isNotEmpty) ...[
          Text(
            'Your losses:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.error,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          _UnitList(units: yourCasualties!),
        ] else
          Text(
            'No losses',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.green.shade700,
            ),
          ),

        const SizedBox(height: 4),

        // Enemy losses
        if (enemyCasualties != null && enemyCasualties!.isNotEmpty) ...[
          Text(
            'Enemy losses:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.green.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          _UnitList(units: enemyCasualties!),
        ] else
          Text(
            'Enemy had no losses',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withAlpha(140),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Blocked land phase message
// ---------------------------------------------------------------------------

class _BlockedLandPhase extends StatelessWidget {
  const _BlockedLandPhase();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withAlpha(80),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.error.withAlpha(100),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.anchor,
            size: 16,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Land units blocked — naval gate-keeper',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Survivors section
// ---------------------------------------------------------------------------

class _SurvivorsSection extends StatelessWidget {
  const _SurvivorsSection({required this.yourSurvivors});

  final Map<String, int> yourSurvivors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Remaining:',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          if (yourSurvivors.isEmpty)
            Text(
              'No units remaining',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
            )
          else
            _UnitList(units: yourSurvivors),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared unit list row
// ---------------------------------------------------------------------------

class _UnitList extends StatelessWidget {
  const _UnitList({required this.units});

  final Map<String, int> units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: units.entries
          .where((e) => e.value > 0)
          .map((e) => Text(
                '${_displayName(e.key)}: ${e.value}',
                style: theme.textTheme.bodySmall,
              ))
          .toList(),
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
// Outcome chip
// ---------------------------------------------------------------------------

class _OutcomeChip extends StatelessWidget {
  const _OutcomeChip({required this.outcome});

  final String outcome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color color;
    String label;
    switch (outcome) {
      case 'attacker_won':
        color = Colors.red.shade700;
        label = 'Attacker Won';
        break;
      case 'defender_won':
        color = Colors.blue.shade700;
        label = 'Defender Won';
        break;
      case 'ongoing':
        color = Colors.orange.shade700;
        label = 'Ongoing';
        break;
      default:
        color = theme.colorScheme.onSurface.withAlpha(160);
        label = outcome;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
