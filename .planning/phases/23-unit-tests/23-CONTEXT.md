# Phase 23: Unit Tests - Context

**Gathered:** 2026-03-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Critical Edge Function logic and GodMode Flutter widgets are covered by automated tests that run locally without a live Supabase instance. Tests cover upgrade-building and train-units pure formulas (Deno) and all GodMode widgets (Flutter). No integration tests, no HTTP handler tests, no Supabase client mocking.

</domain>

<decisions>
## Implementation Decisions

### Edge Function extraction
- Extract pure functions into `supabase/functions/_shared/formulas.ts` (centralized shared lib)
- Constants (BASE_COSTS, UNIT_BASE_COSTS, BASE_TIMES, UNIT_BASE_TIMES, UNIT_UNLOCK_LEVELS) move to `_shared/formulas.ts` as named exports
- Each Edge Function `index.ts` imports from `../_shared/formulas.ts`
- Extract formulas only: `calcUpgradeCost`, `calcUpgradeDurationMinutes`, `calcTrainingCost`, `calcTrainingDuration`
- Validation functions (isValidBuildingType, etc.) stay in index.ts — not extracted

### GodMode widget coverage
- Test ALL 8 GodMode widgets: bot_badge, elapsed_timer_text, event_feed, event_tile, player_row, player_table, godmode_dashboard_screen, godmode_placeholder_screen
- Provider isolation via `ProviderScope` with `overrides` (existing codebase pattern from dev_toolbar_test.dart)
- Assertions verify rendering + key data display (text, icons, data from mock providers)
- Do NOT test tap handlers that call Supabase RPCs, scroll behavior, or refresh fetching
- Test all 3 async states for widgets with async providers: loading (spinner), error (error message), data (content)

### Test file organization
- Deno tests: `supabase/functions/tests/upgrade_building_test.ts` and `train_units_test.ts` (underscore naming)
- Flutter GodMode tests: `test/widget/godmode/` subdirectory with per-widget test files
- Shared mock data: `test/widget/godmode/godmode_test_helpers.dart` with mock GodmodePlayer, GodmodeEvent objects

### Test scope boundaries
- Edge Function formula tests: happy path + edge cases (level 0, mid-level ~5, high-level ~20)
- Test every building/unit type returns valid non-empty cost at level 0
- Dev speed multiplier tested in both modes (devMode=true → 0.2x, devMode=false → 1.0x)
- Flutter widget tests cover loading, error, and data-loaded states for async providers

### Claude's Discretion
- Exact mock data values for GodmodePlayer and GodmodeEvent objects
- Which specific building types to use as test subjects for mid/high level tests
- Loading spinner and error message widget finder patterns
- Whether to add a deno.json test task configuration

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Edge Functions (extraction targets)
- `supabase/functions/upgrade-building/index.ts` — Contains calcUpgradeCost, calcUpgradeDurationMinutes, BASE_COSTS, BASE_TIMES constants to extract
- `supabase/functions/train-units/index.ts` — Contains UNIT_BASE_COSTS, UNIT_BASE_TIMES, UNIT_UNLOCK_LEVELS constants and training calc logic to extract

### GodMode widgets (test targets)
- `lib/features/godmode/widgets/bot_badge.dart` — Bot badge widget
- `lib/features/godmode/widgets/elapsed_timer_text.dart` — Elapsed timer text widget
- `lib/features/godmode/widgets/event_feed.dart` — Event feed widget
- `lib/features/godmode/widgets/event_tile.dart` — Event tile widget
- `lib/features/godmode/widgets/player_row.dart` — Player row widget
- `lib/features/godmode/widgets/player_table.dart` — Player table widget
- `lib/features/godmode/screens/godmode_dashboard_screen.dart` — Dashboard screen
- `lib/features/godmode/screens/godmode_placeholder_screen.dart` — Placeholder screen

### GodMode data models (for mock data)
- `lib/features/godmode/models/godmode_event.dart` — GodmodeEvent model
- `lib/features/godmode/models/godmode_player.dart` — GodmodePlayer model
- `lib/features/godmode/providers/godmode_world_provider.dart` — World state provider to override
- `lib/features/godmode/providers/godmode_events_provider.dart` — Events provider to override

### Existing test patterns (reference for consistency)
- `test/widget/dev_toolbar_test.dart` — ProviderScope override pattern to follow
- `test/helpers/test_helpers.dart` — Existing test helper utilities

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/helpers/mocks.dart` and `test/helpers/test_helpers.dart`: Existing test helper infrastructure
- ProviderScope override pattern: Well-established across 6 widget test files
- 27 existing test files: Naming conventions and structure are clear

### Established Patterns
- Widget tests use `ProviderScope(overrides: [...])` wrapping `MaterialApp(home: WidgetUnderTest())`
- Unit tests in `test/unit/` test pure Dart functions (formulas, models, constants)
- Stub notifiers return null/empty data to avoid Supabase calls

### Integration Points
- `_shared/formulas.ts` will be imported by both `upgrade-building/index.ts` and `train-units/index.ts`
- Deno test runner invoked via `deno test supabase/functions/tests/`
- Flutter test runner invoked via `flutter test test/`

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 23-unit-tests*
*Context gathered: 2026-03-18*
