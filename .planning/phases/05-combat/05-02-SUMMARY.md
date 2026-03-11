---
phase: 05-combat
plan: "02"
subsystem: combat-client
tags: [flutter, riverpod, supabase-realtime, dart, models, battle, tdd]

requires:
  - phase: 05-01
    provides: battles table, battle_turns table, resolve_battles function, battle-tick cron
  - phase: 04-02
    provides: UnitType enum, unit_constants.dart pattern for constants maps
  - phase: 04-03
    provides: MilitaryRepository, StreamProvider.autoDispose.family, dual-stream merge pattern

provides:
  - Battle model with fromJson, isActive getter, Map<String,int> units (JSONB)
  - BattleTurn model with fromJson, nullable naval/land casualties, non-nullable survivors
  - unitAttackStats and unitDefenseStats const maps (13 unit types each) in unit_constants.dart
  - BattleRepository with watchBattlesAsAttacker, watchBattlesAsDefender, watchBattleTurns
  - attackerBattlesProvider, defenderBattlesProvider (StreamProvider.autoDispose.family)
  - allMyBattlesProvider (merged + deduplicated + sorted)
  - battleTurnsProvider (StreamProvider.autoDispose.family keyed by battleId)

affects: [05-03-battles-ui, any future battle-detail or battle-list screens]

tech-stack:
  added: []
  patterns:
    - TDD-red-green: test stubs written first, import errors confirmed RED, then production code makes GREEN
    - dual-stream-merge: two Realtime .stream() subscriptions (attacker + defender) merged client-side with seen-set dedup
    - nullable-JSONB: _parseUnits static helper converts nullable Map<String,dynamic> to Map<String,int>?
    - read-only-model: Battle and BattleTurn have fromJson but no toJson/insert/update/delete (CMBT-05)

key-files:
  created:
    - lib/features/battles/models/battle.dart
    - lib/features/battles/models/battle_turn.dart
    - lib/features/battles/data/battle_repository.dart
    - lib/features/battles/providers/battles_provider.dart
    - lib/features/battles/providers/battle_turns_provider.dart
  modified:
    - lib/core/constants/unit_constants.dart
    - test/unit/battle_models_test.dart
    - test/unit/combat_formula_test.dart

key-decisions:
  - "unitAttackStats/unitDefenseStats values match resolve_battles() SQL constants exactly — sync comment enforces manual consistency"
  - "BattleTurn._parseUnits static helper isolates nullable JSONB casting logic — keeps fromJson factory readable"
  - "allMyBattlesProvider uses Provider.autoDispose (not StreamProvider) because it merges two async values into a synchronous list"

patterns-established:
  - "BattleTurn._parseUnits: static helper for nullable JSONB Map casting — reusable pattern for any nullable JSONB field"
  - "dual-stream Provider.autoDispose merge: watch both family providers, use asData?.value ?? [], deduplicate by ID, sort"

requirements-completed: [CMBT-01, CMBT-02, CMBT-03, CMBT-04, CMBT-05]

duration: 3min
completed: "2026-03-12"
---

# Phase 5 Plan 02: Combat Client Data Layer Summary

**Battle/BattleTurn Dart models, 13-unit combat stat constants, and dual-stream BattleRepository with 4 Riverpod providers — all TDD-verified with 20 new tests.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-11T21:45:43Z
- **Completed:** 2026-03-12T21:48:34Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Battle and BattleTurn models parse all DB fields including nullable JSONB casualty maps; read-only by design (no write methods — CMBT-05)
- unitAttackStats and unitDefenseStats added to unit_constants.dart with values matching the pg resolve_battles() function exactly
- BattleRepository streams battles via dual Supabase Realtime subscriptions (attacker + defender); allMyBattlesProvider merges and deduplicates client-side
- All Wave 0 test stubs replaced with real assertions; 20 new tests pass (10 battle model + 10 combat formula)

## Task Commits

Each task was committed atomically:

1. **Task 1: Battle/BattleTurn models, unit combat stats, TDD tests** - `c738e8a` (feat)
2. **Task 2: BattleRepository, StreamProviders, combined battles provider** - `8f030b3` (feat)

_Note: Task 1 was a full TDD cycle — RED (import errors confirmed) then GREEN (all 20 tests pass)._

## Files Created/Modified

- `lib/features/battles/models/battle.dart` - Battle model: fromJson, isActive getter, JSONB Map parsing
- `lib/features/battles/models/battle_turn.dart` - BattleTurn model: fromJson, nullable casualty fields, _parseUnits helper
- `lib/features/battles/data/battle_repository.dart` - BattleRepository with 3 Realtime stream methods + battleRepositoryProvider
- `lib/features/battles/providers/battles_provider.dart` - attackerBattlesProvider, defenderBattlesProvider, allMyBattlesProvider
- `lib/features/battles/providers/battle_turns_provider.dart` - battleTurnsProvider StreamProvider.autoDispose.family
- `lib/core/constants/unit_constants.dart` - unitAttackStats and unitDefenseStats const maps added (13 entries each)
- `test/unit/battle_models_test.dart` - 10 real tests replacing all Wave 0 stubs
- `test/unit/combat_formula_test.dart` - 10 real tests replacing all Wave 0 stubs

## Decisions Made

- `allMyBattlesProvider` uses `Provider.autoDispose` (not `StreamProvider.autoDispose`) because it merges two async stream values into a synchronous list — there is no single stream to subscribe to.
- `BattleTurn._parseUnits` static helper isolates the nullable JSONB Map cast in one place; fromJson factory remains readable.
- Unit stat values (unitAttackStats/unitDefenseStats) match resolve_battles() SQL constants exactly — sync comment enforces manual consistency since server authority must not import client code.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Self-Check: PASSED

All created files found on disk. Task commits c738e8a and 8f030b3 confirmed in git log. All 59 unit tests pass.

## Next Phase Readiness

- All data layer for battles is complete: models, repository, providers
- 05-03 (Battles UI) can consume allMyBattlesProvider and battleTurnsProvider directly
- BattleRepository streams are ready for widget integration with CountdownTimerWidget pattern

---
*Phase: 05-combat*
*Completed: 2026-03-12*
