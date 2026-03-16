// Test scaffold for espionage model and BuildingCell readOnly parameter.
//
// Covers: ESPY-01 (SpyReport.fromJson parsing),
//         ESPY-02 (BuildingCell readOnly param disables onTap)
//
// All tests are Wave 0 stubs — implementation lives in Plans 16-01 and 16-02.

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpyReport.fromJson', () {
    test('parses valid JSONB report data with all fields', () {
      // Stub — will be implemented when spy_report.dart exists (Plan 16-01)
    }, skip: 'Wave 0 stub — awaiting Plan 16-01 implementation');

    test('handles missing optional fields with defaults', () {
      // Stub — will be implemented when spy_report.dart exists (Plan 16-01)
    }, skip: 'Wave 0 stub — awaiting Plan 16-01 implementation');

    test('uses (v as num).toInt() for numeric JSONB fields', () {
      // Stub — will be implemented when spy_report.dart exists (Plan 16-01)
    }, skip: 'Wave 0 stub — awaiting Plan 16-01 implementation');
  });

  group('BuildingCell readOnly', () {
    test('readOnly=true sets onTap to null', () {
      // Stub — will be implemented when BuildingCell readOnly param added (Plan 16-02)
    }, skip: 'Wave 0 stub — awaiting Plan 16-02 implementation');
  });
}
