// Tests for hideoutProtectionFloor() in building_constants.dart.
// Verifies the protection floor formula: floor(100 * 1.5^level)
// and the base-50 fallback when no Hideout is built (level == null).

import 'package:flutter_test/flutter_test.dart';
import 'package:ikariam/core/constants/building_constants.dart';

void main() {
  group('hideoutProtectionFloor', () {
    test('returns 50 for null (no Hideout built — base protection)', () {
      expect(hideoutProtectionFloor(null), equals(50));
    });

    test('returns 100 for level 0 (floor(100 * 1.5^0) = 100)', () {
      expect(hideoutProtectionFloor(0), equals(100));
    });

    test('returns 150 for level 1 (floor(100 * 1.5^1) = 150)', () {
      expect(hideoutProtectionFloor(1), equals(150));
    });

    test('returns 759 for level 5 (floor(100 * 1.5^5) = 759)', () {
      expect(hideoutProtectionFloor(5), equals(759));
    });

    test('returns 5766 for level 10 (floor(100 * 1.5^10) = 5766)', () {
      expect(hideoutProtectionFloor(10), equals(5766));
    });
  });
}
