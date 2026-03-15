// Widget tests for BattleLossChart and PillageResultCard.
// Verifies chart rendering behavior and pillage card visibility.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ikariam/features/battles/models/battle_turn.dart';
import 'package:ikariam/features/battles/screens/widgets/battle_loss_chart.dart';
import 'package:ikariam/features/battles/screens/widgets/pillage_result_card.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

BattleTurn _mockTurn({
  int turnNumber = 1,
  Map<String, int>? navalAttackerCasualties,
  Map<String, int>? navalDefenderCasualties,
  Map<String, int>? landAttackerCasualties,
  Map<String, int>? landDefenderCasualties,
}) {
  return BattleTurn(
    id: 'turn-$turnNumber',
    battleId: 'battle-1',
    turnNumber: turnNumber,
    navalAttackerCasualties: navalAttackerCasualties,
    navalDefenderCasualties: navalDefenderCasualties,
    navalOutcome: navalAttackerCasualties != null ? 'ongoing' : null,
    landAttackerCasualties: landAttackerCasualties,
    landDefenderCasualties: landDefenderCasualties,
    landOutcome: landAttackerCasualties != null ? 'ongoing' : null,
    attackerSurvivors: const {},
    defenderSurvivors: const {},
    resolvedAt: DateTime.utc(2026, 3, 15, 12, 0, 0),
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

// ---------------------------------------------------------------------------
// BattleLossChart tests
// ---------------------------------------------------------------------------

void main() {
  group('BattleLossChart', () {
    testWidgets(
        'renders BarChart widgets when turns have casualties',
        (tester) async {
      final turns = [
        _mockTurn(
          turnNumber: 1,
          navalAttackerCasualties: {'ram_ship': 2},
          navalDefenderCasualties: {'diving_boat': 1},
          landAttackerCasualties: {'hoplite': 5},
          landDefenderCasualties: {'phalanx': 3},
        ),
        _mockTurn(
          turnNumber: 2,
          navalAttackerCasualties: {'cargo_ship': 1},
          navalDefenderCasualties: {'catapult_ship': 1},
          landAttackerCasualties: {'archer': 2},
          landDefenderCasualties: {},
        ),
        _mockTurn(
          turnNumber: 3,
          navalAttackerCasualties: {},
          navalDefenderCasualties: {'mortar_ship': 1},
          landAttackerCasualties: {'cavalry': 1},
          landDefenderCasualties: {'mortar': 1},
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 400,
            height: 600,
            child: BattleLossChart(turns: turns),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // At least one BarChart should be rendered (naval + land both have losses)
      expect(find.byType(BarChart), findsAtLeastNWidgets(1));
    });

    testWidgets(
        'renders no BarChart when turns list is empty',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 400,
            height: 600,
            child: BattleLossChart(turns: []),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Empty turns = no BarChart widgets
      expect(find.byType(BarChart), findsNothing);
    });

    testWidgets(
        'shows placeholder text when no casualties in a phase',
        (tester) async {
      // Turns have only land casualties — naval section should show placeholder
      final turns = [
        _mockTurn(
          turnNumber: 1,
          landAttackerCasualties: {'hoplite': 3},
          landDefenderCasualties: {'phalanx': 2},
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 400,
            height: 600,
            child: BattleLossChart(turns: turns),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No naval losses'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // PillageResultCard tests
  // ---------------------------------------------------------------------------

  group('PillageResultCard', () {
    testWidgets(
        'renders nothing when pillageResult is null',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PillageResultCard(
            pillageResult: null,
            isAttacker: true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(Card), findsNothing);
    });

    testWidgets(
        'renders nothing when pillageResult is empty map',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PillageResultCard(
            pillageResult: {},
            isAttacker: true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(Card), findsNothing);
    });

    testWidgets(
        'renders resource amounts for attacker view',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PillageResultCard(
            pillageResult: {'wood': 100, 'marble': 50},
            isAttacker: true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(Card), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      expect(find.text('Resources gained:'), findsOneWidget);
    });

    testWidgets(
        'shows Resources lost label for defender view',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PillageResultCard(
            pillageResult: {'crystal': 200, 'sulfur': 75},
            isAttacker: false,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(Card), findsOneWidget);
      expect(find.text('Resources lost:'), findsOneWidget);
      expect(find.text('200'), findsOneWidget);
      expect(find.text('75'), findsOneWidget);
    });
  });
}
