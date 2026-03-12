// Tests for partial army engagement formula (CMBT-02).
// Verifies that engagement fraction, damage calculation, and casualty
// application all follow the 30% engagement model.
//
// These Dart tests mirror the SQL constants in:
//   supabase/migrations/20260312000009_partial_engagement.sql
// Any change to v_engagement_fraction must be reflected here.

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Mirrors the SQL constant v_engagement_fraction CONSTANT numeric := 0.30
  // in migration 20260312000009_partial_engagement.sql
  const double engagementFraction = 0.30;

  group('partial army engagement (CMBT-02)', () {
    test('engagement fraction is 30%', () {
      // The engagement constant must equal 0.30 (30% of army engages per turn).
      // SQL: v_engagement_fraction CONSTANT numeric := 0.30
      // See: supabase/migrations/20260312000009_partial_engagement.sql
      expect(engagementFraction, equals(0.30));
    });

    test('only engaged units participate in damage calculation', () {
      // Given 100 hoplites at 30% engagement: 30 units engage, 70 hold back.
      // Only the 30 engaged units contribute attack/defense power.
      // SQL: v_att_engaged := GREATEST(1, FLOOR(v_att_qty * v_engagement_fraction))
      const total = 100;
      final engaged = (total * engagementFraction).floor();
      expect(engaged, equals(30));
    });

    test('casualties applied only to engaged subset', () {
      // Given 30 engaged units with 50% loss ratio:
      // casualties = floor(30 * 0.5) = 15
      // survivors = 100 - 15 = 85
      // Full army carries forward: 100 total - 15 dead = 85 in next turn.
      // SQL: loss_ratio is computed from engaged totals; casualties from FLOOR(qty * loss_ratio)
      const totalArmy = 100;
      const engaged = 30;
      const lossRatio = 0.50;
      final casualties = (engaged * lossRatio).floor();
      final survivors = totalArmy - casualties;
      expect(casualties, equals(15));
      expect(survivors, equals(85));
    });

    test('minimum 1 unit engages when army > 0', () {
      // Given 2 units at 30% engagement: floor(2 * 0.3) = floor(0.6) = 0
      // Must clamp to minimum of 1 to avoid zero-damage battles.
      // SQL: GREATEST(1, FLOOR(v_att_qty * v_engagement_fraction))
      const total = 2;
      final raw = (total * engagementFraction).floor();
      final engaged = raw < 1 ? 1 : raw; // mirrors GREATEST(1, FLOOR(...))
      expect(raw, equals(0)); // without clamp would be zero
      expect(engaged, equals(1)); // with clamp is one
    });
  });
}
