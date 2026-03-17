// Tests for ProfileNotifier isBot / isAdmin field accessors.
//
// These are pure Dart unit tests — no Flutter widgets, no ProviderContainer,
// no Supabase connection needed.  The helper functions defined below mirror
// the (profile?['is_bot'] as bool?) ?? false pattern used in the getters so
// that the logic is covered independently of the Riverpod state machinery.

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Profile bot field accessors', () {
    // Helper that mirrors the getter logic in ProfileNotifier
    bool isBot(Map<String, dynamic>? profile) {
      return (profile?['is_bot'] as bool?) ?? false;
    }

    bool isAdmin(Map<String, dynamic>? profile) {
      return (profile?['is_admin'] as bool?) ?? false;
    }

    // ── isBot ──────────────────────────────────────────────────────────────

    test('isBot defaults to false when key absent', () {
      final map = <String, dynamic>{'display_name': 'Alice', 'avatar_id': 1};
      expect(isBot(map), false);
    });

    test('isBot returns true when is_bot is true', () {
      final map = <String, dynamic>{'display_name': 'BotAres', 'is_bot': true};
      expect(isBot(map), true);
    });

    test('isBot returns false when is_bot is false', () {
      final map = <String, dynamic>{'display_name': 'Human', 'is_bot': false};
      expect(isBot(map), false);
    });

    test('isBot returns false for null profile', () {
      expect(isBot(null), false);
    });

    // ── isAdmin ────────────────────────────────────────────────────────────

    test('isAdmin defaults to false when key absent', () {
      final map = <String, dynamic>{'display_name': 'Alice'};
      expect(isAdmin(map), false);
    });

    test('isAdmin returns true when is_admin is true', () {
      final map = <String, dynamic>{'display_name': 'Admin', 'is_admin': true};
      expect(isAdmin(map), true);
    });

    test('isAdmin returns false when is_admin is false', () {
      final map = <String, dynamic>{'display_name': 'User', 'is_admin': false};
      expect(isAdmin(map), false);
    });

    test('isAdmin returns false for null profile', () {
      expect(isAdmin(null), false);
    });
  });
}
