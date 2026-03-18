// Riverpod providers for computing hourly production rates per resource type.
//
// Watches buildings, city economy (happiness), and city island data to
// calculate rates matching the server-side process_resource_tick() formula.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/building_constants.dart';
import '../models/city_building.dart';
import 'buildings_provider.dart';
import 'city_economy_provider.dart';
import 'city_provider.dart';

// ---------------------------------------------------------------------------
// Breakdown model
// ---------------------------------------------------------------------------

/// Breakdown of a single resource's hourly production into contributing parts.
class ProductionBreakdown {
  const ProductionBreakdown({
    required this.baseRate,
    required this.buildingBonus,
    required this.islandBonus,
    this.researchBonus = 0.0,
  });

  /// Workers × building-level-1 × 5.0 × tick multiplier (happiness).
  final double baseRate;

  /// Additional production from building levels above 1.
  final double buildingBonus;

  /// Additional production from island resource level multiplier.
  final double islandBonus;

  /// Bonus from research (always 0.0 in v1).
  final double researchBonus;

  double get total => baseRate + buildingBonus + islandBonus + researchBonus;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Maps a resource type name to its corresponding production [BuildingType].
BuildingType _productionBuilding(String resourceType) {
  switch (resourceType) {
    case 'wood':
      return BuildingType.sawmill;
    case 'marble':
      return BuildingType.quarry;
    case 'crystal':
      return BuildingType.glassblower;
    case 'sulfur':
      return BuildingType.sulfurPit;
    default:
      throw ArgumentError('No production building for resource: $resourceType');
  }
}

/// The four resource types that have production buildings.
const _productionResources = ['wood', 'marble', 'crystal', 'sulfur'];

// ---------------------------------------------------------------------------
// productionRateProvider
// ---------------------------------------------------------------------------

/// Provider that computes hourly production rates for all production resources.
///
/// Returns a [Map<String, double>] keyed by resource name (e.g. 'wood').
/// Formula per resource: workers × buildingLevel × 5.0 × productionMult ×
/// islandMult × 12 (12 ticks/hr at 5-min interval).
final productionRateProvider =
    Provider.autoDispose.family<Map<String, double>, String>((ref, cityId) {
  // Buildings list.
  final buildings = ref
          .watch(buildingsStreamProvider(cityId))
          .whenOrNull(data: (list) => list) ??
      <CityBuilding>[];

  // Happiness-based multiplier.
  final happiness = ref
          .watch(cityEconomyStreamProvider(cityId))
          .whenOrNull(data: (eco) => (eco?['happiness'] as num?)?.toDouble()) ??
      0.0;
  final productionMult = happiness < 0 ? 0.5 : 1.0;

  // Island resource level from city data.
  final cityData =
      ref.watch(cityProvider).whenOrNull(data: (c) => c);
  final islandLevel =
      ((cityData?['islands'] as Map<String, dynamic>?)?['resource_level']
          as num?)?.toInt() ??
      0;
  final islandMult = 1.0 + islandLevel * 0.10;

  final rates = <String, double>{};
  for (final resource in _productionResources) {
    final buildingType = _productionBuilding(resource);
    final building = buildings
        .where((b) => b.buildingType == buildingType)
        .firstOrNull;
    final workers = building?.assignedWorkers ?? 0;
    final level = building?.level ?? 0;
    rates[resource] = workers * level * 5.0 * productionMult * islandMult * 12;
  }
  return rates;
});

// ---------------------------------------------------------------------------
// productionBreakdownProvider
// ---------------------------------------------------------------------------

/// Provider that returns a detailed [ProductionBreakdown] for one resource.
///
/// Takes a record (cityId, resourceTypeName) as parameter.
final productionBreakdownProvider = Provider.autoDispose
    .family<ProductionBreakdown, (String, String)>((ref, args) {
  final (cityId, resourceTypeName) = args;

  // Buildings list.
  final buildings = ref
          .watch(buildingsStreamProvider(cityId))
          .whenOrNull(data: (list) => list) ??
      <CityBuilding>[];

  // Happiness-based multiplier.
  final happiness = ref
          .watch(cityEconomyStreamProvider(cityId))
          .whenOrNull(data: (eco) => (eco?['happiness'] as num?)?.toDouble()) ??
      0.0;
  final productionMult = happiness < 0 ? 0.5 : 1.0;

  // Island resource level.
  final cityData =
      ref.watch(cityProvider).whenOrNull(data: (c) => c);
  final islandLevel =
      ((cityData?['islands'] as Map<String, dynamic>?)?['resource_level']
          as num?)?.toInt() ??
      0;
  final islandMult = 1.0 + islandLevel * 0.10;

  // Find building for this resource type.
  final buildingType = _productionBuilding(resourceTypeName);
  final building = buildings
      .where((b) => b.buildingType == buildingType)
      .firstOrNull;
  final workers = building?.assignedWorkers ?? 0;
  final level = building?.level ?? 0;

  // Breakdown components.
  // baseRate: what you'd get at building level 1.
  final baseRate = workers * 1 * 5.0 * productionMult * 12;
  // buildingBonus: additional from higher building levels (level-1 increment).
  final buildingBonus = workers * (level - 1) * 5.0 * productionMult * 12;
  // islandBonus: additional from island multiplier applied to full production.
  final islandBonus =
      workers * level * 5.0 * productionMult * (islandMult - 1.0) * 12;

  return ProductionBreakdown(
    baseRate: baseRate.clamp(0.0, double.infinity),
    buildingBonus: buildingBonus.clamp(0.0, double.infinity),
    islandBonus: islandBonus,
    researchBonus: 0.0,
  );
});
