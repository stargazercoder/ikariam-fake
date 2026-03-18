import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ikariam/features/godmode/data/godmode_repository.dart';
import 'package:ikariam/features/godmode/models/godmode_player.dart';
import 'package:ikariam/features/godmode/providers/godmode_events_provider.dart';
import 'package:ikariam/features/godmode/providers/godmode_world_provider.dart';
import 'package:ikariam/features/godmode/screens/godmode_dashboard_screen.dart';

import 'godmode_test_helpers.dart';

/// Silences pre-existing RenderFlex overflow errors in the PlayerRow actions
/// column (120px SizedBox is too narrow for 3 bot action buttons).
void _ignoreOverflowErrors(FlutterErrorDetails details) {
  if (details.toString().contains('A RenderFlex overflowed')) return;
  FlutterError.dumpErrorToConsole(details);
}

/// Notifier that stays in loading state forever — used to test the loading UI.
class _LoadingWorldNotifier extends GodmodeWorldNotifier {
  @override
  Future<List<GodmodePlayer>> build() async {
    await Completer<void>().future; // never completes
    return [];
  }

  @override
  bool get isRefreshing => false;

  @override
  DateTime get lastUpdated => DateTime(2026, 3, 18);
}

void main() {
  group('GodModeDashboardScreen', () {
    setUp(() {
      // Silence pre-existing PlayerRow actions column overflow.
      FlutterError.onError = _ignoreOverflowErrors;
    });
    tearDown(() {
      FlutterError.onError = FlutterError.dumpErrorToConsole;
    });

    testWidgets('shows loading spinner while world state loads', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            godmodeWorldProvider.overrideWith(_LoadingWorldNotifier.new),
            godmodeEventsProvider.overrideWith(
              () => FakeEventsNotifier([]),
            ),
            godmodeEventFilterProvider.overrideWith(
              FakeEventFilterNotifier.new,
            ),
            godmodeRepositoryProvider.overrideWithValue(
              FakeGodmodeRepository(),
            ),
          ],
          child: const MaterialApp(
            home: GodModeDashboardScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // Dispose widget to cancel any active timers (ElapsedTimerText).
      await tester.pumpWidget(Container());
    });

    testWidgets('shows error message on world state failure', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            godmodeWorldProvider.overrideWith(ErrorWorldNotifier.new),
            godmodeEventsProvider.overrideWith(
              () => FakeEventsNotifier([]),
            ),
            godmodeEventFilterProvider.overrideWith(
              FakeEventFilterNotifier.new,
            ),
            godmodeRepositoryProvider.overrideWithValue(
              FakeGodmodeRepository(),
            ),
          ],
          child: const MaterialApp(
            home: GodModeDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Failed to load world'), findsOneWidget);

      // Dispose widget to cancel ElapsedTimerText timer.
      await tester.pumpWidget(Container());
    });

    testWidgets('shows GodMode title and tabs when data loaded', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            godmodeWorldProvider.overrideWith(
              () => FakeWorldNotifier([mockHumanPlayer(), mockBotPlayer()]),
            ),
            godmodeEventsProvider.overrideWith(
              () => FakeEventsNotifier([mockBattleEvent()]),
            ),
            godmodeEventFilterProvider.overrideWith(
              FakeEventFilterNotifier.new,
            ),
            godmodeRepositoryProvider.overrideWithValue(
              FakeGodmodeRepository(),
            ),
          ],
          child: const MaterialApp(
            home: GodModeDashboardScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('GodMode'), findsOneWidget);
      expect(find.text('Players'), findsOneWidget);
      expect(find.text('Events'), findsOneWidget);

      // Dispose to cancel ElapsedTimerText timer.
      await tester.pumpWidget(Container());
    });

    testWidgets('shows player table in Players tab when data loaded',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            godmodeWorldProvider.overrideWith(
              () => FakeWorldNotifier([mockHumanPlayer(), mockBotPlayer()]),
            ),
            godmodeEventsProvider.overrideWith(
              () => FakeEventsNotifier([mockBattleEvent()]),
            ),
            godmodeEventFilterProvider.overrideWith(
              FakeEventFilterNotifier.new,
            ),
            godmodeRepositoryProvider.overrideWithValue(
              FakeGodmodeRepository(),
            ),
          ],
          child: const MaterialApp(
            home: GodModeDashboardScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('TestHuman'), findsOneWidget);
      expect(find.text('Bot01'), findsOneWidget);

      // Dispose to cancel ElapsedTimerText timer.
      await tester.pumpWidget(Container());
    });
  });
}
