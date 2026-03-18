import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ikariam/features/godmode/widgets/bot_badge.dart';

void main() {
  group('BotBadge', () {
    testWidgets('renders BOT text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: BotBadge()),
        ),
      );
      expect(find.text('BOT'), findsOneWidget);
    });

    testWidgets('has orange background', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: BotBadge()),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, equals(Colors.orange));
    });
  });
}
