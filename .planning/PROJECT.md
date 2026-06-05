# Ikariam Clone

## What This Is

A browser-based multiplayer strategy game inspired by Ikariam. Players build cities on islands, gather resources, train armies, and wage turn-based wars against other players and AI bots. Features a deep economic loop with happiness/wine mechanics, population-based taxation, cooperative island upgrades, meaningful combat with pillage rewards, espionage, and resource trading. Includes 20 autonomous AI bot players, a GodMode admin dashboard, and CI/CD automation. Built with Flutter web frontend and Supabase backend (Auth, PostgreSQL, Edge Functions, pg_cron, Realtime), targeting a small community of players.

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
- ✓ AI bot players with periodic pg_cron-driven behaviors (attack, train, upgrade) — v1.3
- ✓ 20 bot accounts with diverse game states seeded at init — v1.3
- ✓ GodMode admin dashboard for observing all players and world state — v1.3
- ✓ GodMode controls for pausing/resuming bots and modifying game state — v1.3
- ✓ Rich seed data script for realistic test environments — v1.3
- ✓ Unit tests for critical Edge Functions and Flutter widgets — v1.3
- ✓ Automation scripts: DB reset, seed, serve, build, test, lint pipeline — v1.3

### Active

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
- Barbarian villages (PvE) — requires combat maturity
- WASM renderer — CanvasKit sufficient
- Negative happiness causing population loss — anti-feature for small community

## Context

- Shipped v0.1.0 MVP in 2 days (2026-03-11 → 2026-03-12)
- Shipped v1.1 Economy & Combat Depth in 3 days (2026-03-13 → 2026-03-15)
- Shipped v1.2 Espionage, Trading & Polish in 2 days (2026-03-16 → 2026-03-17)
- Shipped v1.3 Bots, Testing & Automation in 2 days (2026-03-17 → 2026-03-18)
- Shipped v1.4 UI Consistency in 3 days (2026-03-19 → 2026-03-21)
- Codebase: ~28,500 LOC (est. after v1.4 additions)
- Tech stack: Flutter web + Supabase (Auth, PostgreSQL, Edge Functions, pg_cron, Realtime) + Riverpod
- 24 phases, 57 plans completed across 4 milestones
- 20 bot accounts + 7 test accounts with varied game states
- GodMode admin dashboard for real-time world observation and bot control
- Dev toolbar for instant game-state manipulation (debug mode only)
- GitHub Actions CI pipeline with Flutter + Deno quality gate
- Game balance formulas (costs, rates, unit stats) not yet validated — needs iteration post-launch
- Known tech debt: cityProvider staleness after island donation, JSONB cast inconsistency, bot archetype weights need tuning

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
| Single consolidated bot-think-tick at */15 cron | Avoids pg_cron worker pool exhaustion vs per-behavior cron jobs | ✓ Good — v1.3 |
| GodMode uses SECURITY DEFINER RPCs with is_admin check | service_role key never reaches Flutter client | ✓ Good — v1.3 |
| Bot actions write directly to game tables | Same tables as Edge Functions; no pg_net HTTP round-trips from pg_cron | ✓ Good — v1.3 |
| Deterministic bot UUIDs (b{NN}00000 pattern) | Easy identification and ON CONFLICT correctness for idempotent seeds | ✓ Good — v1.3 |
| Pure function extraction for Edge Function testing | No Supabase client mock required; import only formula module | ✓ Good — v1.3 |
| Deno pinned to 2.2.x in CI | Supabase Edge Runtime does not support Deno 2.3+ lock file v5 | ⚠️ Revisit — track supabase/supabase#33093 |

## Current State: v1.4 Shipped

**Shipped:** 2026-03-21
**Total shipped:** 28 phases, 62 plans across 5 milestones

**v1.4 shipped features:**
- Canonical visual system: `visual_constants.dart` + `ResourceBadge` widget, consistent resource/building icons and colors across all UI
- Unified building detail sheet: DraggableScrollableSheet for all 14 building types with dynamic content per building
- Building downgrade: instant 50% refund via `downgrade-building` Edge Function
- Dispatch carry capacity: live X/Y cargo capacity indicator in dispatch dialog
- City screen cleanup: city/player name title texts removed from all screens
- Deprecated code removed: barracks_screen, shipyard_screen, building_upgrade_card, old routes

**Tech debt carried to v1.5:**
- `cityProvider` not refreshed after island donation — stale island multiplier in production rate labels
- JSONB cast inconsistency: older models use `v as int`, newer use `(v as num).toInt()`
- `hideoutProtectionFloor()` Dart helper not surfaced in any UI
- Bot archetype weight values need balance tuning
- Deno pinned to 2.2.x — track supabase/supabase#33093 for upgrade

## Next Milestone Goals

Run `/gsd-new-milestone` to define v1.5 requirements and roadmap.

Candidate features for v1.5:
- Research system (4 branches: Seafaring, Economy, Science, Military)
- Marketplace with buy/sell orders (order book)
- Alliance system (create/join, Embassy, roles)
- Ranking system (building + research + military + gold scores)
- Reinforcements during ongoing battles

---
*Last updated: 2026-06-05 after v1.4 milestone archive*
