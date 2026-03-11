---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
stopped_at: Completed 04-military-04-01-PLAN.md
last_updated: "2026-03-11T13:55:59.865Z"
last_activity: "2026-03-11 - Completed 02-00: Wave 0 test scaffolds for Phase 2"
progress:
  total_phases: 6
  completed_phases: 3
  total_plans: 15
  completed_plans: 12
  percent: 63
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-11)

**Core value:** Players can build and manage cities, gather resources, and engage in real-time turn-based warfare — the core loop of build, expand, and conquer must feel satisfying and strategically meaningful.
**Current focus:** Phase 2 — Core Economy

## Current Position

Phase: 4 of 6 (Military)
Plan: 2 of 4 in current phase (04-01 complete)
Status: Executing
Last activity: 2026-03-11 - Completed 04-01: Military database layer (tables + functions + cron jobs)

Progress: [███████░░░] 68%

## Performance Metrics

**Velocity:**
- Total plans completed: 3
- Average duration: 12 min
- Total execution time: 0.60 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1. Foundation | 3/4 | ~36 min | 12 min |

**Recent Trend:**
- Last 5 plans: 01-00 (15 min), 01-01 (17 min), 01-02 (4 min)
- Trend: Accelerating

*Updated after each plan completion*
| Phase 01-foundation P01 | 17 | 2 tasks | 13 files |
| Phase 01-foundation P02 | 4 | 2 tasks | 12 files |
| Phase 01-foundation P03 | 4 | 2 tasks | 7 files |
| Phase 02-core-economy P00 | 2 | 1 tasks | 3 files |
| Phase 02-core-economy P01 | 3 | 2 tasks | 7 files |
| Phase 02-core-economy P02 | 4 | 2 tasks | 8 files |
| Phase 02-core-economy P03 | 5 | 2 tasks | 8 files |
| Phase 03-world-map P00 | 5 | 1 tasks | 3 files |
| Phase 03-world-map P01 | 3 | 2 tasks | 8 files |
| Phase 03-world-map P02 | 45 | 2 tasks | 9 files |
| Phase 04-military P00 | 5 | 1 tasks | 3 files |
| Phase 04-military P01 | 3 | 2 tasks | 6 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- All game mutations go through Edge Functions — no Flutter client writes directly to game-state tables
- pg_cron jobs must be created via raw SQL (not dashboard UI) to avoid 5-second HTTP timeout cap
- RLS must be enabled in the same migration that creates each table — never added later
- All timestamps are server-side NOW() — client computes display-only countdowns from server UTC
- [01-00] Mock stubs in mocks.dart use placeholder classes until supabase_flutter + go_router are added in Plan 01-01
- [01-00] Test scaffolding pattern: all requirement-mapped tests created as skipped stubs before production code exists
- [Phase 01-foundation]: riverpod_generator omitted from pubspec: incompatible with flutter_test pinned deps in Dart 3.10.1 (analyzer ^9.0.0 conflict); to be added when SDK supports it
- [Phase 01-foundation]: Supabase DB verification via docker exec supabase_db_ikariam psql (psql not in PATH on Windows)
- [01-02] Manual Riverpod providers used throughout (no @riverpod code-gen): riverpod_generator still requires analyzer ^9.0.0, incompatible with Dart 3.10.1
- [01-02] GoRouter created once per app lifetime; _RouterNotifier bridges Riverpod state changes to refreshListenable — router never recreated on auth change
- [01-02] ProfileRepository.updateProfile uses direct client write (exception to Edge Function rule): profiles is a player-preferences table with profiles_update_own RLS policy
- [Phase 01-foundation]: AppTheme._primaryColor promoted to public static const: AvatarWidget needs the primary colour at field level without BuildContext
- [Phase 01-foundation]: CityNotifier uses manual AsyncNotifier (no code-gen): riverpod_generator still incompatible with Dart 3.10.1 — same decision as 01-02
- [Phase 01-foundation]: CityRepository is SELECT-only with island join: cities table has SELECT-only RLS; city creation is trigger-only (handle_new_user)
- [quick-1]: .env.local gitignored to allow per-developer port/key overrides; local Supabase keys are deterministic but devs may run on different ports
- [quick-1]: Islands table RLS blocks anon reads — 100 islands confirmed via service_role key (Content-Range: 0-0/100)
- [Phase 02-core-economy]: Wave 0 test scaffolds follow same skip pattern as Phase 1 Plan 01-00: stubs with TODO comments pointing to implementing plan
- [Phase 02-core-economy]: Production buildings (sawmill, quarry, glassblower, sulfur_pit) included in city_buildings CHECK constraint — required for all 5 resources to produce via process_resource_tick()
- [Phase 02-core-economy]: pg_cron extension registered via migration file (not seed.sql) to avoid schema-cron-does-not-exist error on supabase db reset
- [Phase 02-core-economy]: BASE_COSTS and BASE_TIMES duplicated in Edge Function TypeScript and Dart constants — sync comment enforces manual consistency; server authority must not import client code
- [Phase 02-core-economy]: Non-atomic resource deduction in upgrade-building: deduct_resource() called sequentially per resource; partial deduction possible on failure (acceptable for v1)
- [Phase 02-core-economy]: ConstructionQueueEntry.buildingType is String (not BuildingType enum) to keep construction model decoupled from building enum
- [Phase 02-core-economy]: BuildingUpgradeException wraps Edge Function server error message for structured UI error display
- [Phase 02-core-economy]: CountdownTimerWidget is display-only: Timer.periodic ticks display every second, pg_cron complete_building_upgrades() handles actual completion
- [Phase 02-core-economy]: constructionQueueProvider streams construction_queue directly without repository class — no client-side mutations so repository abstraction adds no value
- [Phase 03-world-map]: Phase 03 Wave 0 test scaffolds follow same skip pattern as Phase 1 and Phase 2: unit tests use skip string messages, widget tests use skip:true boolean
- [Phase 03-world-map]: File-level GlobalKey<NavigatorState> for StatefulShellBranch navigator keys — must not be recreated inside Provider or build
- [Phase 03-world-map]: NavigationBar (Material 3) used instead of BottomNavigationBar — useMaterial3: true confirmed in app_theme.dart
- [Phase 03-world-map]: Auth Rule 4 redirect changed from /city to /map — world map is the post-login landing screen
- [Phase 03-world-map]: 5x5 world map grid (not 5x2): expanded from checkpoint feedback, matched seed data
- [Phase 03-world-map]: playerIslandIdProvider added: IslandScreen derives default island from cityProvider to avoid null loading state
- [Phase 04-military]: Wave 0 test scaffolds follow same skip pattern as Phases 1, 2, and 3: unit stubs use skip string messages pointing to implementing plan, widget stubs use skip: true boolean
- [04-01]: unit_movements uses JSONB snapshot (not join table): army immutable at departure, no cascading deletes, simpler Phase 5 combat resolution
- [04-01]: city_units has no pre-population trigger — complete_training() uses INSERT ON CONFLICT for first unit creation in a city
- [04-01]: process_arrivals() uses jsonb_each_text() to iterate JSONB unit type/quantity pairs in unit_movements.units

### Pending Todos

None yet.

### Blockers/Concerns

- Phase 4/5: Turn-based battle networking over WebSocket is a niche pattern with sparse documentation — research recommended before planning Phase 5
- Phase 3: flame_tiled integration and multi-city ownership schema (colonies) may need phase-level research before planning
- Game balance formulas (base costs, production rates, unit stats) not validated — will need iteration post-launch

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 1 | Setup Supabase local dev with Docker - start services, init config, apply migrations | 2026-03-11 | 0b035b5 | [1-setup-supabase-local-dev-with-docker-sta](./quick/1-setup-supabase-local-dev-with-docker-sta/) |

## Session Continuity

Last session: 2026-03-11T07:20:00Z
Stopped at: Completed 04-military-04-01-PLAN.md
Resume file: None
