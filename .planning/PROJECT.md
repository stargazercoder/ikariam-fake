# Ikariam Clone

## What This Is

A browser-based multiplayer strategy game inspired by Ikariam. Players build cities on islands, gather resources, train armies, and wage turn-based wars against other players. Features a deep economic loop with happiness/wine mechanics, population-based taxation, cooperative island upgrades, and meaningful combat with pillage rewards. Built with Flutter web frontend and Supabase backend (Auth, PostgreSQL, Edge Functions, pg_cron, Realtime), targeting a small community of players.

## Core Value

Players can build and manage cities, gather resources, and engage in real-time turn-based warfare with other players — the core loop of build, expand, and conquer must feel satisfying and strategically meaningful.

## Requirements

### Validated

- ✓ Authentication with email/password via Supabase Auth — v0.1.0
- ✓ Player profile creation (name, avatar) with auto city placement on first login — v0.1.0
- ✓ 5 resource types: Wood, Marble, Crystal, Sulfur, Gold — v0.1.0
- ✓ Server-side resource production with pg_cron ticks (every 5 minutes) — v0.1.0
- ✓ Production formula: workers x building_level x research_bonus — v0.1.0
- ✓ Warehouse capacity limits on resource storage — v0.1.0
- ✓ Building system with 10 building types (Town Hall, Warehouse, Barracks, Shipyard, Academy, Embassy, Trading Port, Town Wall, Hideout, Tavern) — v0.1.0
- ✓ Building upgrade mechanics: cost formula (base_cost x 1.5^level), time formula (base_time x 1.2^level) — v0.1.0
- ✓ Single construction queue per city — v0.1.0
- ✓ World map with island-based 2D grid system — v0.1.0
- ✓ Each island holds 16-17 city slots, 1 wood resource + 1 luxury resource — v0.1.0
- ✓ Island view showing all cities and resource areas — v0.1.0
- ✓ City view with grid-based building layout — v0.1.0
- ✓ Land military units (8 types) trainable from Barracks — v0.1.0
- ✓ Naval units (5 types) buildable from Shipyard — v0.1.0
- ✓ Unit training queue with time-based completion via pg_cron — v0.1.0
- ✓ Troops dispatched to other cities with travel time based on distance — v0.1.0
- ✓ Turn-based battle system: 5-minute turns, partial army engagement per turn — v0.1.0
- ✓ Naval battle phase before land battle phase each turn — v0.1.0
- ✓ Battle reports sent to both parties via Supabase Realtime — v0.1.0
- ✓ All battle calculations run server-side — v0.1.0
- ✓ Flutter web splash screen during CanvasKit load — v0.1.0
- ✓ All game state mutations server-side (no client writes to game tables) — v0.1.0
- ✓ RLS enabled on every database table — v0.1.0
- ✓ Happiness system: tavern consumes wine to boost happiness, happiness affects population growth rate — v1.1
- ✓ Population-based tax income (idle citizens x 3 gold/hour) — v1.1
- ✓ Island resource points upgradeable (shared resource building levels) — v1.1
- ✓ Resource UI: hourly production rate in main resource bar + detailed breakdown — v1.1
- ✓ Battle outcome: pillage (steal resources on victory, Hideout protection floor) — v1.1
- ✓ Battle reports: turn-by-turn unit loss visualization with color-coded unit types — v1.1
- ✓ Tavern happiness configuration (wine spending rate adjustable) — v1.1
- ✓ Espionage system: spy on enemy cities to see resources, buildings, army counts — v1.2
- ✓ View other players' city screens (read-only) — v1.2
- ✓ Player-to-player resource trading via cargo ships — v1.2
- ✓ Movement visibility: armies and cargo in transit with destinations and ETAs — v1.2
- ✓ UI polish: transparent city AppBar, ownership color borders, unit type icons — v1.2
- ✓ Dev toolbar: bulk unit spawn, instant complete, 5x faster timers — v1.2

### Active

- [ ] AI bot players with periodic pg_cron-driven behaviors (attack, train, upgrade)
- [ ] 20 bot accounts with diverse game states seeded at init
- [ ] GodMode admin dashboard for observing all players and world state
- [ ] GodMode controls for pausing/resuming bots and modifying game state
- [ ] Rich seed data script for realistic test environments
- [ ] Unit tests for critical Edge Functions and Flutter widgets
- [ ] Automation scripts: DB reset, seed, serve, build, test, lint pipeline
- [ ] Marketplace with buy/sell orders (order book)
- [ ] Research system with 4 branches: Seafaring, Economy, Science, Military
- [ ] Research prerequisites (tech tree with dependencies)
- [ ] Academy building generates research points hourly
- [ ] Players can send reinforcements during ongoing battles
- [ ] Battle outcome: occupation (city takeover)
- [ ] Alliance system: create/join (requires Embassy), roles
- [ ] Alliance chat and player-to-player messaging via Realtime
- [ ] War declarations and NAP agreements
- [ ] Ranking system: total score, military, naval, alliance, island
- [ ] Score calculation: building + research + military + gold points

### Out of Scope

- Isometric rendering — 2D grid works well, upgrade later
- OAuth login (Google/Apple) — email/password sufficient for small community
- Mobile/Desktop native apps — web-only, Flutter enables future expansion
- Multi-language (i18n) — English only
- Drag & drop building placement — deferred UX enhancement
- Museum building — low priority decorative feature
- Animated construction effects — visual polish deferred
- Premium/monetization — no P2W for small community
- Espionage system — requires stable combat first
- Barbarian villages (PvE) — requires combat maturity
- WASM renderer — CanvasKit sufficient
- Negative happiness causing population loss — anti-feature for small community

## Context

- Shipped v0.1.0 MVP in 2 days (2026-03-11 → 2026-03-12)
- Shipped v1.1 Economy & Combat Depth in 3 days (2026-03-13 → 2026-03-15)
- Codebase: ~18,000 LOC (12,700 Dart + 1,044 TypeScript + 4,219 SQL)
- Tech stack: Flutter web + Supabase (Auth, PostgreSQL, Edge Functions, pg_cron, Realtime) + Riverpod
- 12 phases, 35 plans completed across 2 milestones
- 7 test accounts with varied game states for testing
- Dev toolbar for instant game-state manipulation (debug mode only)
- Game balance formulas (costs, rates, unit stats) not yet validated — needs iteration post-launch
- Known tech debt: cityProvider staleness after island donation, JSONB cast inconsistency, missing cargo-in-transit UI

## Constraints

- **Backend**: Supabase only — all server logic via Edge Functions and pg_cron
- **Frontend**: Flutter web — single codebase (Flame engine available but not heavily used)
- **State**: Riverpod for reactive state management
- **Security**: All calculations server-side, client only triggers actions
- **Time**: All timestamps server-side (NOW()) to prevent manipulation
- **Platform**: Web-first
- **Map**: Simple 2D grid, isometric rendering deferred

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Flutter + Flame over pure web (React/Vue) | Single codebase for future mobile expansion, Flame for 2D game rendering | ✓ Good — Flutter web works, Flame available for future map upgrades |
| Supabase over custom backend | Auth, DB, Realtime, Edge Functions, pg_cron all in one | ✓ Good — reduced infrastructure complexity significantly |
| 2D grid map for v1 | Isometric rendering is complex; ship faster with simple grid | ✓ Good — shipped fast, upgrade path clear |
| 5-minute turn-based battles | More strategic depth than instant resolution, allows reinforcements | ✓ Good — unique mechanic, needs player validation |
| Web-only for v1 | Faster iteration, smaller scope, browser access | ✓ Good — appropriate for small community |
| English-only UI | Simpler development, i18n can be added later | ✓ Good |
| All mutations via Edge Functions | Server authority prevents cheating | ✓ Good — one exception (ProfileRepository.updateProfile) documented and accepted |
| JSONB snapshots for unit_movements | Army immutable at departure, simpler combat resolution | ✓ Good — simplified Phase 5 significantly |
| pg_cron for game loops | Resource ticks, training, construction, battle resolution | ✓ Good — reliable server-side automation |
| Manual Riverpod providers (no code-gen) | riverpod_generator incompatible with Dart 3.10.1 | ⚠️ Revisit — upgrade when SDK supports it |
| Gold produced ONLY via idle citizen tax | Town Hall worker gold path removed to prevent double income | ✓ Good — v1.1 |
| Population stored as NUMERIC | Fractional tick growth; negative happiness halts growth + 50% production penalty | ✓ Good — v1.1 |
| Hideout-only pillage protection (no Warehouse) | Warehouse provides storage capacity only; Hideout is sole protection mechanism | ✓ Good — v1.1, simpler mental model |
| Wine icon: Icons.wine_bar + Colors.purple.shade600 | Consistent across all UI files | ✓ Good — v1.1 |
| Island multiplier uniform for all 4 production resources | Luxury type distinction deferred to v1.2 | ✓ Good — v1.1 |
| Pillage ratio: LEAST(0.75, total_land_units / 50.0 * 0.10) | Scales with surviving attackers, caps at 75% | ✓ Good — v1.1, needs balance tuning |
| SELECT FOR UPDATE on defender resources during pillage | Prevents race condition with concurrent resource tick | ✓ Good — v1.1 |

## Current Milestone: v1.3 Bots, Testing & Automation

**Goal:** Populate the world with 20 AI bot players that autonomously build, train, and fight on periodic schedules; add a full-page GodMode admin dashboard to observe and control the living world; enrich seed data for realistic testing; add unit tests for critical paths; and provide automation scripts for dev setup, DB reset, and CI/CD pipeline.

**Target features:**
- Bot system: 20 AI accounts with varied military, building, and resource levels running on pg_cron schedules
- Bot behaviors: periodic attacks, army retraining, island resource upgrades
- GodMode admin dashboard: full-page screen showing all players, armies, battles, resources in real-time
- GodMode controls: pause/resume bots, force actions, modify player state
- Rich seed data: project init creates 20 diverse bot accounts with realistic game states
- Unit tests: critical server-side functions and Flutter widgets covered
- Automation scripts: DB reset + seed, Edge Functions serve, Flutter build, test runner, lint check — single-command dev setup and CI/CD pipeline

---
*Last updated: 2026-03-17 after v1.3 milestone start*
