# Ikariam Clone

## What This Is

A browser-based multiplayer strategy game inspired by Ikariam. Players build cities on islands, gather resources, train armies, and wage turn-based wars against other players. Built with Flutter web frontend and Supabase backend (Auth, PostgreSQL, Edge Functions, pg_cron, Realtime), targeting a small community of players. Shipped v0.1.0 MVP with full build-expand-conquer loop.

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

### Active

- [ ] Research system with 4 branches: Seafaring, Economy, Science, Military
- [ ] Research prerequisites (tech tree with dependencies)
- [ ] Academy building generates research points hourly
- [ ] Players can send reinforcements during ongoing battles
- [ ] Battle outcomes: pillage (steal resources) + occupation (city takeover)
- [ ] Player-to-player resource trading via cargo ships
- [ ] Marketplace with buy/sell orders (order book)
- [ ] Alliance system: create/join (requires Embassy), roles
- [ ] Alliance chat and player-to-player messaging via Realtime
- [ ] War declarations and NAP agreements
- [ ] Ranking system: total score, military, naval, alliance, island
- [ ] Score calculation: building + research + military + gold points

### Out of Scope

- Isometric rendering — 2D grid works well for v0.1.0, upgrade later
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

## Context

- Shipped v0.1.0 MVP in 2 days (2026-03-11 → 2026-03-12)
- Codebase: ~14,500 LOC (10,400 Dart + 735 TypeScript + 3,400 SQL)
- Tech stack: Flutter web + Supabase (Auth, PostgreSQL, Edge Functions, pg_cron, Realtime) + Riverpod
- 225 files, 9 phases, 27 plans completed
- 7 test accounts with varied game states for testing
- Dev toolbar for instant game-state manipulation (debug mode only)
- Test automation CLI (test_all.sh / test_all.ps1)
- Game balance formulas (costs, rates, unit stats) not yet validated — needs iteration post-launch

## Constraints

- **Backend**: Supabase only — all server logic via Edge Functions and pg_cron
- **Frontend**: Flutter web — single codebase (Flame engine available but not heavily used in v0.1.0)
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

---
*Last updated: 2026-03-12 after v0.1.0 milestone*
