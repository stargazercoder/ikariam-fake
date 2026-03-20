// Town Hall stats widget for the building detail sheet.
// Shows population, max population formula, and idle citizens.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/city_economy_provider.dart';

/// Stats panel for the Town Hall building.
///
/// Watches [cityEconomyStreamProvider] for live population data.
/// Max population uses the formula `200 + level * 50` as a client-side
/// approximation (no server formula exists yet).
class TownHallStats extends ConsumerWidget {
  const TownHallStats({
    super.key,
    required this.cityId,
    required this.level,
  });

  final String cityId;
  final int level;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final economyAsync = ref.watch(cityEconomyStreamProvider(cityId));

    final population = economyAsync.whenOrNull(
      data: (economy) => (economy?['population'] as num?)?.toInt(),
    );

    final maxPopulation = 200 + level * 50;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatRow(
          label: 'Population',
          value: population != null ? '$population' : '—',
          theme: theme,
        ),
        _StatRow(
          label: 'Max Population',
          value: '~$maxPopulation',
          theme: theme,
        ),
        _StatRow(
          label: 'Growth',
          value: 'Coming soon',
          theme: theme,
          valueColor: Colors.grey.shade500,
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.theme,
    this.valueColor,
  });

  final String label;
  final String value;
  final ThemeData theme;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade700,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
