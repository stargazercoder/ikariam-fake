---
phase: 16-espionage-city-viewing
verified: 2026-03-17T00:00:00Z
status: passed
score: 13/13 must-haves verified
re_verification: false
human_verification:
  - test: "Spy action end-to-end in running app"
    expected: "Tap 'Spy (100 gold)' on enemy city -> loading spinner -> report dialog with resources, buildings, army count; gold deducted; 'View City' button enabled after spy"
    why_human: "Network calls to Supabase Edge Function and real-time gold deduction cannot be verified statically"
  - test: "Read-only building grid — no tap response"
    expected: "Tapping any building cell in EnemyCityViewScreen does nothing (no sheet, no navigation)"
    why_human: "GestureDetector onTap=null suppression requires runtime Flutter test; static grep confirms the pattern but behavior needs human confirmation"
  - test: "Bottom nav visible in Spy Log"
    expected: "Navigating via Battles AppBar spy icon to /spy-log keeps bottom navigation bar visible"
    why_human: "StatefulShellBranch nesting behavior requires device/emulator confirmation"
---

# Phase 16: Espionage City Viewing — Verification Report

**Phase Goal:** Players can spy on enemy cities to gather intelligence and view any player's city layout in read-only mode
**Verified:** 2026-03-17
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | test/unit/espionage_test.dart exists with stub tests for SpyReport.fromJson and BuildingCell readOnly | VERIFIED | File exists, 4 skipped stubs (3 for SpyReport.fromJson, 1 for BuildingCell readOnly), compiles |
| 2 | test/widget/enemy_city_view_test.dart exists with smoke test stub for EnemyCityViewScreen | VERIFIED | File exists, 2 widget test stubs with skip: true |
| 3 | spy_reports table exists with player_id, target_city_id, report_data JSONB, created_at columns | VERIFIED | `20260316000003_spy_reports.sql` — CREATE TABLE confirmed with all required columns, RLS, index |
| 4 | spy-city Edge Function deducts 100 gold, queries target city data, inserts spy_report, returns report JSON | VERIFIED | `spy-city/index.ts` — auth, own-city guard, gold check, deduct_resources RPC, resources/buildings/army queries, insert, successResponse |
| 5 | SpyReport model parses JSONB report_data using (v as num).toInt() pattern | VERIFIED | `spy_report.dart` — 3 occurrences of (v as num).toInt() for resources map, buildings map, armyCount |
| 6 | EspionageRepository.spyOnCity() calls spy-city Edge Function and returns SpyReport | VERIFIED | `espionage_repository.dart` line 38: `functions.invoke('spy-city', body: {'target_city_id': targetCityId})` |
| 7 | spyReportsProvider fetches player's spy reports ordered by created_at DESC | VERIFIED | `espionage_providers.dart` — FutureProvider.autoDispose calling fetchSpyReports() |
| 8 | hasSpiedProvider returns bool for a given targetCityId | VERIFIED | `espionage_providers.dart` — FutureProvider.autoDispose.family<bool, String> querying spy_reports table |
| 9 | Player can tap 'Spy (100 gold)' on enemy city and see spy report dialog | VERIFIED | `island_screen.dart` line 338: showSpyReportDialog() called from Spy button; `spy_report_dialog.dart` has spyOnCity() auto-trigger, resources/buildings/army display |
| 10 | Player can tap 'View City' to navigate to read-only enemy city screen | VERIFIED | `spy_report_dialog.dart` line 217-220: context.push('/city-view?cityId=...') with Uri.encodeComponent; `app_router.dart` line 142-149: /city-view route -> EnemyCityViewScreen |
| 11 | Read-only city view shows building grid without tap handlers, red AppBar | VERIFIED | `enemy_city_view_screen.dart`: Colors.red.shade800 AppBar, "Viewing enemy city — read only" banner, BuildingsGrid(readOnly: true); `city_grid_screen.dart` line 278-280: onTap: readOnly ? null : ... |
| 12 | View City button is greyed out with 'View City (spy first)' for un-spied cities | VERIFIED | `island_screen.dart` line 366: Text(hasSpied ? 'View City' : 'View City (spy first)'), onPressed null when !hasSpied |
| 13 | Spy log accessible from Battles tab with bottom nav bar remaining visible | VERIFIED | `battles_screen.dart` line 34-36: IconButton Spy Log -> context.push('/spy-log'); `app_router.dart` line 216: /spy-log nested inside _battlesNavigatorKey StatefulShellBranch |

**Score:** 13/13 truths verified

---

## Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `test/unit/espionage_test.dart` | VERIFIED | Exists, 31 lines, 4 skipped stubs covering SpyReport.fromJson (ESPY-01) and BuildingCell readOnly (ESPY-02) |
| `test/widget/enemy_city_view_test.dart` | VERIFIED | Exists, 27 lines, 2 widget stubs with skip: true |
| `supabase/migrations/20260316000003_spy_reports.sql` | VERIFIED | Exists, 21 lines — CREATE TABLE, CREATE INDEX, ENABLE ROW LEVEL SECURITY, CREATE POLICY |
| `supabase/functions/spy-city/index.ts` | VERIFIED | Exists, 258 lines — Deno.serve, CORS_HEADERS, full spy logic, deduct_resources, spy_reports insert |
| `lib/features/espionage/models/spy_report.dart` | VERIFIED | Exists, 71 lines — class SpyReport, factory fromJson, (v as num).toInt() x3, Map<String, int> resources + buildings |
| `lib/features/espionage/data/espionage_repository.dart` | VERIFIED | Exists, 83 lines — class EspionageRepository, invoke('spy-city'), spyOnCity(), fetchSpyReports() |
| `lib/features/espionage/providers/espionage_providers.dart` | VERIFIED | Exists, 44 lines — espionageRepositoryProvider, spyReportsProvider, hasSpiedProvider |
| `lib/features/espionage/screens/spy_report_dialog.dart` | VERIFIED | Exists — showSpyReportDialog, _SpyReportDialogContent, spyOnCity, View City button, Uri.encodeComponent, Not enough gold error |
| `lib/features/espionage/screens/spy_log_screen.dart` | VERIFIED | Exists, 144 lines — SpyLogScreen, spyReportsProvider, Icons.visibility_off, Icons.chevron_right, _SpyLogTile navigates to /city-view |
| `lib/features/map/screens/enemy_city_view_screen.dart` | VERIFIED | Exists, 171 lines — EnemyCityViewScreen, Colors.red.shade800, readOnly: true, "Viewing enemy city — read only" |
| `lib/features/map/screens/city_grid_screen.dart` | VERIFIED (modified) | readOnly: bool = false in BuildingsGrid + BuildingCell constructors; onTap: readOnly ? null : ... |
| `lib/features/map/screens/island_screen.dart` | VERIFIED (modified) | showSpyReportDialog, 'Spy (100 gold)', hasSpiedProvider, 'View City (spy first)', Uri.encodeComponent |
| `lib/core/router/app_router.dart` | VERIFIED (modified) | /city-view (top-level, hides bottom nav), /spy-log (nested in battles branch, keeps bottom nav) |
| `lib/features/battles/screens/battles_screen.dart` | VERIFIED (modified) | Spy Log AppBar IconButton, Icons.visibility, context.push('/spy-log') |

---

## Key Link Verification

| From | To | Via | Status | Evidence |
|------|----|-----|--------|----------|
| `island_screen.dart` | `spy_report_dialog.dart` | showSpyReportDialog() call | WIRED | island_screen.dart line 338: showSpyReportDialog(context, targetCityId: slot.cityId!, ...) |
| `spy_report_dialog.dart` | `espionage_repository.dart` | spyOnCity() call | WIRED | spy_report_dialog.dart line 66: ref.read(espionageRepositoryProvider); line 68: repo.spyOnCity() |
| `spy_report_dialog.dart` | `enemy_city_view_screen.dart` | context.push('/city-view') | WIRED | spy_report_dialog.dart lines 217-220: context.push('/city-view?cityId=...') with encoded params |
| `enemy_city_view_screen.dart` | `city_grid_screen.dart` | BuildingsGrid(readOnly: true) | WIRED | enemy_city_view_screen.dart line 98: readOnly: true |
| `island_screen.dart` | `espionage_providers.dart` | hasSpiedProvider for View City | WIRED | island_screen.dart line 349: ref.watch(hasSpiedProvider(slot.cityId!)) |
| `battles_screen.dart` | `app_router.dart` | context.push('/spy-log') | WIRED | battles_screen.dart line 36: context.push('/spy-log'); app_router.dart line 216: path: '/spy-log' in battles branch |
| `espionage_repository.dart` | `spy-city/index.ts` | Supabase functions invoke | WIRED | espionage_repository.dart line 38: functions.invoke('spy-city', body: ...) |
| `espionage_providers.dart` | `espionage_repository.dart` | Provider calling repository | WIRED | espionage_providers.dart line 13-14: espionageRepositoryProvider returns const EspionageRepository() |
| `spy-city/index.ts` | `spy_reports migration` | INSERT into spy_reports | WIRED | spy-city/index.ts lines 234-243: admin.from('spy_reports').insert({...}) |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| ESPY-01 | 16-00, 16-01 | User can send a spy to an enemy city to reveal resource amounts, building levels, and army counts | SATISFIED | spy-city Edge Function queries all 3 data types; SpyReport model stores them; EspionageRepository.spyOnCity() invokes Edge Function; spy_report_dialog.dart displays resources/buildings/army |
| ESPY-02 | 16-00, 16-02 | User can view a read-only version of another player's city screen (buildings layout) | SATISFIED | EnemyCityViewScreen with BuildingsGrid(readOnly: true) suppresses all cell taps; accessible via View City button in spy dialog and spy log tiles; /city-view route registered in app_router.dart |

No orphaned requirements — both ESPY-01 and ESPY-02 are claimed in plan frontmatter and have implementation evidence.

---

## Anti-Patterns Found

No anti-patterns found across all 14 modified/created files. All files are clean of TODO/FIXME/placeholder comments, empty returns, and stub implementations.

**Note on test stubs:** `test/unit/espionage_test.dart` and `test/widget/enemy_city_view_test.dart` are intentional Wave 0 scaffolds with `skip:` annotations. These are not implementation stubs — they are Nyquist test scaffolds per the plan design. The implementation they cover (SpyReport.fromJson, BuildingCell readOnly) is fully realized in the production files. The test bodies themselves are pending but the feature code they will test is complete.

---

## Commit Verification

All task commits documented in summaries exist in git log:

| Commit | Plan | Description |
|--------|------|-------------|
| `880f44e` | 16-00 Task 1 | test: add Wave 0 espionage test scaffold stubs |
| `2952766` | 16-01 Task 1 | feat: create spy_reports migration and spy-city Edge Function |
| `06d9d52` | 16-01 Task 2 | feat: create SpyReport model, EspionageRepository, and Riverpod providers |
| `3130668` | 16-02 Task 1 | feat: add readOnly to BuildingsGrid/BuildingCell, create EnemyCityViewScreen and SpyReportDialog |
| `b4c3743` | 16-02 Task 2 | feat: create SpyLogScreen, wire island dialog, register GoRouter routes |

---

## Human Verification Required

### 1. Spy Action End-to-End

**Test:** Start app, navigate to Island tab, tap an enemy city, tap "Spy (100 gold)"
**Expected:** Loading spinner appears, then spy report dialog shows with city name, owner name, resources (5 types), buildings (with levels), army count; 100 gold deducted from player city; "View City" button enabled on second visit to enemy city dialog
**Why human:** Network calls to Supabase Edge Function (auth, gold deduction, data query, insert) cannot be verified statically

### 2. Read-Only Building Grid

**Test:** After spy, tap "View City", then tap any building cell in the enemy city view
**Expected:** Nothing happens — no upgrade sheet opens, no navigation occurs
**Why human:** GestureDetector onTap=null behavior requires Flutter runtime to confirm suppression; static code confirms the pattern (line 278-280 in city_grid_screen.dart) but tap suppression needs real device verification

### 3. Bottom Navigation Preserved in Spy Log

**Test:** In Battles tab, tap the spy icon (visibility icon) in AppBar to navigate to Spy Log
**Expected:** Spy Log screen displays with bottom navigation bar still visible (Military tab active)
**Why human:** StatefulShellBranch navigation behavior in GoRouter requires device/emulator to confirm bottom nav visibility

---

## Summary

Phase 16 goal is fully achieved. All 13 observable truths are verified against the actual codebase — not just claimed in summaries. The espionage feature is complete and wired end-to-end:

- **Database layer:** `spy_reports` table with RLS and index, fully specified schema
- **Edge Function:** `spy-city` validates auth, guards own-city, checks gold, deducts atomically via RPC, queries all target data, inserts report, returns JSON
- **Dart data layer:** `SpyReport` model with safe JSONB numeric casts, `EspionageRepository` with invoke + fetch, three Riverpod providers
- **Flutter UI:** Spy report auto-trigger dialog, read-only enemy city view with red AppBar, spy log list screen, island menu integration (4 buttons: Attack, Trade, Spy, View City), GoRouter routes (/city-view top-level, /spy-log nested in battles branch)
- **Key invariants enforced:** `readOnly ? null` on BuildingCell.onTap, `View City (spy first)` gating via hasSpiedProvider, /spy-log nested inside battles StatefulShellBranch to preserve bottom nav

Three items flagged for human verification are behavioral (network, tap suppression, nav bar) and cannot be confirmed statically — all static code checks pass cleanly.

---

_Verified: 2026-03-17_
_Verifier: Claude (gsd-verifier)_
