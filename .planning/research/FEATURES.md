# Feature Research

**Domain:** Ikariam-style browser strategy game — v1.3 Bots, Testing & Automation features
**Researched:** 2026-03-17
**Confidence:** MEDIUM (FSM/bot patterns from academic research + community sources; Supabase testing from official docs HIGH; CI/CD patterns HIGH)

> **Scope note:** This document covers only the NEW features targeted for v1.3. All existing systems
> (buildings, combat, happiness, pillage, trading, espionage, dev toolbar) are stable dependencies.
> The v1.1 feature research document remains authoritative for earlier mechanics.

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features that a game with AI bots and an admin dashboard must have. Missing these = the feature area feels half-built.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Bots that actually attack players | If bots exist, players expect to be raided; idle bots break the "living world" premise | MEDIUM | Bot dispatches military units to a nearby target city on a schedule; uses existing `dispatch-units` infrastructure and pg_cron trigger |
| Bots that train units over time | Bots with static armies become trivially exploitable; players expect them to replenish after combat | MEDIUM | Bot checks army size vs a target threshold; if below, queues training via existing `train-units` flow or a direct DB insert bypassing Edge Functions (for bot authority) |
| Bots that upgrade buildings | Economic progression is the game loop; bots must participate in it or their cities stagnate | MEDIUM | Bot evaluates which building gives highest ROI next, queues upgrade; uses same construction queue as players |
| 20 bot accounts with distinct game states | A world where all bots are at level 1 feels fake; players expect varied opponents | MEDIUM | Seed script creates 20 profiles + cities across multiple islands with varying resource, building, and army levels |
| GodMode: view all player states in one screen | Any admin tool must let the admin see the whole world without navigating city by city | MEDIUM | Full-page Flutter screen; reads from admin-scoped Supabase queries; shows resource levels, army sizes, active battles, bot status |
| GodMode: pause/resume bots | Essential for debugging and balance tuning; without a kill switch, a misbehaving bot cannot be stopped without DB intervention | LOW | `is_bot_paused` flag on profile row; bot tick function skips paused bots; toggle via admin UI button |
| Automation script: DB reset + reseed | Without this, every developer must manually reset state; standard for any project with seeded data | LOW | Bash/npm script: `supabase db reset && deno run seed.ts`; single command restores known state |
| Unit tests for critical Edge Functions | Server-side calculations (pillage, battle, resource tick) are where bugs cause economy exploits; teams always test these | MEDIUM | Deno test runner (`deno test`) in `supabase/functions/tests/`; tests use local Supabase via `supabase start` |
| Flutter widget tests for critical screens | Resource bar, battle report, city view widget tree — any regression here is immediately visible to players | MEDIUM | `flutter_test` package; `testWidgets()` for key screens; mock Riverpod providers with `ProviderContainer` overrides |

### Differentiators (Competitive Advantage)

Features that elevate this game's AI and tooling above a minimal implementation.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Bot personality archetypes (militarist, economist, builder) | Bots with differentiated strategies create varied and more realistic opponents than a uniform AI | MEDIUM | 3 archetypes stored on bot profile row; militarist prioritizes unit training and attacks; economist prioritizes island donations and trading; builder focuses on upgrading buildings; behavior weights differ per archetype |
| Bot tick with stochastic jitter (not all bots tick at same cron interval) | Synchronized bots acting at exactly the same time create unnatural world patterns; jitter makes the world feel alive | LOW | Bot cron fires every 15 minutes; within the function, each bot rolls a random skip (20% chance) so actions are distributed unevenly across time |
| GodMode: force-trigger bot action | Lets admin validate bot behavior instantly rather than waiting 15 minutes for the next cron cycle | LOW | Admin button calls an RPC `run_bot_tick(bot_profile_id)` immediately; same logic path as cron tick |
| GodMode: modify player resource balances | Balance testing requires setting specific resource levels; doing this via SQL manually is error-prone | LOW | Admin form with player selector + resource sliders; calls a privileged RPC `admin_set_resources(city_id, wood, marble, ...)` |
| Rich seed data: diverse island distribution | Bots distributed across multiple islands (not all on one) creates a realistic sparse world and tests island-level interactions | MEDIUM | Seed assigns bots to 8-10 different islands; each island has 2-4 bot cities + reserved slots for real players |
| CI pipeline with lint + test + build in single workflow | Flutter + Supabase projects rarely have a complete CI pipeline; having one signals code quality discipline | MEDIUM | GitHub Actions workflow: `flutter analyze` + `flutter test` + `deno lint` + `deno test` + `flutter build web`; triggers on push to main |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| ML/LLM-based adaptive bot AI | More intelligent bots that learn from player patterns | Massively over-engineered for a small-community game; adds inference latency, cost, and complexity with no validated player benefit | FSM with 3 archetypes + random jitter; revisit if player counts justify it |
| Bots that use player Edge Functions directly | Cleaner code reuse | Player Edge Functions enforce RLS and auth context; bots would need to impersonate player auth tokens — a security footgun | Bots call internal SQL functions directly with postgres role; no HTTP Edge Function calls from cron |
| Real-time bot action streaming to all clients | Players can watch bots act in real-time | Supabase Realtime is designed for player-owned data subscriptions; broadcasting all bot actions to all clients causes O(n) subscription overhead | Bot actions update DB normally; clients only receive updates for cities/battles they are subscribed to |
| GodMode accessible to all users (soft admin flag in profile) | Easier to implement | If admin detection is a simple profile column, a DB exploit or misconfigured RLS reveals controls to non-admins | Hardcode admin user IDs in Flutter app (constants file); double-check on backend with `auth.uid() = ANY(admin_uids)` |
| 100% code coverage mandate | Engineering thoroughness appeal | For a rapid-iteration game, 100% coverage forces tests on trivial getters and UI glue code; slows development without proportional bug reduction | Cover critical paths only: battle resolution, resource tick, pillage, construction queue; target ~60-70% coverage on Edge Functions |
| Integration tests that spin up a full Supabase instance in CI | Comprehensive testing | Supabase local startup in CI takes 60-120 seconds per run; dramatically slows the feedback loop | Unit tests with mocked Supabase client for Flutter; Deno tests use `supabase functions serve` locally (developer runs these, not CI) |
| Bot actions via Supabase Realtime events (event-driven) | Reactive rather than polling | pg_cron is already the proven pattern for periodic game actions in this codebase; Realtime adds a new event bus with additional failure modes | Stick with pg_cron scheduled functions for all bot actions; bot tick is a SQL function, not an event handler |

---

## Feature Dependencies

```
[Bot System]
    └──requires──> [profiles table with is_bot + bot_archetype columns] (schema addition)
    └──requires──> [pg_cron bot-tick job] (new cron schedule)
    └──requires──> [bot_tick() SQL function] (new function)
    └──uses──>     [complete_training()] (already exists)
    └──uses──>     [complete_building_upgrades()] (already exists)
    └──uses──>     [process_arrivals()] (already exists)

[Bot Behaviors: Attack]
    └──requires──> [Bot System]
    └──requires──> [dispatch_units() or direct unit_movements insert] (already exists)
    └──requires──> [battle system] (already exists)

[Bot Behaviors: Train Units]
    └──requires──> [Bot System]
    └──requires──> [training_queue table] (already exists)
    └──requires──> [city_units table] (already exists)

[Bot Behaviors: Upgrade Buildings]
    └──requires──> [Bot System]
    └──requires──> [construction_queue table] (already exists)
    └──requires──> [city_buildings table] (already exists)

[GodMode Dashboard]
    └──requires──> [Admin identity check] (hardcoded UID constant)
    └──requires──> [admin_* RPC functions] (new privileged functions, SECURITY DEFINER)
    └──requires──> [Bot System] (to show bot status)
    └──reads──>    [all player profiles, cities, resources, battles, movements]

[GodMode Controls]
    └──requires──> [GodMode Dashboard]
    └──requires──> [is_bot_paused flag on profiles] (schema addition)
    └──requires──> [admin_set_resources() RPC] (new privileged function)
    └──requires──> [run_bot_tick() RPC] (new privileged function)

[Rich Seed Data]
    └──requires──> [Bot System schema] (bot profile columns must exist before seeding)
    └──requires──> [All existing tables] (cities, buildings, units, resources)
    └──outputs──>  [20 bot profiles across 8-10 islands with varied states]

[Unit Tests: Edge Functions]
    └──requires──> [supabase start] (local Supabase running)
    └──requires──> [deno test runner] (built into Deno)
    └──tests──>    [upgrade-building, train-units, dispatch-units, spy-city, send-trade]

[Unit Tests: Flutter Widgets]
    └──requires──> [flutter_test package] (ships with Flutter SDK)
    └──requires──> [Riverpod ProviderContainer overrides] (mock game state)
    └──tests──>    [ResourceBar, BattleReport, CityView, IslandView widgets]

[CI/CD Pipeline]
    └──requires──> [Unit Tests: Edge Functions] (runs in pipeline)
    └──requires──> [Unit Tests: Flutter Widgets] (runs in pipeline)
    └──requires──> [flutter analyze] (lint)
    └──requires──> [deno lint] (lint)
    └──outputs──>  [GitHub Actions workflow .github/workflows/ci.yml]

[Automation Scripts]
    └──requires──> [Supabase CLI] (already used)
    └──requires──> [Rich Seed Data script] (seed.ts or seed.sql)
    └──outputs──>  [scripts/reset.sh, scripts/seed.sh, scripts/serve.sh, scripts/test.sh]
```

### Dependency Notes

- **Bot System must exist before Seed Data**: The seed script inserts rows into `profiles` with `is_bot=true` and `bot_archetype` columns; those columns must exist in the migration before seeding runs.
- **GodMode requires no new auth system**: Admin identity is checked client-side (hardcoded UID in `lib/config/admin.dart`) and server-side in every admin RPC using `SECURITY DEFINER` with an explicit `auth.uid() = ANY('{uuid1,uuid2}'::uuid[])` guard.
- **Bot functions must use postgres role, not player auth**: The `bot_tick()` SQL function runs with `SECURITY DEFINER` under the postgres superuser so it can write to any city without being blocked by RLS policies intended for players.
- **Unit tests are independent of CI**: Developers run `deno test` and `flutter test` locally; CI runs the same commands. The test suite must work without a running Supabase instance (mock client) for CI speed.
- **Seed data depends on DB reset being idempotent**: The automation script runs `supabase db reset` (wipes and re-applies all migrations) then `seed.ts`; seed script must handle the clean-slate state and not assume prior data.

---

## MVP Definition

### Launch With (v1.3 — this milestone)

- [ ] Bot schema additions: `is_bot BOOLEAN`, `bot_archetype TEXT`, `is_bot_paused BOOLEAN` on `profiles` — enables all bot features
- [ ] `bot_tick()` SQL function: per-bot FSM logic for attack / train / upgrade decisions based on archetype weights
- [ ] pg_cron `bot-tick` job: every 15 minutes, calls `bot_tick()` for all non-paused bot profiles
- [ ] Seed script: 20 bot accounts across 8-10 islands, varied building levels (1-8), unit counts (0-200), resource balances
- [ ] GodMode dashboard screen: full-page admin view showing all players (bot + human), resource levels, army sizes, active battles
- [ ] GodMode bot controls: pause/resume toggle per bot; force-tick button
- [ ] GodMode resource edit: set resource balances for any city (for balance testing)
- [ ] Unit tests: `upgrade-building` and `train-units` Edge Functions (highest bug-surface functions)
- [ ] Widget tests: `ResourceBar` and `BattleReportScreen` (most data-sensitive widgets)
- [ ] Automation scripts: `reset-and-seed`, `serve` (Edge Functions), `test` (combined Flutter + Deno runner)
- [ ] CI workflow: GitHub Actions with `flutter analyze` + `flutter test` + `deno lint` on push to main

### Add After Validation (v1.x)

- [ ] Bot personality tuning via GodMode UI (adjust archetype weights without code change) — only needed if bots prove unbalanced post-launch
- [ ] Bot alliance formation (bots join same alliance to simulate player alliances) — requires alliance system first (v1.4+)
- [ ] Full CI build artifact: `flutter build web` producing deployable output — add when hosting is configured
- [ ] Integration test suite (full Supabase + Flutter E2E) — add when team size justifies the maintenance cost

### Future Consideration (v2+)

- [ ] Adaptive bot difficulty (bot archetype shifts based on win/loss ratio) — requires gameplay telemetry first
- [ ] Public bot leaderboard (show which bot archetype "wins" the world) — novelty feature for established player base
- [ ] Automated deployment pipeline (CD, not just CI) — deferred until hosting target is chosen

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Bot system (schema + tick function) | HIGH — bots populate the world | MEDIUM | P1 — core of this milestone |
| Rich seed data (20 bots, varied states) | HIGH — realistic world for testing and new players | MEDIUM | P1 — needed immediately after bot schema |
| GodMode dashboard (read-only view) | HIGH — essential for admin observation | MEDIUM | P1 — dev tool with high payoff |
| GodMode bot pause/resume | HIGH — safety control for misbehaving bots | LOW | P1 — must ship with bot system |
| Automation scripts (reset + seed) | HIGH — eliminates manual dev setup friction | LOW | P1 — first thing every developer needs |
| Unit tests: Edge Functions | HIGH — prevents economy exploits from regressions | MEDIUM | P1 — battle + pillage functions are high risk |
| Unit tests: Flutter widgets | MEDIUM — catches UI regressions | MEDIUM | P2 — less critical than backend tests |
| CI pipeline (GitHub Actions) | MEDIUM — code quality gate | LOW | P2 — set up once, runs forever |
| GodMode resource edit | MEDIUM — balance testing accelerator | LOW | P2 — useful but not blocking |
| Bot archetypes (3 personalities) | MEDIUM — world variety | LOW | P1 — cheap differentiation from uniform bots |

**Priority key:**
- P1: Must have for v1.3 launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

---

## Bot Behavior Design

### FSM State Machine (Per Bot, Per Tick)

Each bot evaluates its current state and takes at most one action per tick to avoid overwhelming game queues.

```
[Evaluate State]
    ├── army_strength < archetype_target_army?
    │       └── [Train Units] — queue highest-priority unit type for archetype
    ├── has_idle_construction_slot AND gold >= next_upgrade_cost?
    │       └── [Upgrade Building] — pick building with highest archetype ROI
    ├── army_strength >= attack_threshold AND cooldown_expired?
    │       └── [Select Target] — find nearest city not on same island
    │               └── [Dispatch Attack] — insert into unit_movements
    └── [Idle] — do nothing this tick (also triggered by 20% random skip)
```

### Archetype Weights (MEDIUM confidence — needs balance tuning post-launch)

| Behavior | Militarist | Economist | Builder |
|----------|------------|-----------|---------|
| Train units frequency | High (every 2 ticks) | Low (every 5 ticks) | Low (every 5 ticks) |
| Attack frequency | High (every 3 ticks if army ready) | Low (every 8 ticks) | Very low (every 12 ticks) |
| Building upgrades | Low priority | Medium priority | High priority (every tick) |
| Island donations | None | High (donates 20% of wood surplus) | Medium |
| Target army size | 200 units | 60 units | 80 units |

### pg_cron Implementation Pattern

The `bot_tick()` function follows the established pattern of all other game cron functions in this codebase:

```sql
-- Scheduled every 15 minutes
-- Function iterates over all bot profiles where is_bot_paused = false
-- Each bot evaluates its own city state and inserts into appropriate queue tables
-- SECURITY DEFINER to bypass RLS (same pattern as process_resource_tick)
-- Random jitter: bot SKIPS action if random() < 0.2 (20% skip rate per tick)
```

This is HIGH confidence — it directly mirrors the existing `complete_building_upgrades()`, `complete_training()`, and `process_arrivals()` cron function patterns already in the codebase.

---

## Testing Strategy

### Edge Function Tests (Deno — HIGH confidence from official Supabase docs)

Test files live in `supabase/functions/tests/` as `[function-name]-test.ts`.

```
Priority 1 (HIGH business risk):
  - upgrade-building-test.ts  → test cost formula, level cap, queue insertion
  - train-units-test.ts       → test resource deduction, queue insertion, unit type validation
  - dispatch-units-test.ts    → test distance calculation, unit deduction, movement insertion

Priority 2 (MEDIUM business risk):
  - spy-city-test.ts          → test RLS enforcement (can't spy own city)
  - send-trade-test.ts        → test cargo ship deduction, movement insertion
```

Test pattern: `deno test --allow-env --allow-net supabase/functions/tests/`
Requires local Supabase running: `supabase start` before `supabase functions serve`

### Flutter Widget Tests (flutter_test — HIGH confidence from Flutter docs)

```
Priority 1 (visible to player immediately):
  - resource_bar_test.dart    → test +X/hr display, capacity bar width
  - battle_report_test.dart   → test turn-by-turn unit loss display

Priority 2 (less regression risk):
  - city_view_test.dart       → test building grid renders, button states
  - island_view_test.dart     → test city slot ownership borders
```

Use `ProviderContainer` overrides to inject mock game state without network calls.
Use `pump()` and `pumpAndSettle()` for async widget renders.

### What NOT to Test (Anti-Feature: 100% coverage)

- UI glue code (routing, theming, icon selection)
- Generated/formulaic code (building definitions, unit stat tables)
- pg_cron scheduling itself (Supabase manages this; trust the platform)
- Trivial getters and model constructors with no logic

---

## Automation Scripts Design

### scripts/reset-and-seed.sh

```bash
#!/bin/bash
# Resets DB to clean migration state, then seeds bot accounts
supabase db reset
deno run --allow-env --allow-net seed/seed.ts
```

### scripts/serve.sh

```bash
#!/bin/bash
# Starts local Edge Functions server for development
supabase functions serve --env-file .env.local
```

### scripts/test.sh

```bash
#!/bin/bash
# Runs all tests: Flutter unit + widget tests, Deno Edge Function tests
flutter test
deno test --allow-env --allow-net supabase/functions/tests/
```

### scripts/build.sh

```bash
#!/bin/bash
# Production Flutter web build
flutter build web --release
```

### .github/workflows/ci.yml (CI Pipeline)

Triggers: push to `main`, pull requests to `main`

Steps:
1. `flutter analyze` — Dart static analysis (zero warnings policy)
2. `flutter test` — all widget + unit tests
3. `deno lint supabase/functions/` — TypeScript lint
4. `deno check supabase/functions/` — TypeScript type check
5. (Optional P2) `flutter build web --release` — verify build succeeds

---

## GodMode Dashboard Design

### Read-Only World View (P1)

| Panel | Data Shown | Update Strategy |
|-------|------------|-----------------|
| Player list | Profile name, is_bot, bot_archetype, is_bot_paused, city count | Poll every 30s |
| Resource snapshot | Wood/Marble/Crystal/Sulfur/Gold per city (admin query bypasses RLS) | Poll every 30s |
| Army snapshot | Total units per city, units in transit | Poll every 30s |
| Active battles | Attacker, defender, current turn, turn count | Poll every 10s |
| Bot status | Last tick time, last action taken, skip count | Poll every 30s |

### Admin Actions (P1-P2)

| Control | Action | Implementation |
|---------|--------|----------------|
| Pause bot | Sets `is_bot_paused = true` on profile | `admin_pause_bot(profile_id)` RPC |
| Resume bot | Sets `is_bot_paused = false` on profile | `admin_resume_bot(profile_id)` RPC |
| Force bot tick | Runs `bot_tick()` for one bot immediately | `run_bot_tick(profile_id)` RPC |
| Set resources | Updates city resource amounts | `admin_set_resources(city_id, ...)` RPC |

All admin RPCs use `SECURITY DEFINER` and check `auth.uid() = ANY('{admin_uuid}'::uuid[])` — no client-side trust.

---

## Competitor Feature Analysis

| Feature | Original Ikariam | Other Browser Games (Travian/Grepolis) | Our v1.3 Approach |
|---------|-----------------|----------------------------------------|-------------------|
| NPC / bot players | Barbarian villages (PvE targets only, not full players) | AI placeholder accounts in early worlds | Full bot accounts with auth profiles; participate in same game loop as players |
| Admin tools | GameForge internal — not visible to community | Private GM tools; players report via ticket | In-game GodMode screen for the single admin (project owner); accessible via Flutter route guard |
| World seeding | Bots and players start fresh simultaneously | Pre-seeded NPC villages at world launch | 20 bot accounts seeded at DB init via migration or seed script |
| CI/CD | N/A (closed source) | N/A | GitHub Actions: lint + test + build |
| Test coverage | N/A | N/A | Critical paths only; Edge Functions + key Flutter widgets |

---

## Sources

- [Supabase: Testing your Edge Functions](https://supabase.com/docs/guides/functions/unit-test) — Official Deno test setup, file organization, permissions flags
- [Supabase: Automated testing using GitHub Actions](https://supabase.com/docs/guides/deployment/ci/testing) — CI/CD workflow patterns for Supabase projects
- [Supabase: pg_cron extension](https://supabase.com/docs/guides/database/extensions/pg_cron) — Scheduling syntax and patterns
- [Flutter: Testing overview](https://docs.flutter.dev/testing/overview) — Unit, widget, integration test types
- [Flutter: Widget testing introduction](https://docs.flutter.dev/cookbook/testing/widget/introduction) — testWidgets(), WidgetTester, pump()
- [Little Polygon Dev Blog: FSM in game AI](https://blog.littlepolygon.com/posts/fsm/) — FSM decomposition, state/transition patterns
- [ResearchGate: A Review of Real-Time Strategy Game AI](https://www.researchgate.net/publication/279335137_A_Review_of_Real-Time_Strategy_Game_AI) — Hierarchical AI, behavior trees vs FSMs
- [Ikabot Collective: ikabot (Ikariam bot)](https://github.com/Ikabot-Collective/ikabot) — Real-world Ikariam automation behaviors (city management, warfare, alerts)
- [Supabase: Development tips for Edge Functions](https://supabase.com/docs/guides/functions/development-tips) — Local development patterns

---

*Feature research for: Ikariam clone v1.3 — Bots, Testing & Automation (Flutter + Supabase)*
*Researched: 2026-03-17*
