// Tests for military data models.
//
// Covers: MIL-04 (TrainingQueueEntry, CityUnit fromJson, isComplete),
//         MIL-05 (UnitMovement fromJson, remaining travel time)

import 'package:flutter_test/flutter_test.dart';
import 'package:ikariam/features/military/models/training_queue_entry.dart';
import 'package:ikariam/features/military/models/city_unit.dart';
import 'package:ikariam/features/military/models/unit_movement.dart';

void main() {
  group('TrainingQueueEntry', () {
    test('fromJson parses Supabase row correctly', () {
      final json = {
        'id': 'tq-uuid-001',
        'city_id': 'city-uuid-001',
        'unit_type': 'hoplite',
        'quantity': 10,
        'finish_at': '2026-03-11T15:00:00.000Z',
        'created_at': '2026-03-11T14:00:00.000Z',
      };

      final entry = TrainingQueueEntry.fromJson(json);

      expect(entry.id, equals('tq-uuid-001'));
      expect(entry.cityId, equals('city-uuid-001'));
      expect(entry.unitType, equals('hoplite'));
      expect(entry.quantity, equals(10));
      expect(entry.finishAt, equals(DateTime.utc(2026, 3, 11, 15, 0, 0)));
      expect(entry.createdAt, equals(DateTime.utc(2026, 3, 11, 14, 0, 0)));
    });

    test('isComplete returns true when finishAt is past', () {
      final pastEntry = TrainingQueueEntry(
        id: 'tq-past',
        cityId: 'city-001',
        unitType: 'archer',
        quantity: 5,
        finishAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
        createdAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
      );
      expect(pastEntry.isComplete, isTrue);

      final futureEntry = TrainingQueueEntry(
        id: 'tq-future',
        cityId: 'city-001',
        unitType: 'archer',
        quantity: 5,
        finishAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        createdAt: DateTime.now().toUtc(),
      );
      expect(futureEntry.isComplete, isFalse);
    });
  });

  group('CityUnit', () {
    test('fromJson parses Supabase row correctly', () {
      final json = {
        'id': 'cu-uuid-001',
        'city_id': 'city-uuid-001',
        'unit_type': 'archer',
        'quantity': 25,
        'updated_at': '2026-03-11T14:30:00.000Z',
      };

      final unit = CityUnit.fromJson(json);

      expect(unit.id, equals('cu-uuid-001'));
      expect(unit.cityId, equals('city-uuid-001'));
      expect(unit.unitType, equals('archer'));
      expect(unit.quantity, equals(25));
      expect(unit.updatedAt, equals(DateTime.utc(2026, 3, 11, 14, 30, 0)));
    });
  });

  group('UnitMovement', () {
    test('fromJson parses JSONB units field correctly', () {
      final json = {
        'id': 'um-uuid-001',
        'origin_city_id': 'city-origin',
        'destination_city_id': 'city-dest',
        'owner_id': 'user-uuid-001',
        'units': {'hoplite': 10, 'archer': 5},
        'depart_at': '2026-03-11T14:00:00.000Z',
        'arrive_at': '2026-03-11T14:50:00.000Z',
        'created_at': '2026-03-11T14:00:00.000Z',
      };

      final movement = UnitMovement.fromJson(json);

      expect(movement.id, equals('um-uuid-001'));
      expect(movement.originCityId, equals('city-origin'));
      expect(movement.destinationCityId, equals('city-dest'));
      expect(movement.ownerId, equals('user-uuid-001'));
      expect(movement.units, equals({'hoplite': 10, 'archer': 5}));
      expect(movement.departAt, equals(DateTime.utc(2026, 3, 11, 14, 0, 0)));
      expect(movement.arriveAt, equals(DateTime.utc(2026, 3, 11, 14, 50, 0)));
    });

    test('remaining travel time calculation works', () {
      final futureMovement = UnitMovement(
        id: 'um-future',
        originCityId: 'city-a',
        destinationCityId: 'city-b',
        ownerId: 'user-001',
        units: const {'hoplite': 10},
        departAt: DateTime.now().toUtc().subtract(const Duration(minutes: 10)),
        arriveAt: DateTime.now().toUtc().add(const Duration(minutes: 40)),
        createdAt: DateTime.now().toUtc().subtract(const Duration(minutes: 10)),
      );

      expect(futureMovement.hasArrived, isFalse);
      expect(futureMovement.remainingTravelTime.inMinutes,
          greaterThan(30)); // roughly 40 minutes remaining

      final arrivedMovement = UnitMovement(
        id: 'um-arrived',
        originCityId: 'city-a',
        destinationCityId: 'city-b',
        ownerId: 'user-001',
        units: const {'hoplite': 10},
        departAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
        arriveAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
        createdAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
      );

      expect(arrivedMovement.hasArrived, isTrue);
    });
  });
}
