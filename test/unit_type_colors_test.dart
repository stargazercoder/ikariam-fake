// Tests for unitTypeColors constant map in unit_constants.dart.
// Verifies 13 entries, full UnitType coverage, and distinct color values.

import 'package:flutter_test/flutter_test.dart';
import 'package:ikariam/core/constants/unit_constants.dart';

void main() {
  group('unitTypeColors', () {
    test('has exactly 13 entries — one per UnitType value', () {
      expect(unitTypeColors.length, equals(13));
    });

    test('every UnitType.values entry is present as a key', () {
      for (final type in UnitType.values) {
        expect(
          unitTypeColors.containsKey(type),
          isTrue,
          reason: '${type.name} is missing from unitTypeColors',
        );
      }
    });

    test('all 13 Color values are distinct — no two unit types share a color', () {
      final colorValues = unitTypeColors.values.map((c) => c.toARGB32()).toSet();
      expect(
        colorValues.length,
        equals(13),
        reason: 'Expected 13 distinct colors but found ${colorValues.length}',
      );
    });
  });
}
