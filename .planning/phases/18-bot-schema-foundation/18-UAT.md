---
status: partial
phase: v1.3-milestone (phases 18-24)
source: 18-01-SUMMARY.md, 19-01-SUMMARY.md, 19-02-SUMMARY.md, 20-01-SUMMARY.md, 21-01-SUMMARY.md, 22-01-SUMMARY.md, 22-02-SUMMARY.md, 23-01-SUMMARY.md, 23-02-SUMMARY.md, 24-01-SUMMARY.md, 24-02-SUMMARY.md
started: 2026-03-19T00:00:00Z
updated: 2026-06-05T00:00:00Z
---

## Current Test
<!-- OVERWRITE each test - shows where we are -->

number: 17
name: Deno Unit Tests Pass
expected: Run `deno test supabase/functions/tests/` — all 14 tests pass.
result: [passed] — 14/14 passed (131ms)

## Tests

### 1. Cold Start Smoke Test
expected: Kill any running Supabase services. Run `supabase db reset` (applies all migrations + seed.sql). Start Edge Functions with `supabase functions serve`. The reset completes without errors, all migrations apply cleanly (including bot schema, bot functions, godmode RPCs, admin_set_army, RPC return type fix), and seed.sql inserts 7 human accounts + 20 bot accounts without constraint violations.
result: [skipped] — requires local Supabase environment

### 2. Bot Profiles Exist in Database
expected: Query `SELECT id, display_name, is_bot, is_admin FROM profiles WHERE is_bot = true` — returns exactly 20 rows with Greek hero names (Achilles, Hector, Odysseus, etc.). All have is_bot=true. None have is_admin=true.
result: [skipped] — requires local Supabase environment

### 3. Existing Player Profiles Unaffected
expected: Query `SELECT id, display_name, is_bot, is_admin FROM profiles WHERE is_bot = false` — returns the 7 human test accounts. is_bot=false and is_admin=false for all except Leonidas who has is_admin=true.
result: [skipped] — requires local Supabase environment

### 4. Bot Schedules Table Populated
expected: Query `SELECT * FROM bot_schedules` — returns 20 rows. Each has a bot_id matching a bot profile, aggression between 0-3, is_paused=false, and a next_action_at timestamp. Aggression distribution: 5 bots at 0, 5 at 1, 5 at 2, 5 at 3.
result: [skipped] — requires local Supabase environment

### 5. Bot Tier Diversity (Resources & Army)
expected: Check bot game states via SQL. Low-tier bots (1-7) have resources 500-1500 and only hoplite+cook units. Mid-tier (8-14) have resources 2000-5000 and additional unit types. High-tier (15-20) have resources 5000-15000 and full unit variety including catapult/mortar.
result: [skipped] — requires local Supabase environment

### 6. Bot RLS Deny-All for Clients
expected: From a non-admin authenticated client (e.g., Supabase JS client as a regular player), attempt `SELECT * FROM bot_schedules` — returns 0 rows (RLS deny-all). Attempt to UPDATE a bot profile's is_bot column — fails (column-level REVOKE).
result: [skipped] — requires local Supabase environment

### 7. Bot Cron Job Active
expected: Query `SELECT * FROM cron.job WHERE jobname = 'bot-think-tick'` — returns one row with schedule `*/15 * * * *` and command `SELECT public.run_bot_decisions()`.
result: [skipped] — requires local Supabase environment

### 8. Bot Decision Engine Executes
expected: Manually run `SELECT public.run_bot_decisions()` in SQL. Check that bot_schedules.next_action_at has been updated for eligible bots (those where next_action_at was in the past). Check construction_queue, training_queue, or unit_movements for new bot entries.
result: [skipped] — requires local Supabase environment

### 9. GodMode Route Guard
expected: Log in as a non-admin player in the Flutter app. Navigate to /godmode URL directly. You are redirected to /map (not shown the GodMode dashboard). Log in as Leonidas (admin). Navigate to /godmode — the GodMode dashboard loads.
result: [skipped] — requires running Flutter app

### 10. GodMode Dashboard - Players Tab
expected: On the GodMode dashboard (logged in as Leonidas), the Players tab shows a sortable table with all players (human + bot). Bot players have an orange "BOT" badge. Columns include name, resources, land army, naval, buildings, battles. Clicking column headers sorts the table.
result: [skipped] — requires running Flutter app

### 11. GodMode Dashboard - Bot Controls
expected: On a bot player row, there are pause/play, force action, and edit buttons. Click pause on a bot — the bot's is_paused becomes true (verify in DB or UI refresh). Click force action — a confirmation dialog appears; confirming it triggers the bot priority chain (check construction_queue or training_queue for new entry). Click play to resume.
result: [skipped] — requires running Flutter app

### 12. GodMode Dashboard - Inline Resource Editing
expected: Click the edit button on a player row. Resource fields become editable TextFields. Enter new values (e.g., wood=99999). Save. Query the database — city_resources for that player reflect the new values.
result: [skipped] — requires running Flutter app

### 13. GodMode Dashboard - Army Editing
expected: In edit mode on a player row, army unit fields appear with 0 pre-filled. Enter values (e.g., hoplite=100). Save. Query city_units — the player now has 100 hoplites.
result: [skipped] — requires running Flutter app

### 14. GodMode Dashboard - Bulk Bot Controls
expected: Click "Pause All Bots" button. All bot rows show paused state. A SnackBar confirms the count. Click "Resume All Bots" — all bots resume. SnackBar confirms.
result: [skipped] — requires running Flutter app

### 15. GodMode Dashboard - Events Tab
expected: Switch to the Events tab. An event feed shows recent battles, trades, and spy reports. Filter chips (All/Battle/Trade/Espionage) filter the list. Selecting "Battle" shows only battle events.
result: [skipped] — requires running Flutter app

### 16. GodMode Dashboard - Live Refresh
expected: The AppBar shows a live elapsed timer ("Xs ago") that counts up. Every 30 seconds, data auto-refreshes (spinner appears briefly in AppBar during refresh). New bot actions appear in the events feed after refresh.
result: [skipped] — requires running Flutter app

### 17. Deno Unit Tests Pass
expected: Run `deno test supabase/functions/tests/` — all 14 tests pass (7 upgrade-building formula tests + 7 train-units formula tests). Exit code 0.
result: [passed] — 14/14 passed (131ms)

### 18. Flutter Unit Tests Pass
expected: Run `flutter test test/unit/` — profile bot fields tests pass (8 tests for isBot/isAdmin getters). Run `flutter test test/widget/godmode/` — all 24 GodMode widget tests pass. Total `flutter test` exits 0.
result: [passed] — unit: 96 passed, 30 skipped (Wave 0 stubs); widget/godmode: 24/24 passed

### 19. Dev Setup Script
expected: Run `scripts/dev_setup.ps1` (or .sh on Linux). It checks prerequisites (flutter, deno, npx), runs db reset, starts Edge Functions serve in background, and builds Flutter web. All steps complete without errors.
result: [skipped] — script exists (dev_setup.ps1 / dev_setup.sh); requires local Supabase environment to run

### 20. Test Runner Script
expected: Run `scripts/test_all.ps1` (or .sh). It runs 3 steps: [1/3] db reset, [2/3] deno test, [3/3] flutter test. All steps pass. Exit code 0.
result: [skipped] — script exists (test_all.ps1 / test_all.sh); requires local Supabase environment to run

### 21. CI Workflow File Exists
expected: File `.github/workflows/ci.yml` exists with triggers on push to main and pull_request to main. Steps include: checkout, flutter setup, deno setup (v2.2.x pinned), pub get, flutter analyze, deno test, flutter test, flutter build web.
result: [passed] — CI workflow exists at `.gitea/workflows/ci.yml` (project uses Gitea, not GitHub). Triggers: push/PR to main. Steps include checkout, flutter setup, deno setup, pub get, flutter analyze, deno test, flutter test, flutter build web + deploy.

## Summary

total: 21
passed: 3
issues: 0
pending: 0
skipped: 18
blocked_reason: Tests 1-16, 19-20 require local Supabase environment (supabase start + db reset)

## Gaps

- Tests 1-16: Require local Supabase dev environment — deferred to manual testing session
- Tests 19-20: Scripts exist but require live Supabase to verify end-to-end
