// Warehouse stats widget — per-resource fill bars with capacity indicators.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/resource_constants.dart';
import '../../../../core/constants/visual_constants.dart';
import '../../../../shared/widgets/resource_badge.dart';
import '../../providers/resources_provider.dart';

/// Warehouse building stats — shows per-resource fill bars with current
/// amount vs capacity for the 4 storable resources (wood, marble, crystal, sulfur).
class WarehouseStats extends ConsumerWidget {
  const WarehouseStats({
    super.key,
    required this.cityId,
    required this.level,
  });

  final String cityId;
  final int level;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final resourcesAsync = ref.watch(resourcesStreamProvider(cityId));

    // Capacity formula: floor(500 * 1.5^level) — matches warehouseCapacity().
    final capacity = warehouseCapacity(level).floor();

    // The 4 storable resources (wine and gold are excluded).
    const storableResources = [
      ResourceType.wood,
      ResourceType.marble,
      ResourceType.crystal,
      ResourceType.sulfur,
    ];

    return resourcesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(
        'Failed to load resources: $e',
        style: TextStyle(color: theme.colorScheme.error),
      ),
      data: (resources) {
        final amounts = {
          for (final r in resources) r.resourceType: r.amount,
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Storage Capacity: $capacity per resource',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
            ...storableResources.map((type) {
              final amount = amounts[type] ?? 0.0;
              final fillRatio = (amount / capacity).clamp(0.0, 1.0);
              final color = resourceTypeColor[type] ?? theme.colorScheme.primary;
              final resourceName = _resourceName(type);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ResourceBadge(type: type, radius: 10),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            resourceName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '${amount.toInt()} / $capacity',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: fillRatio,
                      color: color,
                      backgroundColor: color.withAlpha(40),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  String _resourceName(ResourceType type) {
    switch (type) {
      case ResourceType.wood:
        return 'Wood';
      case ResourceType.marble:
        return 'Marble';
      case ResourceType.crystal:
        return 'Crystal';
      case ResourceType.sulfur:
        return 'Sulfur';
      default:
        return type.name;
    }
  }
}
