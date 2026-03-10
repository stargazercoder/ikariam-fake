// Scaffold for INFR-02 and INFR-03: RLS enforcement integration tests.
//
// These tests will be implemented once the database schema with RLS policies
// is created in Plan 01-01.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('RLS Enforcement', () {
    testWidgets(
      'client cannot INSERT into cities table',
      (WidgetTester tester) async {
        // TODO: needs running Supabase with RLS policies from Plan 01-01
      },
      skip: true,
    );

    testWidgets(
      'client cannot INSERT into islands table',
      (WidgetTester tester) async {
        // TODO: needs running Supabase with RLS policies from Plan 01-01
      },
      skip: true,
    );

    testWidgets(
      'client cannot UPDATE game-state tables directly',
      (WidgetTester tester) async {
        // TODO: needs running Supabase with RLS policies from Plan 01-01
      },
      skip: true,
    );
  });
}
