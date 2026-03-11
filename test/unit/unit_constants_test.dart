// Tests for military unit constants.
//
// Covers: MIL-01 (8 land unit types), MIL-02 (5 naval unit types),
//         MIL-03 (unlock levels), MIL-05 (travel time formula)

import 'package:flutter_test/flutter_test.dart';
import 'package:ikariam/core/constants/unit_constants.dart';

void main() {
  group('UnitType enum', () {
    test('has 8 land unit types', () {
      final landUnits = UnitType.values.where((u) => !u.isNaval).toList();
      expect(landUnits.length, equals(8));
    });

    test('has 5 naval unit types', () {
      final navalUnits = UnitType.values.where((u) => u.isNaval).toList();
      expect(navalUnits.length, equals(5));
    });

    test('isNaval returns true only for naval units', () {
      expect(UnitType.hoplite.isNaval, isFalse);
      expect(UnitType.phalanx.isNaval, isFalse);
      expect(UnitType.archer.isNaval, isFalse);
      expect(UnitType.cavalry.isNaval, isFalse);
      expect(UnitType.catapult.isNaval, isFalse);
      expect(UnitType.mortar.isNaval, isFalse);
      expect(UnitType.medic.isNaval, isFalse);
      expect(UnitType.cook.isNaval, isFalse);
      expect(UnitType.cargoShip.isNaval, isTrue);
      expect(UnitType.ramShip.isNaval, isTrue);
      expect(UnitType.catapultShip.isNaval, isTrue);
      expect(UnitType.mortarShip.isNaval, isTrue);
      expect(UnitType.divingBoat.isNaval, isTrue);
    });

    test('dbName returns correct snake_case string for all types', () {
      expect(UnitType.hoplite.dbName, equals('hoplite'));
      expect(UnitType.phalanx.dbName, equals('phalanx'));
      expect(UnitType.archer.dbName, equals('archer'));
      expect(UnitType.cavalry.dbName, equals('cavalry'));
      expect(UnitType.catapult.dbName, equals('catapult'));
      expect(UnitType.mortar.dbName, equals('mortar'));
      expect(UnitType.medic.dbName, equals('medic'));
      expect(UnitType.cook.dbName, equals('cook'));
      expect(UnitType.cargoShip.dbName, equals('cargo_ship'));
      expect(UnitType.ramShip.dbName, equals('ram_ship'));
      expect(UnitType.catapultShip.dbName, equals('catapult_ship'));
      expect(UnitType.mortarShip.dbName, equals('mortar_ship'));
      expect(UnitType.divingBoat.dbName, equals('diving_boat'));
    });
  });

  group('unitUnlockLevels', () {
    test('covers all 13 unit types', () {
      expect(unitUnlockLevels.length, equals(13));
      for (final unitType in UnitType.values) {
        expect(unitUnlockLevels.containsKey(unitType), isTrue,
            reason: 'Missing unlock level for ${unitType.dbName}');
      }
    });

    test('land units require barracks levels 1-5', () {
      expect(unitUnlockLevels[UnitType.hoplite], equals(1));
      expect(unitUnlockLevels[UnitType.phalanx], equals(2));
      expect(unitUnlockLevels[UnitType.archer], equals(2));
      expect(unitUnlockLevels[UnitType.cavalry], equals(3));
      expect(unitUnlockLevels[UnitType.catapult], equals(4));
      expect(unitUnlockLevels[UnitType.mortar], equals(5));
      expect(unitUnlockLevels[UnitType.medic], equals(3));
      expect(unitUnlockLevels[UnitType.cook], equals(1));
    });

    test('naval units require shipyard levels 1-4', () {
      expect(unitUnlockLevels[UnitType.cargoShip], equals(1));
      expect(unitUnlockLevels[UnitType.ramShip], equals(2));
      expect(unitUnlockLevels[UnitType.catapultShip], equals(3));
      expect(unitUnlockLevels[UnitType.mortarShip], equals(4));
      expect(unitUnlockLevels[UnitType.divingBoat], equals(3));
    });
  });

  group('travel time formula', () {
    test('same coordinates returns minimum 1 minute', () {
      expect(calcTravelMinutes(0, 0, 0, 0), equals(1));
      expect(calcTravelMinutes(3, 4, 3, 4), equals(1));
    });

    test('distance between islands calculates correctly', () {
      // Distance from (0,0) to (3,4) = sqrt(9+16) = sqrt(25) = 5
      // 5 * 10 baseMinutesPerUnit = 50
      expect(calcTravelMinutes(0, 0, 3, 4), equals(50));
      // Distance from (0,0) to (1,0) = 1; 1 * 10 = 10
      expect(calcTravelMinutes(0, 0, 1, 0), equals(10));
    });
  });
}
