// Building type definitions, base costs, base times, and upgrade formulas.

import 'dart:math';
import 'package:ikariam/core/constants/resource_constants.dart';

/// Enum representing all 14 building types in the game.
/// 10 city buildings + 4 production buildings.
enum BuildingType {
  townHall,
  warehouse,
  barracks,
  shipyard,
  academy,
  embassy,
  tradingPort,
  townWall,
  hideout,
  tavern,
  sawmill,
  quarry,
  glassblower,
  sulfurPit;

  /// Returns the DB column value (snake_case string matching city_buildings.building_type CHECK constraint).
  String get dbName {
    switch (this) {
      case BuildingType.townHall:
        return 'town_hall';
      case BuildingType.warehouse:
        return 'warehouse';
      case BuildingType.barracks:
        return 'barracks';
      case BuildingType.shipyard:
        return 'shipyard';
      case BuildingType.academy:
        return 'academy';
      case BuildingType.embassy:
        return 'embassy';
      case BuildingType.tradingPort:
        return 'trading_port';
      case BuildingType.townWall:
        return 'town_wall';
      case BuildingType.hideout:
        return 'hideout';
      case BuildingType.tavern:
        return 'tavern';
      case BuildingType.sawmill:
        return 'sawmill';
      case BuildingType.quarry:
        return 'quarry';
      case BuildingType.glassblower:
        return 'glassblower';
      case BuildingType.sulfurPit:
        return 'sulfur_pit';
    }
  }

  /// Returns a human-readable display name.
  String get displayName {
    switch (this) {
      case BuildingType.townHall:
        return 'Town Hall';
      case BuildingType.warehouse:
        return 'Warehouse';
      case BuildingType.barracks:
        return 'Barracks';
      case BuildingType.shipyard:
        return 'Shipyard';
      case BuildingType.academy:
        return 'Academy';
      case BuildingType.embassy:
        return 'Embassy';
      case BuildingType.tradingPort:
        return 'Trading Port';
      case BuildingType.townWall:
        return 'Town Wall';
      case BuildingType.hideout:
        return 'Hideout';
      case BuildingType.tavern:
        return 'Tavern';
      case BuildingType.sawmill:
        return 'Sawmill';
      case BuildingType.quarry:
        return 'Quarry';
      case BuildingType.glassblower:
        return 'Glassblower';
      case BuildingType.sulfurPit:
        return 'Sulfur Pit';
    }
  }

  /// Returns true if this is a production building (sawmill, quarry, glassblower, sulfur_pit).
  bool get isProductionBuilding {
    return this == BuildingType.sawmill ||
        this == BuildingType.quarry ||
        this == BuildingType.glassblower ||
        this == BuildingType.sulfurPit;
  }
}

/// Parses a DB snake_case building_type string to a [BuildingType] enum value.
/// Throws [ArgumentError] if the string does not match any known type.
BuildingType buildingTypeFromDbName(String dbName) {
  return BuildingType.values.firstWhere(
    (b) => b.dbName == dbName,
    orElse: () => throw ArgumentError('Unknown building type: $dbName'),
  );
}

/// Parses a DB snake_case resource_type string to a [ResourceType] enum value.
/// Throws [ArgumentError] if the string does not match any known type.
ResourceType resourceTypeFromDbName(String dbName) {
  return ResourceType.values.firstWhere(
    (r) => r.value == dbName,
    orElse: () => throw ArgumentError('Unknown resource type: $dbName'),
  );
}

/// Base resource costs for each building type at level 0.
/// Formula: upgradeCost = base_cost * 1.5^currentLevel (each resource, ceil'd)
const Map<BuildingType, Map<ResourceType, int>> buildingBaseCosts = {
  BuildingType.townHall: {
    ResourceType.gold: 100,
    ResourceType.wood: 200,
  },
  BuildingType.warehouse: {
    ResourceType.wood: 100,
    ResourceType.marble: 50,
  },
  BuildingType.barracks: {
    ResourceType.wood: 150,
    ResourceType.gold: 100,
  },
  BuildingType.shipyard: {
    ResourceType.wood: 200,
    ResourceType.marble: 100,
    ResourceType.gold: 150,
  },
  BuildingType.academy: {
    ResourceType.wood: 100,
    ResourceType.crystal: 100,
    ResourceType.gold: 200,
  },
  BuildingType.embassy: {
    ResourceType.wood: 80,
    ResourceType.marble: 80,
    ResourceType.gold: 100,
  },
  BuildingType.tradingPort: {
    ResourceType.wood: 150,
    ResourceType.gold: 120,
  },
  BuildingType.townWall: {
    ResourceType.wood: 200,
    ResourceType.marble: 150,
  },
  BuildingType.hideout: {
    ResourceType.wood: 100,
    ResourceType.gold: 80,
  },
  BuildingType.tavern: {
    ResourceType.wood: 120,
    ResourceType.gold: 100,
  },
  BuildingType.sawmill: {
    ResourceType.wood: 50,
    ResourceType.gold: 50,
  },
  BuildingType.quarry: {
    ResourceType.wood: 80,
    ResourceType.marble: 30,
  },
  BuildingType.glassblower: {
    ResourceType.wood: 80,
    ResourceType.crystal: 30,
  },
  BuildingType.sulfurPit: {
    ResourceType.wood: 80,
    ResourceType.sulfur: 30,
  },
};

/// Base upgrade time in minutes for each building type at level 0.
/// Formula: upgradeDurationMinutes = ceil(base_time * 1.2^currentLevel)
/// NOTE: Values reduced to 1/10 for faster testing.
const Map<BuildingType, int> buildingBaseTimes = {
  BuildingType.townHall: 1,
  BuildingType.warehouse: 1,
  BuildingType.barracks: 1,
  BuildingType.shipyard: 1,
  BuildingType.academy: 1,
  BuildingType.embassy: 1,
  BuildingType.tradingPort: 1,
  BuildingType.townWall: 1,
  BuildingType.hideout: 1,
  BuildingType.tavern: 1,
  BuildingType.sawmill: 1,
  BuildingType.quarry: 1,
  BuildingType.glassblower: 1,
  BuildingType.sulfurPit: 1,
};

/// Growth factor applied to resource costs per level.
const double costGrowthFactor = 1.5;

/// Growth factor applied to upgrade time per level.
const double timeGrowthFactor = 1.2;

/// Calculates the resource cost to upgrade [type] from [currentLevel].
/// Formula: ceil(base_cost * 1.5^currentLevel) for each resource.
Map<ResourceType, int> upgradeCost(BuildingType type, int currentLevel) {
  final baseCosts = buildingBaseCosts[type]!;
  final multiplier = pow(costGrowthFactor, currentLevel);
  return baseCosts.map(
    (resource, baseCost) =>
        MapEntry(resource, (baseCost * multiplier).ceil()),
  );
}

/// Calculates the time in minutes to upgrade [type] from [currentLevel].
/// Formula: ceil(base_time * 1.2^currentLevel)
int upgradeDurationMinutes(BuildingType type, int currentLevel) {
  final baseTime = buildingBaseTimes[type]!;
  return (baseTime * pow(timeGrowthFactor, currentLevel)).ceil();
}

/// Calculates the resource refund for downgrading [type] from [currentLevel].
///
/// Returns 50% (floored) of the cost to upgrade from (currentLevel-1) to
/// currentLevel. Asserts that currentLevel > 1.
Map<ResourceType, int> downgradeRefund(BuildingType type, int currentLevel) {
  assert(currentLevel > 1, 'Cannot downgrade below level 1');
  final fullCost = upgradeCost(type, currentLevel - 1);
  return fullCost.map((r, v) => MapEntry(r, (v * 0.5).floor()));
}

/// Calculates the resource protection floor provided by a Hideout at [level].
/// Each of the 4 pillageable resources (wood, marble, crystal, sulfur) is
/// independently protected up to this amount.
/// If [level] is null (no Hideout built), returns 50 per resource (base protection
/// for new players — per user decision).
/// Otherwise: floor(100 * 1.5^level). Level 0 = 100 per resource.
/// Matches the SQL formula in resolve_battles() pillage logic.
int hideoutProtectionFloor(int? level) {
  if (level == null) return 50;
  return (100.0 * pow(1.5, level)).floor();
}
