// Typed model for construction_queue table rows from Supabase.

/// Immutable model representing a row in the construction_queue table.
/// The UNIQUE(city_id) constraint means at most one entry exists per city.
class ConstructionQueueEntry {
  const ConstructionQueueEntry({
    required this.id,
    required this.cityId,
    required this.buildingType,
    required this.targetLevel,
    required this.finishAt,
    required this.createdAt,
  });

  final String id;
  final String cityId;

  /// The DB snake_case building type string (e.g., 'warehouse', 'town_hall').
  final String buildingType;
  final int targetLevel;

  /// UTC time when the construction finishes.
  final DateTime finishAt;
  final DateTime createdAt;

  /// Parses a Supabase JSON row into a [ConstructionQueueEntry] instance.
  /// finish_at is parsed and stored as UTC DateTime.
  factory ConstructionQueueEntry.fromJson(Map<String, dynamic> json) {
    return ConstructionQueueEntry(
      id: json['id'] as String,
      cityId: json['city_id'] as String,
      buildingType: json['building_type'] as String,
      targetLevel: (json['target_level'] as num).toInt(),
      finishAt: DateTime.parse(json['finish_at'] as String).toUtc(),
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    );
  }

  /// Serializes this model back to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'city_id': cityId,
      'building_type': buildingType,
      'target_level': targetLevel,
      'finish_at': finishAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// How much time remains until construction finishes.
  /// Returns [Duration.zero] if already complete.
  Duration get remainingDuration {
    final remaining = finishAt.toUtc().difference(DateTime.now().toUtc());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Returns true if construction has finished.
  bool get isComplete => remainingDuration == Duration.zero;

  @override
  String toString() =>
      'ConstructionQueueEntry(id: $id, cityId: $cityId, buildingType: $buildingType, '
      'targetLevel: $targetLevel, finishAt: $finishAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConstructionQueueEntry &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
