// Tests for partial army engagement formula (CMBT-02).
// Verifies that engagement fraction, damage calculation, and casualty
// application all follow the 30% engagement model.
//
// Wave 0 stubs — unskipped in 08-02 Task 2 when engagement logic is added.

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('partial army engagement (CMBT-02)', () {
    test(
      'engagement fraction is 30%',
      () {
        // The engagement constant must equal 0.30 (30% of army engages per turn)
        const engagementFraction = 0.30;
        expect(engagementFraction, equals(0.30));
      },
      skip: 'Unskipped in 08-02 Task 2',
    );

    test(
      'only engaged units participate in damage calculation',
      () {
        // Given 100 hoplites at 30% engagement: 30 units engage, 70 hold back.
        // Only the 30 engaged units contribute attack/defense power.
        const total = 100;
        const engagementFraction = 0.30;
        final engaged = (total * engagementFraction).floor();
        expect(engaged, equals(30));
      },
      skip: 'Unskipped in 08-02 Task 2',
    );

    test(
      'casualties applied only to engaged subset',
      () {
        // Given 30 engaged units with 50% loss ratio:
        // casualties = floor(30 * 0.5) = 15
        // survivors = 100 - 15 = 85
        const totalArmy = 100;
        const engaged = 30;
        const lossRatio = 0.50;
        final casualties = (engaged * lossRatio).floor();
        final survivors = totalArmy - casualties;
        expect(casualties, equals(15));
        expect(survivors, equals(85));
      },
      skip: 'Unskipped in 08-02 Task 2',
    );

    test(
      'minimum 1 unit engages when army > 0',
      () {
        // Given 2 units at 30% engagement: floor(2 * 0.3) = floor(0.6) = 0
        // Must clamp to minimum of 1 to avoid zero-damage battles.
        const total = 2;
        const engagementFraction = 0.30;
        final raw = (total * engagementFraction).floor();
        final engaged = raw < 1 ? 1 : raw; // clamp to minimum 1
        expect(raw, equals(0)); // without clamp would be zero
        expect(engaged, equals(1)); // with clamp is one
      },
      skip: 'Unskipped in 08-02 Task 2',
    );
  });
}
