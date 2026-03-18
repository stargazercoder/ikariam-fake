// Typed model for city_buildings table rows from Supabase.

import 'package:ikariam/core/constants/building_constants.dart';

/// Immutable model representing a row in the city_buildings table.
class CityBuilding {
  const CityBuilding({
    required this.id,
    required this.cityId,
    required this.buildingType,
    required this.level,
    required this.assignedWorkers,
    required this.updatedAt,
  });

  final String id;
  final String cityId;
  final BuildingType buildingType;
  final int level;
  final int assignedWorkers;
  final DateTime updatedAt;

  /// Parses a Supabase JSON row into a [CityBuilding] instance.
  /// The building_type string is mapped to the [BuildingType] enum.
  factory CityBuilding.fromJson(Map<String, dynamic> json) {
    return CityBuilding(
      id: json['id'] as String,
      cityId: json['city_id'] as String,
      buildingType: buildingTypeFromDbName(json['building_type'] as String),
      level: (json['level'] as num).toInt(),
      assignedWorkers: (json['assigned_workers'] as num).toInt(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
    );
  }

  /// Serializes this model back to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'city_id': cityId,
      'building_type': buildingType.dbName,
      'level': level,
      'assigned_workers': assignedWorkers,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'CityBuilding(id: $id, cityId: $cityId, buildingType: ${buildingType.dbName}, level: $level)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CityBuilding &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
