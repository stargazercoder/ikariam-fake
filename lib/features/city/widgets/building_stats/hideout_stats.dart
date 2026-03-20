// Hideout stats widget for the building detail sheet.
// Shows resource protection floor using hideoutProtectionFloor().

import 'package:flutter/material.dart';

import '../../../../core/constants/building_constants.dart';

/// Stats panel for the Hideout building.
///
/// Displays the per-resource protection floor calculated by
/// [hideoutProtectionFloor]. This matches the SQL formula used in
/// resolve_battles() pillage logic.
class HideoutStats extends StatelessWidget {
  const HideoutStats({super.key, required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final protected = hideoutProtectionFloor(level);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        'Resource Protection: $protected per resource',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
