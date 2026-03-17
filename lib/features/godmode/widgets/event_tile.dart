import 'package:flutter/material.dart';

import '../models/godmode_event.dart';

/// A single tile in the GodMode event feed.
///
/// Renders a [ListTile] with a type-specific leading icon, the event
/// [GodmodeEvent.summary] as the title, and a formatted timestamp as
/// the subtitle. No external date-formatting dependencies — timestamp
/// is formatted via manual zero-padded string interpolation.
class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.event});

  final GodmodeEvent event;

  Icon _iconForType(String eventType) {
    switch (eventType) {
      case 'battle':
        return const Icon(Icons.sports_kabaddi, color: Colors.red);
      case 'trade':
        return const Icon(Icons.inventory_2, color: Colors.blue);
      case 'espionage':
        return const Icon(Icons.visibility, color: Colors.purple);
      default:
        return const Icon(Icons.info);
    }
  }

  String _formatTimestamp(DateTime ts) {
    final y = ts.year.toString();
    final mo = ts.month.toString().padLeft(2, '0');
    final d = ts.day.toString().padLeft(2, '0');
    final h = ts.hour.toString().padLeft(2, '0');
    final mi = ts.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _iconForType(event.eventType),
      title: Text(
        event.summary,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _formatTimestamp(event.timestamp),
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
    );
  }
}
