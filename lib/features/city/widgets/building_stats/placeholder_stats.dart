// Placeholder stats widget for buildings whose content is not yet implemented.
// Used for Academy (Research) and Embassy (Alliance) in Plan 01.
// Plan 02 will replace these with full dynamic content.

import 'package:flutter/material.dart';

/// Placeholder stats panel for buildings with future content.
///
/// Displays a centered info message: "[featureName]: Coming soon".
/// Used for Academy and Embassy until Plan 02 implements full content.
class PlaceholderStats extends StatelessWidget {
  const PlaceholderStats({super.key, required this.featureName});

  /// Feature name shown in the message, e.g. "Research" or "Alliance".
  final String featureName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Text(
            '$featureName: Coming soon',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
