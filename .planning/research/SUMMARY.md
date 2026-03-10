# Project Research Summary

**Project:** Ikariam Clone — Browser-based Multiplayer Strategy Game
**Domain:** Ancient Greek island city-building MMO strategy (browser-first, Flutter web)
**Researched:** 2026-03-11
**Confidence:** HIGH

## Executive Summary

This project is an Ikariam-style multiplayer browser strategy game built on Flutter Web + Flame for rendering, Supabase for the backend (PostgreSQL, Auth, Realtime, Edge Functions, pg_cron), and Riverpod for reactive state management. The stack is well-supported by official packages with verified version compatibility; Flutter 3.29/Dart 3.7 + Flame 1.36 + supabase_flutter 2.12 + flutter_riverpod 3.3.1 + flame_riverpod 5.5.3 form a coherent, WASM-forward, production-capable combination. The architecture follows a strict dumb-client / authoritative-server model where all game-state mutations flow through Supabase Edge Functions or pg_cron SQL, never from the Flutter client directly — this is both the security foundation and the anti-cheat backbone of the entire system.

The recommended approach is feature-first project structure organized around 6 development phases: Auth/Foundation, Core Economy (city + resources), World Map + Research, Military + Battle System, Social + Trade, and Meta (ranking + diplomacy). The 5-minute turn-based combat system is the primary gameplay differentiator versus all existing competitors (Ikariam, Grepolis, Travian all resolve combat instantly). Island-cooperative shared buildings are a secondary differentiator that should land in v1.x. The MVP is substantial — 18 P1 features — but the dependency chain is clear and the architecture is designed for incremental addition of features without rewrites.

The two most consequential risks are both architectural and must be resolved before any feature is built on top of them: (1) accidentally placing resource/building calculations on the client side instead of the server, and (2) creating pg_cron jobs via the Supabase dashboard UI which silently applies a 5000ms HTTP timeout that will break resource ticks under player load. Both are easy to prevent with correct patterns from day one but catastrophically expensive to fix retroactively. RLS must be enabled on every table at migration time, and all transaction-level resource deductions must use atomic SQL patterns to prevent double-spend race conditions.

---

## Key Findings

### Recommended Stack

The entire stack is built within the Dart/Flutter ecosystem, keeping a single codebase that compiles to web today and mobile later without significant rework. Flame provides the 2D game loop and component system; flame_riverpod bridges Riverpod state into Flame components which are not Flutter widgets. Supabase provides the full backend surface needed for a multiplayer game (Auth, Postgres with RLS, Realtime WebSockets, Edge Functions, pg_cron) without requiring a custom server. The stack compiles to CanvasKit for v1 (broadest browser support) with a WASM migration path available once all transitive dependencies confirm WASM support.

See full details: `.planning/research/STACK.md`

**Core technologies:**
- **Flutter 3.29 / Dart 3.7** — web build target (CanvasKit), single codebase for future mobile; WASM-ready
- **Flame 1.36.0** — 2D game engine (FlameGame, Component tree, Camera2D, flame_tiled integration); only mature 2D engine in Flutter ecosystem
- **flame_riverpod 5.5.3** — bridges Riverpod providers into Flame component tree; required for reactive state in Flame components
- **supabase_flutter 2.12.0** — unified client for Auth, PostgREST, Realtime, Edge Functions; WASM-compatible (uses dart:js_interop)
- **flutter_riverpod 3.3.1** — context-free reactive state; works outside widget tree; critical for Flame/Flutter hybrid
- **freezed 3.2.5 + json_serializable 6.13.0** — immutable Dart model classes with JSON serialization for all game data types
- **go_router 17.1.0** — URL-based navigation; required for Supabase Auth deep-link callbacks on web
- **pg_cron (Postgres extension)** — server-side resource production ticks every 5 minutes; no client trust required

**Critical version constraints:**
- flame_riverpod 5.x requires flutter_riverpod 3.x — do not mix versions
- supabase_flutter 2.x only (v1.x is not WASM-compatible)
- riverpod_generator, riverpod_annotation, flutter_riverpod must all be updated together (same author, pinned versions)

### Expected Features

Research cross-referenced against original Ikariam, Grepolis, Travian, and Tribal Wars. Feature set is well-understood and genre-standardized. The MVP is 18 P1 features; the full feature dependency chain is mapped.

See full details: `.planning/research/FEATURES.md`

**Must have for launch (P1 — table stakes):**
- Authentication (email/password) + persistent player profile — identity foundation
- 5 resource types (Wood, Marble, Crystal, Sulfur, Gold) with server-side production (pg_cron) — core idle loop
- Warehouse capacity limits — resource scarcity and trade pressure
- 10 core building types (Town Hall, Barracks, Academy, Shipyard, Trading Post, Palace, Embassy, Warehouse, Tavern, Hideout) + single-slot upgrade queue
- Research tree (4 branches: Seafaring, Economy, Science, Military; 20+ techs with prerequisites) — progression system
- World map (2D grid, island-based) — spatial context and target-finding
- Island view + city view navigation
- 6 land unit types + 3 naval unit types
- Turn-based combat (5-minute turns) with battle reports and pillage mechanic
- Player-to-player messaging
- Alliance system (create/join, roles: Leader, General, Diplomat, Member)
- Resource trading via cargo ships (distance-based travel time)
- Ranking leaderboard (total score)
- Beginner protection (no attacks until Town Hall level 4)
- Colony expansion (Palace + Seafaring research + Colony Ship)
- Basic tutorial / onboarding

**Should have after validation (P2 — v1.x):**
- Barbarian villages (PvE combat practice) — once PvP is stable
- Daily tasks / favor system — daily re-engagement
- Marketplace order book — once enough players trading
- Spy / espionage system — intelligence layer over PvP
- Occupation / city takeover — ultimate PvP goal
- Vacation mode — quality-of-life for small community
- Island shared buildings (Sawmill, luxury resource, miracle building) — cooperative differentiator
- War declarations + NAP between alliances — political meta-game

**Defer to v2+:**
- Isometric/3D map rendering — purely visual, massive scope
- Drag-and-drop building placement — no strategic value
- Automated trade routes — reduces player agency
- Museum + artifact system — marginal value
- Premium cosmetics — only if monetization needed; never pay-to-win

**Anti-features to permanently reject:**
- Pay-to-win monetization (kills small communities)
- Real-time instant-resolve combat (destroys strategic depth)
- Server seasonal wipes (destroys player investment)

### Architecture Approach

The architecture is a strict 3-layer client-server model: Flutter/Flame client (rendering + UI), Supabase backend (PostgreSQL as single source of truth), and a server-logic layer (Edge Functions for mutations, pg_cron for time-based progression). The client is deliberately "dumb" — it sends intents, never computed results. All game arithmetic (build costs, resource production, battle outcomes) happens server-side. Realtime WebSocket push (Supabase Realtime) replaces all polling: DB Changes for persistent events, Broadcast for ephemeral battle turn updates. Riverpod AsyncNotifiers per domain cache server state and subscribe to Realtime streams.

See full details: `.planning/research/ARCHITECTURE.md`

**Major components:**
1. **Flutter UI Layer** — screens, dialogs, menus, HUD overlays via Flutter widgets; uses `GameWidget.overlayBuilderMap` to sit on top of Flame canvas
2. **Flame World Layer** — separate FlameGame subclass per view (WorldMapGame, CityGame); never one global FlameGame
3. **Riverpod Providers** — one AsyncNotifier per game domain (city, resources, research, battle, trade, alliance); each loads from Supabase and subscribes to Realtime
4. **Service Layer** — thin Dart wrappers over Supabase SDK; no game logic; calls Edge Functions for all mutations
5. **Supabase Edge Functions (Deno/TypeScript)** — authoritative server logic: build queue, battle resolution, trade route validation, construction completion; invoked by client JWT or pg_cron
6. **pg_cron** — scheduled SQL jobs: resource production tick every 5 min, daily score recalculation; stores target timestamps, not timers
7. **PostgreSQL + RLS** — single source of truth; RLS on every table; all player data isolated by `auth.uid()`; atomic SQL patterns for resource deductions

**Key architectural rules:**
- Client NEVER writes directly to game-state tables (no INSERT/UPDATE from Flutter)
- All timestamps are server-side (`NOW()`) — client calculates display-only countdowns from server UTC timestamps
- Separate FlameGame instances per screen view (not one monolithic game)
- Realtime DB Changes for persistent events; Broadcast for ephemeral battle updates

### Critical Pitfalls

See full details: `.planning/research/PITFALLS.md`

1. **Client-side resource/game calculations** — Any `.update()` call on game state tables from Flutter is exploitable. Prevention: 100% of mutations go through Edge Functions with server-side validation. Establish this pattern before Phase 1 ends and enforce via code review.

2. **pg_cron 5-second HTTP timeout** — Creating cron jobs via the Supabase dashboard UI silently caps HTTP timeout at 5000ms, causing resource ticks to fail silently above ~100 players. Prevention: always create cron jobs via raw SQL with `timeout_milliseconds := 30000`; never use the dashboard UI for game-critical jobs.

3. **Race condition double-spend** — Two simultaneous "upgrade building" requests both read sufficient balance and both deduct cost, resulting in negative resources or duplicate queue entries. Prevention: atomic SQL `UPDATE resources SET wood = wood - $cost WHERE wood >= $cost RETURNING wood` pattern + `CHECK (wood >= 0)` constraints on all resource columns.

4. **RLS disabled by default on new tables** — Every new Supabase table has RLS off by default. One forgotten table leaks all players' private data (army composition, messages, resources). Prevention: enable RLS in the same migration that creates every table; add a CI assertion that no public table has `rowsecurity = false`.

5. **Battle state desynchronization** — If a pg_cron battle tick is delayed, client countdown reaches 0 but no new state arrives. Prevention: store `last_processed_at` server-side; client shows "Waiting for server..." if `last_processed_at` is more than `turn_duration + 30s` behind `NOW()`; battle tick Edge Function must be idempotent.

6. **Ghost cities exhausting island slots** — Inactive players permanently occupy island slots, making the map feel dead. Prevention: design abandonment policy in schema from day one (`last_login_at` column, pg_cron inactivity check removing cities after 30 days).

7. **Flutter Web CanvasKit cold-load penalty** — 3-10 MB WASM binary download blocks first paint for 5-15 seconds on slow connections. Prevention: self-host CanvasKit on CDN, add static HTML/CSS splash screen, enable PWA service worker caching before launch.

---

## Implications for Roadmap

Based on the combined dependency chain from FEATURES.md, the build order from ARCHITECTURE.md, and the phase-mapped pitfalls from PITFALLS.md, the following 6-phase structure is recommended. This ordering is not arbitrary — each phase is a prerequisite for the next.

### Phase 1: Foundation (Auth + Schema + Server Authority)

**Rationale:** Auth must exist before any table has a `player_id` foreign key. RLS must be enabled on every table from day one. The server-authority contract (no client-side game mutations) must be established before any feature is built on top of it — retrofitting this is a full rewrite.

**Delivers:** Working registration/login, player profile auto-creation, base DB schema with RLS enabled on all tables, migration conventions, Supabase local dev environment, first Edge Function scaffold.

**Addresses features:** Authentication, player profile, beginner protection (schema-level).

**Avoids pitfalls:** RLS disabled on tables, client-side calculation pattern, race condition (add CHECK constraints now), service role key exposure.

**Research flag:** Standard patterns — Supabase Auth + RLS is well-documented. Skip phase research.

---

### Phase 2: Core Economy (Resources + City + Buildings)

**Rationale:** Resources are the foundation of all other systems — building upgrades cost resources, military training costs resources, research costs resources. The pg_cron tick must be validated under load before any other feature depends on it. The building upgrade queue is the first real game loop.

**Delivers:** 5 resource types with server-side pg_cron production ticks (every 5 min), warehouse capacity caps, city view with building slots, single-slot building upgrade queue via Edge Function, resource display with client-side estimated counter (reconciled on Realtime tick).

**Addresses features:** Resource production, warehouse limits, building upgrade queue, core building types (Town Hall, Warehouse, Barracks, Academy, Shipyard, Trading Post, Palace, Embassy, Tavern, Hideout).

**Uses stack:** pg_cron (resource tick), Edge Functions (upgrade-building), Supabase Realtime DB Changes (resource updates), Flame CityGame, Riverpod CityNotifier + ResourceNotifier.

**Avoids pitfalls:** pg_cron 5s timeout (create via SQL, test with 100 rows), double-spend race condition (atomic SQL deduction, CHECK constraints), client-side calculations.

**Research flag:** pg_cron timeout issue is a known gotcha — validate during implementation with load test. Otherwise standard patterns.

---

### Phase 3: World Map + Research + Colony

**Rationale:** Players need the world map to find each other before social/combat systems matter. Research tree requires the Academy (built in Phase 2) and gates mid-game progression. Colony expansion gates the late-game; it belongs here because it requires Palace (Phase 2) and Seafaring research.

**Delivers:** 2D grid world map (Flame WorldMapGame + flame_tiled), island view with city slots, player city placement on first login, research tree UI (4 branches, 20+ techs, prerequisites), colony expansion (Palace + research + Colony Ship unit), ghost city abandonment schema.

**Addresses features:** World map, island view, city view navigation, research system, colony expansion, basic tutorial/onboarding.

**Uses stack:** flame_tiled for world map grid, Tiled Map Editor for .tmx map assets, Riverpod WorldMapNotifier + ResearchNotifier, Supabase Realtime Presence (online players on map).

**Avoids pitfalls:** Ghost city island exhaustion (add `last_login_at` column and inactivity pg_cron job now), countdown timer client-side (server timestamps only).

**Research flag:** Tiled map editor integration + flame_tiled setup may need phase-level research if not previously used. Colony expansion logic (multi-city ownership) has complexity worth a planning deep-dive.

---

### Phase 4: Military + Battle System

**Rationale:** Military units require the Barracks and Shipyard (Phase 2) and unit tables seeded with stats. The 5-minute turn-based battle engine is the project's primary differentiator and the most architecturally complex feature — it requires idempotent pg_cron tick processing, battle-state server authority, Realtime Broadcast for live turn updates, and careful balance. This deserves its own isolated phase.

**Delivers:** 6 land unit types + 3 naval unit types (seeded data), unit training queue, turn-based combat engine (5-min turns via pg_cron + Edge Function), battle report system, pillage mechanic (resource transfer), beginner protection enforcement (no attacks below Town Hall level 4).

**Addresses features:** Military units, naval units, turn-based combat, battle reports, pillage.

**Uses stack:** Edge Function `battle-turn` (authoritative calculation), pg_cron to invoke it every 5 min during active battles, Supabase Realtime Broadcast for live turn-by-turn updates to both players, Riverpod BattleNotifier.

**Avoids pitfalls:** Battle state desynchronization (idempotent tick function, `last_processed_at` column, "Waiting for server" client UI), client-side battle outcome calculation, Realtime subscription to high-churn tables (push summary events not raw rows).

**Research flag:** Turn-based battle networking over WebSocket is a niche pattern with sparse documentation. Phase-level research recommended for battle tick architecture and idempotency implementation.

---

### Phase 5: Social + Trade + Alliance

**Rationale:** Social features require established players with cities and resources — there is nothing to trade or ally around until Phases 2-4 are live. Messaging, alliance system, and resource trading form a coherent social layer that must arrive together to be functional (alliances without messaging are unusable; trading without the marketplace requires manual coordination via messaging).

**Delivers:** Player-to-player messaging (Supabase Realtime Broadcast), alliance system (create/join, roles, Embassy building gate), resource trading via cargo ships (distance-based travel time, escrowed resources at departure), ranking leaderboard (server-side score calculation via pg_cron).

**Addresses features:** Player messaging, alliance system, resource trading, ranking leaderboard.

**Uses stack:** Supabase Realtime Broadcast (chat), Realtime DB Changes (trade arrival notifications), Edge Function `trade-route` (cargo ship dispatch with travel time enforcement), Riverpod AllianceNotifier + MessageNotifier + TradeNotifier.

**Avoids pitfalls:** Alliance role checked only client-side (every privileged action re-checks role in Edge Function), trade resource not escrowed at departure (resources deducted immediately on dispatch, not arrival), message content readable by other players (RLS on messages table).

**Research flag:** Cargo ship travel time + resource escrow mechanics have subtle implementation complexity. Standard alliance CRUD is well-documented; skip research for that portion.

---

### Phase 6: Polish + Deployment + Hardening

**Rationale:** All core systems are functional after Phase 5. This phase closes security holes, optimizes cold-load performance, adds indexes for production query performance, and ships the game to a real hosting environment.

**Delivers:** Flutter web deployment (self-hosted CDN for CanvasKit WASM, HTML/CSS splash screen, PWA service worker), database index audit (all `player_id`, `island_id`, `alliance_id`, `status`, `created_at` columns indexed), security audit (RLS CI assertion, rate limiting on Edge Functions, CORS restriction), pg_cron job monitoring (`cron_job_log` table with alerting), inactivity cleanup job (ghost city removal after 30 days), first-load performance validation (throttled 3G test, target < 10 seconds time-to-interactive).

**Addresses features:** Production deployment, performance, security hardening, onboarding polish.

**Uses stack:** Flutter build web --release (CanvasKit), PWA manifest, Supabase dashboard for monitoring, pg_cron for inactivity job.

**Avoids pitfalls:** Flutter WASM cold-load penalty, missing indexes, open CORS, rate limiting gaps, pg_cron silent failures.

**Research flag:** PWA and CDN configuration for Flutter web is well-documented. Standard patterns — skip phase research.

---

### Phase Ordering Rationale

- **Auth before all:** Every table's RLS policies reference `auth.uid()` — no schema is meaningful without auth
- **Resources before buildings:** Building cost validation requires a functional resource system to check against
- **pg_cron tick before city view is shipped:** Displaying resource production numbers to users requires the tick to actually be running and validated
- **Buildings before research:** Research requires Academy; unit training requires Barracks/Shipyard
- **Units before battle:** Battle formulas reference unit stats tables which must be seeded
- **Players established before social:** You cannot trade or ally with no neighbors — social features require density first
- **Realtime added incrementally:** Each phase can start with polling-fallback and replace with Realtime subscriptions feature by feature; this reduces Phase 1 complexity

---

### Research Flags

**Phases needing deeper research during planning:**
- **Phase 3 (World Map):** flame_tiled integration, Tiled map editor workflow, multi-city ownership schema for colonies
- **Phase 4 (Battle System):** Turn-based battle networking patterns, idempotent pg_cron tick design, Realtime Broadcast for live battle updates — sparse documentation, high complexity

**Phases with standard well-documented patterns (skip phase research):**
- **Phase 1 (Foundation):** Supabase Auth + RLS patterns are extensively documented
- **Phase 2 (Economy):** pg_cron + Edge Function resource tick pattern is documented in official Supabase blog; known gotcha (5s timeout) is documented with fix
- **Phase 5 (Social/Trade):** Supabase Realtime Broadcast for chat and DB Changes for notifications are standard; alliance CRUD is straightforward Postgres
- **Phase 6 (Deployment):** Flutter web deployment + CDN configuration is well-covered

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All package versions verified via pub.dev official pages on research date; version compatibility matrix validated |
| Features | HIGH | Cross-referenced against Ikariam wiki, Grepolis, Travian, Tribal Wars; genre conventions are stable and well-documented |
| Architecture | HIGH | Pattern verified via official Supabase architecture docs, Flame docs, and Gabriel Gambetta's authoritative client-server architecture reference |
| Pitfalls | HIGH (technical) / MEDIUM (balance) | Technical pitfalls verified via GitHub issues and official docs; game balance pitfalls from community sources |

**Overall confidence:** HIGH

### Gaps to Address

- **Game balance formulas:** Exponential cost formula `base * 1.5^level` is referenced but specific balance values (base costs per building, production rates per worker, unit stats) are not validated against playtesting. These will need iteration post-launch.
- **Exact RLS policy patterns for public game data vs. private player data:** Some game data is intentionally public (world map city locations, leaderboard scores, alliance names) while some is private (army composition, resource counts, messages). The exact boundary needs explicit policy design during Phase 1.
- **WASM production readiness:** All identified packages claim WASM compatibility but transitive dependency WASM support was not exhaustively verified. Validate before switching from CanvasKit to WASM build.
- **pg_cron performance ceiling:** The resource tick batching strategy is described but the exact batch size thresholds (LIMIT 500 per invocation) need real measurement at player counts above 100.
- **Combat balance:** Turn-based combat with 5-minute turns is the key differentiator but specific unit stats, terrain bonuses, and research multipliers were not researched. This requires dedicated balance design work before Phase 4.

---

## Sources

### Primary (HIGH confidence)

- pub.dev official package pages (Flame 1.36.0, supabase_flutter 2.12.0, flutter_riverpod 3.3.1, flame_riverpod 5.5.3, all supporting packages)
- docs.flutter.dev/platform-integration/web/renderers — CanvasKit vs WASM renderer comparison
- supabase.com/docs/guides/realtime — Broadcast, Presence, Postgres Changes
- supabase.com/docs/guides/database/extensions/pg_cron — pg_cron scheduling
- supabase.com/docs/guides/troubleshooting/rls-performance-and-best-practices — RLS indexing
- supabase.com/blog/flutter-real-time-multiplayer-game — official Flutter + Flame + Supabase tutorial
- supabase.com/docs/guides/getting-started/architecture — Supabase system architecture
- docs.flame-engine.org — Flame component system, flame_riverpod bridge
- gabrielgambetta.com/client-server-game-architecture.html — authoritative multiplayer architecture reference
- supabase/supabase GitHub Issue #37629 — pg_cron 5s HTTP timeout confirmed bug
- supabase.com/docs/guides/troubleshooting/pgcron-debugging-guide — pg_cron debugging

### Secondary (MEDIUM confidence)

- ikariam.fandom.com/wiki — detailed Ikariam mechanics (espionage, colonization, daily tasks, barbarian villages, trading, vacation mode)
- en.wikipedia.org/wiki/Ikariam — feature overview
- heroiclabs.com/docs — authoritative multiplayer architecture patterns
- aleksandra.codes/supabase-game — Supabase Realtime game implementation
- longwelwind.net/blog/networking-turn-based-game — turn-based networking patterns
- gamedesignskills.com/game-design/player-retention — retention mechanics
- gamedeveloper.com — game economy design handbook
- push.cx/game-influence-ikariam — design analysis (island cooperation as key mechanic)

### Tertiary (LOW confidence — needs validation during implementation)

- Game balance formula values (base costs, production rates, unit stats) — inferred from Ikariam wiki; must be validated through playtesting
- pg_cron batch size thresholds — estimated from Supabase performance docs; must be measured empirically

---

*Research completed: 2026-03-11*
*Ready for roadmap: yes*
