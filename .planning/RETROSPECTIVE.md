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

## Milestone: v1.2 — Espionage, Trading & Polish

**Shipped:** 2026-03-17
**Phases:** 5 | **Plans:** 11

### What Was Built
- Dev acceleration: bulk unit spawn, 5x timer speed, instant complete button
- Movement visibility: armies and cargo in transit with destinations and ETAs
- Resource trading: player-to-player resource transfers via cargo ships with travel time
- Espionage: instant spy action revealing enemy resources, buildings, and army counts
- Read-only enemy city view with spy log history
- UI polish: transparent city AppBar, ownership color borders, unit type CircleAvatar icons

### What Worked
- Movement visibility (Phase 14) built before trading (Phase 15) — cargo display was already proven when trade cargo appeared
- Dev toolbar enhancements in Phase 13 accelerated testing of all subsequent phases
- Wave 0 test scaffold in Phase 16 maintained test discipline during rapid feature delivery

### What Was Inefficient
- 5 phases in 2 days — high velocity but no milestone audit was run before shipping
- Phase details remained in ROADMAP.md instead of being archived, making it grow large

### Patterns Established
- `movement_type CHECK IN ('attack','return','trade')` — extensible movement type enum via ALTER
- Spy action as instant server-side operation (no travel time, no spy unit)
- ReadOnly mode for city views via `isReadOnly` parameter on BuildingsGrid

### Key Lessons
1. When milestone velocity is very high, skip audit at your own risk — tech debt accumulates silently
2. Movement visibility before trading was the right dependency order — proved cargo display worked first

### Cost Observations
- Model mix: balanced profile
- Notable: 11 plans across 5 phases in 2 days — highest velocity milestone

---

## Milestone: v1.3 — Bots, Testing & Automation

**Shipped:** 2026-03-18
**Phases:** 7 | **Plans:** 11

### What Was Built
- Bot schema: is_bot/is_admin columns, bot_schedules table with RLS deny-all
- Bot behavior engine: PL/pgSQL run_bot_decisions() with attack, retrain, upgrade on */15 cron
- Seed data: 20 diverse bot accounts with tiered game states, idempotent ON CONFLICT inserts
- GodMode backend: 5 SECURITY DEFINER RPCs with is_admin Postgres guard
- GodMode dashboard: full-page admin screen with sortable player table, bot controls, event feed, inline editing
- Unit tests: Deno tests for extracted pure formulas, Flutter widget tests with ProviderScope overrides
- CI/CD: dev setup scripts (bash + PowerShell), GitHub Actions quality gate

### What Worked
- Single consolidated bot-think-tick cron job — avoided pg_cron worker pool exhaustion
- SECURITY DEFINER RPCs with Postgres-level is_admin check — service_role key never touches Flutter
- Pure function extraction for testing — no Supabase client mocks needed for Edge Function tests
- Deterministic bot UUIDs (b{NN}00000) — made ON CONFLICT and debugging trivial
- RETURNS SETOF json fix for PostgREST compatibility — resolved opaque jsonb introspection issue

### What Was Inefficient
- STATE.md fell out of sync during rapid execution — showed "ready to plan" when all phases were done
- ROADMAP.md plan checkboxes for phases 19-24 showed `[ ]` despite having SUMMARY files — manual checkbox maintenance is fragile
- No milestone audit was run — skipped directly to completion

### Patterns Established
- `autoRefreshToken: false` in test Supabase clients to prevent GoTrueClient timer leaks
- ProviderScope.overrideWith() with stub AsyncNotifier subclasses for widget testing
- `calcTrainingDurationMinutes(devSpeedMultiplier)` — inject env dependency as parameter for pure testability
- Dev setup scripts with prerequisite checks before any work

### Key Lessons
1. STATE.md should be updated by the execution workflow, not just by resume — it drifted significantly during v1.3
2. ROADMAP.md checkboxes that duplicate SUMMARY file existence are fragile — single source of truth is better
3. Skipping milestone audit for 2 consecutive milestones (v1.2, v1.3) means accumulated tech debt is unvalidated
4. RETURNS SETOF json vs RETURNS jsonb is a PostgREST gotcha worth documenting as a constraint

### Cost Observations
- Model mix: balanced profile
- Notable: 11 plans across 7 phases in 2 days — sustained high velocity

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Plans | Days | Key Change |
|-----------|--------|-------|------|------------|
| v0.1.0 | 9 | 27 | 2 | Initial process established: wave-0 scaffolds, Edge Function authority, pg_cron loops |
| v1.1 | 3 | 8 | 3 | Phase verification integrated into execute-phase; milestone audit caught cross-phase bugs |
| v1.2 | 5 | 11 | 2 | Highest velocity milestone; no audit run; dependency ordering proved valuable |
| v1.3 | 7 | 11 | 2 | Bot AI + GodMode + CI/CD; pure function extraction for testing; STATE.md drift discovered |

### Cumulative Quality

| Milestone | Tests | Coverage | Notes |
|-----------|-------|----------|-------|
| v0.1.0 | 75 pass, 12 skip | — | 12 skips are auth/profile stubs needing live DB |
| v1.1 | 7 new widget tests | — | fl_chart chart rendering + pillage card visibility tests |
| v1.2 | — | — | No new tests added (high velocity, test discipline maintained via wave-0 scaffolds) |
| v1.3 | Deno + 9 Flutter test files | — | Pure formula Deno tests + GodMode widget tests with isolated ProviderContainer |

### Top Lessons (Verified Across Milestones)

1. Milestone audit before shipping catches integration bugs that phase-level verification misses (v0.1.0: dispatch NaN; v1.1: cityProvider staleness) — skipping it in v1.2/v1.3 means unvalidated tech debt
2. Server-authority contract (Edge Functions only) prevents entire classes of security issues
3. Always update requirement text when design decisions change scope — docs-code mismatch causes unnecessary rework (v1.1: CMBT-02)
4. STATE.md must be updated by execution workflows, not just resume — it drifted in v1.3
5. Pure function extraction enables testing without mocks — proven pattern for Edge Function testing (v1.3)
