import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ikariam/features/godmode/models/godmode_event.dart';
import 'package:ikariam/features/godmode/providers/godmode_events_provider.dart';
import 'package:ikariam/features/godmode/widgets/event_feed.dart';

import 'godmode_test_helpers.dart';

/// Notifier that stays in loading state forever — used to test the loading UI.
class _LoadingEventsNotifier extends GodmodeEventsNotifier {
  @override
  Future<List<GodmodeEvent>> build() async {
    await Completer<void>().future; // never completes
    return [];
  }
}

void main() {
  group('EventFeed', () {
    testWidgets('shows loading spinner while events load', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            godmodeEventsProvider.overrideWith(_LoadingEventsNotifier.new),
            godmodeEventFilterProvider.overrideWith(
              FakeEventFilterNotifier.new,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: EventFeed()),
          ),
        ),
      );
      // Let provider start its async build.
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message on failure', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            godmodeEventsProvider.overrideWith(ErrorEventsNotifier.new),
            godmodeEventFilterProvider.overrideWith(
              FakeEventFilterNotifier.new,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: EventFeed()),
          ),
        ),
      );
      // Run all frames until the error async state propagates.
      await tester.pumpAndSettle();
      expect(find.textContaining('Failed to load events'), findsOneWidget);
    });

    testWidgets('shows event tiles when data loaded', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            godmodeEventsProvider.overrideWith(
              () => FakeEventsNotifier([mockBattleEvent(), mockTradeEvent()]),
            ),
            godmodeEventFilterProvider.overrideWith(
              FakeEventFilterNotifier.new,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: EventFeed()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.text('Battle turn 2 - active'), findsOneWidget);
      expect(find.text('Trade completed'), findsOneWidget);
    });

    testWidgets('shows filter chips', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            godmodeEventsProvider.overrideWith(
              () => FakeEventsNotifier([mockBattleEvent(), mockTradeEvent()]),
            ),
            godmodeEventFilterProvider.overrideWith(
              FakeEventFilterNotifier.new,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: EventFeed()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Battle'), findsOneWidget);
      expect(find.text('Trade'), findsOneWidget);
      expect(find.text('Espionage'), findsOneWidget);
    });
  });
}
