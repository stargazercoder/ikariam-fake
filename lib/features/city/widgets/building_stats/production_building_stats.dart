// Production building stats widget — hourly production breakdown.
// Shows base rate, building bonus, island bonus, research bonus, and total.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/building_constants.dart';
import '../../providers/production_rate_provider.dart';

/// Stats widget for production buildings (sawmill, quarry, glassblower, sulfurPit).
///
/// Displays a breakdown of hourly production including base rate, building
/// level bonus, island level bonus, and research bonus, matching the
/// calculation used by [productionBreakdownProvider].
class ProductionBuildingStats extends ConsumerWidget {
  const ProductionBuildingStats({
    super.key,
    required this.cityId,
    required this.buildingType,
  });

  final String cityId;
  final BuildingType buildingType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final resourceTypeName = _resourceTypeName(buildingType);
    final breakdown = ref.watch(
      productionBreakdownProvider((cityId, resourceTypeName)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BreakdownRow(
          label: 'Base Rate',
          value: '+${breakdown.baseRate.toStringAsFixed(1)}/hr',
          theme: theme,
        ),
        _BreakdownRow(
          label: 'Building Level Bonus',
          value: '+${breakdown.buildingBonus.toStringAsFixed(1)}/hr',
          theme: theme,
        ),
        _BreakdownRow(
          label: 'Island Level Bonus',
          value: '+${breakdown.islandBonus.toStringAsFixed(1)}/hr',
          theme: theme,
        ),
        _BreakdownRow(
          label: 'Research Bonus',
          value: '+${breakdown.researchBonus.toStringAsFixed(1)}/hr',
          theme: theme,
        ),
        const Divider(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '+${breakdown.total.toStringAsFixed(1)}/hr',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Maps a production [BuildingType] to the resource type name string used
  /// by [productionBreakdownProvider].
  String _resourceTypeName(BuildingType type) {
    switch (type) {
      case BuildingType.sawmill:
        return 'wood';
      case BuildingType.quarry:
        return 'marble';
      case BuildingType.glassblower:
        return 'crystal';
      case BuildingType.sulfurPit:
        return 'sulfur';
      default:
        throw ArgumentError('Not a production building: $type');
    }
  }
}

/// A label + value row used in the production breakdown.
class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
