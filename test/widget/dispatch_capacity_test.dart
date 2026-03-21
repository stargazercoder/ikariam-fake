// Test scaffold for carry capacity indicator in dispatch screen.
//
// Covers: BTUI-02 (carry capacity display in dispatch dialog)
//
// Stubs verify the _CargoCapacityRow widget renders
// correct capacity values and warning states.

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Carry capacity row shows "0 / Y" with warning when no cargo ships selected',
    (tester) async {
      // TODO: pump _CargoCapacityRow with controllers['cargo_ship'].text = '0'
      // and roster containing cargo_ship with quantity 5
      // Verify: find.text('0 / 2500') findsOneWidget
      // Verify: find.text('No cargo ships \u2014 army cannot carry loot') findsOneWidget
    },
    skip: true,
  );

  testWidgets(
    'Carry capacity row shows correct capacity for N cargo ships',
    (tester) async {
      // TODO: pump _CargoCapacityRow with controllers['cargo_ship'].text = '3'
      // and roster containing cargo_ship with quantity 5
      // Verify: find.text('1500 / 2500') findsOneWidget
      // Verify: find.text('No cargo ships') findsNothing (warning hidden)
    },
    skip: true,
  );

  testWidgets(
    'Carry capacity row hidden when roster has no cargo ships',
    (tester) async {
      // TODO: pump _CargoCapacityRow with empty roster (no cargo_ship unit)
      // Verify: find.text('Carry Capacity') findsNothing
    },
    skip: true,
  );
}
