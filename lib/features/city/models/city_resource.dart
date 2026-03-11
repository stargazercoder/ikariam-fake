// Typed model for city_resources table rows from Supabase.

import 'package:ikariam/core/constants/building_constants.dart';
import 'package:ikariam/core/constants/resource_constants.dart';

/// Immutable model representing a row in the city_resources table.
class CityResource {
  const CityResource({
    required this.id,
    required this.cityId,
    required this.resourceType,
    required this.amount,
    required this.updatedAt,
  });

  final String id;
  final String cityId;
  final ResourceType resourceType;
  final double amount;
  final DateTime updatedAt;

  /// Parses a Supabase JSON row into a [CityResource] instance.
  /// The resource_type string is mapped to the [ResourceType] enum.
  factory CityResource.fromJson(Map<String, dynamic> json) {
    return CityResource(
      id: json['id'] as String,
      cityId: json['city_id'] as String,
      resourceType: resourceTypeFromDbName(json['resource_type'] as String),
      amount: (json['amount'] as num).toDouble(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
    );
  }

  /// Serializes this model back to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'city_id': cityId,
      'resource_type': resourceType.value,
      'amount': amount,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'CityResource(id: $id, cityId: $cityId, resourceType: ${resourceType.value}, amount: $amount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CityResource &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
