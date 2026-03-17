# Pitfalls Research

**Domain:** Browser-based multiplayer strategy game — v1.3 Bot Players, GodMode Admin, Seed Data, Unit Tests, CI/CD additions to existing Supabase/Flutter system
**Stack:** Flutter web + Supabase (Auth/DB/Realtime/Edge Functions/pg_cron) + Riverpod (manual providers)
**Researched:** 2026-03-17
**Confidence:** HIGH (Supabase/PostgreSQL-specific pitfalls verified via official docs and GitHub issues); MEDIUM (Flutter/Riverpod testing patterns from official Riverpod docs and community sources); LOW (bot behavior design patterns from general game dev community sources)

---

## Critical Pitfalls

### Pitfall 1: Bot pg_cron Jobs Piling Up — Overlap With Existing Game Loop Ticks

**What goes wrong:**
The existing game has four pg_cron jobs running every minute (`training-tick`, `arrivals-tick`, `battle-tick`) and every 5 minutes (`resource-tick`). Adding bot behavior jobs (e.g., `bot-attack-tick`, `bot-upgrade-tick`, `bot-train-tick`) at the same 1-minute interval means all jobs fire simultaneously. If any existing tick overruns 60 seconds, pg_cron queues the next run while the previous is still executing. Bot jobs doing full table scans on `cities` or `city_units` for all 20 bots compound this. Supabase's default `cron.max_running_jobs` is 32, but each overlapping job consumes a worker process. When `max_running_jobs` is exceeded, pg_cron silently skips the queued run rather than waiting, so bots may not fire on their intended schedule.

**Why it happens:**
Developers model each bot behavior as its own cron job (easiest to reason about in isolation) without considering cumulative worker consumption. The existing game ticks already occupy 4 workers every minute. Adding 3 more bot jobs pushes total concurrent workers to 7. If any job runs long (e.g., `resolve_battles()` processes a large battle), the worker pool backpressure silently drops scheduled runs.

**How to avoid:**
Consolidate all bot behaviors into a single `bot-tick` pg_cron job that runs its own internal dispatch loop. Inside `bot_tick()`, iterate over bots and apply one action per bot per invocation using a deterministic priority: upgrade first, then train, then attack. Add a `bots_enabled` flag in a `game_config` table so the GodMode dashboard can disable all bots with one row update rather than unscheduling pg_cron entries. Keep bot tick interval at 5 minutes (not 1 minute) — bots do not need per-minute precision and this avoids collision with the existing minute-level ticks. Add a `SELECT pg_sleep(0)` heartbeat guard: if the previous bot tick is still running (detectable via `cron.job_run_details`), the new invocation should exit immediately.

**Warning signs:**
- Bot behaviors defined as 3+ separate `cron.schedule()` entries firing at `* * * * *`
- No `bots_enabled` kill switch in config table
- `cron.job_run_details` showing `failed` status for existing game ticks after bot jobs were added
- Resource tick execution time growing from ~200ms to >5s after bots were added

**Phase to address:**
Bot Infrastructure phase (first bot phase). Define the single `bot_tick()` function and its cron schedule before writing any individual bot behavior logic.

---

### Pitfall 2: Bot Accounts Triggering RLS — Service Role vs. Authenticated Session Confusion

**What goes wrong:**
Bot accounts are real Supabase Auth users. When the `bot_tick()` PostgreSQL function (running as `SECURITY DEFINER`) calls Edge Functions or attempts direct table writes, it runs as the function owner role, not as any specific bot user. If a bot behavior needs to call an Edge Function (e.g., `dispatch-units`), it cannot provide a user JWT because pg_cron functions have no session context. Developers either bypass this by calling the Edge Function from inside the DB using `http_post()` (requires `pg_net` extension), or they write a separate `SECURITY DEFINER` function that bypasses RLS and directly writes to `unit_movements`. The second approach works but silently breaks the invariant that "all mutations go through Edge Functions." The first approach adds network latency and failure modes (pg_net failures are not automatically retried by pg_cron).

**Why it happens:**
The game's architecture says "all mutations via Edge Functions" (see PROJECT.md Key Decisions). Bot behaviors are server-side pg_cron code, not client requests. Developers discover the conflict mid-implementation and take the path of least resistance — writing direct DB mutations — without documenting the exception.

**How to avoid:**
Explicitly allow bot logic to call `SECURITY DEFINER` PostgreSQL functions directly (not Edge Functions), because bots are server-side actors and the Edge Function security boundary exists to prevent client-side cheating, not server-side automation. Document this clearly in the bot migration file header. Bot functions must still enforce the same business rules as the equivalent Edge Functions (cost checks, queue checks, RLS-equivalent ownership checks). Do NOT use `pg_net` HTTP calls from pg_cron to call Edge Functions — the latency, failure modes, and debugging difficulty are not worth it. Keep bot attack logic in `bot_dispatch_attack(p_bot_city_id, p_target_city_id)` — a `SECURITY DEFINER` function that mirrors `dispatch-units` Edge Function logic.

**Warning signs:**
- `SELECT extensions.http_post(...)` calls inside bot PL/pgSQL functions
- Bot behavior code written in a pg_cron-scheduled TypeScript Edge Function (invoked via `pg_net`) rather than a native PostgreSQL function
- No header comment in bot migration files explaining why direct DB writes are acceptable here
- Bot tests passing because they bypass the Edge Function but real users blocked because RLS applies

**Phase to address:**
Bot Infrastructure phase. Decide the architecture explicitly in the plan document before writing bot logic. Do not discover this mid-implementation.

---

### Pitfall 3: Seed Data Creates Bot Auth Users Non-Idempotently — `supabase db reset` Fails on Repeat

**What goes wrong:**
Bot accounts are seeded in `seed.sql` by inserting rows into `auth.users` and `auth.identities` with hardcoded UUIDs. The `handle_new_user` trigger fires on each `auth.users` insert and creates a profile + city. On the first `supabase db reset`, this works. On a subsequent reset (e.g., after schema changes), the seed runs again. Because `supabase db reset` re-runs all migrations first (wiping all tables) then runs `seed.sql`, the auth schema may not be fully wiped — `auth.users` rows from the previous session can persist depending on the Supabase CLI version and local docker volume state. The result is `duplicate key value violates unique constraint "users_pkey"` on every reset after the first, breaking the dev workflow.

**Why it happens:**
The existing 7 test accounts in `seed.sql` use `ON CONFLICT DO NOTHING` on `auth.users` (see line 33 of current seed.sql — `handle_new_user` fires anyway). But `auth.identities` requires its own idempotency guard. Adding 20 more bot accounts with `crypt()` password hashing and `auth.identities` inserts without conflict handling turns seed.sql into a fragile document that breaks on any second run.

**How to avoid:**
Wrap all auth user inserts in `ON CONFLICT (id) DO NOTHING`. For `auth.identities`, add `ON CONFLICT (provider_id, provider) DO NOTHING` (the unique constraint Supabase added in recent versions). Wrap all seed data in a single idempotent `DO $$ BEGIN ... END $$` block. Test idempotency explicitly: run `supabase db reset` twice back-to-back and verify the second run completes without errors. Use `INSERT INTO auth.users (...) ON CONFLICT (id) DO UPDATE SET updated_at = NOW()` rather than `DO NOTHING` for the bot accounts — this handles schema changes to the auth.users structure between resets. Check Supabase CLI version: prior to version 1.50, `supabase db reset` in local dev does wipe auth tables; later versions may not — pin the CLI version in the scripts.

**Warning signs:**
- `seed.sql` bot user inserts using bare `INSERT INTO auth.users` without `ON CONFLICT`
- `auth.identities` inserts not present in seed (trigger may not create them in newer Supabase versions)
- `supabase db reset` failing with `duplicate key` error on second run
- Seed script assumes clean-slate environment rather than idempotent upsert semantics

**Phase to address:**
Seed Data phase. Write idempotency tests for the seed script on day one. Do not ship the seed until `supabase db reset && supabase db reset` (double reset) passes cleanly.

---

### Pitfall 4: GodMode Dashboard Uses `service_role` Key Client-Side — Security Catastrophe

**What goes wrong:**
The GodMode dashboard needs to see all players' data regardless of RLS. Developers solve this by creating a second Supabase client initialized with the `service_role` key and using it in the Flutter GodMode screen. The `service_role` key bypasses RLS entirely. If the Flutter web app is bundled and served publicly (even to internal testers), the `service_role` key is visible in the browser's network tab, JavaScript bundle, or `--dart-define` values embedded in the compiled WASM. Any user who extracts the key gains full unrestricted read/write access to the entire database.

**Why it happens:**
The `service_role` key is the most direct way to bypass RLS in a Supabase project. Flutter developers unfamiliar with web security assume that `--dart-define` values are secret. They are not — they are compiled into the Dart JavaScript/WASM bundle and extractable with modest effort.

**How to avoid:**
Never embed the `service_role` key in any client-side Flutter code or `--dart-define`. GodMode data visibility must be achieved one of two ways: (A) Create a dedicated `admin` Postgres role and write RLS policies with `(auth.jwt() ->> 'role') = 'admin'` — set the admin role on the specific user accounts that need GodMode access; or (B) Create a `SECURITY DEFINER` RPC function `admin_get_world_state()` that checks `auth.uid() IN (SELECT id FROM admin_users)` before returning all-player data — this keeps RLS bypass inside the database where it belongs. The GodMode Flutter screen calls this RPC using the normal `anon` key client — the database enforces admin-only access. Do NOT use the `service_role` key in Flutter code for any reason.

**Warning signs:**
- `SupabaseClient(url, serviceRoleKey)` anywhere in Flutter Dart code
- `--dart-define=SUPABASE_SERVICE_ROLE_KEY=...` in any Flutter run script
- GodMode queries using `.rls(false)` (a Supabase client flag that requires service role)
- Any GodMode feature that works in Flutter web but exposes `eyJ...` (JWT prefix) in the browser network inspector

**Phase to address:**
GodMode Admin Dashboard phase. Define the admin access architecture (RLS policy with admin role OR SECURITY DEFINER admin RPC) before writing any GodMode Flutter widget.

---

### Pitfall 5: Bot Attack Targeting — Bots Only Attack Each Other, Never Real Players (or Always Attack Real Players)

**What goes wrong:**
Bot attack logic selects a random nearby city as target. If the selection query is `SELECT city_id FROM cities WHERE island_id != p_bot_island_id ORDER BY RANDOM() LIMIT 1`, it picks any city equally — including other bots, real players, and cities that are already under attack. The result is either: (A) all 20 bots form attack cycles between each other, never touching real players (no challenge for real players), or (B) all bots pile onto the single nearest real player city, making the game unplayable. Neither is the intended behavior.

**Why it happens:**
Uniform random selection is the simplest targeting implementation. The developer tests with only bot accounts and sees attacks happening, marks the feature "done," but the targeting is unbalanced.

**How to avoid:**
Implement a two-tiered targeting system: (1) bots prefer attacking other bots 70% of the time (maintains a living world without targeting real players too often), (2) each bot has a `bot_aggression_level` (low/medium/high) stored in a `bots` config table — high-aggression bots can target real players, low-aggression bots only target other bots. Add a cooldown: once a bot attacks a city, that `(attacker_bot_id, defender_city_id)` pair is blocked for 30 minutes via a `bot_attack_cooldowns` table. This prevents bot dogpiling. Exclude cities that already have an active incoming attack (`unit_movements` with `movement_type = 'attack'` arriving within the next 10 minutes). Test the targeting distribution by running 100 simulated bot ticks and counting real-player vs. bot targets.

**Warning signs:**
- Bot targeting is `ORDER BY RANDOM() LIMIT 1` with no player-type filter
- No cooldown mechanism between bot attacks on the same target
- No `bot_aggression_level` differentiation — all bots behave identically
- After running for 1 hour, `unit_movements` shows only bot-to-bot attacks

**Phase to address:**
Bot Behaviors phase. Targeting strategy must be defined in the phase plan before writing the attack SQL. A unit test should verify targeting distribution over N simulated runs.

---

### Pitfall 6: Unit Tests Mock Supabase Client Calls — Tests Pass But Real Function Behavior Is Untested

**What goes wrong:**
Flutter unit tests for game logic (building formulas, combat calculations, economy formulas) mock out the Supabase client at the repository layer. The mock returns hardcoded data. Tests pass with 100% coverage, but the actual `upgrade-building` Edge Function logic (cost formula, queue enforcement, resource deduction) is never tested. A bug in the cost formula in `upgrade-building/index.ts` will not be caught by any existing Flutter test. Similarly, the `process_resource_tick()` PostgreSQL function has no test coverage — only `hideout_protection_test.dart` and `building_formulas_test.dart` test pure Dart math.

**Why it happens:**
Mocking is fast and easy. Testing actual Supabase Edge Functions requires a running Supabase local instance, Deno CLI, and correct environment variables — a setup that is painful to configure for CI. Developers mock everything to make tests green quickly without validating the actual server logic.

**How to avoid:**
Separate test concerns explicitly: (A) Dart unit tests — test pure math functions (formulas, constants, models) without any Supabase dependency. These should stay mocked. (B) Edge Function integration tests — use Deno's built-in test runner with `supabase functions serve` running locally. Write one integration test per Edge Function that sends a real HTTP request and verifies the database state change. These tests require `supabase start` to be running and are tagged as integration tests, not unit tests. (C) PostgreSQL function tests — use `pgTAP` or raw SQL test scripts to test `process_resource_tick()`, `resolve_battles()`, `bot_tick()` directly with known input data. The `scripts/test_all.sh` already does `supabase db reset` which can run pgTAP tests as part of that reset. Keep CI split: fast unit tests on every commit, integration tests on PR merge.

**Warning signs:**
- `test/unit/` folder contains only formula tests and model tests; no test exercises an actual Edge Function
- `supabase/functions/tests/` directory does not exist (Supabase's recommended folder for function tests)
- `scripts/test_all.sh` does not start `supabase functions serve` before running tests
- `mock_supabase_client` covers 100% of repository calls — nothing actually calls the real Supabase

**Phase to address:**
Unit Testing phase. In the plan, explicitly list: "Flutter formula tests (mock-based)" AND "Edge Function integration tests (Deno test runner, require supabase start)" as separate deliverables with separate test commands.

---

### Pitfall 7: Deno Edge Function Tests Fail in CI — `deno` Not Installed in GitHub Actions Runner

**What goes wrong:**
Edge Function tests written with Deno's test runner run fine locally (`deno test supabase/functions/tests/`). The CI pipeline (`test_all.sh` or a GitHub Actions workflow) does not install Deno before running tests. The step fails with `deno: command not found`. The Supabase CLI's own documentation for CI/CD does not include a Deno setup step — this is a documented known gap (GitHub issue #33093). The CI pipeline reports all tests as failed even though the Dart tests passed.

**Why it happens:**
The Supabase CLI wraps Deno internally for local development but does not expose Deno on the system PATH. Developers test locally with Deno installed via their IDE plugin or direct install, but GitHub Actions Ubuntu runners do not have Deno pre-installed. The `test_all.sh` script only runs `flutter test` — it does not include a Deno test step.

**How to avoid:**
Add a dedicated Deno install step to any CI pipeline that runs Edge Function tests. For GitHub Actions, use `uses: denoland/setup-deno@v2` with a pinned version. For `test_all.sh`, add a check: `if command -v deno &> /dev/null; then deno test ...; else echo "SKIP: deno not installed"; fi`. On Windows dev machines, install Deno via `winget install DenoLand.Deno` and document this in the project README under "Developer Setup." Pin the Deno version in `scripts/test_all.sh` — `DENO_VERSION=2.x.x` — to prevent silent breakage when Deno updates its module resolution.

**Warning signs:**
- `supabase/functions/tests/` folder exists but `scripts/test_all.sh` has no `deno test` line
- GitHub Actions workflow does not include `uses: denoland/setup-deno@v2`
- CI logs show "flutter test" passing but no output for Edge Function tests (silently skipped, not failed)
- Local dev works because developer has Deno installed globally; CI runner does not

**Phase to address:**
CI/CD Automation phase. Add Deno setup to CI before writing any Edge Function tests. If CI is set up first, Deno tests will fail loudly rather than silently skipping.

---

### Pitfall 8: Bot State Is Inconsistent After `supabase db reset` — Bots Have No Resources or Wrong Building Levels

**What goes wrong:**
Seed data inserts 20 bot accounts into `auth.users`. The `handle_new_user` trigger fires and creates each bot's city with the default starting state (100 population, level-1 buildings, 2500 wood, 1000 marble, etc.). This produces 20 bot cities that are identical newborn states. When the bot tick fires, all 20 bots have the same resources, same buildings, same army — they all try to do the same action. The "diverse game states" requirement from PROJECT.md is not met. Worse, if the seed is re-run (after a db reset during development), the trigger fires again but the city already exists — creating duplicate cities for the same user, or failing with a unique constraint error if city placement is slot-based.

**Why it happens:**
The `handle_new_user` trigger is designed for real user onboarding — it auto-places the city on the first available island slot. Adding 20 accounts at once via seed can exhaust island slots on small test islands, place bots in non-deterministic positions, and produce uniform starting states that make the test world boring and unrealistic.

**How to avoid:**
Do NOT rely on `handle_new_user` to set up bot cities. Instead, after inserting bot accounts, run a second seed block that directly sets each bot city to a pre-designed state: different building levels (some bots mid-game, some advanced), different army compositions, different resource quantities. Use named SQL blocks with explicit `UPDATE` statements per bot city. Assign bots to specific island positions using hardcoded grid coordinates to ensure deterministic placement. Set `ON CONFLICT DO NOTHING` on the trigger-created city then `UPDATE cities SET population = ..., wine_spending_rate = ... WHERE owner_id = ...` to reach the desired state. This decouples the trigger (which must work for real users) from the seed's desired bot diversity.

**Warning signs:**
- `seed.sql` inserts bot accounts but has no follow-up `UPDATE` statements customizing their city state
- All 20 bots start with identical resources and building levels
- After `supabase db reset`, bot cities land on random island positions (non-deterministic)
- Seed fails with "no island slots available" after running more than 16 bot inserts on a single island

**Phase to address:**
Seed Data phase. The diversity design (which bots get which buildings/army/resources) must be written as explicit seed SQL, not left to trigger defaults.

---

### Pitfall 9: GodMode Controls Modify Live Bot State While `bot_tick()` Is Mid-Execution — Partial Update Window

**What goes wrong:**
A GodMode "pause all bots" action sets `game_config.bots_enabled = false`. Meanwhile, `bot_tick()` is currently executing (it runs for 500ms–2 seconds processing 20 bots). The bot_tick function reads `bots_enabled` once at the start of its function body. If the GodMode update commits between bot_tick's initial read and its last bot action, bot_tick has already started attacking for some bots — the pause takes effect only from the next invocation. The GodMode user sees bots as "paused" (the config flag is false) but sees new attack movements appearing in the movement log because the current tick is still running.

**Why it happens:**
The `bots_enabled` flag is read as a simple `SELECT` at the top of `bot_tick()`. The function then processes bots in a loop. The flag state is not re-checked per bot. This is a natural design but creates a partial-tick window where half the bots acted and half did not.

**How to avoid:**
Read the `bots_enabled` flag inside a `SELECT ... FOR SHARE` at the start of `bot_tick()`. The GodMode pause RPC should use `SELECT ... FOR UPDATE` on the `game_config` row and wait for any running bot tick to release its share lock before committing the pause. This ensures either: (A) the tick acquires the SHARE lock before the pause commits — the full tick runs, THEN bots are paused, OR (B) the pause commits its UPDATE before the tick acquires the SHARE lock — the tick sees `bots_enabled = false` and exits immediately. No partial execution. Additionally, log each bot action to a `bot_action_log` table — the GodMode dashboard can show what the last tick did even after pausing, giving the admin a full audit trail.

**Warning signs:**
- `bot_tick()` reads `bots_enabled` with a plain `SELECT` (no locking)
- GodMode pause updates `game_config` with a plain `UPDATE` (no row lock)
- After clicking "Pause Bots," new unit movements appear in the GodMode map for 1-2 seconds before stopping
- No `bot_action_log` table to audit what bots did during a tick

**Phase to address:**
GodMode Controls phase (must coordinate with Bot Infrastructure phase to add locking to `bot_tick()`).

---

### Pitfall 10: Riverpod Providers Not Isolated in Widget Tests — Global State Leaks Between Tests

**What goes wrong:**
Widget tests for GodMode screens (or any screen using Riverpod providers) share a `ProviderContainer` or use a `ProviderScope` without overrides. If one test modifies provider state (e.g., simulates a bot pause), the state leaks into the next test's `ProviderScope`. Tests pass in isolation (run individually) but fail when run as a suite (`flutter test --reporter expanded`). This causes intermittent CI failures that are hard to debug because the failure only appears when tests run in a specific order.

**Why it happens:**
The current `test_helpers.dart` only provides `createTestApp(Widget)` and `createScaffoldApp(Widget)` — there is no `createProviderScope(Widget, {overrides})` helper yet (the commented-out code in test_helpers.dart confirms this). Developers writing GodMode widget tests use raw `ProviderScope(child: ...)` without per-test overrides, allowing providers to accumulate state from previous test runs in the same Flutter test binary session.

**How to avoid:**
Implement the commented-out `createTestProviderScope` helper in `test/helpers/test_helpers.dart` now. Every widget test that uses Riverpod must use this helper with explicit provider overrides. Never use a module-level `ProviderContainer` shared across test functions — always create a new container per test. For the GodMode provider (which reads all-player data), create a `FakeAdminRepository` that returns deterministic test data and override the admin provider in every GodMode test. Add a lint rule: `prefer_const_constructors` and `avoid_relative_lib_imports` — these catch common test isolation mistakes.

**Warning signs:**
- `test/helpers/test_helpers.dart` does not have a `createProviderScope` or `createContainerWithOverrides` helper
- Widget tests use `tester.pumpWidget(ProviderScope(child: TestedWidget()))` without `overrides:`
- Tests pass when run individually with `flutter test test/widget/godmode_screen_test.dart` but fail when run with `flutter test`
- GodMode tests directly depend on a live Supabase connection (not mocked)

**Phase to address:**
Unit Testing phase — before writing any GodMode widget tests. Implement `createProviderScope` helper as the first task in the testing phase.

---

### Pitfall 11: CI Script Is Windows-Path-Aware Locally But Fails on Linux CI Runner

**What goes wrong:**
The existing scripts (`run_local.sh`, `test_all.sh`) use `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` which works correctly in bash on Windows (Git Bash / WSL) and Linux. However, if any CI script uses Windows-specific paths (backslashes, `%APPDATA%`, `NUL` instead of `/dev/null`), it fails on the GitHub Actions Ubuntu runner. The `.ps1` scripts (`run_local.ps1`, `test_all.ps1`) are Windows-only and cannot run in GitHub Actions without `windows-latest` runner. Mixing `.ps1` and `.sh` scripts for the same task creates maintenance burden — changes must be made in two places.

**Why it happens:**
Development is on Windows 11. The developer writes `.ps1` scripts because they run natively in PowerShell and also writes `.sh` scripts for compatibility. CI uses Linux. Small path or command differences between PowerShell and bash accumulate over time. A command that works in `run_local.ps1` is assumed to work in `test_all.sh` but uses a Windows-specific pattern.

**How to avoid:**
Make `.sh` scripts the canonical scripts for all CI operations. The `.ps1` scripts are developer-convenience wrappers only. CI workflows must use only `.sh` scripts on `ubuntu-latest` runners. In `.sh` scripts, never use Windows path patterns. When calling `npx supabase`, pin the version in `package.json` (add `"supabase": "x.y.z"` to devDependencies) so `npx supabase` resolves to the same version locally and in CI. For the new `seed.sh`, `reset_db.sh` automation scripts, test them in a fresh WSL Ubuntu session before committing — this catches any hidden Windows-isms. Add a one-line header comment to each `.sh` file: `# CI canonical — runs on ubuntu-latest GitHub Actions runner`.

**Warning signs:**
- `.ps1` and `.sh` scripts duplicating the same logic with different commands
- Any `.sh` script using `\\` path separators, `NUL`, `%APPDATA%`, or `cmd.exe`-style syntax
- `scripts/test_all.sh` never actually run on a Linux machine by the developer before committing
- CI failure message: `npx: command not found` or `flutter: command not found` due to PATH differences between Windows dev and Linux CI

**Phase to address:**
CI/CD Automation phase. All new `.sh` scripts must pass a `shellcheck` lint before being committed.

---

### Pitfall 12: Realtime Fan-Out Overload From Bot State Changes — Existing Concern Made Worse

**What goes wrong:**
This project has an existing known concern: "cities Realtime fan-out at scale" (PROJECT.md tech debt). The resource tick already updates `cities` table rows every 5 minutes, triggering Realtime broadcasts to all subscribed clients. Adding 20 bot cities means 20 additional `cities` row updates every 5 minutes from the resource tick alone. Each bot attack also creates rows in `unit_movements`, triggering Realtime events for all subscribers watching the world map. If the GodMode dashboard subscribes to ALL movements and ALL city changes simultaneously (to show the "living world"), it will receive a burst of 20+ Realtime events every 5 minutes. On Supabase free tier, the limit is 100 messages/second. On Pro, 500/second. A batch of 20 simultaneous `cities` updates from one tick invocation may hit this limit during the tick's execution window.

**Why it happens:**
The resource tick function updates `cities` rows inside a loop — each `UPDATE cities SET population = ... WHERE id = ...` is a separate DML statement that triggers a separate Realtime CDC event. Twenty bots means 20 additional CDC events per 5-minute tick. The GodMode dashboard, designed to see everything in real-time, amplifies this by subscribing to broad channels.

**How to avoid:**
Do not subscribe the GodMode dashboard to raw table change events for `cities` or `unit_movements`. Instead, poll a `SECURITY DEFINER` RPC `admin_world_snapshot()` every 30 seconds — it returns a JSON snapshot of all relevant state in one query. Use Supabase Realtime only for high-value events (new battles, battle outcomes) not for resource tick state. For the resource tick, consider batching all city updates into a single `UPDATE cities SET ... FROM (VALUES ...) AS v WHERE cities.id = v.id` statement — one Realtime CDC event instead of N. This optimization is also valuable for real players beyond bots.

**Warning signs:**
- GodMode dashboard uses `supabase.from('cities').on('UPDATE', ...)` to watch all city changes
- GodMode dashboard uses `supabase.from('unit_movements').on('INSERT', ...)` to watch all movements
- `process_resource_tick()` uses a per-city loop with individual `UPDATE` statements (each triggers CDC)
- After adding bots, the resource tick duration in `cron.job_run_details` increases from ~200ms to >2s

**Phase to address:**
GodMode Admin Dashboard phase — design the dashboard as a polling + targeted events dashboard from the start, not a full Realtime subscription dashboard.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Bot behaviors as 3+ separate pg_cron jobs | Each behavior is independently schedulable | Worker pool exhaustion; existing ticks start failing silently when max_running_jobs exceeded | Never — consolidate into one `bot_tick()` |
| GodMode uses service_role key in Flutter client | Immediate RLS bypass without additional backend code | Service role key exposed in browser bundle; total database compromise | Never — use SECURITY DEFINER RPC with admin role check |
| Seed bot accounts rely on `handle_new_user` trigger for city setup | No extra seed SQL needed | All bots start identical (no diverse states); non-deterministic island placement; trigger conflict on double-reset | Never for diversity requirement — trigger is fine for account creation only |
| Edge Function integration tests skipped (mock everything) | Tests run fast without Supabase running | Real function bugs never caught; cost formula drift between Edge Function and Flutter client | OK for pure formula unit tests; never acceptable for Edge Function behavior tests |
| `supabase db reset` without idempotency guard on seed | Simpler seed SQL | Fails on second reset with duplicate key errors; breaks dev workflow | Never — all seed inserts must have `ON CONFLICT` handling |
| Bot attack targeting is `ORDER BY RANDOM()` with no filters | Simple to implement | All bots attack same target or cycle only among themselves; unplayable for real players | OK for first-pass smoke test; never for shipped feature |
| GodMode subscribes to all Realtime table events | Simple to implement | Message rate limit hit from 20-bot world; GodMode dashboard disconnected by Supabase during active ticks | Never — use polling + targeted events |
| Windows `.ps1` scripts as CI scripts | Works locally on Windows | Fails on GitHub Actions ubuntu-latest; two codebases to maintain | OK as developer shortcuts; never as CI canonical scripts |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| pg_cron + bot behaviors | Multiple bot-specific cron jobs at `* * * * *` conflict with existing game ticks | One `bot_tick()` at `*/5 * * * *` with internal dispatch loop |
| Supabase Auth + seed bot accounts | Direct `auth.users` insert without `auth.identities` row | Always insert matching `auth.identities` row; add `ON CONFLICT DO NOTHING` on both |
| Flutter Riverpod + widget tests | Shared `ProviderContainer` across tests leaks state | New `ProviderContainer` with `overrides:` per test; use `createProviderScope` helper |
| Deno test runner + CI | `deno test` assumes `deno` is on PATH; GitHub Actions runners do not have Deno | Add `uses: denoland/setup-deno@v2` step before any Deno test command |
| GodMode dashboard + Supabase RLS | Using `service_role` key in Flutter to bypass RLS | Use `SECURITY DEFINER` RPC with admin-role check; never embed service_role in client code |
| Supabase Realtime + 20 bot city updates | Per-row UPDATE in tick loop triggers 20 Realtime CDC events per tick | Batch UPDATE with VALUES list or poll admin RPC instead of subscribing to raw table events |
| `supabase db reset` + seeded auth users | `handle_new_user` trigger fires during reset for pre-seeded bots creating duplicate cities | Follow-up UPDATE city state after trigger; do not rely on trigger defaults for diverse state |
| GitHub Actions + Flutter web build | Flutter web build fails if `SUPABASE_URL` or `SUPABASE_ANON_KEY` dart-defines not set in CI env | Add these as GitHub Actions secrets and pass with `--dart-define` in CI build step |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Bot tick scans all cities per behavior (no bot-type filter) | `bot_tick()` execution time grows linearly with total city count | Add `is_bot = true` column to `profiles` or a dedicated `bots` table; always filter by bot flag | 50+ total cities (bots + real players) |
| GodMode dashboard `SELECT *` from cities, movements, battles with no pagination | Admin dashboard load time grows with world data volume | Use `LIMIT` + cursor pagination in admin RPCs; GodMode shows last 24h data by default | 100+ movements in transit simultaneously |
| `bot_tick()` does full army count query per bot to decide attack eligibility | N+1 query: 20 bots = 20 separate `SELECT SUM(quantity) FROM city_units WHERE city_id = ?` | Batch query: `SELECT city_id, SUM(quantity) FROM city_units WHERE city_id = ANY(bot_city_ids) GROUP BY city_id` | 20+ bot cities (N+1 is already noticeable) |
| Seed script inserts 20 bots + their city data in sequential statements | `supabase db reset` takes 30+ seconds due to sequential inserts triggering triggers 20 times | Batch insert auth users; use `SET session_replication_role = 'replica'` to disable triggers during bulk seed, then re-enable | Always — even at 20 bots, sequential trigger-per-row adds 5-10 seconds to reset time |
| Flutter widget test `pump` without `pumpAndSettle` on async providers | Tests pass locally but fail in CI with tighter timeouts | Always use `pumpAndSettle(timeout: Duration(seconds: 5))` when testing widgets with async Riverpod providers | Any async provider that takes >16ms to resolve |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| `service_role` key in Flutter code for GodMode | Total database access for anyone who extracts the bundle | Use SECURITY DEFINER RPC with admin role check; never embed service_role in client |
| GodMode "force attack" control calls bot attack function without ownership check | Any admin can trigger attacks from non-bot cities; game state corruption | GodMode force-action RPCs must verify `p_city_id` is owned by a bot account (`is_bot = true`) before executing |
| Bot accounts have real passwords in seed.sql committed to git | Leaked test credentials; if bots share a password pattern with real users, it signals password weakness | Use random UUIDs as bot passwords (not human-memorable strings); bots never login interactively so password strength is irrelevant |
| `admin_get_world_state()` SECURITY DEFINER function has no admin check | Any authenticated user can call it via RPC and see all other players' resources/armies | Always check `auth.uid() IN (SELECT user_id FROM admin_users)` as the first statement in any SECURITY DEFINER admin function |
| Dev-only functions (`dev_bulk_spawn_units`, `dev_instant_complete`) deployed to production Supabase | Anyone can spawn unlimited units or instantly complete all queues | Guard with `IF current_setting('app.environment', true) != 'development' THEN RAISE EXCEPTION 'dev only'; END IF;` or remove migration before production deploy |
| CI pipeline logs print `SUPABASE_ANON_KEY` or `SUPABASE_SERVICE_ROLE_KEY` in build output | Keys exposed in public CI logs | Use `::add-mask::` in GitHub Actions for all secret values; never echo key values in scripts |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| GodMode shows raw UUIDs for player/city identification | Admin cannot quickly identify which entity is which | Display `profile.display_name` + `city.name` alongside UUIDs in all GodMode views |
| Bot icons in world map look identical to real player icons | Players cannot distinguish active bots from real opponents; changes player strategy | Add a subtle bot indicator (small gear icon or "CPU" badge) visible only to admin in GodMode; real players see bots as normal players |
| GodMode "pause bots" gives no visual feedback on current tick progress | Admin clicks pause but bots keep attacking for up to 1 minute; admin thinks the button broke | Show "pausing after current tick..." state with a spinner; update to "paused" only after `bot_tick()` releases its lock |
| Seed data bot cities named `bot_1`, `bot_2` ... `bot_20` | Real players immediately identify and ignore bot cities; reduces immersion | Name bots with historically-themed names (Sparta, Athens, Corinth...); randomize resource levels so bot cities feel like real player cities |
| CI failure message is raw `flutter test` output with no summary | Developer must scroll through 200 lines to find which test failed | Add a test result summary section to `test_all.sh` output: "X passed, Y failed" with failed test names listed at the end |

---

## "Looks Done But Isn't" Checklist

- [ ] **Bot tick registered:** `SELECT cron.schedule('bot-tick', ...)` exists in migration — verify `SELECT * FROM cron.job WHERE jobname = 'bot-tick'` returns one row after `supabase db reset`.
- [ ] **Bot diversity:** 20 bot accounts seeded — verify that at least 3 different building level profiles exist across bots (low/mid/high) by querying `SELECT AVG(level) FROM city_buildings WHERE city_id IN (SELECT id FROM cities WHERE owner_id IN (SELECT id FROM profiles WHERE is_bot = true))`.
- [ ] **GodMode security:** GodMode screen loads data — verify the feature works when logged in as a non-admin user and returns 403/empty (not all-player data); confirm no `service_role` key in Flutter source.
- [ ] **Seed idempotency:** `supabase db reset` runs successfully — verify it also runs a SECOND time (`supabase db reset && supabase db reset`) without any `duplicate key` errors.
- [ ] **Flutter unit tests:** `flutter test` reports passing — verify at least one test in `test/unit/` tests the actual formula used in the Edge Function (not just the Dart constant), confirming parity between client and server.
- [ ] **Edge Function tests exist:** `supabase/functions/tests/` directory exists — verify at least `upgrade-building-test.ts` and one bot-related test file are present and run with `deno test`.
- [ ] **CI pipeline runs end-to-end:** `scripts/test_all.sh` is committed — verify it actually runs on a clean Linux environment (WSL or GitHub Actions) without `deno: command not found` or `flutter: command not found` errors.
- [ ] **Bots pause control works:** GodMode "pause bots" button is visible — verify that after clicking pause, no new rows appear in `unit_movements` with `is_bot_action = true` within the next 5 minutes.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Multiple bot cron jobs cause existing ticks to fail | HIGH | `SELECT cron.unschedule('bot-attack-tick'); SELECT cron.unschedule('bot-train-tick');` — remove individual bot jobs, create single `bot_tick()`; monitor `cron.job_run_details` for recovery |
| Service role key exposed in client bundle | CRITICAL | Rotate service role key immediately in Supabase dashboard; audit access logs for unauthorized calls; rebuild and redeploy Flutter app without the key; audit git history and rewrite if key was committed |
| Seed double-reset fails with duplicate key | LOW | Add `ON CONFLICT DO NOTHING` to all auth.users and auth.identities inserts; run `supabase db reset` again |
| GodMode admin RPC accessible by non-admin users | HIGH | Add `IF auth.uid() NOT IN (SELECT user_id FROM admin_users) THEN RAISE EXCEPTION 'unauthorized'; END IF;` to the RPC; run security audit on all SECURITY DEFINER functions |
| Bot attacks only bot accounts (never real players) | MEDIUM | Update `bot_select_target()` to apply player-type weighting; no schema changes needed; new migration adding targeting logic |
| Widget tests failing in CI due to shared provider state | MEDIUM | Add `overrides:` to all `ProviderScope` usages in tests; run `flutter test --concurrency=1` as temporary workaround while fixing isolation |
| Deno tests not running in CI | LOW | Add `uses: denoland/setup-deno@v2` to GitHub Actions workflow; add `deno test supabase/functions/tests/` to `test_all.sh` |
| Bot cities all identical state after seed | MEDIUM | Write follow-up migration `supabase/migrations/YYYYMMDD_bot_diversity_state.sql` that UPDATEs each bot city to its designed state; re-run `supabase db reset` |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Bot cron job pile-up | Bot Infrastructure (first bot phase) | `SELECT COUNT(*) FROM cron.job` — should increase by exactly 1 after bot phase |
| Bot RLS vs. SECURITY DEFINER architecture | Bot Infrastructure | Code review: grep for `http_post` inside bot PL/pgSQL; should return zero results |
| Seed idempotency failure | Seed Data phase | Run `supabase db reset && supabase db reset`; second reset must exit 0 |
| GodMode service_role in client | GodMode Dashboard phase | grep Dart code for `serviceRoleKey`; must return zero results |
| Bot targeting imbalance | Bot Behaviors phase | Simulate 100 bot tick runs; verify >30% of attacks target non-bot cities |
| Flutter test mocking hides real bugs | Unit Testing phase | `supabase/functions/tests/` must contain at least one integration test per Edge Function |
| Deno not in CI | CI/CD Automation phase | GitHub Actions workflow `deno --version` step must succeed |
| Bot state inconsistency after seed | Seed Data phase | Query avg building level per bot after reset; must show 3+ distinct levels |
| GodMode pause partial-tick window | GodMode Controls phase | Click pause; verify no new movements appear after confirmed pause state |
| Riverpod test isolation | Unit Testing phase | Run `flutter test` 3x in a row; all 3 runs must produce identical pass/fail results |
| CI script Linux/Windows incompatibility | CI/CD Automation phase | Run `bash scripts/test_all.sh` in WSL (Ubuntu) environment; must pass |
| Realtime overload from bot updates | GodMode Dashboard phase | Monitor Realtime message rate in Supabase dashboard during a resource tick with bots active |

---

## Sources

- [Supabase pg_cron Debugging Guide](https://supabase.com/docs/guides/troubleshooting/pgcron-debugging-guide-n1KTaz) — job overlap, max_running_jobs, silent failure detection
- [pg_cron GitHub Issue #63: hangs when max_running_jobs exceeded](https://github.com/citusdata/pg_cron/issues/63) — confirmed bug in state machine for job queuing
- [Supabase Edge Function Unit Testing Docs](https://supabase.com/docs/guides/functions/unit-test) — recommended folder structure, Deno test runner setup
- [GitHub Issue #33093: CI docs for Edge Functions missing Deno setup step](https://github.com/supabase/supabase/issues/33093) — confirmed documentation gap for CI Deno installation
- [Supabase GitHub Discussion #9251: Can't seed or signup auth users locally](https://github.com/orgs/supabase/discussions/9251) — auth.identities provider_id requirement in newer versions
- [Supabase GitHub Issue #1420: custom triggers on db reset causing duplicate keys](https://github.com/supabase/cli/issues/1420) — trigger-during-seed pitfall with `handle_new_user`
- [Riverpod Testing Docs](https://riverpod.dev/docs/how_to/testing) — ProviderContainer isolation, DO NOT share containers, auto-disposal during tests
- [Supabase RLS Troubleshooting: Why service_role key is not working](https://supabase.com/docs/guides/troubleshooting/why-is-my-service-role-key-client-getting-rls-errors-or-not-returning-data-7_1K9z) — Authorization header vs. apikey header confusion
- [How to Secure Supabase Service Role Key (Chat2DB)](https://chat2db.ai/resources/blog/secure-supabase-role-key) — never embed service_role in client code
- [Supabase Realtime Limits](https://supabase.com/docs/guides/realtime/limits) — message rate limits per plan tier (100/sec free, 500/sec pro)
- [Supabase Realtime Architecture Docs](https://supabase.com/docs/guides/realtime/architecture) — single-thread processing for Postgres Changes; RLS policy complexity impact on first-message latency
- [Deploying Supabase Migrations with GitHub Actions (Finalist Tech Blog)](https://techblog.finalist.nl/blog/deploying-supabase-migrations-github-actions) — CI workflow patterns; `db diff` reliability caveats
- [Neon Blog: How to Maintain Seed Files](https://neon.com/blog/how-to-maintain-seed-data) — factory approach vs. static seed files; CI-verified seed maintenance
- Personal project context — `supabase/seed.sql`, `scripts/test_all.sh`, `supabase/migrations/20260316000001_dev_bulk_spawn_and_instant_complete.sql`, `test/helpers/test_helpers.dart`

---
*Pitfalls research for: Ikariam-style browser strategy game — v1.3 Bot Players, GodMode Admin, Seed Data, Unit Tests, CI/CD (adding to existing v1.2 system)*
*Stack: Flutter web + Supabase + pg_cron + Riverpod (manual providers)*
*Researched: 2026-03-17*
