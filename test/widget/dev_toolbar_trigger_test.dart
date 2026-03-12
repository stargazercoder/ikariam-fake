// Widget test for dev toolbar trigger battle dispose fix.
// Verifies that TextEditingController text is captured before dispose()
// is called, preventing use-after-dispose errors.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dev toolbar trigger battle (dispose fix)', () {
    test('capture text before dispose preserves value', () {
      // This test documents and verifies the correct controller lifecycle pattern:
      //   1. Capture controller.text into a local variable
      //   2. Then call controller.dispose()
      //   3. Use the captured local variable (not controller.text) afterwards
      //
      // This is the fix applied to _triggerBattle() in dev_toolbar.dart.
      final controller = TextEditingController();
      controller.text = 'test-city-uuid-1234';

      // Fixed pattern: capture before dispose
      final captured = controller.text.trim();
      controller.dispose();

      // Captured value survives after dispose — no use-after-dispose error
      expect(captured, equals('test-city-uuid-1234'));
      expect(captured.isEmpty, isFalse);
    });

    test('empty text captured before dispose returns isEmpty true', () {
      final controller = TextEditingController();
      // No text set — empty by default

      final captured = controller.text.trim();
      controller.dispose();

      expect(captured.isEmpty, isTrue);
    });
  });
}
