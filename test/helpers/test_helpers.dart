// Shared test helper utilities.
//
// These helpers reduce boilerplate in individual test files.
// Full implementations will be added once flutter_riverpod is available (Plan 01-01).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] in a [MaterialApp] for widget testing.
///
/// Usage:
/// ```dart
/// await tester.pumpWidget(createTestApp(MyWidget()));
/// ```
Widget createTestApp(Widget child) {
  return MaterialApp(home: child);
}

/// Wraps [child] in a minimal test scaffold with a [Scaffold] body.
///
/// Useful when testing widgets that require a [Scaffold] ancestor.
Widget createScaffoldApp(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

// Future helper (uncomment after Plan 01-01 adds flutter_riverpod):
// import 'package:flutter_riverpod/flutter_riverpod.dart';
//
// Widget createTestProviderScope(Widget child, {List<Override>? overrides}) {
//   return ProviderScope(
//     overrides: overrides ?? const [],
//     child: MaterialApp(home: child),
//   );
// }
