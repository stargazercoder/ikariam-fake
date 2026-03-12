import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikariam/core/dev/dev_toolbar.dart';
import 'package:ikariam/features/city/providers/city_provider.dart';

void main() {
  group('DevToolbarWrapper', () {
    testWidgets('renders FAB in debug mode', (tester) async {
      // kDebugMode is always true in the flutter test environment.
      // Tree-shaking behaviour in release mode is verified via
      // `flutter build web --release` (cannot be tested in widget tests).
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Override cityProvider to return null — no Supabase call needed.
            cityProvider.overrideWith(_NullCityNotifier.new),
          ],
          child: const MaterialApp(
            home: DevToolbarWrapper(
              child: Scaffold(body: Text('Game')),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.developer_mode), findsOneWidget);
      expect(find.text('Game'), findsOneWidget);
    });

    testWidgets('child content is always rendered', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cityProvider.overrideWith(_NullCityNotifier.new),
          ],
          child: const MaterialApp(
            home: DevToolbarWrapper(
              child: Scaffold(body: Text('Content')),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Content'), findsOneWidget);
    });
  });
}

/// Stub notifier that returns null city — no Supabase call needed.
class _NullCityNotifier extends CityNotifier {
  @override
  Future<Map<String, dynamic>?> build() async => null;
}
