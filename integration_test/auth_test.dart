// Scaffold for AUTH-01: Full signup flow integration test.
//
// This test will be implemented once a running Supabase project is connected
// in Plan 01-01 and auth screens are built in Plan 01-02.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Auth Integration', () {
    testWidgets(
      'user can sign up with email and password',
      (WidgetTester tester) async {
        // TODO: needs running Supabase instance and auth screens from Plan 01-02
      },
      skip: true,
    );

    testWidgets(
      'user session persists after app restart',
      (WidgetTester tester) async {
        // TODO: needs running Supabase instance and auth screens from Plan 01-02
      },
      skip: true,
    );
  });
}
