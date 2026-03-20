// Section heading widget for building detail sheet panels.
// Provides a consistent labeled section with a divider and child content.

import 'package:flutter/material.dart';

/// A labeled section within a building detail sheet.
///
/// Renders an uppercase label, a thin divider, then the [child] widget.
/// Used for "STATS" and "ACTIONS" sections (and future sections in Plan 02).
class BuildingSheetSection extends StatelessWidget {
  const BuildingSheetSection({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.grey.shade600,
              letterSpacing: 1.1,
            ),
          ),
        ),
        const Divider(height: 8),
        child,
      ],
    );
  }
}
