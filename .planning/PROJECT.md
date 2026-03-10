# Ikariam Clone

## What This Is

A browser-based multiplayer strategy game inspired by Ikariam. Players build cities on islands, gather resources, research technologies, train armies, and wage wars against other players. Built with Flutter (Flame engine) frontend and Supabase backend, targeting a small community of players.

## Core Value

Players can build and manage cities, gather resources, and engage in real-time turn-based warfare with other players — the core loop of build, expand, and conquer must feel satisfying and strategically meaningful.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Authentication with email/password via Supabase Auth
- [ ] Player profile creation (name, avatar) with auto city placement on first login
- [ ] 5 resource types: Wood, Marble, Crystal, Sulfur, Gold
- [ ] Server-side resource production with pg_cron ticks (every 5 minutes)
- [ ] Production formula: workers x building_level x research_bonus
- [ ] Warehouse capacity limits on resource storage
- [ ] Building system with 15+ building types across 4 categories (admin, resource, military, science/diplomacy)
- [ ] Building upgrade mechanics: cost formula (base_cost x 1.5^level), time formula (base_time x 1.2^level)
- [ ] Single construction queue per city (premium: 2 simultaneous)
- [ ] Research system with 4 branches: Seafaring, Economy, Science, Military
- [ ] Research prerequisites (tech tree with dependencies)
- [ ] Academy building generates research points hourly
- [ ] World map with island-based grid system
- [ ] Each island holds 16-17 city slots, 1 wood resource + 1 luxury resource
- [ ] Simple 2D grid map for v1 (isometric deferred)
- [ ] Island view showing all cities and resource areas
- [ ] City view with grid-based building placement
- [ ] Land military units (8 types: Hoplite, Phalanx, Archer, Cavalry, Catapult, Mortar, Medic, Cook)
- [ ] Naval units (5 types: Cargo Ship, Ram Ship, Catapult Ship, Mortar Ship, Diving Boat)
- [ ] Turn-based battle system: 5-minute turns, partial army engagement per turn, survivors carry to next turn
- [ ] Players can send reinforcements during ongoing battles
- [ ] Battle outcomes: pillage (steal resources) + occupation (city takeover under conditions)
- [ ] Battle reports sent to both parties via Realtime
- [ ] Player-to-player resource trading via cargo ships (travel time based on distance)
- [ ] Marketplace with buy/sell orders (order book)
- [ ] Alliance system: create/join (requires Embassy building), roles (Leader, General, Diplomat, Member)
- [ ] Alliance chat and player-to-player messaging via Supabase Realtime
- [ ] War declarations and NAP (non-aggression pact) agreements
- [ ] Ranking system: total score, military, naval, alliance, island rankings
- [ ] Score calculation: building points + research points + military points + gold points

### Out of Scope

- Isometric rendering — deferred, start with simple 2D grid
- OAuth login (Google/Apple) — email/password sufficient for v1
- Mobile/Desktop native apps — web-only for v1
- Multi-language (i18n) — English only for v1
- Drag & drop building placement — deferred to later version
- Museum building — deferred
- Animated building construction/smoke effects — deferred
- Premium/monetization features — deferred

## Context

- Inspired by the classic browser game Ikariam (ancient Greek island-based strategy)
- Target audience: small community of friends/players
- Tech stack decided: Flutter + Flame (frontend), Supabase (backend), Riverpod (state management)
- All game logic (resource calculation, battle resolution, construction completion) runs server-side to prevent cheating
- Supabase provides: Auth, PostgreSQL, Edge Functions, Realtime, pg_cron
- Battle system is unique: real-time turn-based (5-minute turns) rather than instant resolution — allows tactical reinforcement during combat
- Platform: Web only (Flutter web build)
- Game language: English

## Constraints

- **Backend**: Supabase only — all server logic via Edge Functions and pg_cron
- **Frontend**: Flutter + Flame engine — single codebase
- **State**: Riverpod for reactive state management
- **Security**: All calculations server-side, client only triggers actions
- **Time**: All timestamps server-side (NOW()) to prevent manipulation
- **Platform**: Web-first for v1
- **Map**: Simple 2D grid for v1, isometric rendering deferred

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Flutter + Flame over pure web (React/Vue) | Single codebase for future mobile expansion, Flame for 2D game rendering | — Pending |
| Supabase over custom backend | Auth, DB, Realtime, Edge Functions, pg_cron all in one — reduces infrastructure complexity | — Pending |
| 2D grid map for v1 | Isometric rendering is complex; ship faster with simple grid, upgrade later | — Pending |
| 5-minute turn-based battles | More strategic depth than instant resolution, allows reinforcement mechanics | — Pending |
| Web-only for v1 | Faster iteration, smaller scope, community can access via browser | — Pending |
| English-only UI | Simpler development, i18n can be added later | — Pending |

---
*Last updated: 2026-03-11 after initialization*
