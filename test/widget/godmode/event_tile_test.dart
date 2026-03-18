import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ikariam/features/godmode/widgets/event_tile.dart';

import 'godmode_test_helpers.dart';

void main() {
  group('EventTile', () {
    testWidgets('renders battle event with sword icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventTile(event: mockBattleEvent()),
          ),
        ),
      );
      expect(find.byIcon(Icons.sports_kabaddi), findsOneWidget);
      expect(find.text('Battle turn 2 - active'), findsOneWidget);
    });

    testWidgets('renders trade event with inventory icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventTile(event: mockTradeEvent()),
          ),
        ),
      );
      expect(find.byIcon(Icons.inventory_2), findsOneWidget);
      expect(find.text('Trade completed'), findsOneWidget);
    });

    testWidgets('renders espionage event with visibility icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventTile(event: mockEspionageEvent()),
          ),
        ),
      );
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('renders formatted timestamp', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventTile(event: mockBattleEvent()),
          ),
        ),
      );
      // mockBattleEvent timestamp: DateTime(2026, 3, 18, 10, 30)
      expect(find.text('2026-03-18 10:30'), findsOneWidget);
    });
  });
}
