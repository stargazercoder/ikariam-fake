// Card widget showing per-resource pillage breakdown after a battle.
// Displays resources gained (attacker) or lost (defender).

import 'package:flutter/material.dart';

import '../../../../core/constants/building_constants.dart';
import '../../../../shared/widgets/resource_badge.dart';

/// Shows a breakdown of pillaged resources for a completed battle.
///
/// Renders nothing when [pillageResult] is null or empty.
/// Attacker sees "Resources gained:" in green; defender sees "Resources lost:" in red.
class PillageResultCard extends StatelessWidget {
  const PillageResultCard({
    super.key,
    required this.pillageResult,
    required this.isAttacker,
  });

  final Map<String, int>? pillageResult;

  /// True when the viewing player is the attacker.
  final bool isAttacker;

  @override
  Widget build(BuildContext context) {
    if (pillageResult == null || pillageResult!.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final valueColor = isAttacker ? Colors.green.shade700 : colorScheme.error;
    final headingText =
        isAttacker ? 'Resources gained:' : 'Resources lost:';

    // Only show resources with non-zero amounts
    final entries = pillageResult!.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => _resourceOrder(a.key) - _resourceOrder(b.key));

    if (entries.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card title
            Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pillage',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Text(
              headingText,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
            const SizedBox(height: 6),

            // Resource rows
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: entries
                  .map((e) => _ResourceRow(
                        resourceKey: e.key,
                        amount: e.value,
                        valueColor: valueColor,
                        theme: theme,
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns a sort order for canonical resource display order.
  static int _resourceOrder(String key) {
    const order = ['wood', 'marble', 'crystal', 'sulfur'];
    final idx = order.indexOf(key);
    return idx == -1 ? 99 : idx;
  }
}

// ---------------------------------------------------------------------------
// Single resource row
// ---------------------------------------------------------------------------

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({
    required this.resourceKey,
    required this.amount,
    required this.valueColor,
    required this.theme,
  });

  final String resourceKey;
  final int amount;
  final Color valueColor;
  final ThemeData theme;

  /// Returns a ResourceBadge for the given DB name string.
  /// Falls back to a help icon if the key is unrecognised.
  Widget _resourceBadge(String key) {
    try {
      final type = resourceTypeFromDbName(key);
      return ResourceBadge(type: type, radius: 10);
    } catch (_) {
      return const Icon(Icons.help_outline, size: 16);
    }
  }

  String _displayName(String key) {
    switch (key) {
      case 'wood':
        return 'Wood';
      case 'marble':
        return 'Marble';
      case 'crystal':
        return 'Crystal';
      case 'sulfur':
        return 'Sulfur';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _resourceBadge(resourceKey),
        const SizedBox(width: 4),
        Text(
          _displayName(resourceKey),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(width: 4),
        Text(
          '$amount',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
