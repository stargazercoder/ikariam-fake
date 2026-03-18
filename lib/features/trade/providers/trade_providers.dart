// Riverpod providers for trade feature: recipient city info for trade dialog.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';

/// Holds recipient city warehouse capacity and current resource amounts,
/// used by the trade dialog to show available space and prevent overfilling.
class RecipientCityInfo {
  const RecipientCityInfo({
    required this.warehouseCapacity,
    required this.resourceAmounts,
  });

  /// Maximum storage capacity for any single resource type.
  final double warehouseCapacity;

  /// Current stored amounts by resource_type DB name.
  final Map<String, double> resourceAmounts;

  /// Returns how much more of [resourceType] the recipient can accept.
  double remainingSpace(String resourceType) {
    final current = resourceAmounts[resourceType] ?? 0;
    return (warehouseCapacity - current).clamp(0, double.infinity);
  }
}

/// FutureProvider.family that fetches recipient city warehouse capacity and
/// current resource amounts for the trade dialog.
///
/// Fetches warehouse level from city_buildings and resource amounts from
/// city_resources for the given [cityId].
final recipientCityInfoProvider = FutureProvider.autoDispose
    .family<RecipientCityInfo, String>((ref, cityId) async {
  // Fetch warehouse level from city_buildings.
  final warehouseResult = await supabaseClient
      .from('city_buildings')
      .select('level')
      .eq('city_id', cityId)
      .eq('building_type', 'warehouse')
      .maybeSingle();

  final warehouseLevel = (warehouseResult?['level'] as num?)?.toInt() ?? 0;
  // Calculate capacity: 500 * 1.5^level
  final capacity = 500 * _pow(1.5, warehouseLevel);

  // Fetch all resource amounts for the recipient city.
  final resourceRows = await supabaseClient
      .from('city_resources')
      .select('resource_type, amount')
      .eq('city_id', cityId);

  final amounts = <String, double>{};
  for (final row in resourceRows) {
    amounts[row['resource_type'] as String] =
        (row['amount'] as num).toDouble();
  }

  return RecipientCityInfo(
    warehouseCapacity: capacity,
    resourceAmounts: amounts,
  );
});

/// Helper to compute base^exponent without importing dart:math.
double _pow(double base, int exponent) {
  double result = 1.0;
  for (int i = 0; i < exponent; i++) {
    result *= base;
  }
  return result;
}
