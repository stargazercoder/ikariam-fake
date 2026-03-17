# Roadmap: Ikariam Clone

## Milestones

- ✅ **v0.1.0 MVP** — Phases 1-9 (shipped 2026-03-12)
- ✅ **v1.1 Economy & Combat Depth** — Phases 10-12 (shipped 2026-03-15)
- ✅ **v1.2 Espionage, Trading & Polish** — Phases 13-17 (shipped 2026-03-17)
- 🚧 **v1.3 Bots, Testing & Automation** — Phases 18-24 (in progress)

## Phases

<details>
<summary>✅ v0.1.0 MVP (Phases 1-9) — SHIPPED 2026-03-12</summary>

- [x] Phase 1: Foundation (4/4 plans) — completed 2026-03-10
- [x] Phase 2: Core Economy (4/4 plans) — completed 2026-03-11
- [x] Phase 3: World Map (3/3 plans) — completed 2026-03-11
- [x] Phase 4: Military (4/4 plans) — completed 2026-03-11
- [x] Phase 5: Combat (4/4 plans) — completed 2026-03-11
- [x] Phase 6: Production Hardening (2/2 plans) — completed 2026-03-12
- [x] Phase 7: Test Infrastructure (3/3 plans) — completed 2026-03-12
- [x] Phase 8: Bug Fixes & Timer Guards (2/2 plans) — completed 2026-03-12
- [x] Phase 9: Phase 2 Verification (1/1 plan) — completed 2026-03-12

Full details: [milestones/v0.1.0-ROADMAP.md](milestones/v0.1.0-ROADMAP.md)

</details>

<details>
<summary>✅ v1.1 Economy & Combat Depth (Phases 10-12) — SHIPPED 2026-03-15</summary>

- [x] Phase 10: Economy Foundation (3/3 plans) — completed 2026-03-13
- [x] Phase 11: Island Upgrades + Resource Rate UI (2/2 plans) — completed 2026-03-13
- [x] Phase 12: Combat Depth (3/3 plans) — completed 2026-03-15

Full details: [milestones/v1.1-ROADMAP.md](milestones/v1.1-ROADMAP.md)

</details>

<details>
<summary>✅ v1.2 Espionage, Trading & Polish (Phases 13-17) — SHIPPED 2026-03-17</summary>

- [x] Phase 13: Dev Acceleration (2/2 plans) — completed 2026-03-16
- [x] Phase 14: Movement Visibility (2/2 plans) — completed 2026-03-16
- [x] Phase 15: Resource Trading (2/2 plans) — completed 2026-03-16
- [x] Phase 16: Espionage & City Viewing (3/3 plans) — completed 2026-03-16
- [x] Phase 17: UI Polish (2/2 plans) — completed 2026-03-17

</details>

### 🚧 v1.3 Bots, Testing & Automation (Phases 18-24)

**Milestone Goal:** Populate the world with 20 AI bot players that autonomously build, train, and fight; add a GodMode admin dashboard to observe and control the living world; enrich seed data; add unit tests for critical paths; and provide single-command automation for dev setup and CI/CD.

- [x] **Phase 18: Bot Schema Foundation** — DB migration adding is_bot/is_admin columns and bot_schedules table; updated Profile Dart model (completed 2026-03-17)
- [x] **Phase 19: Bot Behavior Engine** — PL/pgSQL run_bot_decisions() + pg_cron bot-think-tick driving attack, retrain, and upgrade behaviors (completed 2026-03-17)
- [ ] **Phase 20: Seed Data** — 20 diverse bot accounts with varied buildings, armies, and resources seeded idempotently on db reset
- [ ] **Phase 21: GodMode Backend** — SECURITY DEFINER RPCs for world-state reads and bot/player controls; go_router admin route guard
- [ ] **Phase 22: GodMode Flutter Dashboard** — Full-page admin screen with player table, bot pause controls, event feed, and resource edit form
- [ ] **Phase 23: Unit Tests** — Deno test suite for critical Edge Functions; Flutter widget tests with isolated ProviderContainer
- [ ] **Phase 24: Automation & CI** — Single-command dev scripts and GitHub Actions CI pipeline running tests, lint, and build on push

## Phase Details

### Phase 13: Dev Acceleration
**Goal**: Developers can accelerate game testing by spawning multiple unit types at once and running timers at 5x speed
**Depends on**: Nothing (dev-mode-only changes, no production feature dependencies)
**Requirements**: DEVT-01, DEVT-02, DEVT-03
**Success Criteria** (what must be TRUE):
  1. Dev toolbar shows a bulk spawn dialog where multiple unit types and quantities can be selected and spawned in a single action
  2. Unit training completes at 1/5 of normal time when dev mode is active
  3. Unit travel and arrival completes at 1/5 of normal time when dev mode is active
  4. Bulk spawn and timer overrides are invisible and inert in production builds
**Plans:** 2/2 plans complete
Plans:
- [x] 13-01-PLAN.md — Server-side RPC functions and Edge Function timer speed-ups
- [x] 13-02-PLAN.md — Flutter dev toolbar bulk spawn dialog and instant complete button

### Phase 14: Movement Visibility
**Goal**: Players can see all their armies and cargo currently in transit with full context (destination, ETA, composition)
**Depends on**: Nothing (reads existing unit_movements table; cargo JSONB column already present)
**Requirements**: MOVE-01, MOVE-02
**Success Criteria** (what must be TRUE):
  1. Player sees a list of all outgoing army movements showing destination city, arrival ETA, and the unit types and counts in the movement
  2. Player sees returning cargo ships in the same movement list showing the resource amounts being carried (pillage loot or trade cargo)
  3. Movement list updates in real-time as new dispatches are sent and arrivals are confirmed
**Plans:** 2/2 plans complete
Plans:
- [x] 14-01-PLAN.md — UnitMovement model update, global movements stream, and movement providers
- [x] 14-02-PLAN.md — Movements screen UI, navigation tab, and end-to-end verification

### Phase 15: Resource Trading
**Goal**: Players can send resources to any other player's city using cargo ships that travel in real time
**Depends on**: Phase 14 (movement visibility confirms cargo display works before adding trade-originated cargo)
**Requirements**: TRAD-01
**Success Criteria** (what must be TRUE):
  1. Player can open a trade dialog from another player's city and specify resource type and amount to send
  2. Sending resources deducts the amount from the sender's warehouse immediately and creates a cargo ship movement
  3. Cargo ships arrive at the destination city after the distance-based travel time and the resources are added to the recipient's warehouse
  4. Both sender and recipient can see the in-transit cargo in their movement lists (Phase 14 visibility)
  5. Trade is blocked if the sender has insufficient resources or the recipient's warehouse would overflow
**Plans:** 2/2 plans complete
Plans:
- [x] 15-01-PLAN.md — DB migration (trade movement type + deduct_resources RPC) and send-trade Edge Function
- [x] 15-02-PLAN.md — TradeRepository, TradeDialog with sliders, island screen trade integration, movements screen trade display

### Phase 16: Espionage & City Viewing
**Goal**: Players can spy on enemy cities to gather intelligence and view any player's city layout in read-only mode
**Depends on**: Nothing (espionage is an instant server-side action; read-only city view reads existing city/building data)
**Requirements**: ESPY-01, ESPY-02
**Success Criteria** (what must be TRUE):
  1. Player can trigger a spy action against any enemy city and receive a report showing current resource amounts, building levels, and total army counts
  2. Spy action resolves instantly (no travel time, no spy unit consumed)
  3. Player can navigate to any other player's city screen and see a read-only version of their building grid and city stats
  4. Read-only city view clearly indicates it is not the player's own city (no action buttons, ownership label visible)
**Plans:** 3/3 plans complete
Plans:
- [x] 16-00-PLAN.md — Wave 0 test scaffold (unit + widget test stubs for Nyquist compliance)
- [x] 16-01-PLAN.md — DB migration (spy_reports table) + spy-city Edge Function + SpyReport model + repository + providers
- [x] 16-02-PLAN.md — Spy report dialog, enemy city view screen, spy log, island screen integration, router

### Phase 17: UI Polish
**Goal**: City view, map, and military screens are visually cleaner and players can instantly distinguish their own vs enemy cities and unit types by color
**Depends on**: Nothing (visual-only changes; no new data dependencies)
**Requirements**: UIPL-01, UIPL-02, UIPL-03
**Success Criteria** (what must be TRUE):
  1. City view screen has no AppBar title bar — the building grid fills the full available vertical space
  2. On the island view and world map, each city slot uses a distinct color to differentiate own city (green), allied cities, and enemy cities
  3. Unit type rows in military screens (training queue, battle reports, army lists) render with the matching color from unitTypeColors for that unit type
  4. Color coding is consistent across all screens that display units or city markers
**Plans:** 2/2 plans complete
Plans:
- [x] 17-01-PLAN.md — Constants (ownership colors, unit type icons) and transparent AppBar on city screens
- [x] 17-02-PLAN.md — Ownership color borders on maps and CircleAvatar unit icons on military screens

### Phase 18: Bot Schema Foundation
**Goal**: The database schema and Dart model are ready for bot accounts and admin access, unblocking all other v1.3 phases
**Depends on**: Nothing (schema-only migration, no v1.2 feature coupling)
**Requirements**: BOT-01, BOT-06
**Success Criteria** (what must be TRUE):
  1. profiles table has is_bot (boolean, default false) and is_admin (boolean, default false) columns with correct RLS — existing player rows are unaffected
  2. bot_schedules table exists with aggression (0-3), is_paused, and next_action_at columns; RLS is enabled with no client-facing policies
  3. Profile Dart model exposes isBot and isAdmin fields that round-trip correctly through the existing profile provider
  4. A bot profile row (is_bot = true) cannot be read or modified by a non-admin player through any existing RLS policy
**Plans:** 1/1 plans complete
Plans:
- [x] 18-01-PLAN.md — Bot schema migration (profiles columns + bot_schedules table) and Profile Dart model getters

### Phase 19: Bot Behavior Engine
**Goal**: Bot players autonomously attack neighboring cities, retrain their armies after losses, and upgrade buildings and island resources on a pg_cron schedule
**Depends on**: Phase 18 (requires is_bot, is_admin, bot_schedules schema)
**Requirements**: BOT-02, BOT-03, BOT-04, BOT-05
**Success Criteria** (what must be TRUE):
  1. A single bot-think-tick pg_cron job fires every 15 minutes and processes one action per non-paused bot per tick without exhausting the pg_cron worker pool
  2. After 15 minutes with bots present, at least one bot has a new entry in unit_movements (attack dispatched) or training_queue (retraining) or construction_queue (upgrade)
  3. Bots with higher aggression values dispatch attacks more frequently than low-aggression bots across a 100-tick simulation
  4. A bot that loses army units below its target threshold inserts a new training_queue row to retrain within the next tick
  5. Bot actions write directly to the same game tables (training_queue, construction_queue, unit_movements) that Edge Functions write to — existing processing ticks handle bot completions without modification
**Plans:** 2/2 plans complete
Plans:
- [ ] 19-01-PLAN.md — Bot helper functions: bot_decide_upgrade() and bot_decide_train() with cost tables and queue logic
- [ ] 19-02-PLAN.md — Bot attack function, run_bot_decisions() orchestrator, and bot-think-tick pg_cron registration

### Phase 20: Seed Data
**Goal**: Running supabase db reset produces a world with 20 diverse bot accounts ready for gameplay testing, and running it twice produces no errors
**Depends on**: Phase 18 (bot schema columns must exist), Phase 19 (bot_schedules rows reference bot behavior)
**Requirements**: SEED-01, SEED-02
**Success Criteria** (what must be TRUE):
  1. After db reset, 20 bot profiles exist on the world map distributed across at least 8 distinct islands with varied city slot positions
  2. Bot accounts show at least 3 distinct development profiles: low (level 1-2 buildings, small army), mid (level 3-4 buildings, moderate army), high (level 5+ buildings, large army)
  3. Running supabase db reset a second time immediately after the first completes with exit code 0 and no duplicate key errors
  4. All 20 bots have bot_schedules rows with varied aggression levels (0-3) distributed across the range
**Plans**: TBD

### Phase 21: GodMode Backend
**Goal**: SECURITY DEFINER RPCs expose full world state and bot/player controls to admin users only — the service_role key never appears in any Flutter file
**Depends on**: Phase 18 (requires is_admin column on profiles)
**Requirements**: GOD-05
**Success Criteria** (what must be TRUE):
  1. godmode_get_world_state() RPC returns a JSONB snapshot of all players' resources, army sizes, active battles, and bot status — calling it as a non-admin user returns an error or empty result
  2. godmode_set_bot_paused() RPC sets is_paused on a bot_schedules row; the next bot-think-tick skips that bot
  3. godmode_force_action() RPC triggers one immediate bot decision for the specified bot without waiting for the cron schedule
  4. admin_set_resources() RPC modifies any player's resource balances; calling it as a non-admin user is rejected at the Postgres layer
  5. A /godmode route guard in app_router.dart redirects non-admin users before any GodMode widget renders — the guard reads isAdmin from the Profile model, not a client-side flag
**Plans**: TBD

### Phase 22: GodMode Flutter Dashboard
**Goal**: An admin user can open a full-page dashboard to observe every player's state in real time and control bot behaviors without leaving the app
**Depends on**: Phase 21 (requires all GodMode RPCs to be stable and tested)
**Requirements**: GOD-01, GOD-02, GOD-03, GOD-04
**Success Criteria** (what must be TRUE):
  1. Admin sees a sortable, sticky-header table showing all players with columns for resources, army size, building count, active battles, and bot/human indicator
  2. Admin can pause or resume any individual bot from the dashboard row — the pause state updates visually within the next poll cycle (30 seconds)
  3. Admin sees a live event feed panel displaying the last N battles, trades, and espionage actions across all players, refreshing every 30 seconds
  4. Admin can open a resource edit form for any player, enter new resource amounts, and submit — the player's resource display reflects the change within one poll cycle
  5. Bot accounts appear with a distinct visual marker visible only to admin; to all other players they appear as normal human players
**Plans**: TBD

### Phase 23: Unit Tests
**Goal**: Critical Edge Function logic and GodMode Flutter widgets are covered by automated tests that run locally without a live Supabase instance
**Depends on**: Phase 19 (extractable bot logic), Phase 22 (GodMode widgets to test)
**Requirements**: TEST-01, TEST-02
**Success Criteria** (what must be TRUE):
  1. Running deno test supabase/functions/tests/ executes tests for upgrade-building and train-units Edge Functions against extracted pure functions with no Supabase client mock required
  2. Each Deno test file imports only the extracted pure function module — no HTTP server, no Supabase client instantiated
  3. Running flutter test test/ executes GodMode widget tests where each test creates its own isolated ProviderContainer with explicit provider overrides — no test state leaks between runs
  4. All tests pass when run in suite order and in reverse order (proving no inter-test state dependency)
**Plans**: TBD

### Phase 24: Automation & CI
**Goal**: A developer can set up the full project from scratch with one command, and every push to main automatically runs the full quality gate
**Depends on**: Phase 23 (tests must exist and pass before CI is configured)
**Requirements**: AUTO-01, AUTO-02
**Success Criteria** (what must be TRUE):
  1. Running scripts/dev_setup.sh from a clean clone performs db reset, seeds bot data, starts Edge Functions serve, and builds Flutter web — completing without manual intervention
  2. A GitHub Actions workflow triggers on push to main and runs flutter analyze, flutter test, deno test, and flutter build web — all steps must pass for the workflow to succeed
  3. Deno is pinned to 2.2.x in the CI workflow file with an inline comment referencing the Supabase Edge Runtime lock file constraint
  4. A failed flutter analyze (lint error) or failed deno test causes the CI workflow to exit non-zero and block the push
**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation | v0.1.0 | 4/4 | Complete | 2026-03-10 |
| 2. Core Economy | v0.1.0 | 4/4 | Complete | 2026-03-11 |
| 3. World Map | v0.1.0 | 3/3 | Complete | 2026-03-11 |
| 4. Military | v0.1.0 | 4/4 | Complete | 2026-03-11 |
| 5. Combat | v0.1.0 | 4/4 | Complete | 2026-03-11 |
| 6. Production Hardening | v0.1.0 | 2/2 | Complete | 2026-03-12 |
| 7. Test Infrastructure | v0.1.0 | 3/3 | Complete | 2026-03-12 |
| 8. Bug Fixes & Timer Guards | v0.1.0 | 2/2 | Complete | 2026-03-12 |
| 9. Phase 2 Verification | v0.1.0 | 1/1 | Complete | 2026-03-12 |
| 10. Economy Foundation | v1.1 | 3/3 | Complete | 2026-03-13 |
| 11. Island Upgrades + Resource Rate UI | v1.1 | 2/2 | Complete | 2026-03-13 |
| 12. Combat Depth | v1.1 | 3/3 | Complete | 2026-03-15 |
| 13. Dev Acceleration | v1.2 | 2/2 | Complete | 2026-03-16 |
| 14. Movement Visibility | v1.2 | 2/2 | Complete | 2026-03-16 |
| 15. Resource Trading | v1.2 | 2/2 | Complete | 2026-03-16 |
| 16. Espionage & City Viewing | v1.2 | 3/3 | Complete | 2026-03-16 |
| 17. UI Polish | v1.2 | 2/2 | Complete | 2026-03-17 |
| 18. Bot Schema Foundation | 1/1 | Complete    | 2026-03-17 | - |
| 19. Bot Behavior Engine | 2/2 | Complete   | 2026-03-17 | - |
| 20. Seed Data | v1.3 | 0/TBD | Not started | - |
| 21. GodMode Backend | v1.3 | 0/TBD | Not started | - |
| 22. GodMode Flutter Dashboard | v1.3 | 0/TBD | Not started | - |
| 23. Unit Tests | v1.3 | 0/TBD | Not started | - |
| 24. Automation & CI | v1.3 | 0/TBD | Not started | - |
