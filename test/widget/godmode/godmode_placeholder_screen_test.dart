import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ikariam/features/godmode/screens/godmode_placeholder_screen.dart';

void main() {
  group('GodModePlaceholderScreen', () {
    testWidgets('renders GodMode title and placeholder text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GodModePlaceholderScreen(),
        ),
      );
      expect(find.text('GodMode'), findsOneWidget);
      expect(
        find.text('GodMode Dashboard — Coming in Phase 22'),
        findsOneWidget,
      );
    });
  });
}
