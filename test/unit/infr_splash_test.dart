// Wave 0 test scaffold for INFR-01: Splash screen file-content validation.
//
// These tests read the actual web/ source files and assert structural patterns
// required for the branded loading splash to work correctly in production.
// Covers: INFR-01 (splash screen before Flutter engine load)

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('web/index.html splash structure', () {
    late String indexHtml;

    setUpAll(() {
      // Path is relative to project root where `flutter test` is run.
      final file = File('web/index.html');
      indexHtml = file.readAsStringSync();
    });

    test('contains splash element with id="splash"', () {
      expect(indexHtml, contains('id="splash"'));
    });

    test('splash div appears BEFORE the flutter_bootstrap.js script tag', () {
      final splashIndex = indexHtml.indexOf('id="splash"');
      final scriptIndex = indexHtml.indexOf('flutter_bootstrap.js');
      expect(splashIndex, isNot(-1), reason: 'id="splash" must exist');
      expect(scriptIndex, isNot(-1), reason: 'flutter_bootstrap.js script must exist');
      expect(splashIndex, lessThan(scriptIndex),
          reason: 'splash div must appear before the bootstrap script');
    });

    test('splash div contains "IKARIAM" branding text', () {
      expect(indexHtml, contains('IKARIAM'));
    });

    test('title tag reads "Ikariam"', () {
      expect(indexHtml, contains('<title>Ikariam</title>'));
    });

    test('meta description is updated from default Flutter placeholder', () {
      expect(indexHtml, contains('A multiplayer strategy game'));
      expect(indexHtml, isNot(contains('A new Flutter project')));
    });

    test('references flutter_bootstrap.js via script src', () {
      expect(indexHtml, contains('flutter_bootstrap.js'));
    });
  });

  group('web/flutter_bootstrap.js bootstrap content', () {
    late String bootstrapJs;

    setUpAll(() {
      final file = File('web/flutter_bootstrap.js');
      bootstrapJs = file.readAsStringSync();
    });

    test('contains {{flutter_js}} build-time token', () {
      expect(bootstrapJs, contains('{{flutter_js}}'));
    });

    test('contains {{flutter_build_config}} build-time token', () {
      expect(bootstrapJs, contains('{{flutter_build_config}}'));
    });

    test('contains onEntrypointLoaded callback', () {
      expect(bootstrapJs, contains('onEntrypointLoaded'));
    });

    test('removes splash element by id after runApp', () {
      // getElementById with 'splash' reference must exist.
      expect(bootstrapJs, contains("getElementById"));
      expect(bootstrapJs, contains("splash"));
    });

    test('calls runApp to start the Flutter application', () {
      expect(bootstrapJs, contains('runApp'));
    });

    test('splash removal happens after runApp (runApp appears before getElementById)', () {
      final runAppIndex = bootstrapJs.indexOf('runApp');
      final getElementIndex = bootstrapJs.indexOf('getElementById');
      expect(runAppIndex, isNot(-1));
      expect(getElementIndex, isNot(-1));
      expect(runAppIndex, lessThan(getElementIndex),
          reason: 'splash must be removed only after runApp completes');
    });
  });

  group('web/manifest.json PWA branding', () {
    late String manifestJson;

    setUpAll(() {
      final file = File('web/manifest.json');
      manifestJson = file.readAsStringSync();
    });

    test('name field contains "Ikariam"', () {
      expect(manifestJson, contains('"name": "Ikariam"'));
    });

    test('short_name field contains "Ikariam"', () {
      expect(manifestJson, contains('"short_name": "Ikariam"'));
    });

    test('background_color is game primary indigo #1A237E', () {
      expect(manifestJson, contains('#1A237E'));
    });

    test('theme_color is game primary indigo #1A237E', () {
      // Both background_color and theme_color use #1A237E.
      final count = '#1A237E'.allMatches(manifestJson).length;
      expect(count, greaterThanOrEqualTo(2));
    });

    test('description is updated from default Flutter placeholder', () {
      expect(manifestJson, isNot(contains('A new Flutter project')));
    });
  });
}
