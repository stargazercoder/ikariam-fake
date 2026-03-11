// Resource type definitions and warehouse capacity constants.

import 'dart:math';

/// Enum representing all resource types in the game.
/// [value] maps to the DB column values in city_resources.resource_type.
enum ResourceType {
  wood,
  marble,
  crystal,
  sulfur,
  gold;

  /// Returns the DB column value (snake_case string).
  String get value => name;
}

/// Base warehouse storage capacity at level 0.
const int baseWarehouseCapacity = 500;

/// Growth factor for warehouse capacity per level.
const double warehouseCapacityGrowth = 1.5;

/// Calculates warehouse capacity at a given level.
/// Formula: baseWarehouseCapacity * warehouseCapacityGrowth^warehouseLevel
double warehouseCapacity(int warehouseLevel) {
  return (baseWarehouseCapacity * pow(warehouseCapacityGrowth, warehouseLevel))
      .toDouble();
}
