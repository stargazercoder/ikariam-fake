// Canonical resource badge widget.
//
// Renders a colored CircleAvatar + letter for production resources,
// and an Icon(Icons.wine_bar) for wine per the locked user decision.
//
// Usage:
//   ResourceBadge(type: ResourceType.wood)           // circle W, green
//   ResourceBadge(type: ResourceType.wine)           // wine_bar icon, purple
//   ResourceBadge(type: ResourceType.gold, radius: 14)

import 'package:flutter/material.dart';

import '../../core/constants/resource_constants.dart';
import '../../core/constants/visual_constants.dart';

/// Shared resource icon widget.
///
/// - For wine: renders `Icon(Icons.wine_bar)` in the canonical purple color.
/// - For all other types: renders a `CircleAvatar` with the canonical background
///   color and the single-letter identifier (W, M, C, S, G).
class ResourceBadge extends StatelessWidget {
  const ResourceBadge({
    super.key,
    required this.type,
    this.radius = 10.0,
  });

  /// The resource type to display.
  final ResourceType type;

  /// Radius of the CircleAvatar (ignored for wine which renders a plain Icon).
  /// The letter font size is scaled to `radius * 0.9`.
  /// The wine icon size is scaled to `radius * 1.4`.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = resourceTypeColor[type] ?? Colors.grey;

    // Wine uses a plain icon per locked user decision — NOT circle + letter.
    if (type == ResourceType.wine) {
      return Icon(
        Icons.wine_bar,
        size: radius * 1.4,
        color: color,
      );
    }

    final letter = resourceTypeLetter[type] ?? '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
