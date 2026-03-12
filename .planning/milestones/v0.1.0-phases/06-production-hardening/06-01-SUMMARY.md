---
phase: 06-production-hardening
plan: 01
subsystem: web/pwa
tags: [splash-screen, web, pwa, branding, infra]
requirements: [INFR-01]

dependency_graph:
  requires: []
  provides: [web/index.html#splash, web/flutter_bootstrap.js, web/manifest.json]
  affects: [player first-load UX]

tech_stack:
  added: []
  patterns:
    - HTML/CSS splash overlay with fixed positioning and opacity fade
    - flutter_bootstrap.js with onEntrypointLoaded lifecycle hook
    - Dart dart:io File reads for file-content assertions in unit tests

key_files:
  created:
    - web/flutter_bootstrap.js
    - test/unit/infr_splash_test.dart
  modified:
    - web/index.html
    - web/manifest.json

decisions:
  - Splash removal uses opacity fade (0.4s) before DOM removal — ensures smooth transition without layout jank
  - Splash is removed AFTER await appRunner.runApp() — guarantees first Flutter frame is painted before fade begins
  - Background color #1A237E matches AppTheme.primaryColor (indigo) — consistent branding from zero-JS load to app render
  - Test uses dart:io File reads from project root — consistent with flutter test working directory convention

metrics:
  duration: 2 min
  completed_date: "2026-03-12"
  tasks_completed: 1
  files_changed: 4
---

# Phase 6 Plan 01: Web Splash Screen (INFR-01) Summary

**One-liner:** Branded indigo/gold splash screen visible before CanvasKit WASM loads, removed via onEntrypointLoaded after runApp completes.

## What Was Built

A zero-JS-dependency loading splash that eliminates the blank white screen during CanvasKit WASM download (~1.5 MB). The splash is pure HTML/CSS rendered before any JavaScript executes, giving players immediate visual feedback that the game is loading.

### Key Changes

**web/index.html**
- Title updated from "ikariam" to "Ikariam"
- Meta description updated to "A multiplayer strategy game — build cities, gather resources, and conquer enemies"
- `<div id="splash">` added as first `<body>` child, before the bootstrap script tag
- Splash uses `position: fixed; inset: 0` covering the viewport with `#1A237E` background
- Branded "IKARIAM" heading in gold `#C9A84C`, serif font, letter-spacing 0.1em

**web/flutter_bootstrap.js** (new file)
- Contains mandatory `{{flutter_js}}` and `{{flutter_build_config}}` build-time tokens
- `onEntrypointLoaded` callback: initializes engine, calls `runApp()`, then fades splash out

**web/manifest.json**
- name/short_name changed from "ikariam" to "Ikariam"
- background_color and theme_color changed from `#0175C2` to `#1A237E`
- description updated to "A multiplayer strategy game"

**test/unit/infr_splash_test.dart** (new file)
- 17 tests across 3 groups: index.html structure, flutter_bootstrap.js content, manifest.json branding
- All tests pass (confirmed with `flutter test test/unit/infr_splash_test.dart`)

## Verification Results

```
flutter test test/unit/infr_splash_test.dart --reporter=compact
00:11 +17: All tests passed!
```

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

- [x] web/index.html exists with id="splash" before flutter_bootstrap.js script tag
- [x] web/flutter_bootstrap.js exists with {{flutter_js}}, {{flutter_build_config}}, onEntrypointLoaded, runApp, getElementById('splash')
- [x] web/manifest.json contains "Ikariam" and #1A237E
- [x] test/unit/infr_splash_test.dart exists with onEntrypointLoaded assertion
- [x] Commit a527c74 confirmed

## Self-Check: PASSED
