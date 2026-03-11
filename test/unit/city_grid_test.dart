// Tests for building position map — verifies completeness and uniqueness.
//
// Covers: MAP-04 (city grid building positions)

import 'package:flutter_test/flutter_test.dart';
import 'package:ikariam/core/constants/building_constants.dart';
import 'package:ikariam/features/map/constants/building_positions.dart';

void main() {
  group('Building positions', () {
    test(
      'kBuildingPositions contains all 14 BuildingType values',
      () {
        expect(kBuildingPositions.length, equals(14));
        expect(
          kBuildingPositions.keys,
          containsAll(BuildingType.values),
        );
      },
    );

    test(
      'kBuildingPositions has no duplicate row/col positions',
      () {
        final positionStrings = kBuildingPositions.values
            .map((pos) => '${pos.row},${pos.col}')
            .toSet();
        expect(positionStrings.length, equals(14));
      },
    );
  });
}
