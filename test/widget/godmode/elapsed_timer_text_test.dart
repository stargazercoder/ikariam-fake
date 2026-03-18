import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ikariam/features/godmode/widgets/elapsed_timer_text.dart';

void main() {
  group('ElapsedTimerText', () {
    testWidgets('renders elapsed seconds text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElapsedTimerText(since: DateTime.now()),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('s ago'), findsOneWidget);

      // Dispose widget to cancel Timer.periodic — prevents "setState after dispose".
      await tester.pumpWidget(Container());
    });

    testWidgets('timer increments after 1 second', (tester) async {
      final since = DateTime.now();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElapsedTimerText(since: since),
          ),
        ),
      );
      await tester.pump();

      final initialText = tester
          .widget<Text>(find.textContaining('s ago'))
          .data!;

      await tester.pump(const Duration(seconds: 1));

      final updatedText = tester
          .widget<Text>(find.textContaining('s ago'))
          .data!;

      // The elapsed number should have incremented by 1.
      expect(updatedText, isNot(equals(initialText)));

      // Dispose widget to cancel Timer.periodic.
      await tester.pumpWidget(Container());
    });
  });
}
