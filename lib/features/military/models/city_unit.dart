// Typed model for city_units table rows from Supabase.

/// Immutable model representing a stack of one unit type in a city.
/// The UNIQUE(city_id, unit_type) constraint means one row per unit type per city.
class CityUnit {
  const CityUnit({
    required this.id,
    required this.cityId,
    required this.unitType,
    required this.quantity,
    required this.updatedAt,
  });

  final String id;
  final String cityId;

  /// The DB snake_case unit type string (e.g., 'hoplite', 'cargo_ship').
  final String unitType;

  /// Number of units of this type present in the city.
  final int quantity;

  /// UTC time when this roster entry was last updated.
  final DateTime updatedAt;

  /// Parses a Supabase JSON row into a [CityUnit] instance.
  factory CityUnit.fromJson(Map<String, dynamic> json) {
    return CityUnit(
      id: json['id'] as String,
      cityId: json['city_id'] as String,
      unitType: json['unit_type'] as String,
      quantity: (json['quantity'] as num).toInt(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
    );
  }

  @override
  String toString() =>
      'CityUnit(id: $id, cityId: $cityId, unitType: $unitType, quantity: $quantity)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CityUnit &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
