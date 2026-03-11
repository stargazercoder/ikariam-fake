// Typed model for training_queue table rows from Supabase.

/// Immutable model representing a row in the training_queue table.
/// The UNIQUE(city_id) constraint means at most one active training per city.
class TrainingQueueEntry {
  const TrainingQueueEntry({
    required this.id,
    required this.cityId,
    required this.unitType,
    required this.quantity,
    required this.finishAt,
    required this.createdAt,
  });

  final String id;
  final String cityId;

  /// The DB snake_case unit type string (e.g., 'hoplite', 'cargo_ship').
  /// Stored as String (not UnitType enum) to keep model decoupled from constants.
  final String unitType;
  final int quantity;

  /// UTC time when training finishes.
  final DateTime finishAt;
  final DateTime createdAt;

  /// Parses a Supabase JSON row into a [TrainingQueueEntry] instance.
  factory TrainingQueueEntry.fromJson(Map<String, dynamic> json) {
    return TrainingQueueEntry(
      id: json['id'] as String,
      cityId: json['city_id'] as String,
      unitType: json['unit_type'] as String,
      quantity: json['quantity'] as int,
      finishAt: DateTime.parse(json['finish_at'] as String).toUtc(),
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    );
  }

  /// How much time remains until training finishes.
  Duration get remainingDuration {
    final remaining = finishAt.difference(DateTime.now().toUtc());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Returns true if training has finished (finishAt is in the past).
  bool get isComplete => DateTime.now().toUtc().isAfter(finishAt);

  @override
  String toString() =>
      'TrainingQueueEntry(id: $id, cityId: $cityId, unitType: $unitType, '
      'quantity: $quantity, finishAt: $finishAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingQueueEntry &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
