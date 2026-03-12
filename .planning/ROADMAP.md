# Roadmap: Ikariam Clone

## Overview

Seven phases take this game from a blank Flutter project to a playable, easily testable multiplayer strategy game. The dependency chain is strict: auth gates everything (RLS references auth.uid()), resources gate buildings (costs require a working resource system), buildings gate military (units need Barracks/Shipyard), the world map gives military units somewhere to go, and combat is the payoff the entire system exists to deliver. Infrastructure concerns are woven throughout but receive a dedicated phase for production hardening, followed by test infrastructure to make the whole system easy to validate and iterate on.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation** - Auth, database schema with RLS, server-authority contract, and Flutter/Supabase project scaffold (completed 2026-03-10)
- [x] **Phase 2: Core Economy** - Resource production via pg_cron, warehouse limits, buildings system, and single-slot upgrade queue (completed 2026-03-11)
- [x] **Phase 3: World Map** - 2D grid world map, island view, city view, and auto city placement on first login (completed 2026-03-11)
- [x] **Phase 4: Military** - Land and naval unit training, dispatch system, and unit unlock requirements (completed 2026-03-11)
- [x] **Phase 5: Combat** - Turn-based 5-minute battle engine, battle reports, and naval-before-land phase ordering (completed 2026-03-11)
- [x] **Phase 6: Production Hardening** - Flutter web deployment, splash screen, RLS audit, performance validation (completed 2026-03-12)
- [x] **Phase 7: Test Infrastructure** - Multi-account test scenarios, dev toolbar, rich seed scripts, unified test automation CLI (completed 2026-03-12)
- [ ] **Phase 8: Bug Fixes & Timer Guards** - Fix dispatch-units undefined constant, add environment guard for speed-up migration, implement partial army engagement, fix dev toolbar bug
- [ ] **Phase 9: Phase 2 Verification** - Create missing Phase 2 VERIFICATION.md for 9 RSRC/BLDG requirements

## Phase Details

### Phase 1: Foundation
**Goal**: A working Flutter web project with Supabase Auth, a fully RLS-protected database schema, and the server-authority contract established — no game feature can be built without this base
**Depends on**: Nothing (first phase)
**Requirements**: AUTH-01, AUTH-02, AUTH-03, AUTH-04, INFR-02, INFR-03
**Success Criteria** (what must be TRUE):
  1. User can sign up with email and password and receive a confirmation
  2. User can log in and their session persists after a full browser refresh without re-entering credentials
  3. User can create a display name and avatar for their player profile
  4. A city is automatically placed on an island the first time a new player logs in — no manual action required
  5. All database tables have RLS enabled at migration time and no Flutter client can directly write to any game-state table
**Plans:** 4/4 plans complete

Plans:
- [x] 01-00-PLAN.md — Wave 0: Test infrastructure scaffolds, mock helpers, and skeleton test files for all phase requirements
- [x] 01-01-PLAN.md — Flutter/Supabase project scaffold, database migrations with RLS, island seeding, handle_new_user trigger
- [x] 01-02-PLAN.md — Auth system: login/signup screens, Riverpod auth state provider, GoRouter with auth guards
- [x] 01-03-PLAN.md — Profile creation screen with avatar picker, city placeholder screen, end-to-end flow verification

### Phase 2: Core Economy
**Goal**: Cities produce resources on a server-side schedule, warehouses cap storage, and players can queue building upgrades — the core idle loop is running
**Depends on**: Phase 1
**Requirements**: RSRC-01, RSRC-02, RSRC-03, RSRC-04, BLDG-01, BLDG-02, BLDG-03, BLDG-04, BLDG-05
**Success Criteria** (what must be TRUE):
  1. A city's five resource totals (Wood, Marble, Crystal, Sulfur, Gold) increase automatically every 5 minutes without the player doing anything
  2. Resource totals stop increasing once the warehouse capacity for that resource type is full
  3. Player can tap a building slot, see the upgrade cost and time, and queue an upgrade that completes after the correct duration
  4. A second upgrade request is rejected while a construction queue is already active
  5. Production rate displayed to the player reflects the workers x building_level x research_bonus formula running server-side
**Plans:** 4/4 plans complete

Plans:
- [x] 02-00-PLAN.md — Wave 0: Test scaffolds for building upgrade, resource production, and formula tests
- [x] 02-01-PLAN.md — Database schema (city_resources, city_buildings with 14 types, construction_queue), server functions (resource tick, construction completion), pg_cron jobs
- [x] 02-02-PLAN.md — upgrade-building Edge Function, Dart constants/models for buildings and resources, formula unit tests
- [x] 02-03-PLAN.md — Flutter UI: real-time resource display, building list, upgrade bottom sheet, construction countdown, end-to-end verification

### Phase 3: World Map
**Goal**: Players can navigate a 2D grid world map, view islands with their city slots and resource areas, and see their own city laid out on a building grid
**Depends on**: Phase 2
**Requirements**: MAP-01, MAP-02, MAP-03, MAP-04, MAP-05
**Success Criteria** (what must be TRUE):
  1. Player can open the world map and see islands positioned on a 2D grid coordinate system
  2. Tapping an island opens the island view showing all occupied city slots and the island's wood and luxury resource gathering areas
  3. Tapping a city slot owned by the player opens the city view with buildings displayed on a grid layout
  4. The map renders as a simple 2D grid (not isometric) and is navigable by pan and zoom
**Plans:** 3/3 plans complete

Plans:
- [x] 03-00-PLAN.md — Wave 0: Test scaffolds for map models, building positions, and world map smoke test
- [x] 03-01-PLAN.md — Island models, MapRepository, Riverpod providers, StatefulShellRoute navigation shell, seed update (100 to 10 islands)
- [x] 03-02-PLAN.md — World Map, Island View, and City Grid screens with InteractiveViewer pan/zoom, human verification

### Phase 4: Military
**Goal**: Players can train land and naval units from appropriate buildings, units require correct building levels to unlock, and trained troops can be dispatched toward other cities
**Depends on**: Phase 3
**Requirements**: MIL-01, MIL-02, MIL-03, MIL-04, MIL-05
**Success Criteria** (what must be TRUE):
  1. Player with a Barracks can queue training for any of the 8 land unit types that the current building level unlocks
  2. Player with a Shipyard can queue training for any of the 5 naval unit types that the current building level unlocks
  3. Unit training completes automatically after the correct duration via server-side pg_cron and units appear in the player's army roster
  4. Player can dispatch a trained army toward another city and see the troops listed as "in transit" with a travel-time countdown
**Plans:** 4/4 plans complete

Plans:
- [x] 04-00-PLAN.md — Wave 0: Test scaffolds for unit constants, military models, and barracks widget
- [x] 04-01-PLAN.md — Database tables (city_units, training_queue, unit_movements), pg functions (complete_training, deduct_units, process_arrivals), pg_cron jobs
- [x] 04-02-PLAN.md — Edge Functions (train-units, dispatch-units), Dart UnitType enum/constants, military models, TDD unit tests
- [x] 04-03-PLAN.md — Flutter UI: MilitaryRepository, providers, BarracksScreen, ShipyardScreen, DispatchScreen, route integration, human verification

### Phase 5: Combat
**Goal**: Two players' armies can engage in a turn-based battle that resolves in 5-minute turns server-side, both players receive battle reports in real-time, and naval units fight before land units each turn
**Depends on**: Phase 4
**Requirements**: CMBT-01, CMBT-02, CMBT-03, CMBT-04, CMBT-05
**Success Criteria** (what must be TRUE):
  1. When an army arrives at an enemy city, a battle begins and both players can see the battle is active with the current turn number and time until next turn
  2. Each 5-minute turn a portion of armies engage, casualties are applied server-side, and surviving units carry to the next turn automatically
  3. Naval units engage and resolve before land units each turn — the sequence is observable in the battle report
  4. After each turn resolves, both the attacker and defender receive a battle report update via Supabase Realtime without refreshing the page
  5. All battle outcome numbers (casualties, survivors) are calculated server-side and the client cannot submit calculated results
**Plans:** 4/4 plans complete

Plans:
- [x] 05-00-PLAN.md — Wave 0: Test scaffolds for battle models and combat formula
- [x] 05-01-PLAN.md — Database tables (battles, battle_turns), resolve_battles() pg function, modified process_arrivals(), battle-tick cron job
- [x] 05-02-PLAN.md — Dart Battle/BattleTurn models, unit combat stats, BattleRepository with dual Realtime streams, providers (TDD)
- [x] 05-03-PLAN.md — Flutter UI: BattlesScreen, BattleDetailScreen, BattleTurnCard, 4th navigation tab, human verification

### Phase 6: Production Hardening
**Goal**: The game is deployed to the web with acceptable first-load performance, a proper splash screen during CanvasKit load, and the server-authority contract verified in production
**Depends on**: Phase 5
**Requirements**: INFR-01
**Success Criteria** (what must be TRUE):
  1. Visiting the game URL shows a styled HTML/CSS splash screen immediately while CanvasKit loads — the page is never blank
  2. The game reaches interactive state within an acceptable time on a standard connection
  3. All INFR-02 and INFR-03 guarantees (server-only mutations, RLS on all tables) are verified to hold in the production Supabase environment
**Plans:** 2/2 plans complete

Plans:
- [x] 06-01-PLAN.md — Splash screen implementation: Wave 0 test scaffold, index.html splash div, custom flutter_bootstrap.js, manifest.json branding
- [x] 06-02-PLAN.md — Production build, INFR-02/INFR-03 security audits, visual splash verification checkpoint

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 4/4 | Complete   | 2026-03-10 |
| 2. Core Economy | 4/4 | Complete   | 2026-03-11 |
| 3. World Map | 3/3 | Complete   | 2026-03-11 |
| 4. Military | 4/4 | Complete   | 2026-03-11 |
| 5. Combat | 4/4 | Complete   | 2026-03-11 |
| 6. Production Hardening | 2/2 | Complete   | 2026-03-12 |
| 7. Test Infrastructure | 3/3 | Complete   | 2026-03-12 |
| 8. Bug Fixes & Timer Guards | 0/2 | In Progress | - |
| 9. Phase 2 Verification | 0/0 | Not started | - |

### Phase 7: Test Infrastructure
**Goal**: The game is easily testable with multiple pre-configured accounts at different game stages, a dev toolbar for instant game-state manipulation, seed scripts for ready-to-play scenarios, and a unified test automation script that resets and validates everything in one command
**Depends on**: Phase 6
**Requirements**: TEST-01, TEST-02, TEST-03, TEST-04
**Success Criteria** (what must be TRUE):
  1. At least 6+ test accounts exist with varied game states (new player, mid-game with buildings, military-ready with army, active battle, etc.) so each feature can be tested without manual setup
  2. A dev toolbar is accessible in debug mode that allows instant resource injection, building level-up, unit spawning, and battle triggering without going through normal game flows
  3. Seed scripts produce a rich, deterministic game world where multiple accounts are already interacting (troops dispatched, battles in progress, construction queues active)
  4. A single CLI command resets the database, re-seeds all data, runs all Flutter unit/widget tests, and reports pass/fail status
**Plans:** 3/3 plans complete

Plans:
- [x] 07-01-PLAN.md — Expand seed.sql to 7 test accounts with rich game states, create SECURITY DEFINER RPC helpers for dev toolbar
- [x] 07-02-PLAN.md — Flutter DevToolbarWrapper widget with resource injection, building level-up, unit spawning, battle triggering actions
- [x] 07-03-PLAN.md — Unified CLI test scripts (test_all.sh + test_all.ps1), end-to-end human verification

### Phase 8: Bug Fixes & Timer Guards
**Goal**: Fix the dispatch-units undefined constant that breaks unit arrival, add environment guard to speed-up migration so production uses correct timers, implement partial army engagement per turn, and fix dev toolbar trigger battle bug
**Depends on**: Phase 7
**Requirements**: MIL-05, CMBT-01, CMBT-02
**Gap Closure**: Closes gaps from v1.0 milestone audit
**Success Criteria** (what must be TRUE):
  1. Dispatched units arrive at their destination with a valid arrive_at timestamp and process_arrivals picks them up
  2. Production environment uses 5-minute battle turns (CMBT-01) and 5-minute resource ticks (RSRC-02) — speed-up migration is environment-gated
  3. Each battle turn only a fraction of armies engage (e.g., 30%), with survivors carrying to next turn
  4. Dev toolbar "Trigger Battle" action works correctly without controller dispose error
**Plans:** 2 plans

Plans:
- [ ] 08-01-PLAN.md — Wave 0 test scaffolds, dispatch-units constant fix (MIL-05), dev toolbar dispose fix
- [ ] 08-02-PLAN.md — Environment guard migration (CMBT-01), partial army engagement in resolve_battles() (CMBT-02)

### Phase 9: Phase 2 Verification
**Goal**: Create the missing Phase 2 VERIFICATION.md to formally verify all 9 RSRC and BLDG requirements against the codebase
**Depends on**: Phase 8
**Requirements**: RSRC-01, RSRC-02, RSRC-03, RSRC-04, BLDG-01, BLDG-02, BLDG-03, BLDG-04, BLDG-05
**Gap Closure**: Closes verification gap from v1.0 milestone audit
**Success Criteria** (what must be TRUE):
  1. Phase 2 VERIFICATION.md exists with observable truths for all 9 requirements
  2. Each requirement has evidence linking to specific code files and functions
**Plans:** 0/0 plans
