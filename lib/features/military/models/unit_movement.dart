// Typed model for unit_movements table rows from Supabase.

/// Immutable model representing an in-transit army movement between cities.
/// The units field is a JSONB snapshot of the army at departure time.
class UnitMovement {
  const UnitMovement({
    required this.id,
    required this.originCityId,
    required this.destinationCityId,
    required this.ownerId,
    required this.units,
    required this.departAt,
    required this.arriveAt,
    required this.createdAt,
    this.cargo,
    this.movementType = 'attack',
  });

  final String id;
  final String originCityId;
  final String destinationCityId;
  final String ownerId;

  /// Snapshot of units at departure: key = DB snake_case unit type, value = quantity.
  /// Example: {'hoplite': 10, 'archer': 5}
  final Map<String, int> units;

  /// UTC time when the army departed.
  final DateTime departAt;

  /// UTC time when the army will arrive at the destination.
  final DateTime arriveAt;
  final DateTime createdAt;

  /// Pillaged resources being transported (null for non-pillage movements).
  /// Keys are resource types, values are amounts.
  final Map<String, int>? cargo;

  /// The type of movement. Either 'attack' (outgoing assault) or 'return'
  /// (army returning home). Defaults to 'attack' for backward compatibility.
  final String movementType; // 'attack' | 'return'

  /// Parses a Supabase JSON row into a [UnitMovement] instance.
  /// The 'units' JSONB field is parsed from `Map<String, dynamic>` to `Map<String, int>`.
  factory UnitMovement.fromJson(Map<String, dynamic> json) {
    return UnitMovement(
      id: json['id'] as String,
      originCityId: json['origin_city_id'] as String,
      destinationCityId: json['destination_city_id'] as String,
      ownerId: json['owner_id'] as String,
      units: (json['units'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toInt())),
      departAt: DateTime.parse(json['depart_at'] as String).toUtc(),
      arriveAt: DateTime.parse(json['arrive_at'] as String).toUtc(),
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
      cargo: json['cargo'] == null
          ? null
          : (json['cargo'] as Map<String, dynamic>)
              .map((k, v) => MapEntry(k, (v as num).toInt())),
      movementType: json['movement_type'] as String? ?? 'attack',
    );
  }

  /// How much time remains until the army arrives.
  Duration get remainingTravelTime {
    return arriveAt.difference(DateTime.now().toUtc());
  }

  /// Returns true if the army has arrived (arriveAt is in the past).
  bool get hasArrived => DateTime.now().toUtc().isAfter(arriveAt);

  @override
  String toString() =>
      'UnitMovement(id: $id, originCityId: $originCityId, '
      'destinationCityId: $destinationCityId, units: $units, '
      'movementType: $movementType, arriveAt: $arriveAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnitMovement &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
