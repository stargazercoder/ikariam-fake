// Tests for dispatch travel formula (MIL-05).
// Verifies that baseMinutesPerGridUnit matches the TypeScript constant and
// that calcTravelMinutes produces valid results for all island pair scenarios.
//
// Wave 0 stubs — unskipped in 08-01 Task 2 once the TypeScript constant is declared.

import 'package:flutter_test/flutter_test.dart';
import 'package:ikariam/core/constants/unit_constants.dart';

void main() {
  group('dispatch travel formula (MIL-05)', () {
    test(
      'baseMinutesPerGridUnit matches TypeScript constant',
      () {
        // Dart constant and TypeScript BASE_MINUTES_PER_GRID_UNIT must both equal 2.
        // Sync comment in unit_constants.dart references dispatch-units/index.ts.
        expect(baseMinutesPerGridUnit, equals(2));
      },
      skip: 'Unskipped in 08-01 Task 2',
    );

    test(
      'calcTravelMinutes returns positive integer for adjacent islands',
      () {
        // Origin (0,0) -> Dest (1,1): distance = sqrt(2) ~1.41, ceil(1.41 * 2) = 3
        final result = calcTravelMinutes(0, 0, 1, 1);
        expect(result, greaterThan(0));
      },
      skip: 'Unskipped in 08-01 Task 2',
    );

    test(
      'calcTravelMinutes returns 1 for same-island dispatch',
      () {
        // Same coords: distance = 0, max(1, ceil(0)) = 1 (minimum clamp)
        final result = calcTravelMinutes(0, 0, 0, 0);
        expect(result, equals(1));
      },
      skip: 'Unskipped in 08-01 Task 2',
    );
  });
}
