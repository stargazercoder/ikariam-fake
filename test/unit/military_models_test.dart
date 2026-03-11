// Test scaffolds for military data models.
//
// Covers: MIL-04 (TrainingQueueEntry, CityUnit fromJson, isComplete),
//         MIL-05 (UnitMovement fromJson, remaining travel time)
//
// All tests are skipped stubs — implementation lives in Plan 04-02.

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrainingQueueEntry', () {
    test(
      'fromJson parses Supabase row correctly',
      () {
        // TODO: implement when TrainingQueueEntry model is built in Plan 04-02
      },
      skip: 'TODO: 04-02',
    );

    test(
      'isComplete returns true when finishAt is past',
      () {
        // TODO: implement when TrainingQueueEntry model is built in Plan 04-02
      },
      skip: 'TODO: 04-02',
    );
  });

  group('CityUnit', () {
    test(
      'fromJson parses Supabase row correctly',
      () {
        // TODO: implement when CityUnit model is built in Plan 04-02
      },
      skip: 'TODO: 04-02',
    );
  });

  group('UnitMovement', () {
    test(
      'fromJson parses JSONB units field correctly',
      () {
        // TODO: implement when UnitMovement model is built in Plan 04-02
      },
      skip: 'TODO: 04-02',
    );

    test(
      'remaining travel time calculation works',
      () {
        // TODO: implement when UnitMovement model is built in Plan 04-02
      },
      skip: 'TODO: 04-02',
    );
  });
}
