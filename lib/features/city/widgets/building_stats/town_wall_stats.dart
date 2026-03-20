// Town Wall stats widget for the building detail sheet.
// Shows defensive bonus based on building level.

import 'package:flutter/material.dart';

/// Stats panel for the Town Wall building.
///
/// Formula: Defense Bonus = level * 10%
class TownWallStats extends StatelessWidget {
  const TownWallStats({super.key, required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        'Defense Bonus: +${level * 10}%',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
