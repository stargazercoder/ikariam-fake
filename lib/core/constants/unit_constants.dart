// Unit type definitions, unlock levels, base costs, base times, and travel formula.
//
// NOTE: UNIT_UNLOCK_LEVELS, UNIT_BASE_COSTS, UNIT_BASE_TIMES must stay in sync
// with supabase/functions/train-units/index.ts

import 'dart:math';

/// Enum representing all 13 unit types in the game.
/// 8 land units (trained from Barracks) + 5 naval units (trained from Shipyard).
enum UnitType {
  // Land units
  hoplite,
  phalanx,
  archer,
  cavalry,
  catapult,
  mortar,
  medic,
  cook,
  // Naval units
  cargoShip,
  ramShip,
  catapultShip,
  mortarShip,
  divingBoat;

  /// Returns the DB column value (snake_case string matching city_units.unit_type CHECK constraint).
  String get dbName {
    switch (this) {
      case UnitType.hoplite:
        return 'hoplite';
      case UnitType.phalanx:
        return 'phalanx';
      case UnitType.archer:
        return 'archer';
      case UnitType.cavalry:
        return 'cavalry';
      case UnitType.catapult:
        return 'catapult';
      case UnitType.mortar:
        return 'mortar';
      case UnitType.medic:
        return 'medic';
      case UnitType.cook:
        return 'cook';
      case UnitType.cargoShip:
        return 'cargo_ship';
      case UnitType.ramShip:
        return 'ram_ship';
      case UnitType.catapultShip:
        return 'catapult_ship';
      case UnitType.mortarShip:
        return 'mortar_ship';
      case UnitType.divingBoat:
        return 'diving_boat';
    }
  }

  /// Returns a human-readable display name.
  String get displayName {
    switch (this) {
      case UnitType.hoplite:
        return 'Hoplite';
      case UnitType.phalanx:
        return 'Phalanx';
      case UnitType.archer:
        return 'Archer';
      case UnitType.cavalry:
        return 'Cavalry';
      case UnitType.catapult:
        return 'Catapult';
      case UnitType.mortar:
        return 'Mortar';
      case UnitType.medic:
        return 'Medic';
      case UnitType.cook:
        return 'Cook';
      case UnitType.cargoShip:
        return 'Cargo Ship';
      case UnitType.ramShip:
        return 'Ram Ship';
      case UnitType.catapultShip:
        return 'Catapult Ship';
      case UnitType.mortarShip:
        return 'Mortar Ship';
      case UnitType.divingBoat:
        return 'Diving Boat';
    }
  }

  /// Returns the required building type DB name ('barracks' or 'shipyard').
  String get requiredBuilding {
    return isNaval ? 'shipyard' : 'barracks';
  }

  /// Returns true if this is a naval unit (trained from Shipyard).
  bool get isNaval {
    return this == UnitType.cargoShip ||
        this == UnitType.ramShip ||
        this == UnitType.catapultShip ||
        this == UnitType.mortarShip ||
        this == UnitType.divingBoat;
  }
}

/// Parses a DB snake_case unit_type string to a [UnitType] enum value.
/// Throws [ArgumentError] if the string does not match any known type.
UnitType unitTypeFromDbName(String dbName) {
  return UnitType.values.firstWhere(
    (u) => u.dbName == dbName,
    orElse: () => throw ArgumentError('Unknown unit type: $dbName'),
  );
}

/// Minimum building level required to unlock each unit type.
/// Land units require Barracks; naval units require Shipyard.
/// NOTE: Must stay in sync with UNIT_UNLOCK_LEVELS in supabase/functions/train-units/index.ts
const Map<UnitType, int> unitUnlockLevels = {
  // Land units (Barracks)
  UnitType.hoplite: 1,
  UnitType.phalanx: 2,
  UnitType.archer: 2,
  UnitType.cavalry: 3,
  UnitType.catapult: 4,
  UnitType.mortar: 5,
  UnitType.medic: 3,
  UnitType.cook: 1,
  // Naval units (Shipyard)
  UnitType.cargoShip: 1,
  UnitType.ramShip: 2,
  UnitType.catapultShip: 3,
  UnitType.mortarShip: 4,
  UnitType.divingBoat: 3,
};

/// Base resource costs per unit (keys are resource type DB names: 'wood', 'gold', etc.).
/// Total cost = base_cost[resource] * quantity for each resource.
/// NOTE: Must stay in sync with UNIT_BASE_COSTS in supabase/functions/train-units/index.ts
const Map<UnitType, Map<String, int>> unitBaseCosts = {
  UnitType.hoplite: {'wood': 40, 'gold': 30},
  UnitType.phalanx: {'wood': 60, 'marble': 20, 'gold': 50},
  UnitType.archer: {'wood': 50, 'crystal': 20, 'gold': 40},
  UnitType.cavalry: {'wood': 80, 'gold': 100},
  UnitType.catapult: {'wood': 120, 'sulfur': 30, 'gold': 80},
  UnitType.mortar: {'wood': 100, 'sulfur': 50, 'gold': 120},
  UnitType.medic: {'wood': 30, 'crystal': 30, 'gold': 60},
  UnitType.cook: {'wood': 20, 'gold': 20},
  UnitType.cargoShip: {'wood': 200, 'gold': 100},
  UnitType.ramShip: {'wood': 250, 'marble': 100, 'gold': 150},
  UnitType.catapultShip: {'wood': 300, 'sulfur': 50, 'gold': 200},
  UnitType.mortarShip: {'wood': 350, 'sulfur': 80, 'gold': 250},
  UnitType.divingBoat: {'wood': 200, 'crystal': 80, 'gold': 180},
};

/// Base training time in minutes per unit.
/// Total training time = base_time * quantity minutes.
/// NOTE: Must stay in sync with UNIT_BASE_TIMES in supabase/functions/train-units/index.ts
const Map<UnitType, int> unitBaseTimes = {
  UnitType.hoplite: 3,
  UnitType.phalanx: 5,
  UnitType.archer: 4,
  UnitType.cavalry: 8,
  UnitType.catapult: 12,
  UnitType.mortar: 15,
  UnitType.medic: 5,
  UnitType.cook: 2,
  UnitType.cargoShip: 10,
  UnitType.ramShip: 15,
  UnitType.catapultShip: 20,
  UnitType.mortarShip: 25,
  UnitType.divingBoat: 18,
};

/// Base minutes per grid unit of travel distance.
/// NOTE: Must stay in sync with BASE_MINUTES_PER_GRID_UNIT in supabase/functions/dispatch-units/index.ts
const int baseMinutesPerGridUnit = 10;

/// Calculates travel time in minutes between two island grid positions.
/// Formula: max(1, ceil(sqrt(dx^2 + dy^2) * baseMinutesPerUnit))
/// Same-island dispatch (distance = 0) always returns minimum 1 minute.
/// NOTE: Must stay in sync with calcTravelMinutes in supabase/functions/dispatch-units/index.ts
int calcTravelMinutes(
  int originX,
  int originY,
  int destX,
  int destY, {
  int baseMinutesPerUnit = baseMinutesPerGridUnit,
}) {
  final dx = destX - originX;
  final dy = destY - originY;
  final distance = sqrt(dx * dx + dy * dy);
  return max(1, (distance * baseMinutesPerUnit).ceil());
}
