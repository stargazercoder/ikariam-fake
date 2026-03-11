// Unit tests for Island and IslandDetail models — Phase 03 Plan 01
//
// Covers: MAP-01 (grid coordinates), MAP-02 (island metadata), MAP-03 (city aggregation)

import 'package:flutter_test/flutter_test.dart';
import 'package:ikariam/features/map/models/island.dart';
import 'package:ikariam/features/map/models/island_city_slot.dart';

void main() {
  group('Island model', () {
    test('parses grid_x and grid_y from Supabase JSON', () {
      final json = {
        'id': 'abc-123',
        'grid_x': 3,
        'grid_y': 2,
        'luxury_type': 'marble',
        'max_city_slots': 16,
      };

      final island = Island.fromJson(json);

      expect(island.id, 'abc-123');
      expect(island.gridX, 3);
      expect(island.gridY, 2);
    });

    test('exposes max_city_slots and luxury_type', () {
      final json = {
        'id': 'def-456',
        'grid_x': 1,
        'grid_y': 1,
        'luxury_type': 'crystal',
        'max_city_slots': 17,
      };

      final island = Island.fromJson(json);

      expect(island.luxuryType, 'crystal');
      expect(island.maxCitySlots, 17);
    });
  });

  group('IslandDetail', () {
    test('aggregates cities by slot_number correctly', () {
      final island = Island.fromJson({
        'id': 'ghi-789',
        'grid_x': 2,
        'grid_y': 1,
        'luxury_type': 'sulfur',
        'max_city_slots': 16,
      });

      final slots = [
        CitySlot.fromJson({
          'slot_number': 1,
          'name': 'Athens',
          'owner_id': 'user-001',
        }),
        CitySlot.fromJson({
          'slot_number': 2,
          'name': null,
          'owner_id': null,
        }),
        CitySlot.fromJson({
          'slot_number': 3,
          'name': 'Sparta',
          'owner_id': 'user-002',
        }),
      ];

      final detail = IslandDetail(island: island, citySlots: slots);

      expect(detail.island.id, 'ghi-789');
      expect(detail.citySlots.length, 3);
      expect(detail.cityCount, 2); // only slots with owner_id
      expect(detail.citySlots[0].cityName, 'Athens');
      expect(detail.citySlots[0].isOccupied, isTrue);
      expect(detail.citySlots[1].isOccupied, isFalse);
    });
  });
}
