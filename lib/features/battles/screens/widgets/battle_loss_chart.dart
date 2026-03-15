// Stacked bar chart showing turn-by-turn unit losses for a battle.
// Renders two sections: Naval Losses and Land Losses.
// Each section displays attacker and defender losses as side-by-side stacked bar rods.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/unit_constants.dart';
import '../../models/battle_turn.dart';

/// Displays turn-by-turn unit losses as stacked bar charts.
///
/// Shows two sections (Naval and Land) each with a BarChart where every
/// bar group contains two rods: left = attacker losses, right = defender losses.
/// Each rod is stacked by unit type using [unitTypeColors] for consistent colors.
///
/// If a phase has zero total casualties, a placeholder text is shown instead.
class BattleLossChart extends StatelessWidget {
  const BattleLossChart({
    super.key,
    required this.turns,
  });

  final List<BattleTurn> turns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PhaseChart(
          label: 'Naval Losses',
          turns: turns,
          orderedTypes: orderedNavalTypes,
          getAttackerCasualties: (t) => t.navalAttackerCasualties,
          getDefenderCasualties: (t) => t.navalDefenderCasualties,
          theme: theme,
        ),
        const SizedBox(height: 24),
        _PhaseChart(
          label: 'Land Losses',
          turns: turns,
          orderedTypes: orderedLandTypes,
          getAttackerCasualties: (t) => t.landAttackerCasualties,
          getDefenderCasualties: (t) => t.landDefenderCasualties,
          theme: theme,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Single phase chart (naval or land)
// ---------------------------------------------------------------------------

class _PhaseChart extends StatelessWidget {
  const _PhaseChart({
    required this.label,
    required this.turns,
    required this.orderedTypes,
    required this.getAttackerCasualties,
    required this.getDefenderCasualties,
    required this.theme,
  });

  final String label;
  final List<BattleTurn> turns;
  final List<UnitType> orderedTypes;
  final Map<String, int>? Function(BattleTurn) getAttackerCasualties;
  final Map<String, int>? Function(BattleTurn) getDefenderCasualties;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    // Filter turns where at least one side has casualties for this phase.
    final activeTurns = turns.where((t) {
      final atk = getAttackerCasualties(t);
      final def = getDefenderCasualties(t);
      final atkTotal = atk?.values.fold(0, (s, v) => s + v) ?? 0;
      final defTotal = def?.values.fold(0, (s, v) => s + v) ?? 0;
      return atkTotal > 0 || defTotal > 0;
    }).toList();

    final hasLosses = activeTurns.isNotEmpty;

    // Collect unit types that appear in any turn's casualties for the legend.
    final participatingTypes = <UnitType>{};
    for (final t in turns) {
      final atk = getAttackerCasualties(t);
      final def = getDefenderCasualties(t);
      for (final ut in orderedTypes) {
        if ((atk?[ut.dbName] ?? 0) > 0 || (def?[ut.dbName] ?? 0) > 0) {
          participatingTypes.add(ut);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section header
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withAlpha(200),
          ),
        ),
        const SizedBox(height: 8),

        if (!hasLosses)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No ${label.toLowerCase()}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(120),
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else ...[
          // Legend row (attacker / defender)
          Row(
            children: [
              _LegendDot(
                color: theme.colorScheme.error,
                label: 'Attacker',
              ),
              const SizedBox(width: 12),
              _LegendDot(
                color: theme.colorScheme.primary,
                label: 'Defender',
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Chart
          SizedBox(
            height: 180,
            child: BarChart(
              _buildChartData(activeTurns, participatingTypes, theme),
              duration: const Duration(milliseconds: 300),
            ),
          ),

          // Unit type color legend
          if (participatingTypes.isNotEmpty) ...[
            const SizedBox(height: 8),
            _UnitTypeLegend(
              unitTypes: orderedTypes
                  .where((ut) => participatingTypes.contains(ut))
                  .toList(),
            ),
          ],
        ],
      ],
    );
  }

  BarChartData _buildChartData(
    List<BattleTurn> activeTurns,
    Set<UnitType> participatingTypes,
    ThemeData theme,
  ) {
    double maxY = 0;
    final barGroups = <BarChartGroupData>[];

    for (int i = 0; i < activeTurns.length; i++) {
      final turn = activeTurns[i];
      final atkCas = getAttackerCasualties(turn) ?? {};
      final defCas = getDefenderCasualties(turn) ?? {};

      // Build attacker rod (left)
      final atkRod = _buildRod(
        casualties: atkCas,
        orderedTypes: orderedTypes,
        rodX: 0,
        theme: theme,
        isAttacker: true,
      );

      // Build defender rod (right)
      final defRod = _buildRod(
        casualties: defCas,
        orderedTypes: orderedTypes,
        rodX: 1,
        theme: theme,
        isAttacker: false,
      );

      final atkTotal = atkCas.values.fold(0, (s, v) => s + v).toDouble();
      final defTotal = defCas.values.fold(0, (s, v) => s + v).toDouble();
      if (atkTotal > maxY) maxY = atkTotal;
      if (defTotal > maxY) maxY = defTotal;

      barGroups.add(
        BarChartGroupData(
          x: i,
          groupVertically: false,
          barRods: [atkRod, defRod],
          barsSpace: 4,
          showingTooltipIndicators: [],
        ),
      );
    }

    // Ensure a reasonable maxY so chart never has 0 height
    final chartMaxY = maxY <= 0 ? 10.0 : (maxY * 1.2).ceilToDouble();

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: chartMaxY,
      barGroups: barGroups,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            getTitlesWidget: (value, meta) {
              final idx = value.toInt();
              if (idx < 0 || idx >= activeTurns.length) {
                return const SizedBox.shrink();
              }
              final turnNum = activeTurns[idx].turnNumber;
              return Text(
                'T$turnNum',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withAlpha(160),
                ),
              );
            },
          ),
        ),
      ),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final turn = activeTurns[group.x];
            final casualties = rodIndex == 0
                ? getAttackerCasualties(turn) ?? {}
                : getDefenderCasualties(turn) ?? {};
            final side = rodIndex == 0 ? 'Attacker' : 'Defender';
            final lines = orderedTypes
                .where((ut) => (casualties[ut.dbName] ?? 0) > 0)
                .map((ut) => '${ut.displayName}: ${casualties[ut.dbName]}')
                .join('\n');
            if (lines.isEmpty) return null;
            return BarTooltipItem(
              '$side\n$lines',
              const TextStyle(fontSize: 11),
            );
          },
        ),
      ),
    );
  }

  BarChartRodData _buildRod({
    required Map<String, int> casualties,
    required List<UnitType> orderedTypes,
    required int rodX,
    required ThemeData theme,
    required bool isAttacker,
  }) {
    double runningY = 0;
    final stackItems = <BarChartRodStackItem>[];

    for (final ut in orderedTypes) {
      final count = (casualties[ut.dbName] ?? 0).toDouble();
      if (count > 0) {
        final color = unitTypeColors[ut] ?? Colors.grey;
        stackItems.add(
          BarChartRodStackItem(runningY, runningY + count, color),
        );
        runningY += count;
      }
    }

    // If no casualties, show a tiny invisible rod so the group renders
    if (stackItems.isEmpty) {
      stackItems.add(BarChartRodStackItem(0, 0, Colors.transparent));
    }

    return BarChartRodData(
      toY: runningY,
      rodStackItems: stackItems,
      width: 14,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
    );
  }
}

// ---------------------------------------------------------------------------
// Legend widgets
// ---------------------------------------------------------------------------

/// Small colored dot with a label (used for attacker/defender legend).
class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
        ),
      ],
    );
  }
}

/// Colored square + unit type name legend for participating unit types.
class _UnitTypeLegend extends StatelessWidget {
  const _UnitTypeLegend({required this.unitTypes});

  final List<UnitType> unitTypes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: unitTypes.map((ut) {
        final color = unitTypeColors[ut] ?? Colors.grey;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              ut.displayName,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
            ),
          ],
        );
      }).toList(),
    );
  }
}
