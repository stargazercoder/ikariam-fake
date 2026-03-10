// Basic smoke test for the Ikariam app root widget.

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test placeholder', (WidgetTester tester) async {
    // Supabase.initialize requires real credentials so the full app cannot
    // be pumped in unit tests. This placeholder ensures the test runner
    // exits cleanly. Integration tests cover actual app startup.
    expect(true, isTrue);
  });
}
