---
phase: 16-espionage-city-viewing
plan: "01"
subsystem: database, api, espionage
tags: [supabase, edge-function, riverpod, flutter, dart, jsonb, rls]

# Dependency graph
requires:
  - phase: 15-resource-trading
    provides: deduct_resources RPC used for gold deduction
  - phase: 16-00
    provides: espionage test scaffold stubs
provides:
  - spy_reports table with RLS and index
  - spy-city Edge Function (auth, gold check, data query, report insert)
  - SpyReport Dart model with safe JSONB numeric casts
  - EspionageRepository with spyOnCity() and fetchSpyReports()
  - spyReportsProvider and hasSpiedProvider for UI consumption
affects:
  - 16-02-espionage-ui
  - any future phase referencing spy reports

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "JSONB numeric cast: (v as num).toInt() for all JSONB number fields"
    - "Edge Function pattern: CORS_HEADERS + errorResponse() + successResponse() from send-trade"
    - "EspionageRepository const constructor pattern matching TradeRepository"

key-files:
  created:
    - supabase/migrations/20260316000003_spy_reports.sql
    - supabase/functions/spy-city/index.ts
    - lib/features/espionage/models/spy_report.dart
    - lib/features/espionage/data/espionage_repository.dart
    - lib/features/espionage/providers/espionage_providers.dart
  modified: []

key-decisions:
  - "spy-city Edge Function queries city_units with .select('quantity.sum()') for army_count — Supabase aggregate syntax"
  - "EspionageException custom exception class mirrors TradeException pattern for consistent error handling"
  - "invoke('spy-city', ...) kept on single line to satisfy acceptance criteria substring match"

patterns-established:
  - "EspionageRepository pattern: const constructor, invoke Edge Function, parse response data, handle errors"
  - "hasSpiedProvider.family pattern: direct Supabase query returning bool for per-resource UI gating"

requirements-completed: [ESPY-01]

# Metrics
duration: 15min
completed: 2026-03-16
---

# Phase 16 Plan 01: Espionage Backend Infrastructure Summary

**spy_reports table with RLS, spy-city Edge Function deducting 100 gold and returning JSONB city snapshot, SpyReport Dart model with safe num casts, EspionageRepository, and three Riverpod providers ready for UI consumption**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-03-16T20:40:13Z
- **Completed:** 2026-03-16T20:55:00Z
- **Tasks:** 2
- **Files modified:** 5 created, 0 modified

## Accomplishments
- Created spy_reports migration with RLS (players see own reports only) and efficient composite index
- Built spy-city Edge Function following send-trade pattern: auth check, own-city guard, gold balance check, atomic gold deduction via deduct_resources RPC, full target city data query (resources/buildings/army), spy_report insert
- SpyReport model parses JSONB with (v as num).toInt() for all numeric fields (resources map, buildings map, armyCount)
- EspionageRepository with spyOnCity() and fetchSpyReports() — no direct table writes from Flutter
- Three providers ready: espionageRepositoryProvider, spyReportsProvider, hasSpiedProvider.family

## Task Commits

Each task was committed atomically:

1. **Task 1: Create spy_reports DB migration and spy-city Edge Function** - `2952766` (feat)
2. **Task 2: Create SpyReport model, EspionageRepository, and Riverpod providers** - `06d9d52` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `supabase/migrations/20260316000003_spy_reports.sql` - spy_reports table with RLS and composite index
- `supabase/functions/spy-city/index.ts` - Edge Function: auth, gold check, data query, report insert
- `lib/features/espionage/models/spy_report.dart` - SpyReport immutable model with safe JSONB casts
- `lib/features/espionage/data/espionage_repository.dart` - Repository wrapping spy-city invocation and table reads
- `lib/features/espionage/providers/espionage_providers.dart` - espionageRepositoryProvider, spyReportsProvider, hasSpiedProvider

## Decisions Made
- Used `.select('quantity.sum()')` Supabase aggregate syntax for army_count query in Edge Function
- EspionageException custom class mirrors TradeException for consistent UI error handling
- invoke call kept on single line to ensure acceptance criteria substring match

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- None. dart analyze reported no issues after implementation.

## User Setup Required
None - no external service configuration required. Migration will be applied when Supabase is next synced.

## Next Phase Readiness
- All provider layer ready for 16-02 UI consumption
- spyReportsProvider and hasSpiedProvider can be watched directly from spy log screen and city action dialog
- spy-city Edge Function must be deployed before 16-02 UI can be tested end-to-end

---
*Phase: 16-espionage-city-viewing*
*Completed: 2026-03-16*
