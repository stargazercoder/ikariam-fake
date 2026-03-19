// Widget tests for ResourceBadge.
// Verifies:
//   - Production resources render as CircleAvatar + letter
//   - Wine renders as Icon(Icons.wine_bar), not CircleAvatar + letter

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikariam/core/constants/resource_constants.dart';
import 'package:ikariam/shared/widgets/resource_badge.dart';

void main() {
  group('ResourceBadge — production resources', () {
    testWidgets('wood renders CircleAvatar containing W', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ResourceBadge(type: ResourceType.wood),
            ),
          ),
        ),
      );

      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.text('W'), findsOneWidget);
    });

    testWidgets('marble renders CircleAvatar containing M', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ResourceBadge(type: ResourceType.marble),
            ),
          ),
        ),
      );

      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.text('M'), findsOneWidget);
    });

    testWidgets('crystal renders CircleAvatar containing C', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ResourceBadge(type: ResourceType.crystal),
            ),
          ),
        ),
      );

      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
    });

    testWidgets('sulfur renders CircleAvatar containing S', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ResourceBadge(type: ResourceType.sulfur),
            ),
          ),
        ),
      );

      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.text('S'), findsOneWidget);
    });

    testWidgets('gold renders CircleAvatar containing G', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ResourceBadge(type: ResourceType.gold),
            ),
          ),
        ),
      );

      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.text('G'), findsOneWidget);
    });
  });

  group('ResourceBadge — wine (special case)', () {
    testWidgets('wine renders Icon(Icons.wine_bar), not a CircleAvatar with letter', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ResourceBadge(type: ResourceType.wine),
            ),
          ),
        ),
      );

      // Must find an Icon widget with wine_bar codepoint
      final iconFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Icon && widget.icon == Icons.wine_bar,
      );
      expect(iconFinder, findsOneWidget);

      // Must NOT render the letter V (CircleAvatar + Text)
      expect(find.text('V'), findsNothing);
      // Must NOT render a CircleAvatar (wine uses plain Icon)
      expect(find.byType(CircleAvatar), findsNothing);
    });
  });

  group('ResourceBadge — custom radius', () {
    testWidgets('accepts custom radius without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ResourceBadge(type: ResourceType.wood, radius: 16),
            ),
          ),
        ),
      );

      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.text('W'), findsOneWidget);
    });
  });
}
