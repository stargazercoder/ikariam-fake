# Pitfalls Research

**Domain:** Browser-based multiplayer city-building / strategy game (Ikariam-style)
**Stack:** Flutter + Flame (web), Supabase (Auth/DB/Realtime/Edge Functions), pg_cron, Riverpod
**Researched:** 2026-03-11
**Confidence:** HIGH (stack-specific issues verified via official docs and GitHub issues); MEDIUM (design/balance issues from community sources)

---

## Critical Pitfalls

### Pitfall 1: Client-Side Resource Calculation

**What goes wrong:**
Developers calculate resource amounts or building costs in Flutter and send the result to Supabase. A player modifies the request (via DevTools, proxying, or script injection) and gives themselves unlimited resources or skips upgrade costs entirely.

**Why it happens:**
Flutter/Flame state feels "server-like" because Riverpod caches server data. It is tempting to compute `current_wood + production_rate * elapsed_seconds` on the client and PATCH the row. This is fast to develop but fatally insecure.

**How to avoid:**
All writes that mutate resource/building state must go through a Supabase Edge Function or a PostgreSQL function (security definer). The function re-reads the last tick timestamp, recalculates production server-side using `NOW()`, applies the delta, and writes the result atomically. The client never sends a computed quantity — it sends only an intent: `{ action: "upgrade_building", building_id: "..." }`. The server validates affordability, deducts cost, and queues the upgrade.

**Warning signs:**
- Any Supabase `UPDATE resources SET wood = $clientValue` from the Flutter client layer
- Direct `.update()` calls on resource/building tables from the frontend
- Riverpod notifiers that compute balances and write them back to Supabase

**Phase to address:**
Foundation phase (auth + schema + first resource tick). Establish the server-authority pattern before any feature is built on top of it.

---

### Pitfall 2: pg_cron + Edge Function 5-Second UI Timeout

**What goes wrong:**
When scheduling an Edge Function via Supabase's Cron UI, the HTTP timeout defaults to 5000ms. A game tick that processes all active players' resource production will exceed 5 seconds as the player count grows — causing silent failures where some players' resources are never updated.

**Why it happens:**
The 5000ms limit is a Supabase Cron UI decision (not an inherent pg_net or pg_cron limit). Developers use the UI to set up the cron job and do not realize there is a lower timeout cap applied than the Edge Function's own 150-second wall-clock limit.

**How to avoid:**
Create the cron job directly via SQL using `pg_net.http_post()` with an explicit `timeout_milliseconds` parameter instead of using the Supabase dashboard Cron UI. Example:

```sql
SELECT cron.schedule(
  'resource-tick',
  '*/5 * * * *',
  $$
    SELECT net.http_post(
      url := 'https://<project>.supabase.co/functions/v1/resource-tick',
      headers := '{"Authorization": "Bearer <service_role_key>"}'::jsonb,
      timeout_milliseconds := 30000
    );
  $$
);
```

Additionally, design the tick function to batch-process players (chunked queries with LIMIT/OFFSET or cursor-based pagination) so a single invocation never needs more than a few seconds even at scale.

**Warning signs:**
- Cron job created through the Supabase dashboard UI (not raw SQL)
- Edge Function executes a single `UPDATE resources SET ...` across all players without batching
- pg_cron job history shows frequent failures or no rows updated after a certain player count

**Phase to address:**
Resource production phase. Before shipping, test tick with 100 simulated rows and measure execution time.

---

### Pitfall 3: Race Conditions on Resource Spend (Double-Spend)

**What goes wrong:**
A player rapidly sends two "start building upgrade" requests within milliseconds (or two browser tabs submit simultaneously). Both requests read the current resource balance, both see enough resources, and both deduct the cost — leaving the player with a negative resource balance or two buildings in the queue when only one should have been allowed.

**Why it happens:**
Without advisory locks or atomic check-and-deduct, two concurrent transactions read the same row (snapshot isolation) and both pass the affordability check before either commits.

**How to avoid:**
Use `SELECT ... FOR UPDATE` (pessimistic locking) inside a PostgreSQL transaction, or use atomic SQL patterns:

```sql
UPDATE resources
SET wood = wood - $cost
WHERE player_id = $player_id
  AND wood >= $cost
RETURNING wood;
```

If zero rows are returned, the action is rejected (insufficient funds). Implement this in a `SECURITY DEFINER` function called from the Edge Function. Never check-then-update in two separate statements.

**Warning signs:**
- Resource deduction implemented as: read balance → check in app code → write new balance
- No database-level constraint preventing negative resource values
- Missing `CHECK (wood >= 0)` constraints on resource columns

**Phase to address:**
Core economy phase (building upgrades, unit training). Add `CHECK` constraints in the initial schema migration and never remove them.

---

### Pitfall 4: Supabase RLS Disabled on New Tables (Public Data Leak)

**What goes wrong:**
By default, every new Supabase table has RLS disabled. Any player can query the entire table with the anon key — including other players' private data (alliance membership, messages, resource counts, battle reports).

**Why it happens:**
Supabase scaffolds tables without RLS for developer convenience. Developers enable RLS only on "obviously sensitive" tables (users, messages) and forget to enable it on game tables (resources, buildings, armies, trade_orders). Because the game works correctly during single-user testing, the leak is not noticed until a player discovers they can query everyone's army composition.

**How to avoid:**
Enable RLS on every table immediately in the migration that creates it — even before writing the policies. The first policy written is always the most restrictive (deny all), then selectively open what is needed. Add a CI/lint check that asserts `SELECT count(*) FROM pg_tables WHERE rowsecurity = false AND schemaname = 'public'` returns 0.

**Warning signs:**
- Any table created without an accompanying `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` in the same migration
- Supabase dashboard shows tables with RLS toggle OFF
- Players can call `supabase.from('armies').select('*')` and see all armies in the game

**Phase to address:**
Schema foundation phase. Make RLS-enabled-by-default a migration convention from day one.

---

### Pitfall 5: Flutter Web CanvasKit Initial Load Blocking Game Entry

**What goes wrong:**
Flutter Web with CanvasKit/WASM requires downloading a ~3-10 MB WASM binary before painting a single pixel. On slow connections, players see a blank white screen for 5-15 seconds, interpret it as a broken page, and leave before the game loads.

**Why it happens:**
Flame requires CanvasKit (not the HTML renderer) for canvas-based game rendering. Developers build the game, deploy it, and test on their fast local connection — never experiencing the cold-load penalty that new players face.

**How to avoid:**
- Host the CanvasKit WASM file on your own CDN (not unpkg) to avoid third-party latency
- Add an HTML/CSS splash screen that renders immediately (before Flutter boots) using a static `index.html` loading indicator
- Enable service worker caching so returning players load from cache
- Benchmark first-load time on a throttled (3G) connection before launch

**Warning signs:**
- No loading indicator visible before Flutter paints
- CanvasKit loaded from `unpkg.com` (the default hardcoded URL in older Flutter versions)
- No PWA/service worker configured in `web/` directory

**Phase to address:**
Deployment/polish phase. But set up the loading screen in the initial Flutter web scaffold, not as an afterthought.

---

### Pitfall 6: Battle State Desynchronization During 5-Minute Turns

**What goes wrong:**
The 5-minute turn-based battle system processes a turn via pg_cron. If the cron job is delayed or skipped (network hiccup, Supabase cold start), the battle timer still runs client-side. Players see "Turn ends in: 0:00" but the next battle state never arrives. The game appears frozen. Players refresh, get stale state, and assume the battle was lost or won erroneously.

**Why it happens:**
Using wall-clock time as the source of truth without a fallback reconciliation step. The client shows a countdown derived from `battle_turn_deadline` but has no mechanism to detect or recover from missed server ticks.

**How to avoid:**
- Store all battle state server-side: `current_turn`, `turn_deadline`, `last_processed_at`
- Client polls battle state via Supabase Realtime subscription — it never drives state
- If `last_processed_at` is more than `turn_duration + 30s` behind `NOW()`, the client shows a "Waiting for server..." notice (not a frozen timer)
- Edge Function for battle ticks must be idempotent: processing an already-processed turn is a no-op, not an error
- Add a reconciliation query that detects stuck battles: `WHERE last_processed_at < NOW() - INTERVAL '6 minutes' AND status = 'active'`

**Warning signs:**
- Battle tick function throws an exception if called twice for the same turn
- Client countdown timer derived purely from local `Date.now()` without polling server state
- No `last_processed_at` column on the battles table

**Phase to address:**
Battle system phase. Design idempotent tick processing from the start.

---

### Pitfall 7: Island Slot Exhaustion by Inactive Players (Ghost Cities)

**What goes wrong:**
A player creates a city on an island, plays for 2 days, and quits. Their city permanently occupies one of the 16-17 island slots forever. In a small community game, this means popular islands fill up with ghost cities, and active players cannot settle there. The map feels dead and new players have no desirable neighbors.

**Why it happens:**
The initial design focuses on city creation mechanics without specifying what happens to cities of players who never return. There is no abandonment or inactivity system planned for v1.

**How to avoid:**
Design a grace period + abandonment mechanic early:
- After 14 days of inactivity (no login), city enters "Abandoned" status (visible on map, resources stop producing)
- After 30 days, city is removed and the slot is freed
- Send an email notification at 7 days and 13 days via Supabase Auth trigger or Edge Function
- Alternatively: protect cities with an "Inactive Shield" (no attacking) but show them as low-priority neighbors

**Warning signs:**
- No `last_login_at` column on player profile
- No pg_cron job checking for inactive accounts
- Island map showing cities with 0 production and no recent activity after 2 weeks of operation

**Phase to address:**
Player management phase or World Map phase. Define the policy in schema design even if the enforcement job is built later.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Direct `supabase.from('resources').update()` from client | Faster to code initially | Any player can forge requests; full rewrite of economy layer needed | Never — server authority is non-negotiable for game integrity |
| Hardcoded building costs/formulas in Flutter | No server round-trip for UI display | Formula changes require app rebuild and re-deploy; client and server diverge | Never for calculations that gate server actions; OK for display hints with server re-validation |
| Single SQL UPDATE for all players per tick | Simple to write | Locks the entire resources table for seconds; breaks under concurrent play | Never in production; acceptable only for local single-player testing |
| Skip RLS on "read-only" tables like `technologies` | Slightly simpler setup | Creates a habit of skipping RLS; one forgotten table leaks private data | Acceptable for truly static reference data (no player-specific rows) |
| Client-side battle countdown without server polling | Smooth UX without network calls | Desynchronizes when server tick is late; players see wrong state | Never for authoritative game state; OK for cosmetic animations between known events |
| pg_cron job created via Supabase UI | Quick to set up | Hidden 5000ms timeout cap causes silent failures at scale | Never — always create via raw SQL for game-critical ticks |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Supabase pg_cron | Create tick job via dashboard UI, unaware of 5000ms HTTP timeout | Create via SQL with explicit `timeout_milliseconds := 30000` in `net.http_post()` |
| Supabase Realtime | Subscribe to entire table with `supabase.from('battles').on('*')` — receives all battles for all players | Subscribe to filtered channels: `.eq('attacker_id', userId).or('defender_id.eq.' + userId)` |
| Supabase Edge Functions | Call `supabase.createClient()` inside the function with the `anon` key — RLS applies but function needs elevated access | Use `Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')` inside Edge Functions; never expose service key to client |
| Supabase Auth | Trust `user_metadata` in RLS policies (user can write their own metadata) | Use `auth.uid()` as the trust anchor; store server-controlled data in a separate `profiles` table with RLS tied to `auth.uid()` |
| Flutter Flame + CanvasKit | Load CanvasKit from default unpkg.com CDN | Self-host or configure `canvasKitBaseUrl` to a reliable CDN in `index.html` |
| Flutter Riverpod + Supabase Realtime | Manage Realtime subscription lifecycle manually in widgets | Use `ref.onDispose()` to cancel subscriptions when providers are destroyed; prevent memory leaks and duplicate listeners |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| `UPDATE resources SET ... WHERE TRUE` (all players in one query) | Tick takes 30+ seconds; Supabase CPU spikes; some updates missed | Batch with `LIMIT 500` per invocation; use cursor-based pagination across tick calls | ~200 concurrent players |
| N+1 Supabase queries per component re-render | Flutter UI pauses 200-500ms on every Riverpod state change; network tab shows dozens of requests per second | Join data in a single Edge Function query or a PostgreSQL view; cache aggressively in Riverpod | ~10 simultaneous players using the game actively |
| Realtime subscription to high-churn tables (e.g., `battle_events`) | WebSocket floods client with 100s of events per minute; browser tab becomes sluggish | Use Postgres Functions to aggregate events server-side; push summary notifications, not raw rows | ~3-5 simultaneous battles |
| Flame `update()` loop triggering Supabase reads on every frame | 60 HTTP requests/second per player; Supabase rate limit hit immediately | Never read from network in `update()`; drive UI from Riverpod state that is updated via Realtime | Immediately, even single player |
| No database indexes on foreign keys and filter columns | Alliance member queries, island city lists, battle lookups slow as data grows | Add indexes at migration time on `player_id`, `island_id`, `alliance_id`, `status`, `created_at` columns | ~1000 rows per table |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Service role key exposed in Flutter web build | Attacker bypasses all RLS, reads/writes all data in the database | Service role key is server-only (Edge Functions, pg_cron). Use `anon` key in Flutter; restrict with RLS |
| No rate limiting on action endpoints | Bot scripts train unlimited units or upgrade buildings thousands of times per second | Add rate limiting per `auth.uid()` in Edge Functions (e.g., max 10 requests/5 seconds per player); use Supabase's built-in rate limiting |
| Battle outcome calculated client-side | Player sends `{ winner: "me", resources_stolen: 999999 }` | Battle resolution is exclusively server-side in a pg_cron tick or Edge Function; client only observes via Realtime |
| Negative resource values allowed in DB | Exploit: trigger two simultaneous spends, one goes negative, second uses negative balance as credit | `CHECK (wood >= 0, marble >= 0, ...)` constraints on resource columns + atomic deduct-only SQL patterns |
| Alliance role checked only client-side | Any alliance member can invoke leader-only actions (war declarations, kick members) | Every privileged action checks `alliance_members.role` in the Edge Function, not trusting any client-supplied role claim |
| Open CORS on Edge Functions | Third-party sites can impersonate players' browsers and fire actions | Restrict CORS to your own Flutter web origin; validate `Authorization: Bearer <user JWT>` on every request |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No feedback during building upgrade queue | Player clicks "Upgrade" and nothing visibly changes; they click again creating a duplicate queue entry | Optimistic UI update immediately in Riverpod state; show spinner/progress bar; disable the upgrade button while in-flight |
| Resource display shows stale value from last tick | Player resource count appears frozen; player doesn't know production is running | Display a client-side "estimated current" value (last_tick_value + rate * elapsed_seconds) as a live counter; reconcile on next Realtime event |
| 5-minute battle turn with no activity indicator | Player waits 5 minutes unsure if anything is happening; they leave | Show live battle log via Realtime as reinforcements and turn timer update; display countdown clock with server-derived deadline |
| New player overwhelmed by empty city with no tutorial | Bounce rate is high in first 10 minutes; players quit before placing their first building | Minimal onboarding flow: auto-place Town Hall on first login, surface a "First Steps" quest panel pointing at Wood Camp → Townhall upgrade path |
| Inactive player cities appear indistinguishable from active ones on the world map | Player wastes diplomacy or attack resources targeting dead cities | Show "Last Active" badge or gray-out cities inactive for 7+ days on the island view |
| Alliance chat and global chat in the same UI | Private alliance strategy exposed to public; players post in wrong channel by accident | Clearly separate tabs with distinct visual styles (color-coded, labeled); default focus to alliance chat when in an alliance |

---

## "Looks Done But Isn't" Checklist

- [ ] **Resource production:** Tick runs every 5 minutes — verify it also respects warehouse capacity caps and does not produce above `warehouse_max`. A resource that ignores the cap is an exploit vector (unlimited storage).
- [ ] **Building upgrade queue:** Single-slot queue appears to work for one building — verify that a second `start_upgrade` request while a building is in progress is rejected server-side (not just blocked in the UI).
- [ ] **Turn-based battle:** Battle reports show winner and loser — verify that resources are actually transferred server-side (pillag logic) and that occupation conditions (city takeover) are checked and enforced, not just displayed.
- [ ] **Trade routes:** Cargo ships depart and arrive in the UI — verify that the travel-time delay is enforced server-side (not instant), that ships can be intercepted during travel, and that resources are escrowed at departure (not deducted on arrival).
- [ ] **Alliance war declarations:** UI shows "War Declared" — verify that the war status gates actual attack permissions (players in NAP cannot attack each other server-side).
- [ ] **Ranking system:** Scores display in leaderboard — verify score is recalculated server-side on a schedule, not derived from client-supplied values, and that deleted/abandoned buildings reduce score correctly.
- [ ] **Player messaging:** Message appears in inbox — verify unread count badge updates via Realtime (not requiring a page refresh) and that message content is not readable by other players via direct Supabase query (RLS).

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Client-side resource calculation discovered in production | HIGH | Audit all `.update()` calls from Flutter; rewrite economy mutations as Edge Functions; run a data integrity check to find exploited accounts; consider resetting or auditing affected players |
| pg_cron tick failing silently (5s timeout) | MEDIUM | Re-create cron job via SQL with explicit timeout; add a `cron_job_log` table that the tick function writes to on each run; set up alerting if no log entry in last 7 minutes |
| RLS missing on a game table discovered post-launch | MEDIUM | Enable RLS immediately via migration; default-deny policy first; audit Supabase logs for unauthorized reads; notify affected players if private data was exposed |
| Race condition exploited for free resources | HIGH | Restore affected player resources from backup; add `CHECK` constraints and `SELECT FOR UPDATE` patterns; audit for other double-spend surfaces; consider temporary maintenance window |
| Island slots all taken by ghost cities | MEDIUM | Run a one-time cleanup migration removing cities with `last_login > 30 days`; implement ongoing inactivity check as a pg_cron job; compensate active players who lost turns attacking ghost cities |
| Flutter web WASM cold load too slow for user retention | LOW | Self-host CanvasKit WASM on CDN; add HTML splash screen to `index.html`; enable PWA service worker caching; no data migration needed |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Client-side resource calculation | Phase 1: Foundation / Schema | Code review rule: zero `.update()` on game state tables from Flutter; all mutations through Edge Functions |
| pg_cron 5s timeout | Phase 2: Resource Production | Check `cron_job_log` table after tick runs; measure tick duration with 100 test rows |
| Race condition double-spend | Phase 3: Economy (Building Upgrades) | Write integration test sending two simultaneous upgrade requests; assert only one succeeds |
| RLS disabled on tables | Phase 1: Schema Foundation | CI migration linter asserts all public tables have `rowsecurity = true` |
| Flutter WASM cold load | Phase 6: Deployment | Throttle test (3G) and measure time-to-interactive; must be < 10 seconds |
| Battle state desynchronization | Phase 4: Battle System | Integration test: manually skip a tick and verify client shows "Waiting for server" state |
| Ghost city island exhaustion | Phase 3 or 5: World Map / Player Management | Seed test data with 30-day-old players; verify pg_cron abandonment job removes them |
| RLS policy trusting user_metadata | Phase 1: Auth / Schema | Security review: grep all RLS policies for `user_metadata` references; replace with `profiles` table lookup |
| Missing indexes | Phase 1: Schema Foundation | EXPLAIN ANALYZE on island city list query and alliance member query; all must use index scans |
| Realtime subscription to high-churn tables | Phase 4: Battle System | Profile WebSocket traffic during a simulated battle; max 5 events/second per client |

---

## Sources

- [Supabase pg_cron debugging guide](https://supabase.com/docs/guides/troubleshooting/pgcron-debugging-guide-n1KTaz)
- [Supabase Cron UI 5000ms timeout issue (GitHub Discussion #37574)](https://github.com/orgs/supabase/discussions/37574)
- [Supabase Cron UI 5000ms timeout issue (GitHub Issue #37629)](https://github.com/supabase/supabase/issues/37629)
- [Supabase Realtime Limits](https://supabase.com/docs/guides/realtime/limits)
- [Supabase Scheduling Edge Functions](https://supabase.com/docs/guides/functions/schedule-functions)
- [Supabase Processing large jobs with Edge Functions, Cron, and Queues](https://supabase.com/blog/processing-large-jobs-with-edge-functions)
- [Supabase RLS Security Flaw: 170+ Apps Exposed](https://byteiota.com/supabase-security-flaw-170-apps-exposed-by-missing-rls/)
- [Row-Level Recklessness: Testing Supabase Security](https://www.precursorsecurity.com/security-blog/row-level-recklessness-testing-supabase-security)
- [Flame Engine Performance Docs](https://docs.flame-engine.org/latest/flame/other/performance.html)
- [Flutter Web CanvasKit WASM slow load (GitHub Issue #82810)](https://github.com/flutter/flutter/issues/82810)
- [Flutter Web CanvasKit optimization best practices](https://blog.flutter.dev/best-practices-for-optimizing-flutter-web-loading-speed-7cc0df14ce5c)
- [Flutter Web Performance 2025: CanvasKit vs HTML vs Wasm](https://coldfusion-example.blogspot.com/2026/01/flutter-web-performance-2025-canvaskit.html)
- [Networking of a turn-based game (Longwelwind)](https://longwelwind.net/blog/networking-turn-based-game/)
- [Web Race Conditions: PortSwigger Research](https://portswigger.net/research/smashing-the-state-machine)
- [Designing Game Economies: Inflation, Resource Management, and Balance](https://medium.com/@msahinn21/designing-game-economies-inflation-resource-management-and-balance-fa1e6c894670)
- [I Designed Economies for $150M Games](https://www.gamedeveloper.com/production/i-designed-economies-for-150m-games-here-s-my-ultimate-handbook)
- [Flame simplest optimization techniques](https://asgalex.medium.com/flutter-flame-simplest-optimization-techniques-372dbe6815f)
- [AnandTech forum: working on a game similar to Ikariam](https://forums.anandtech.com/threads/working-on-a-web-game-similar-in-some-respects-to-ikariam.325496/)

---
*Pitfalls research for: Ikariam-style browser multiplayer strategy game*
*Stack: Flutter + Flame (web), Supabase, pg_cron, Riverpod*
*Researched: 2026-03-11*
