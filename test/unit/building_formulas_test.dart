// Tests for building upgrade cost and time formulas, and Dart model parsing.
//
// Covers: BLDG-02 (cost formula), BLDG-03 (time formula), BLDG-04 (model parsing)

import 'package:flutter_test/flutter_test.dart';
import 'package:ikariam/core/constants/building_constants.dart';
import 'package:ikariam/core/constants/resource_constants.dart';
import 'package:ikariam/features/city/models/city_building.dart';
import 'package:ikariam/features/city/models/city_resource.dart';
import 'package:ikariam/features/city/models/construction_queue_entry.dart';

void main() {
  group('upgradeCost formula', () {
    test('warehouse level 0 returns base cost {wood: 100, marble: 50}', () {
      final cost = upgradeCost(BuildingType.warehouse, 0);
      expect(cost[ResourceType.wood], 100);
      expect(cost[ResourceType.marble], 50);
    });

    test(
      'warehouse level 2 returns {wood: 225, marble: 113} (1.5^2 with ceil)',
      () {
        final cost = upgradeCost(BuildingType.warehouse, 2);
        // 100 * 1.5^2 = 225.0
        expect(cost[ResourceType.wood], 225);
        // 50 * 1.5^2 = 112.5 -> ceil = 113
        expect(cost[ResourceType.marble], 113);
      },
    );

    test('town_hall level 0 returns base cost {gold: 100, wood: 200}', () {
      final cost = upgradeCost(BuildingType.townHall, 0);
      expect(cost[ResourceType.gold], 100);
      expect(cost[ResourceType.wood], 200);
    });

    test('sawmill level 0 returns base cost {wood: 50, gold: 50}', () {
      final cost = upgradeCost(BuildingType.sawmill, 0);
      expect(cost[ResourceType.wood], 50);
      expect(cost[ResourceType.gold], 50);
    });
  });

  group('upgradeDurationMinutes formula', () {
    test('warehouse level 0 returns base time 5', () {
      expect(upgradeDurationMinutes(BuildingType.warehouse, 0), 5);
    });

    test('warehouse level 3 returns 9 (5 * 1.2^3 = 8.64, ceil = 9)', () {
      expect(upgradeDurationMinutes(BuildingType.warehouse, 3), 9);
    });

    test('town_hall level 0 returns base time 10', () {
      expect(upgradeDurationMinutes(BuildingType.townHall, 0), 10);
    });

    test('sawmill level 0 returns base time 3', () {
      expect(upgradeDurationMinutes(BuildingType.sawmill, 0), 3);
    });

    test('returns ceil of fractional result', () {
      // warehouse level 1: 5 * 1.2^1 = 6.0 exactly
      expect(upgradeDurationMinutes(BuildingType.warehouse, 1), 6);
      // warehouse level 2: 5 * 1.2^2 = 7.2 -> ceil = 8
      expect(upgradeDurationMinutes(BuildingType.warehouse, 2), 8);
    });
  });

  group('BuildingType enum', () {
    test('has 14 values', () {
      expect(BuildingType.values.length, 14);
    });

    test('dbName returns correct snake_case values', () {
      expect(BuildingType.townHall.dbName, 'town_hall');
      expect(BuildingType.warehouse.dbName, 'warehouse');
      expect(BuildingType.tradingPort.dbName, 'trading_port');
      expect(BuildingType.townWall.dbName, 'town_wall');
      expect(BuildingType.sawmill.dbName, 'sawmill');
      expect(BuildingType.sulfurPit.dbName, 'sulfur_pit');
      expect(BuildingType.glassblower.dbName, 'glassblower');
    });

    test('isProductionBuilding returns true only for 4 production types', () {
      expect(BuildingType.sawmill.isProductionBuilding, isTrue);
      expect(BuildingType.quarry.isProductionBuilding, isTrue);
      expect(BuildingType.glassblower.isProductionBuilding, isTrue);
      expect(BuildingType.sulfurPit.isProductionBuilding, isTrue);
      expect(BuildingType.townHall.isProductionBuilding, isFalse);
      expect(BuildingType.warehouse.isProductionBuilding, isFalse);
      expect(BuildingType.barracks.isProductionBuilding, isFalse);
    });
  });

  group('ResourceType enum', () {
    test('value getter returns correct DB string', () {
      expect(ResourceType.wood.value, 'wood');
      expect(ResourceType.marble.value, 'marble');
      expect(ResourceType.crystal.value, 'crystal');
      expect(ResourceType.sulfur.value, 'sulfur');
      expect(ResourceType.gold.value, 'gold');
    });
  });

  group('CityResource.fromJson', () {
    test('parses Supabase row correctly', () {
      final json = {
        'id': 'res-uuid-001',
        'city_id': 'city-uuid-001',
        'resource_type': 'wood',
        'amount': 250.0,
        'updated_at': '2026-03-11T00:00:00.000Z',
      };
      final resource = CityResource.fromJson(json);
      expect(resource.id, 'res-uuid-001');
      expect(resource.cityId, 'city-uuid-001');
      expect(resource.resourceType, ResourceType.wood);
      expect(resource.amount, 250.0);
      expect(resource.updatedAt, isA<DateTime>());
    });

    test('toJson returns correct map', () {
      final json = {
        'id': 'res-uuid-002',
        'city_id': 'city-uuid-002',
        'resource_type': 'gold',
        'amount': 500.0,
        'updated_at': '2026-03-11T00:00:00.000Z',
      };
      final resource = CityResource.fromJson(json);
      final result = resource.toJson();
      expect(result['resource_type'], 'gold');
    });
  });

  group('CityBuilding.fromJson', () {
    test('parses Supabase row correctly', () {
      final json = {
        'id': 'bld-uuid-001',
        'city_id': 'city-uuid-001',
        'building_type': 'warehouse',
        'level': 2,
        'assigned_workers': 5,
        'updated_at': '2026-03-11T00:00:00.000Z',
      };
      final building = CityBuilding.fromJson(json);
      expect(building.id, 'bld-uuid-001');
      expect(building.cityId, 'city-uuid-001');
      expect(building.buildingType, BuildingType.warehouse);
      expect(building.level, 2);
      expect(building.assignedWorkers, 5);
    });

    test('parses town_hall building_type correctly', () {
      final json = {
        'id': 'bld-uuid-002',
        'city_id': 'city-uuid-001',
        'building_type': 'town_hall',
        'level': 1,
        'assigned_workers': 0,
        'updated_at': '2026-03-11T00:00:00.000Z',
      };
      final building = CityBuilding.fromJson(json);
      expect(building.buildingType, BuildingType.townHall);
    });
  });

  group('ConstructionQueueEntry.fromJson', () {
    test('parses Supabase row with finish_at as UTC DateTime', () {
      final futureTime = DateTime.now().toUtc().add(const Duration(minutes: 5));
      final json = {
        'id': 'que-uuid-001',
        'city_id': 'city-uuid-001',
        'building_type': 'warehouse',
        'target_level': 3,
        'finish_at': futureTime.toIso8601String(),
        'created_at': '2026-03-11T00:00:00.000Z',
      };
      final entry = ConstructionQueueEntry.fromJson(json);
      expect(entry.id, 'que-uuid-001');
      expect(entry.cityId, 'city-uuid-001');
      expect(entry.buildingType, 'warehouse');
      expect(entry.targetLevel, 3);
      expect(entry.finishAt.isUtc, isTrue);
    });

    test('isComplete returns false when finishAt is in the future', () {
      final futureTime = DateTime.now().toUtc().add(const Duration(minutes: 5));
      final json = {
        'id': 'que-uuid-002',
        'city_id': 'city-uuid-001',
        'building_type': 'barracks',
        'target_level': 2,
        'finish_at': futureTime.toIso8601String(),
        'created_at': '2026-03-11T00:00:00.000Z',
      };
      final entry = ConstructionQueueEntry.fromJson(json);
      expect(entry.isComplete, isFalse);
    });

    test('isComplete returns true when finishAt is in the past', () {
      final pastTime = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
      final json = {
        'id': 'que-uuid-003',
        'city_id': 'city-uuid-001',
        'building_type': 'barracks',
        'target_level': 2,
        'finish_at': pastTime.toIso8601String(),
        'created_at': '2026-03-11T00:00:00.000Z',
      };
      final entry = ConstructionQueueEntry.fromJson(json);
      expect(entry.isComplete, isTrue);
    });
  });
}
