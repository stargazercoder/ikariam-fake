import 'island.dart';

/// Represents a single city slot on an island.
///
/// Maps to a row from the `cities` table:
/// columns: slot_number (int), name (text), owner_id (uuid)
class CitySlot {
  const CitySlot({
    required this.slotNumber,
    this.cityId,
    this.cityName,
    this.ownerId,
  });

  final int slotNumber;
  final String? cityId;
  final String? cityName;
  final String? ownerId;

  /// True when this slot has a city owned by someone.
  bool get isOccupied => ownerId != null;

  factory CitySlot.fromJson(Map<String, dynamic> json) {
    return CitySlot(
      slotNumber: (json['slot_number'] as num?)?.toInt() ?? 0,
      cityId: json['id'] as String?,
      cityName: json['name'] as String?,
      ownerId: json['owner_id'] as String?,
    );
  }
}

/// Aggregates an [Island] with all its [CitySlot]s.
class IslandDetail {
  const IslandDetail({
    required this.island,
    required this.citySlots,
  });

  final Island island;
  final List<CitySlot> citySlots;

  /// Number of occupied city slots on this island.
  int get cityCount => citySlots.where((s) => s.isOccupied).length;
}
