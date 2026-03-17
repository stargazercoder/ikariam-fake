/// GodmodeEvent — parsed representation of one event entry from
/// the godmode_get_events() RPC response.
///
/// Response shape (from godmode_get_events JSONB array):
/// ```json
/// {
///   "event_type": "battle",
///   "timestamp": "2026-03-17T12:00:00Z",
///   "detail": {
///     "battle_id": "...", "attacker": "...", "defender": "...",
///     "summary": "Battle turn 2 - active"
///   }
/// }
/// ```
///
/// event_type is one of: 'battle', 'trade', 'espionage'
class GodmodeEvent {
  GodmodeEvent({
    required this.eventType,
    required this.timestamp,
    required this.detail,
  });

  /// One of 'battle', 'trade', or 'espionage'.
  final String eventType;

  final DateTime timestamp;

  /// Raw detail map. Keys depend on event_type — use [summary] for a
  /// human-readable one-liner.
  final Map<String, dynamic> detail;

  /// Human-readable summary string from the detail map, or empty string
  /// if absent.
  String get summary => detail['summary'] as String? ?? '';

  factory GodmodeEvent.fromJson(Map<String, dynamic> json) {
    return GodmodeEvent(
      eventType: json['event_type'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      detail: json['detail'] as Map<String, dynamic>? ?? {},
    );
  }

  @override
  String toString() =>
      'GodmodeEvent(eventType: $eventType, timestamp: $timestamp, summary: $summary)';
}
