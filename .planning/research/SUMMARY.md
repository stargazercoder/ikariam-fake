# Project Research Summary

**Project:** Ikariam Clone — v1.3 Bots, Testing & Automation
**Domain:** Browser-based multiplayer strategy game (Flutter web + Supabase)
**Researched:** 2026-03-17
**Confidence:** HIGH

## Executive Summary

v1.3 adds five capability areas to a mature Flutter + Supabase codebase: AI bot players, a GodMode admin dashboard, rich seed data, unit tests, and CI/CD automation. The research conclusion is clear — all five areas are buildable with the existing stack and zero new infrastructure. The only new Dart package justified is `data_table_2 ^2.7.2` for the GodMode player table. Bot AI runs entirely inside PostgreSQL as a pg_cron-scheduled PL/pgSQL function, mirroring the existing pattern of five game-loop cron jobs already in production. Edge Function tests use Deno's built-in test runner. CI runs via GitHub Actions with the canonical `subosito/flutter-action@v2`. No new services, no new server tiers.

The recommended approach is database-first. The schema migration (`profiles.is_bot`, `profiles.is_admin`, `bot_schedules` table) must come first because every other v1.3 feature depends on it — bot functions need it, GodMode RPCs need it, and seed data needs it. From that foundation, bot backend logic and GodMode backend RPCs can be developed in parallel. Flutter GodMode screens and seed data enrichment come after their respective backends are stable. Tests and CI infrastructure are independent of feature order and can start as soon as any extractable logic exists.

The dominant risk is security: the GodMode dashboard needs cross-player data visibility, and the naive implementation (embedding the `service_role` key in Flutter web) is catastrophic — the key would be visible in the compiled JS bundle and grant root database access to anyone who extracts it. The research is unambiguous: all admin data access must go through `SECURITY DEFINER` RPC functions that check `is_admin` at the Postgres layer, using only the anon key in Flutter. A second major risk is pg_cron worker pool exhaustion — bot behavior must be a single consolidated `bot-think-tick` at `*/15 * * * *`, not multiple per-behavior cron jobs. Both risks have proven mitigations that must be locked in at architecture phase, not discovered mid-implementation.

---

## Key Findings

### Recommended Stack

The existing stack (Flutter 3.29, Supabase 2.12.0, Riverpod 3.3.1, Flame 1.35.1, go_router 17.1.0) requires no changes for v1.3. Only one new package is added: `data_table_2 ^2.7.2`, which provides sticky-header paginated tables with async data sources and row-level tap — capabilities absent from Flutter's built-in `PaginatedDataTable`. Bot logic runs as pure PostgreSQL PL/pgSQL, avoiding Edge Function HTTP round-trips. Edge Function tests use Deno's zero-install built-in test runner with `jsr:@std/assert`. CI runs on GitHub Actions with `subosito/flutter-action@v2` and `denoland/setup-deno@v2`.

One critical version constraint: Deno must be pinned to 2.0–2.2.x in CI because Supabase Edge Runtime does not yet support the Deno 2.3+ lock file format (v5). This is confirmed via GitHub Discussion, not official docs (MEDIUM confidence), but must be treated as a hard constraint until official confirmation.

See full details: `.planning/research/STACK.md`

**Core technologies:**
- `data_table_2 ^2.7.2`: GodMode admin tables — sticky headers, async source, row-level tap; MIT license; only new package
- PostgreSQL PL/pgSQL + pg_cron: bot AI tick — no HTTP latency, runs in DB transaction, mirrors existing cron job pattern
- Deno built-in test runner + `jsr:@std/assert`: Edge Function unit tests — zero install, official Supabase recommendation
- GitHub Actions + `subosito/flutter-action@v2` + `denoland/setup-deno@v2`: CI pipeline — free tier, no additional service accounts
- Riverpod 3.3.1 `ProviderContainer.test()`: Flutter provider tests — auto-dispose, no manual teardown boilerplate (new in Riverpod 3.0, Sept 2025)
- `is_admin` on `profiles` table: GodMode gating — checked server-side in every SECURITY DEFINER RPC; anon key only in Flutter client

### Expected Features

See full details: `.planning/research/FEATURES.md`

**Must have (table stakes — v1.3 launch):**
- Bots that attack players — uses existing dispatch-units infrastructure via SECURITY DEFINER SQL; pg_cron trigger
- Bots that train units — checks army threshold against archetype target; inserts into existing training_queue
- Bots that upgrade buildings — evaluates building ROI; uses existing construction_queue
- 20 bot accounts with distinct game states — varied building levels (low/mid/high), unit counts, resource balances across 8-10 islands
- GodMode dashboard: all-player view — resources, army sizes, active battles, bot status; polling RPC every 30s
- GodMode: pause/resume bots per-bot — `is_bot_paused` flag; bot tick skips paused bots
- Automation scripts: DB reset + reseed — single `supabase db reset` restores full known world state
- Unit tests: critical Edge Functions — upgrade-building, train-units (highest bug-surface, economy exploit risk)
- Widget tests: ResourceBar and BattleReportScreen (most data-sensitive Flutter widgets)
- CI pipeline: GitHub Actions with flutter analyze + flutter test + deno lint on push to main

**Should have (differentiators — add when possible):**
- Bot personality archetypes: militarist, economist, builder — stored in `bot_schedules.aggression`; behavior weights differ
- Bot stochastic jitter: 20% random skip per tick — prevents synchronized unnatural world patterns
- GodMode: force-trigger individual bot action — validate bot behavior without waiting 15 min for cron
- GodMode: modify player resource balances — admin form calling `admin_set_resources()` RPC for balance testing
- Rich seed data: bots across 8-10 distinct islands with deterministic island positions

**Defer (v1.x / v2+):**
- Bot personality tuning via GodMode UI (adjust weights without code change) — only if bots prove unbalanced post-launch
- Bot alliance formation — requires alliance system (v1.4+)
- Adaptive bot difficulty based on win/loss ratio — requires gameplay telemetry first
- Full CD pipeline (automated deployment) — deferred until hosting target is chosen
- Full E2E integration test suite — add when team size justifies maintenance cost

**Anti-features to explicitly reject:**
- ML/LLM bot AI — massively over-engineered for a small-community game; revisit only if player counts justify it
- Bots calling player Edge Functions via pg_net — HTTP round-trip latency + auth complexity; use SECURITY DEFINER PL/pgSQL
- Realtime fan-out for all bot state changes — O(n) subscription overhead; use polling admin RPC instead
- 100% test coverage mandate — slows iteration; target 60-70% on Edge Functions, critical paths only
- GodMode accessible via soft profile column without server-side verification — service_role key exposure risk

### Architecture Approach

All v1.3 additions integrate through three clean extension points in the existing architecture: (1) new columns on `profiles` (`is_bot`, `is_admin`) that require no RLS changes because all existing policies and cron functions remain valid; (2) a new `bot_schedules` table accessed only via SECURITY DEFINER functions, with RLS enabled but no client-facing policies; (3) a new `lib/features/admin/` Flutter module with its own provider, model, and screen behind a go_router redirect guard. Bot behaviors write directly to the same game tables (`training_queue`, `construction_queue`, `unit_movements`) that Edge Functions write to — the existing processing ticks handle bot completions with zero modification.

See full details: `.planning/research/ARCHITECTURE.md`

**Major components:**
1. Bot tick engine — `run_bot_decisions()` PL/pgSQL + `bot-think-tick` pg_cron at `*/15 * * * *`; dispatches one action per bot per tick; priority: upgrade → train → attack; SECURITY DEFINER; 15-min + random jitter on `next_action_at`
2. Bot helper functions — `bot_decide_upgrade()`, `bot_decide_train()`, `bot_decide_attack()`; each mirrors the equivalent Edge Function business rules in pure SQL; direct table writes (no pg_net)
3. GodMode RPCs — `godmode_get_world_state()`, `godmode_set_bot_paused()`, `godmode_force_action()`; all check `is_admin` as first statement; return JSONB; Flutter uses anon key only
4. GodMode Flutter module — `lib/features/admin/` with `world_state.dart` model, `admin_provider.dart`, `godmode_screen.dart`; not in bottom nav; route guard in `app_router.dart`
5. Rich seed data layers — Layer 1: islands (existing); Layer 2: 20 bot auth.users + profiles + bot_schedules; Layer 3: diverse game state via existing dev RPCs (`dev_inject_resources`, `dev_level_up_building`, `dev_bulk_spawn_units`)
6. Deno unit tests — `supabase/functions/tests/` directory; pure function extraction pattern; no Supabase mock needed for unit tests
7. GitHub Actions CI — `.github/workflows/ci.yml`; flutter analyze + flutter test + deno test + flutter build web

**Key patterns to follow:**
- Bot functions use SECURITY DEFINER (same as all existing cron functions) — never use pg_net HTTP calls from pg_cron to call Edge Functions
- All admin data access via SECURITY DEFINER RPCs — never embed service_role key in Flutter code
- Single consolidated `bot-think-tick` cron job — not multiple per-behavior jobs
- GodMode dashboard uses polling RPC, not Realtime table subscriptions
- Seed data uses `ON CONFLICT` on all inserts — must be idempotent through double-reset

### Critical Pitfalls

See full details: `.planning/research/PITFALLS.md`

1. **GodMode service_role key in Flutter client** — Never embed `service_role` in Flutter code or `--dart-define`; it appears in the compiled JS/WASM bundle. Use SECURITY DEFINER RPCs with `is_admin` check. Recovery if exposed: rotate key immediately, audit logs, rebuild and redeploy.

2. **Multiple bot pg_cron jobs exhausting worker pool** — Do not create separate cron jobs per bot behavior (`bot-attack-tick`, `bot-train-tick`). The existing five game ticks already occupy workers at `* * * * *`. Adding more at the same interval causes silent drop-skipping when `cron.max_running_jobs` is exceeded. Single `bot-think-tick` at `*/15 * * * *` with internal dispatch loop.

3. **Seed idempotency failure on double `supabase db reset`** — All `auth.users` and `auth.identities` inserts must use `ON CONFLICT (id) DO NOTHING` / `ON CONFLICT (provider_id, provider) DO NOTHING`. Test explicitly: `supabase db reset && supabase db reset` — second run must exit 0 with no duplicate key errors.

4. **Bot tick architecture: PL/pgSQL not pg_net** — Bot behaviors must call SECURITY DEFINER SQL functions directly, writing to the same tables Edge Functions write to. Using `pg_net` HTTP calls to invoke Edge Functions from pg_cron adds HTTP round-trip latency, cold-start overhead, and unretried failure modes. Document this decision in bot migration file headers.

5. **Riverpod provider state leaking between widget tests** — Implement `createProviderScope` helper in `test/helpers/test_helpers.dart` before writing any GodMode widget tests. Every test must use a new `ProviderContainer` with explicit overrides. Failure mode: tests pass individually but fail in suite due to order-dependent state contamination.

6. **Deno not installed in GitHub Actions runner** — Ubuntu-latest does not include Deno. Add `uses: denoland/setup-deno@v2` before any `deno test` step. If missing, tests silently skip (not fail), producing false-green CI.

---

## Implications for Roadmap

Based on combined research (feature dependencies, architecture build order, pitfall-to-phase mapping), a seven-phase structure is recommended.

### Phase 1: Bot Schema Foundation
**Rationale:** Every other v1.3 feature depends on `profiles.is_bot`, `profiles.is_admin`, and `bot_schedules`. This is the unblocking migration — bot functions, GodMode RPCs, seed data, and the Flutter Profile model all require these columns and table to exist. Must come first with no exceptions.
**Delivers:** Migration adding `is_bot` + `is_admin` columns to `profiles`; `bot_schedules` table with `aggression` (0-3) and `is_paused` + `next_action_at`; updated `Profile` Dart model with `isBot` and `isAdmin` fields.
**Addresses:** Foundation for all bot features and GodMode access control.
**Avoids:** Pitfall 2 (bot architecture decision) — document the SECURITY DEFINER pattern explicitly in this migration's header before any bot logic is written.
**Research flag:** Standard pattern — directly mirrors existing `profiles` migration pattern. No additional research needed.

### Phase 2: Bot Backend (pg_cron + PL/pgSQL)
**Rationale:** With schema in place, the bot tick engine can be built and validated entirely at the DB layer before any Flutter work. Testing via direct SQL calls is fast and reliable. Can run in parallel with Phase 3 (GodMode backend) since both share only the schema dependency.
**Delivers:** `run_bot_decisions()` PL/pgSQL function; `bot_decide_upgrade()`, `bot_decide_train()`, `bot_decide_attack()` helper functions; `bot-think-tick` pg_cron job at `*/15 * * * *`; bot archetype weighting via `aggression` level; 15-min + random jitter on `next_action_at`.
**Uses:** Pure PL/pgSQL; `SECURITY DEFINER`; direct writes to `training_queue`, `construction_queue`, `unit_movements` — same tables as Edge Functions.
**Avoids:** Pitfall 1 (pg_cron worker pool exhaustion) — single consolidated tick; Pitfall 5 (bot targeting imbalance) — two-tiered targeting (70% bot-to-bot, aggression-gated player attacks) with cooldown table.
**Research flag:** Standard pattern — directly mirrors `complete_training()`, `resolve_battles()`, `process_resource_tick()`. No additional research needed.

### Phase 3: GodMode Backend (SECURITY DEFINER RPCs)
**Rationale:** GodMode read RPCs are independent of bot logic and can be developed in parallel with Phase 2. Backend security model must be proven before any Flutter GodMode code is written — prevents the service_role pitfall from ever being tempting.
**Delivers:** `godmode_get_world_state()` RPC (JSONB world snapshot); `godmode_set_bot_paused()` RPC; `godmode_force_action()` RPC; `SELECT ... FOR SHARE` locking in bot tick for clean pause semantics; admin account seeded with `is_admin = true`; go_router `/godmode` route guard in `app_router.dart`.
**Avoids:** Pitfall 4 (service_role in Flutter) — architecture locked at backend before any Flutter GodMode widget exists; Pitfall 9 (partial-tick pause window) — row-level locking coordinates pause with running tick.
**Research flag:** Standard pattern — directly mirrors `supabase/migrations/20260312000008_dev_rpc_helpers.sql`. No additional research needed.

### Phase 4: Rich Seed Data (20 Bot Accounts)
**Rationale:** Requires Phase 1 schema and Phase 2 bot_schedules rows. Should be validated before Flutter work begins so the full world state is testable. Bot diversity design must be explicit — trigger defaults produce identical starting states.
**Delivers:** Extended `seed.sql` with 20 bot `auth.users`; profiles with historically-themed names; `bot_schedules` with diverse aggression levels (0-3); at least 3 distinct building-level profiles (low/mid/high) via `dev_level_up_building`; varied army compositions via `dev_bulk_spawn_units`; varied resources via `dev_inject_resources`; bots across 8-10 islands with deterministic slot assignments.
**Addresses:** "20 bot accounts with distinct game states" table-stakes feature; "diverse island distribution" differentiator.
**Avoids:** Pitfall 3 (seed idempotency) — all inserts with `ON CONFLICT`; double-reset validation required before phase is marked complete. Pitfall 8 (bot state inconsistency) — explicit per-bot UPDATE blocks; no reliance on trigger defaults for diverse game state.
**Research flag:** Standard pattern. Phase plan must specify the exact building/army/resource distribution for each of 20 bots (this is design work, not research).

### Phase 5: GodMode Flutter Dashboard
**Rationale:** Depends on Phase 3 RPCs being stable and tested. Flutter work starts only after the DB layer is proven to avoid debugging ambiguity between backend and UI layers.
**Delivers:** `lib/features/admin/models/world_state.dart`; `lib/features/admin/providers/admin_provider.dart`; `lib/features/admin/screens/godmode_screen.dart` with `data_table_2` player table (sortable, sticky headers); bot pause/resume controls per row; resource edit form; bot force-tick button; historically-themed player/bot display names (not raw UUIDs).
**Uses:** `data_table_2 ^2.7.2` (only new Dart package for v1.3); existing Riverpod StreamProvider/polling pattern; go_router redirect guard already added in Phase 3.
**Avoids:** Pitfall 12 (Realtime overload) — dashboard polls `godmode_get_world_state()` RPC every 30s, not Realtime table subscriptions. Pitfall 4 (service_role) — anon key only in Flutter; all admin checks in Postgres.
**Research flag:** `data_table_2` API is well-documented. No additional research needed. UX decisions (pause state feedback, bot badges visible only to admin) should be defined in phase plan.

### Phase 6: Unit Tests (Flutter + Deno)
**Rationale:** Can begin after any extractable logic exists. Deno test infrastructure should be validated before Phase 7 (CI) to surface runner issues early. The `createProviderScope` helper must be implemented before any GodMode widget tests are written.
**Delivers:** `supabase/functions/tests/` directory with `upgrade-building-test.ts`, `train-units-test.ts`, `dispatch-units-test.ts`, `send-trade-test.ts`; pure function extraction from Edge Functions (`cost.ts`, `travel.ts`); `createProviderScope` helper in `test/helpers/test_helpers.dart` (first task); `ResourceBar` and `BattleReportScreen` widget tests with per-test provider overrides.
**Avoids:** Pitfall 6 (mocking hides real bugs) — at least one test per Edge Function exercises real extracted logic, not mocked client. Pitfall 10 (Riverpod test isolation) — `createProviderScope` with per-test `ProviderContainer` and explicit overrides.
**Research flag:** Pure function extraction + Deno test runner is the official Supabase recommendation. No additional research needed.

### Phase 7: CI/CD Automation
**Rationale:** Final phase — gates all previous work with a permanent quality gate. Requires Phase 6 tests to exist. Sets up automated CI for all future v1.3+ development.
**Delivers:** `.github/workflows/ci.yml` with flutter analyze + flutter test + deno test + flutter build web; `scripts/db_reset.sh`; `scripts/seed_bots.sh`; `scripts/ci.sh`; `scripts/lint.sh` (flutter analyze + dart format check); `denoland/setup-deno@v2` step in CI (critical — without it, deno tests silently skip).
**Uses:** GitHub Actions, `subosito/flutter-action@v2` with `cache: true`, `denoland/setup-deno@v2` pinned to 2.2.x, Supabase CLI 2.79.0.
**Avoids:** Pitfall 7 (Deno not in CI) — `denoland/setup-deno@v2` step required. Pitfall 11 (Windows/Linux path incompatibility) — all `.sh` scripts validated in WSL Ubuntu before commit; shellcheck lint on all scripts.
**Research flag:** Standard pattern. Pin Deno to 2.2.x (Supabase Edge Runtime does not support Deno 2.3+ lock file). No additional research needed.

### Phase Ordering Rationale

- **Schema first (Phase 1)** is mandatory — `profiles.is_bot`, `profiles.is_admin`, and `bot_schedules` are dependencies of every other phase. A schema gap discovered mid-implementation cascades into all layers simultaneously.
- **Bot backend and GodMode backend in parallel (Phases 2 and 3)** — they share only the schema dependency and have no runtime coupling. Parallel development maximizes velocity at no risk.
- **Seed data after schema and bot backend (Phase 4)** — `bot_schedules` rows must exist before seed can insert them; `dev_*` RPCs called in Layer 3 rely on bot schema columns.
- **Flutter GodMode after GodMode RPCs (Phase 5)** — UI built against untested RPCs creates ambiguous failures. Backend proven in Phase 3 before any Flutter widget is written.
- **Tests before CI (Phases 6 then 7)** — CI that runs no tests is a false quality gate. Tests must exist and pass locally before the CI workflow is configured.
- **Security architecture decisions locked in Phases 1-3** before any Flutter code exists — service_role exposure (Pitfall 4) is unrecoverable without key rotation if shipped. The correct time to enforce it is before the first GodMode widget is written.

### Research Flags

Phases likely needing design decisions during planning (not additional research):
- **Phase 2 (Bot Backend):** Bot archetype weight values (aggression thresholds, attack frequencies per archetype) are MEDIUM confidence from game dev community sources — not empirically validated. Plan should treat these as tunable parameters with a post-launch balance review milestone. Simulate 100 bot tick runs to verify targeting distribution (target: >30% of attacks targeting non-bot cities).
- **Phase 4 (Seed Data):** The exact building level, army count, and resource amount for each of the 20 bots is design work, not research. Phase plan must specify per-bot state explicitly — research provides the pattern (3 distinct profiles: low/mid/high), not the values.

Phases with standard patterns (no additional research needed):
- **Phase 1 (Schema):** Directly mirrors existing `profiles` migration. No unknowns.
- **Phase 3 (GodMode Backend):** Directly mirrors `20260312000008_dev_rpc_helpers.sql`. Security model is proven in existing codebase.
- **Phase 5 (GodMode Flutter):** `data_table_2` API is documented; go_router redirect guard pattern is established in existing app_router.dart.
- **Phase 6 (Tests):** Official Supabase recommendation; pure function extraction pattern is straightforward.
- **Phase 7 (CI):** GitHub Actions Flutter pipeline is canonical and well-documented.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All technologies verified via pub.dev, official Supabase docs, Riverpod docs, Deno docs. Only one new package (`data_table_2`). Version compatibility confirmed. Deno version constraint is MEDIUM (GitHub Discussion, not official docs) but treated as hard constraint. |
| Features | MEDIUM | Table stakes and GodMode features are HIGH confidence from official docs and existing codebase patterns. Bot archetype weights and targeting ratios are MEDIUM — game balance requires empirical tuning post-launch. |
| Architecture | HIGH | All patterns verified directly against existing codebase (`dev_rpc_helpers.sql`, `app_router.dart`, `seed.sql`, `test_all.sh`, `battle_cron_job.sql`). No speculative patterns. New code mirrors existing code throughout. |
| Pitfalls | HIGH (security/infra) / MEDIUM (game balance) | Supabase/PostgreSQL pitfalls (service_role exposure, pg_cron worker pool, seed idempotency, Realtime limits) are HIGH confidence from official docs and confirmed GitHub issues. Bot behavior design pitfalls (targeting balance, archetype tuning) are MEDIUM from game dev community sources. |

**Overall confidence:** HIGH

### Gaps to Address

- **Bot archetype weight calibration:** Specific values (e.g., "militarist attacks every 2 ticks") are design choices, not research findings. Must be treated as tunable parameters from day one. Add `aggression` level (0-3 integer) as a lever per bot rather than hardcoded archetype constants. Plan a balance review after the first week of bot operation in a live world.
- **Seed data diversity design:** Research specifies the three-layer pattern and confirms the `dev_*` RPC approach, but does not specify the actual per-bot values. Phase 4 plan must explicitly define which of the 20 bots gets which building levels, army counts, and resource amounts — this is design work.
- **GodMode UX specifics:** Research identified UX pitfalls (raw UUIDs, no pause feedback, identical bot names) but deferred specific UX decisions. Phase 5 plan must address: historically-themed bot name list, pause state spinner/confirmed-pause feedback flow, and whether bots are visually distinct to admin but appear as normal players to others.
- **Deno 2.2.x pin:** Pin `deno` to `2.2.x` explicitly in `.github/workflows/ci.yml` and document the reason. Track [supabase/supabase#33093] for when Deno 2.3+ lock file v5 support lands and the pin can be lifted.

---

## Sources

### Primary (HIGH confidence)
- [pub.dev/packages/data_table_2](https://pub.dev/packages/data_table_2) — v2.7.2, MIT, Flutter 3.x compatible; last updated Nov 2025
- [supabase.com/docs/guides/functions/unit-test](https://supabase.com/docs/guides/functions/unit-test) — Official Deno test runner pattern, `supabase/functions/tests/` directory convention
- [riverpod.dev/docs/whats_new](https://riverpod.dev/docs/whats_new) — `ProviderContainer.test()` and `WidgetTester.container` confirmed in Riverpod 3.0 (Sept 2025)
- [supabase.com/docs/guides/database/extensions/pg_cron](https://supabase.com/docs/guides/database/extensions/pg_cron) — `cron.schedule()` syntax, migrations vs. seed.sql pattern
- [supabase.com/docs/guides/database/postgres/row-level-security](https://supabase.com/docs/guides/database/postgres/row-level-security) — service role key security, SECURITY DEFINER pattern
- [supabase.com/docs/guides/realtime/limits](https://supabase.com/docs/guides/realtime/limits) — message rate limits (100/sec free, 500/sec pro)
- [supabase.com/docs/guides/deployment/ci/testing](https://supabase.com/docs/guides/deployment/ci/testing) — GitHub Actions CI/CD patterns for Supabase projects
- [github.com/subosito/flutter-action](https://github.com/subosito/flutter-action) — `subosito/flutter-action@v2` canonical Flutter GitHub Action
- [docs.deno.com/runtime/reference/std/assert/](https://docs.deno.com/runtime/reference/std/assert/) — `jsr:@std/assert` Deno 2.x standard assertions
- [riverpod.dev/docs/how_to/testing](https://riverpod.dev/docs/how_to/testing) — ProviderContainer isolation, per-test containers, auto-disposal
- Existing codebase (direct examination) — `supabase/migrations/20260312000008_dev_rpc_helpers.sql`, `supabase/migrations/20260312000006_battle_cron_job.sql`, `lib/core/router/app_router.dart`, `supabase/seed.sql`, `scripts/test_all.sh`

### Secondary (MEDIUM confidence)
- [github.com/orgs/supabase/discussions/39966](https://github.com/orgs/supabase/discussions/39966) — Deno lock file v5 not supported by Supabase Edge Runtime; pin Deno 2.0–2.2.x in CI
- [github.com/orgs/supabase/issues/28966](https://github.com/orgs/supabase/issues/28966) — `cron.schedule()` fails in seed.sql; use migrations instead
- [github.com/citusdata/pg_cron/issues/63](https://github.com/citusdata/pg_cron/issues/63) — silent job drop when `cron.max_running_jobs` exceeded
- [github.com/supabase/supabase/issues/33093](https://github.com/supabase/supabase/issues/33093) — CI docs for Edge Functions missing Deno setup step (confirmed documentation gap)
- [github.com/Ikabot-Collective/ikabot](https://github.com/Ikabot-Collective/ikabot) — Real-world Ikariam automation behaviors reference for bot action design
- [supabase.com/docs/guides/troubleshooting/pgcron-debugging-guide](https://supabase.com/docs/guides/troubleshooting/pgcron-debugging-guide-n1KTaz) — `cron.job_run_details` debugging, max_running_jobs behavior

### Tertiary (LOW confidence — needs empirical validation)
- [blog.littlepolygon.com/posts/fsm/](https://blog.littlepolygon.com/posts/fsm/) — FSM decomposition for game AI; confirms FSM appropriate for bot scale; archetype weight values require playtesting
- [researchgate.net — A Review of Real-Time Strategy Game AI](https://www.researchgate.net/publication/279335137_A_Review_of_Real-Time_Strategy_Game_AI) — FSM vs. behavior tree comparison; FSM justified for 20-bot scale

---

*Research completed: 2026-03-17*
*Ready for roadmap: yes*
