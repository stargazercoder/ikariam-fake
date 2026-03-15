# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v0.1.0 — MVP

**Shipped:** 2026-03-12
**Phases:** 9 | **Plans:** 27

### What Was Built
- Full auth flow with auto city placement on first login
- Server-side economy: 5 resources, pg_cron production ticks, warehouse caps, building upgrades
- 2D grid world map with island view and city grid
- Military system: 13 unit types, training queue, dispatch with travel time
- Turn-based battle engine: naval-before-land phases, 5-minute turns, Realtime reports
- Production hardening: splash screen, RLS audit, test infrastructure with dev toolbar

### What Worked
- Wave 0 test scaffold pattern: skipped test stubs created before production code, ensuring test coverage plan existed from the start
- Edge Function server-authority pattern: consistent mutation boundary prevented security gaps
- pg_cron for all game loops (resources, training, construction, battles): reliable, no client-side timing issues
- Strict phase dependency chain (auth → economy → map → military → combat): each phase built cleanly on the previous
- Gap closure via milestone audit: Phases 8-9 caught real bugs (dispatch NaN, missing environment guard) before shipping

### What Was Inefficient
- REQUIREMENTS.md traceability table got stale quickly — "Pending" counts lagged behind actual completion
- Phase 8-9 gap closure phases could have been avoided with earlier integration testing
- riverpod_generator incompatibility forced manual provider boilerplate throughout — could have been caught in Phase 1 research
- BASE_COSTS/BASE_TIMES duplicated between Dart and TypeScript with only sync comments — fragile

### Patterns Established
- All game mutations via Edge Functions (one documented exception: ProfileRepository.updateProfile)
- JSONB snapshots for dispatched armies (immutable at departure)
- Server-side NOW() for all timestamps
- Manual Riverpod providers (no code-gen) until Dart SDK upgrade
- Test accounts with varied game states for manual QA
- Dev toolbar with SECURITY DEFINER RPC helpers (debug mode only)

### Key Lessons
1. Milestone audit before shipping catches real integration bugs — always run it
2. Duplicated constants between client/server (Dart/TypeScript) need a better sync mechanism than comments
3. Wave 0 test scaffolds are worth the upfront cost — they document the verification contract early
4. 2-day MVP velocity was possible because phase dependencies were strict and linear — no circular work

### Cost Observations
- Model mix: balanced profile (opus/sonnet/haiku mix)
- Notable: 27 plans across 9 phases in 2 days — high throughput with strict phase ordering

---

## Milestone: v1.1 — Economy & Combat Depth

**Shipped:** 2026-03-15
**Phases:** 3 | **Plans:** 8

### What Was Built
- Happiness/wine economy: tavern consumes wine per tick, drives happiness, controls population growth
- Population-based gold tax: idle citizens generate 3 gold/hour
- Cooperative island upgrades: donate wood to boost island resource production
- Production rate UI: +X/hr labels with detailed breakdown sheet
- Pillage mechanic: battle winners steal unprotected resources, Hideout protection floor
- Battle report visualization: fl_chart stacked bar charts with color-coded unit types

### What Worked
- Phase verification (gsd-verifier) caught CMBT-02 docs-code mismatch before shipping — resolved quickly
- Milestone audit caught stale cityProvider (island donation bug) and JSONB cast inconsistency
- fl_chart integration was smooth — widget tests covered chart rendering edge cases
- 5-step economy loop in single process_resource_tick() function: clean, auditable, no race conditions
- Phase 11 cleanly superseded Phase 10's tick function while preserving all economy steps

### What Was Inefficient
- Phase 11 skipped verification (no VERIFICATION.md) — caught in milestone audit, not during execution
- SUMMARY.md files missing `requirements_completed` frontmatter — 3-source cross-reference was weaker
- CMBT-02 requirement text never updated after CONTEXT.md design decision — caused unnecessary verification gap
- UnitMovement.cargo model field created but no UI renders it — orphaned work

### Patterns Established
- `(v as num).toInt()` for JSONB number parsing (safe cast pattern for Supabase)
- `SELECT FOR UPDATE` on resource rows during pillage to prevent tick race conditions
- `IntrinsicWidth` wrapper for Positioned FAB columns (dev toolbar fix)
- cityEconomyStreamProvider pattern: StreamProvider.autoDispose.family for Realtime city data

### Key Lessons
1. Always update requirement text when design decisions change scope — docs-code mismatch creates unnecessary verification gaps
2. Phase verification should never be skipped — Phase 11 gap was only caught at milestone audit level
3. Don't create model fields without a UI consumer — UnitMovement.cargo is orphaned work
4. Integration checker is valuable — found cityProvider staleness bug that unit tests and phase verification missed

### Cost Observations
- Model mix: sonnet for executors/verifiers, opus for orchestration
- Notable: 8 plans across 3 phases in 3 days — consistent velocity with v0.1.0

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Plans | Key Change |
|-----------|--------|-------|------------|
| v0.1.0 | 9 | 27 | Initial process established: wave-0 scaffolds, Edge Function authority, pg_cron loops |
| v1.1 | 3 | 8 | Phase verification integrated into execute-phase; milestone audit caught cross-phase bugs |

### Cumulative Quality

| Milestone | Tests | Coverage | Notes |
|-----------|-------|----------|-------|
| v0.1.0 | 75 pass, 12 skip | — | 12 skips are auth/profile stubs needing live DB |
| v1.1 | 7 new widget tests | — | fl_chart chart rendering + pillage card visibility tests |

### Top Lessons (Verified Across Milestones)

1. Milestone audit before shipping catches integration bugs that phase-level verification misses (v0.1.0: dispatch NaN; v1.1: cityProvider staleness)
2. Server-authority contract (Edge Functions only) prevents entire classes of security issues
3. Always update requirement text when design decisions change scope — docs-code mismatch causes unnecessary rework (v1.1: CMBT-02)
