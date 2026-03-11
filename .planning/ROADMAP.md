# Roadmap: Ikariam Clone

## Overview

Six phases take this game from a blank Flutter project to a playable multiplayer strategy game. The dependency chain is strict: auth gates everything (RLS references auth.uid()), resources gate buildings (costs require a working resource system), buildings gate military (units need Barracks/Shipyard), the world map gives military units somewhere to go, and combat is the payoff the entire system exists to deliver. Infrastructure concerns are woven throughout but receive a dedicated final phase for production hardening.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation** - Auth, database schema with RLS, server-authority contract, and Flutter/Supabase project scaffold (completed 2026-03-10)
- [ ] **Phase 2: Core Economy** - Resource production via pg_cron, warehouse limits, buildings system, and single-slot upgrade queue
- [ ] **Phase 3: World Map** - 2D grid world map, island view, city view, and auto city placement on first login
- [ ] **Phase 4: Military** - Land and naval unit training, dispatch system, and unit unlock requirements
- [ ] **Phase 5: Combat** - Turn-based 5-minute battle engine, battle reports, and naval-before-land phase ordering
- [ ] **Phase 6: Production Hardening** - Flutter web deployment, splash screen, RLS audit, performance validation

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
**Plans**: TBD

### Phase 3: World Map
**Goal**: Players can navigate a 2D grid world map, view islands with their city slots and resource areas, and see their own city laid out on a building grid
**Depends on**: Phase 2
**Requirements**: MAP-01, MAP-02, MAP-03, MAP-04, MAP-05
**Success Criteria** (what must be TRUE):
  1. Player can open the world map and see islands positioned on a 2D grid coordinate system
  2. Tapping an island opens the island view showing all occupied city slots and the island's wood and luxury resource gathering areas
  3. Tapping a city slot owned by the player opens the city view with buildings displayed on a grid layout
  4. The map renders as a simple 2D grid (not isometric) and is navigable by pan and zoom
**Plans**: TBD

### Phase 4: Military
**Goal**: Players can train land and naval units from appropriate buildings, units require correct building levels to unlock, and trained troops can be dispatched toward other cities
**Depends on**: Phase 3
**Requirements**: MIL-01, MIL-02, MIL-03, MIL-04, MIL-05
**Success Criteria** (what must be TRUE):
  1. Player with a Barracks can queue training for any of the 8 land unit types that the current building level unlocks
  2. Player with a Shipyard can queue training for any of the 5 naval unit types that the current building level unlocks
  3. Unit training completes automatically after the correct duration via server-side pg_cron and units appear in the player's army roster
  4. Player can dispatch a trained army toward another city and see the troops listed as "in transit" with a travel-time countdown
**Plans**: TBD

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
**Plans**: TBD

### Phase 6: Production Hardening
**Goal**: The game is deployed to the web with acceptable first-load performance, a proper splash screen during CanvasKit load, and the server-authority contract verified in production
**Depends on**: Phase 5
**Requirements**: INFR-01
**Success Criteria** (what must be TRUE):
  1. Visiting the game URL shows a styled HTML/CSS splash screen immediately while CanvasKit loads — the page is never blank
  2. The game reaches interactive state within an acceptable time on a standard connection
  3. All INFR-02 and INFR-03 guarantees (server-only mutations, RLS on all tables) are verified to hold in the production Supabase environment
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 4/4 | Complete   | 2026-03-10 |
| 2. Core Economy | 0/TBD | Not started | - |
| 3. World Map | 0/TBD | Not started | - |
| 4. Military | 0/TBD | Not started | - |
| 5. Combat | 0/TBD | Not started | - |
| 6. Production Hardening | 0/TBD | Not started | - |
