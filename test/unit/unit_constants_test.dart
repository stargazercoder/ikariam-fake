// Test scaffolds for military unit constants.
//
// Covers: MIL-01 (8 land unit types), MIL-02 (5 naval unit types),
//         MIL-03 (unlock levels), MIL-05 (travel time formula)
//
// All tests are skipped stubs — implementation lives in Plan 04-02.

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UnitType enum', () {
    test(
      'has 8 land unit types',
      () {
        // TODO: implement when UnitType enum is built in Plan 04-02
      },
      skip: 'TODO: 04-02',
    );

    test(
      'has 5 naval unit types',
      () {
        // TODO: implement when UnitType enum is built in Plan 04-02
      },
      skip: 'TODO: 04-02',
    );

    test(
      'isNaval returns true only for naval units',
      () {
        // TODO: implement when UnitType enum is built in Plan 04-02
      },
      skip: 'TODO: 04-02',
    );

    test(
      'dbName returns correct snake_case string for all types',
      () {
        // TODO: implement when UnitType enum is built in Plan 04-02
      },
      skip: 'TODO: 04-02',
    );
  });

  group('unitUnlockLevels', () {
    test(
      'covers all 13 unit types',
      () {
        // TODO: implement when unitUnlockLevels map is built in Plan 04-02
      },
      skip: 'TODO: 04-02',
    );

    test(
      'land units require barracks levels 1-5',
      () {
        // TODO: implement when unitUnlockLevels map is built in Plan 04-02
      },
      skip: 'TODO: 04-02',
    );

    test(
      'naval units require shipyard levels 1-4',
      () {
        // TODO: implement when unitUnlockLevels map is built in Plan 04-02
      },
      skip: 'TODO: 04-02',
    );
  });

  group('travel time formula', () {
    test(
      'same coordinates returns minimum 1 minute',
      () {
        // TODO: implement when calcTravelMinutes is built in Plan 04-02
      },
      skip: 'TODO: 04-02',
    );

    test(
      'distance between islands calculates correctly',
      () {
        // TODO: implement when calcTravelMinutes is built in Plan 04-02
      },
      skip: 'TODO: 04-02',
    );
  });
}
