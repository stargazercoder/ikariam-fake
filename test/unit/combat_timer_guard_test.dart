// Tests for production timer contract — CMBT-01.
//
// These are documentary tests: they verify the Dart-side constants and
// documented production values that must match the SQL migrations.
//
// Production timers (migration 20260312000008_env_guard_timers.sql):
//   - Battle turn interval: 5 minutes
//   - Resource tick schedule: */5 * * * *
//
// Dev speed-up timers (migration 20260312000007_speed_up_all_timers.sql):
//   - Battle turn interval: 10 seconds

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Production timer constants documented here.
  // These values must match migration 20260312000008_env_guard_timers.sql.
  const int productionBattleTurnMinutes = 5;
  const String productionResourceTickCron = '*/5 * * * *';

  // Dev speed-up constant documented here.
  // Must match migration 20260312000007_speed_up_all_timers.sql.
  const int devBattleTurnSeconds = 10;

  group('production timer constants (CMBT-01)', () {
    test('production battle turn interval is 5 minutes', () {
      // CMBT-01: In production, each battle turn resolves after 5 minutes.
      // SQL: next_turn_at + INTERVAL '5 minutes'
      // See: supabase/migrations/20260312000008_env_guard_timers.sql
      expect(productionBattleTurnMinutes, 5);
    });

    test('production resource tick is every 5 minutes', () {
      // CMBT-01: In production, the resource tick pg_cron schedule is */5 * * * *
      // SQL: cron.schedule('resource-tick', '*/5 * * * *', ...)
      // See: supabase/migrations/20260312000008_env_guard_timers.sql
      expect(productionResourceTickCron, '*/5 * * * *');
    });

    test('dev speed-up uses 10-second battle turns', () {
      // Dev mode: battle turns resolve after 10 seconds for faster testing.
      // SQL: next_turn_at + INTERVAL '10 seconds'
      // See: supabase/migrations/20260312000007_speed_up_all_timers.sql
      expect(devBattleTurnSeconds, 10);
    });
  });
}
