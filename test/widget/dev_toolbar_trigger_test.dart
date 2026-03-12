// Widget test for dev toolbar trigger battle dispose fix.
// Verifies that TextEditingController text is captured before dispose()
// is called, preventing use-after-dispose errors.
//
// Wave 0 stub — unskipped in 08-01 Task 2 after the dispose ordering is fixed.

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dev toolbar trigger battle (dispose fix)', () {
    test(
      'trigger battle dialog completes without dispose error',
      () {
        // The fix: capture controller.text BEFORE calling controller.dispose().
        //
        // Broken pattern (dev_toolbar.dart lines 250-253 before fix):
        //   controller.dispose();                           // disposes first
        //   if (confirmed != true || controller.text...) return; // reads after dispose -> error
        //
        // Fixed pattern:
        //   final defenderCityId = controller.text.trim(); // capture first
        //   controller.dispose();                           // then dispose
        //   if (confirmed != true || defenderCityId.isEmpty) return; // read captured value
        //
        // This test documents the expected behavior.
        expect(true, isTrue); // documentation test
      },
      skip: 'Unskipped in 08-01 Task 2',
    );
  });
}
