// Trading Port stats widget for the building detail sheet.
// Shows trade capacity based on building level.

import 'package:flutter/material.dart';

/// Stats panel for the Trading Port building.
///
/// Formula: Trade Capacity = 100 + level * 50 units (client-side approximation).
class TradingPortStats extends StatelessWidget {
  const TradingPortStats({super.key, required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        'Trade Capacity: ${100 + level * 50} units',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
