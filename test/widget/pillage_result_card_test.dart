// Test scaffold for PillageResultCard widget.
//
// Covers: BTUI-01 (pillage resource breakdown in battle reports)
//
// Stubs verify the existing PillageResultCard implementation
// renders correct labels for attacker vs defender.

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'PillageResultCard shows "Resources gained:" for attacker',
    (tester) async {
      // TODO: pump PillageResultCard with isAttacker: true and non-empty pillageResult
      // Verify: find.text('Resources gained:') findsOneWidget
    },
    skip: true,
  );

  testWidgets(
    'PillageResultCard shows "Resources lost:" for defender',
    (tester) async {
      // TODO: pump PillageResultCard with isAttacker: false and non-empty pillageResult
      // Verify: find.text('Resources lost:') findsOneWidget
    },
    skip: true,
  );

  testWidgets(
    'PillageResultCard renders SizedBox.shrink when pillageResult is null',
    (tester) async {
      // TODO: pump PillageResultCard with pillageResult: null
      // Verify: find.byType(Card) findsNothing
    },
    skip: true,
  );

  testWidgets(
    'PillageResultCard shows per-resource breakdown with ResourceBadge',
    (tester) async {
      // TODO: pump PillageResultCard with pillageResult: {'wood': 100, 'marble': 50}
      // Verify: find.text('100') and find.text('50') findsOneWidget each
    },
    skip: true,
  );
}
