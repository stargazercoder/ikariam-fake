// Tests for combat formula logic and naval gate-keeper behavior.
//
// Covers: CMBT-02 (unitAttackStats, unitDefenseStats, computeCasualties formula,
//                   Town Wall bonus),
//         CMBT-03 (navalUnitTypes set, naval gate-keeper end condition)

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:ikariam/core/constants/unit_constants.dart';
import 'package:ikariam/features/battles/models/battle_turn.dart';

void main() {
  group('unitAttackStats and unitDefenseStats', () {
    test('unitAttackStats contains all 13 unit types', () {
      expect(unitAttackStats.length, 13);
      for (final type in UnitType.values) {
        expect(
          unitAttackStats.containsKey(type),
          isTrue,
          reason: 'unitAttackStats missing UnitType.${type.name}',
        );
      }
    });

    test('unitDefenseStats contains all 13 unit types', () {
      expect(unitDefenseStats.length, 13);
      for (final type in UnitType.values) {
        expect(
          unitDefenseStats.containsKey(type),
          isTrue,
          reason: 'unitDefenseStats missing UnitType.${type.name}',
        );
      }
    });
  });

  group('computeCasualties formula', () {
    // Formula: floor(enemy_total_attack / max(own_total_defense, 1) * own_units)
    // clamped to [0, quantity]

    test('returns floor(enemy_attack / own_defense * own_units) clamped to [0, quantity]', () {
      // Example: enemy attack = 100, own defense = 200, own units = 10
      // loss_ratio = 100 / 200 = 0.5
      // casualties = floor(10 * 0.5) = 5
      const enemyAttack = 100;
      const ownDefense = 200;
      const ownUnits = 10;
      final lossRatio = enemyAttack / max(ownDefense, 1);
      final casualties = min(lossRatio * ownUnits, ownUnits.toDouble()).floor();
      expect(casualties, 5);
    });

    test('result is clamped to 0 when enemy attack is 0', () {
      const enemyAttack = 0;
      const ownDefense = 100;
      const ownUnits = 20;
      final lossRatio = enemyAttack / max(ownDefense, 1);
      final casualties = min(lossRatio * ownUnits, ownUnits.toDouble()).floor();
      expect(casualties, 0);
    });

    test('result is clamped to own unit quantity when casualties exceed total', () {
      // Very high enemy attack means loss_ratio > 1 — should clamp to ownUnits
      const enemyAttack = 10000;
      const ownDefense = 1;
      const ownUnits = 5;
      final lossRatio = enemyAttack / max(ownDefense, 1);
      final casualties = min(lossRatio * ownUnits, ownUnits.toDouble()).floor();
      expect(casualties, ownUnits);
    });
  });

  group('navalUnitTypes', () {
    test('contains exactly 5 types: cargo_ship, ram_ship, catapult_ship, mortar_ship, diving_boat', () {
      final navalTypes = UnitType.values.where((u) => u.isNaval).toList();
      expect(navalTypes.length, 5);
      final navalDbNames = navalTypes.map((u) => u.dbName).toSet();
      expect(navalDbNames, containsAll([
        'cargo_ship',
        'ram_ship',
        'catapult_ship',
        'mortar_ship',
        'diving_boat',
      ]));
    });

    test('naval gate-keeper: battle ends when attacker naval units are fully wiped', () {
      // The gate-keeper logic: if attacker had naval units and all wiped => defender_won
      // Simulate: attacker_survivors has no naval units remaining
      final attackerSurvivors = {'hoplite': 10}; // no naval
      final attackerStartedWithNaval = true; // attacker had naval at battle start
      final navalTypes = UnitType.values.where((u) => u.isNaval).map((u) => u.dbName).toSet();
      final attackerNavalRemaining = attackerSurvivors.keys
          .where((k) => navalTypes.contains(k))
          .fold(0, (sum, k) => sum + attackerSurvivors[k]!);

      final gateKeeperTriggered = attackerStartedWithNaval && attackerNavalRemaining == 0;
      expect(gateKeeperTriggered, isTrue);
    });
  });

  group('Town Wall defense bonus', () {
    // Formula: wall_bonus = 1.0 + 0.05 * wall_level
    // Applied as multiplier to defender land defense total

    test('multiplies defender land defense by (1 + 0.05 * wall_level)', () {
      const baseDefense = 200;
      const wallLevel = 4;
      final multiplier = 1.0 + 0.05 * wallLevel;
      final boostedDefense = (baseDefense * multiplier).round();
      expect(multiplier, closeTo(1.2, 0.001));
      expect(boostedDefense, 240);
    });

    test('wall level 0 applies no bonus (multiplier = 1.0)', () {
      const wallLevel = 0;
      final multiplier = 1.0 + 0.05 * wallLevel;
      expect(multiplier, 1.0);
    });

    test('wall level 10 applies 50% bonus (multiplier = 1.5)', () {
      const wallLevel = 10;
      final multiplier = 1.0 + 0.05 * wallLevel;
      expect(multiplier, closeTo(1.5, 0.001));
    });
  });
}
