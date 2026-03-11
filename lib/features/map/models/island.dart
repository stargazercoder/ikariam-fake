/// Island data model representing a single island on the world map.
///
/// Maps directly to the `islands` table in Supabase:
/// columns: id (uuid), grid_x (int), grid_y (int), luxury_type (text), max_city_slots (int)
class Island {
  const Island({
    required this.id,
    required this.gridX,
    required this.gridY,
    required this.luxuryType,
    required this.maxCitySlots,
  });

  final String id;
  final int gridX;
  final int gridY;
  final String luxuryType;
  final int maxCitySlots;

  factory Island.fromJson(Map<String, dynamic> json) {
    return Island(
      id: json['id'] as String? ?? '',
      gridX: json['grid_x'] as int? ?? 0,
      gridY: json['grid_y'] as int? ?? 0,
      luxuryType: json['luxury_type'] as String? ?? 'marble',
      maxCitySlots: json['max_city_slots'] as int? ?? 16,
    );
  }
}
