// Smoke test for WorldMapScreen rendering.
//
// Covers: MAP-05 (world map screen renders without error)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikariam/features/map/models/island.dart';
import 'package:ikariam/features/map/providers/islands_provider.dart';
import 'package:ikariam/features/map/screens/world_map_screen.dart';

void main() {
  testWidgets(
    'WorldMapScreen renders without error',
    (tester) async {
      final fakeIslands = [
        const Island(
          id: 'island-1',
          gridX: 0,
          gridY: 0,
          luxuryType: 'marble',
          maxCitySlots: 16,
        ),
        const Island(
          id: 'island-2',
          gridX: 1,
          gridY: 0,
          luxuryType: 'crystal',
          maxCitySlots: 12,
        ),
        const Island(
          id: 'island-3',
          gridX: 2,
          gridY: 1,
          luxuryType: 'sulfur',
          maxCitySlots: 8,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allIslandsProvider.overrideWith((ref) async => fakeIslands),
          ],
          child: const MaterialApp(
            home: WorldMapScreen(),
          ),
        ),
      );

      // Pump to let FutureProvider resolve.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify no uncaught exceptions and the screen renders.
      expect(tester.takeException(), isNull);

      // Should find at least one island coordinate text.
      expect(find.textContaining('('), findsWidgets);
    },
  );
}
