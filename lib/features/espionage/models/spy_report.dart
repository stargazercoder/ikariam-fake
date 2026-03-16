// Typed model for spy_reports table rows from Supabase.
//
// The report_data JSONB column holds nested maps; all numeric values are
// parsed with (v as num).toInt() to handle the JSONB cast inconsistency
// where Dart may receive a double instead of int at runtime.

/// Immutable model representing a spy report returned by the spy-city Edge Function
/// or fetched from the spy_reports table.
class SpyReport {
  const SpyReport({
    required this.id,
    required this.targetCityId,
    required this.targetCityName,
    required this.ownerName,
    required this.createdAt,
    required this.resources,
    required this.buildings,
    required this.armyCount,
  });

  final String id;
  final String targetCityId;
  final String targetCityName;
  final String ownerName;
  final DateTime createdAt;

  /// Resource amounts keyed by resource_type (wood, marble, crystal, sulfur, gold).
  final Map<String, int> resources;

  /// Building levels keyed by building_type (town_hall, warehouse, etc.).
  final Map<String, int> buildings;

  /// Total unit count in the target city (no per-type breakdown).
  final int armyCount;

  /// Parses a Supabase row into a [SpyReport].
  ///
  /// Expects a row with top-level fields: id, target_city_id, created_at,
  /// and a nested report_data JSONB object containing city_name, owner_name,
  /// resources (map), buildings (map), and army_count.
  factory SpyReport.fromJson(Map<String, dynamic> json) {
    final data = json['report_data'] as Map<String, dynamic>;
    return SpyReport(
      id: json['id'] as String,
      targetCityId: json['target_city_id'] as String,
      targetCityName: data['city_name'] as String? ?? '',
      ownerName: data['owner_name'] as String? ?? 'Unknown',
      createdAt: DateTime.parse(json['created_at'] as String),
      resources: (data['resources'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toInt())),
      buildings: (data['buildings'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toInt())),
      armyCount: (data['army_count'] as num).toInt(),
    );
  }

  @override
  String toString() =>
      'SpyReport(id: $id, targetCityId: $targetCityId, targetCityName: $targetCityName, '
      'ownerName: $ownerName, armyCount: $armyCount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpyReport &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
