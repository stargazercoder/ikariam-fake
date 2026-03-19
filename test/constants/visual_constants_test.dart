// Tests for visual_constants.dart — verifies map completeness for all enum values.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikariam/core/constants/building_constants.dart';
import 'package:ikariam/core/constants/resource_constants.dart';
import 'package:ikariam/core/constants/visual_constants.dart';

void main() {
  group('resourceTypeColor', () {
    test('has an entry for every ResourceType value', () {
      expect(
        resourceTypeColor.length,
        equals(ResourceType.values.length),
        reason: 'resourceTypeColor must cover all ${ResourceType.values.length} ResourceType values',
      );
    });

    test('wine is purple (Color(0xFF8E24AA))', () {
      expect(
        resourceTypeColor[ResourceType.wine],
        equals(const Color(0xFF8E24AA)),
        reason: 'Wine color is locked to purple.shade600 per PROJECT.md decision',
      );
    });

    test('all entries are non-null Colors', () {
      for (final type in ResourceType.values) {
        expect(
          resourceTypeColor[type],
          isNotNull,
          reason: 'resourceTypeColor[$type] must not be null',
        );
      }
    });
  });

  group('resourceTypeLetter', () {
    test('has an entry for every ResourceType value', () {
      expect(
        resourceTypeLetter.length,
        equals(ResourceType.values.length),
        reason: 'resourceTypeLetter must cover all ${ResourceType.values.length} ResourceType values',
      );
    });

    test('wood maps to W', () {
      expect(resourceTypeLetter[ResourceType.wood], equals('W'));
    });

    test('marble maps to M', () {
      expect(resourceTypeLetter[ResourceType.marble], equals('M'));
    });

    test('crystal maps to C', () {
      expect(resourceTypeLetter[ResourceType.crystal], equals('C'));
    });

    test('sulfur maps to S', () {
      expect(resourceTypeLetter[ResourceType.sulfur], equals('S'));
    });

    test('gold maps to G', () {
      expect(resourceTypeLetter[ResourceType.gold], equals('G'));
    });

    test('wine maps to V (avoids clash with Wood W)', () {
      expect(resourceTypeLetter[ResourceType.wine], equals('V'));
    });

    test('all entries are single uppercase letters', () {
      for (final type in ResourceType.values) {
        final letter = resourceTypeLetter[type];
        expect(letter, isNotNull, reason: 'resourceTypeLetter[$type] must not be null');
        expect(letter!.length, equals(1), reason: 'resourceTypeLetter[$type] must be a single character');
      }
    });
  });

  group('resourceTypeIcon', () {
    test('has an entry for every ResourceType value', () {
      expect(
        resourceTypeIcon.length,
        equals(ResourceType.values.length),
        reason: 'resourceTypeIcon must cover all ${ResourceType.values.length} ResourceType values',
      );
    });

    test('wine icon is Icons.wine_bar', () {
      expect(resourceTypeIcon[ResourceType.wine], equals(Icons.wine_bar));
    });

    test('all entries are non-null IconData', () {
      for (final type in ResourceType.values) {
        expect(
          resourceTypeIcon[type],
          isNotNull,
          reason: 'resourceTypeIcon[$type] must not be null',
        );
      }
    });
  });

  group('buildingTypeColor', () {
    test('has an entry for every BuildingType value', () {
      expect(
        buildingTypeColor.length,
        equals(BuildingType.values.length),
        reason: 'buildingTypeColor must cover all ${BuildingType.values.length} BuildingType values',
      );
    });

    test('all entries are non-null Colors', () {
      for (final type in BuildingType.values) {
        expect(
          buildingTypeColor[type],
          isNotNull,
          reason: 'buildingTypeColor[$type] must not be null',
        );
      }
    });
  });

  group('buildingTypeIcon', () {
    test('has an entry for every BuildingType value', () {
      expect(
        buildingTypeIcon.length,
        equals(BuildingType.values.length),
        reason: 'buildingTypeIcon must cover all ${BuildingType.values.length} BuildingType values',
      );
    });

    test('all entries are non-null IconData', () {
      for (final type in BuildingType.values) {
        expect(
          buildingTypeIcon[type],
          isNotNull,
          reason: 'buildingTypeIcon[$type] must not be null',
        );
      }
    });
  });
}
