// Shared header widget for the building detail bottom sheet.
// Shows building icon (in canonical color), name, level subtitle, and close button.

import 'package:flutter/material.dart';

import '../../../core/constants/visual_constants.dart';
import '../models/city_building.dart';

/// Header row displayed at the top of every building detail sheet.
///
/// Layout:
///   [Icon] | [Name (bold) / Level X (grey)] | [×]
/// Followed by a [Divider].
class BuildingSheetHeader extends StatelessWidget {
  const BuildingSheetHeader({
    super.key,
    required this.building,
    required this.onClose,
  });

  final CityBuilding building;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = buildingTypeColor[building.buildingType]
        ?? theme.colorScheme.primary;
    final icon = buildingTypeIcon[building.buildingType] ?? Icons.home;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    building.buildingType.displayName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Level ${building.level}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onClose,
              tooltip: 'Close',
            ),
          ],
        ),
        const Divider(height: 24),
      ],
    );
  }
}
