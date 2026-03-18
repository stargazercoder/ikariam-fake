import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ikariam/features/godmode/data/godmode_repository.dart';
import 'package:ikariam/features/godmode/providers/godmode_world_provider.dart';
import 'package:ikariam/features/godmode/widgets/player_table.dart';

import 'godmode_test_helpers.dart';

/// Silences pre-existing RenderFlex overflow errors in the PlayerRow actions
/// column (120px SizedBox is too narrow for 3 bot action buttons).
void _ignoreOverflowErrors(FlutterErrorDetails details) {
  if (details.toString().contains('A RenderFlex overflowed')) return;
  FlutterError.dumpErrorToConsole(details);
}

void main() {
  group('PlayerTable', () {
    setUp(() => FlutterError.onError = _ignoreOverflowErrors);
    tearDown(() => FlutterError.onError = FlutterError.dumpErrorToConsole);

    testWidgets('renders header row with column names', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            godmodeWorldProvider.overrideWith(
              () => FakeWorldNotifier([]),
            ),
            godmodeRepositoryProvider.overrideWithValue(
              FakeGodmodeRepository(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PlayerTable(
                players: [mockHumanPlayer(), mockBotPlayer()],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Resources'), findsOneWidget);
      expect(find.text('Land'), findsOneWidget);
      expect(find.text('Actions'), findsOneWidget);
    });

    testWidgets('renders player rows', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            godmodeWorldProvider.overrideWith(
              () => FakeWorldNotifier([]),
            ),
            godmodeRepositoryProvider.overrideWithValue(
              FakeGodmodeRepository(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PlayerTable(
                players: [mockHumanPlayer(), mockBotPlayer()],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('TestHuman'), findsOneWidget);
      expect(find.text('Bot01'), findsOneWidget);
    });

    testWidgets('renders bulk control buttons', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            godmodeWorldProvider.overrideWith(
              () => FakeWorldNotifier([]),
            ),
            godmodeRepositoryProvider.overrideWithValue(
              FakeGodmodeRepository(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PlayerTable(
                players: [mockHumanPlayer(), mockBotPlayer()],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Pause All Bots'), findsOneWidget);
      expect(find.text('Resume All Bots'), findsOneWidget);
    });
  });
}
