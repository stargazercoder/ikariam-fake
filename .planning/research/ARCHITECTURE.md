# Architecture Research

**Domain:** Browser-based multiplayer strategy game (Ikariam-style)
**Researched:** 2026-03-11
**Confidence:** HIGH (Supabase + Flutter + Flame official docs verified; game architecture patterns from authoritative sources)

## Standard Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                         CLIENT LAYER (Flutter Web)                    │
├──────────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐               │
│  │ Flutter UI   │  │  Flame World │  │  Riverpod    │               │
│  │ (Screens,    │  │  (Map, City  │  │  Providers   │               │
│  │  Overlays,   │  │   Views,     │  │  (Game State │               │
│  │  Dialogs)    │  │   Battle HUD)│  │   Cache)     │               │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘               │
│         │                 │                 │                        │
│         └─────────────────┴─────────────────┘                        │
│                           │                                          │
│                  ┌────────┴────────┐                                 │
│                  │  Service Layer  │                                 │
│                  │ (Supabase SDK)  │                                 │
│                  └────────┬────────┘                                 │
└───────────────────────────┼──────────────────────────────────────────┘
                            │  HTTPS / WebSockets
┌───────────────────────────┼──────────────────────────────────────────┐
│                     SUPABASE BACKEND                                  │
│  ┌──────────────┐         │        ┌──────────────┐                  │
│  │ Kong API     ├─────────┘        │  GoTrue Auth │                  │
│  │ Gateway      │                  │  (JWT tokens)│                  │
│  └──────┬───────┘                  └──────┬───────┘                  │
│         │                                 │                          │
│  ┌──────┴──────────────────────────────────┴──────────────────────┐  │
│  │                     PostgreSQL Database                         │  │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌──────────┐  │  │
│  │  │  Players   │  │  Cities /  │  │  Battles / │  │ Alliances│  │  │
│  │  │  Profiles  │  │  Buildings │  │  Reports   │  │  Trades  │  │  │
│  │  └────────────┘  └────────────┘  └────────────┘  └──────────┘  │  │
│  └─────────────────────────────────────────────────────────────────┘  │
│         │                    │                    │                   │
│  ┌──────┴───────┐   ┌────────┴────────┐  ┌───────┴──────┐           │
│  │  PostgREST   │   │   Realtime      │  │  Edge        │           │
│  │  (REST API   │   │   (WebSockets:  │  │  Functions   │           │
│  │   via RLS)   │   │   Broadcast +  │  │  (Deno/TS:   │           │
│  │              │   │   DB Changes)  │  │  game logic) │           │
│  └──────────────┘   └─────────────────┘  └──────┬───────┘           │
│                                                  │                   │
│                                         ┌────────┴────────┐          │
│                                         │   pg_cron       │          │
│                                         │ (Tick Scheduler)│          │
│                                         │ Every 5 minutes │          │
│                                         └─────────────────┘          │
└──────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Implementation |
|-----------|---------------|----------------|
| Flutter UI Layer | Screens, dialogs, menus, HUD overlays | Flutter widgets, Navigator, MaterialApp |
| Flame World Layer | 2D rendering of map grid, city grid, battle animations | FlameGame + World + Camera2D |
| Riverpod Providers | Reactive game state cache, optimistic updates | AsyncNotifier, StreamProvider |
| Service Layer | API calls, WebSocket subscriptions, auth tokens | Supabase Dart SDK |
| Kong Gateway | Request routing, rate limiting, auth header verification | Managed by Supabase |
| GoTrue Auth | User registration, login, JWT issuance | Supabase Auth |
| PostgreSQL | Single source of truth for all game state | Tables + RLS + triggers |
| PostgREST | Auto-generated REST API honoring RLS | Managed by Supabase |
| Supabase Realtime | Push battle events, chat, trade updates to clients | WebSocket channels (Broadcast + DB Changes) |
| Edge Functions | Authoritative game calculations (battle, construction) | Deno TypeScript |
| pg_cron | Server-side tick scheduler (resource production) | pg_cron extension |

---

## Recommended Project Structure

```
ikariam/
├── lib/
│   ├── main.dart                    # App entry point, ProviderScope
│   ├── app.dart                     # MaterialApp + router setup
│   │
│   ├── core/
│   │   ├── supabase_client.dart     # Supabase singleton init
│   │   ├── router.dart              # go_router or auto_route config
│   │   └── constants.dart           # Game constants (tick interval, etc.)
│   │
│   ├── features/
│   │   ├── auth/
│   │   │   ├── auth_provider.dart   # Riverpod: auth state
│   │   │   ├── auth_service.dart    # Supabase Auth wrapper
│   │   │   └── screens/            # Login, register screens
│   │   │
│   │   ├── world_map/
│   │   │   ├── world_map_game.dart  # FlameGame subclass for world map
│   │   │   ├── components/         # IslandTile, FleetMarker components
│   │   │   ├── world_map_provider.dart
│   │   │   └── screens/            # WorldMapScreen (wraps GameWidget)
│   │   │
│   │   ├── city/
│   │   │   ├── city_game.dart       # FlameGame subclass for city view
│   │   │   ├── components/         # BuildingSlot, ResourceBar components
│   │   │   ├── city_provider.dart   # Riverpod: city state, buildings
│   │   │   ├── services/
│   │   │   │   ├── building_service.dart
│   │   │   │   └── construction_service.dart
│   │   │   └── screens/            # CityScreen
│   │   │
│   │   ├── resources/
│   │   │   ├── resource_provider.dart  # Riverpod: resource counts
│   │   │   └── resource_service.dart   # Supabase reads (resources table)
│   │   │
│   │   ├── research/
│   │   │   ├── research_provider.dart
│   │   │   ├── research_service.dart
│   │   │   └── screens/            # ResearchScreen (tech tree UI)
│   │   │
│   │   ├── military/
│   │   │   ├── army_provider.dart
│   │   │   ├── unit_service.dart
│   │   │   └── screens/            # BarracksScreen, NavyScreen
│   │   │
│   │   ├── battle/
│   │   │   ├── battle_provider.dart  # Riverpod: active battle state
│   │   │   ├── battle_service.dart   # Edge Function caller
│   │   │   ├── battle_realtime.dart  # Supabase Realtime subscription
│   │   │   └── screens/             # BattleReportScreen
│   │   │
│   │   ├── trade/
│   │   │   ├── trade_provider.dart
│   │   │   ├── marketplace_service.dart
│   │   │   └── screens/             # MarketplaceScreen
│   │   │
│   │   ├── alliance/
│   │   │   ├── alliance_provider.dart
│   │   │   ├── alliance_service.dart
│   │   │   └── screens/             # AllianceScreen, DiplomacyScreen
│   │   │
│   │   └── messaging/
│   │       ├── chat_provider.dart    # Riverpod: alliance chat
│   │       ├── message_realtime.dart # Supabase Realtime broadcast
│   │       └── screens/             # ChatScreen, InboxScreen
│   │
│   └── shared/
│       ├── widgets/                  # Reusable UI (ResourceBar, etc.)
│       ├── models/                   # Dart data classes (City, Building, etc.)
│       └── extensions/               # Dart extensions
│
├── supabase/
│   ├── migrations/                   # SQL schema files
│   ├── functions/
│   │   ├── battle-turn/              # Battle calculation Edge Function
│   │   ├── start-battle/             # Battle initiation Edge Function
│   │   ├── upgrade-building/         # Construction queue Edge Function
│   │   ├── complete-research/        # Research tick Edge Function
│   │   ├── trade-route/              # Cargo ship dispatch Edge Function
│   │   └── _shared/                  # Shared logic (formulas, validators)
│   └── seed.sql                      # Initial game data (units, buildings)
│
└── pubspec.yaml
```

### Structure Rationale

- **features/:** Feature-first organization. Each feature owns its Flame game (if needed), Riverpod providers, services, and screens. Prevents cross-feature coupling.
- **features/[x]/services/:** Thin wrappers over Supabase SDK calls. No game logic here — logic lives in Edge Functions or pg_cron.
- **supabase/functions/:** One Edge Function per game action. Each function is a security boundary — the client can call it with JWT, the function validates, mutates DB, and returns result.
- **shared/models/:** Plain Dart classes. No UI, no Supabase dependencies. Easy to test.

---

## Architectural Patterns

### Pattern 1: Dumb Client — Authoritative Server

**What:** Client sends intent (action request), server validates and calculates, server writes state, server pushes result back.

**When to use:** All game-affecting actions — building upgrades, troop movements, battle resolutions, resource production. This is the core anti-cheat mechanism.

**Trade-offs:** Slightly higher latency per action (network round trip to Edge Function). For a slow-paced strategy game, this is acceptable and preferred over client-side trust.

**Example:**
```dart
// Client: send intent only, never compute outcomes
Future<void> upgradeBuilding(String buildingId) async {
  // Calls Edge Function — no local calculation
  final result = await supabase.functions.invoke(
    'upgrade-building',
    body: {'building_id': buildingId},
  );
  // State comes back via Realtime subscription or function response
}
```

```typescript
// Edge Function: validate + calculate + write
Deno.serve(async (req) => {
  const { building_id } = await req.json();
  const user = await getUser(req); // JWT verification

  // Server validates preconditions
  const building = await getBuilding(building_id, user.id);
  if (!canAfford(building, user.resources)) {
    return error('Insufficient resources');
  }

  // Server calculates cost and time
  const cost = baseCost * Math.pow(1.5, building.level);
  const duration = baseTime * Math.pow(1.2, building.level);

  // Server writes atomically
  await db.transaction([
    deductResources(user.id, cost),
    queueConstruction(building_id, duration),
  ]);

  return success({ queued_until: completionTime });
});
```

### Pattern 2: pg_cron Tick System for Passive Production

**What:** Scheduled PostgreSQL jobs run every 5 minutes to advance game state — resource production, construction completion, battle turns, fleet arrivals.

**When to use:** Any time-based passive progression. This pattern ensures state advances correctly even when no players are online and prevents client-side time manipulation.

**Trade-offs:** 5-minute resolution is the minimum tick granularity. Intermediate states (e.g., "building 3 minutes from completion") are stored as target timestamps, not countdown timers. The client calculates display-only countdowns from server timestamps.

**Example:**
```sql
-- pg_cron job: runs every 5 minutes
SELECT cron.schedule(
  'resource-production-tick',
  '*/5 * * * *',
  $$
    UPDATE city_resources cr
    SET amount = LEAST(
      cr.amount + (
        SELECT workers * building_level * research_bonus
        FROM production_buildings pb
        WHERE pb.city_id = cr.city_id AND pb.resource_type = cr.resource_type
      ),
      warehouse_capacity
    )
    FROM cities c
    WHERE cr.city_id = c.id;
  $$
);
```

### Pattern 3: Supabase Realtime for Push Notifications

**What:** Use Realtime DB Changes (WAL streaming) for persistent game events (battle reports, trade arrivals, messages) and Broadcast for ephemeral real-time events (active battle turn updates).

**When to use:**
- DB Changes: battle report inserts, construction completions, resource deliveries — anything that needs to persist and be received even on reconnect
- Broadcast: active battle turn-by-turn updates, typing indicators in chat — ephemeral and low-latency

**Trade-offs:** DB Changes have higher latency (WAL → Realtime → client) but guarantee delivery. Broadcast is faster but ephemeral — if client disconnects, it misses the message.

**Example:**
```dart
// DB Changes: battle reports (persistent)
supabase
  .from('battle_reports')
  .stream(primaryKey: ['id'])
  .eq('defender_id', userId)
  .listen((reports) {
    ref.read(battleProvider.notifier).updateReports(reports);
  });

// Broadcast: active battle turns (ephemeral)
final channel = supabase.channel('battle:${battleId}');
channel.onBroadcast(
  event: 'turn_result',
  callback: (payload) {
    ref.read(activeBattleProvider.notifier).applyTurnResult(payload);
  },
).subscribe();
```

### Pattern 4: Riverpod Provider Per Game Domain

**What:** One Riverpod `AsyncNotifier` per major game domain (city, resources, research, battle). Providers load from Supabase on first access, subscribe to Realtime for updates, and expose optimistic update methods.

**When to use:** All game state that needs to be reactively displayed in UI and kept in sync with the server.

**Trade-offs:** More boilerplate than a single global store, but provides clean isolation between domains. Individual features can be developed and tested independently.

**Example:**
```dart
@riverpod
class CityNotifier extends _$CityNotifier {
  @override
  Future<City> build(String cityId) async {
    // Initial load from Supabase
    final data = await supabase
      .from('cities')
      .select('*, buildings(*), construction_queue(*)')
      .eq('id', cityId)
      .single();

    // Subscribe to Realtime updates
    ref.onDispose(() => _subscription?.cancel());
    _subscription = supabase
      .from('cities')
      .stream(primaryKey: ['id'])
      .eq('id', cityId)
      .listen((data) => state = AsyncData(City.fromJson(data.first)));

    return City.fromJson(data);
  }
}
```

---

## Data Flow

### Player Action Flow (e.g., queue building upgrade)

```
[Player taps "Upgrade"]
        |
[Flutter UI] --> dispatch action to CityNotifier
        |
[CityNotifier] --> optimistic update (optional: show "pending")
        |
[BuildingService] --> POST to Edge Function /upgrade-building
        |
[Edge Function] --> validate JWT + check preconditions + calculate
        |
[PostgreSQL] --> atomic transaction: deduct resources + insert queue entry
        |
[Realtime WAL] --> detects INSERT into construction_queue
        |
[Realtime WebSocket] --> pushes DB change event to subscribed client
        |
[CityNotifier.stream] --> receives update --> state = AsyncData(updatedCity)
        |
[Flutter UI] --> rebuilds with new construction queue entry
```

### Passive Tick Flow (resource production)

```
[pg_cron] -- every 5 minutes -->
        |
[SQL UPDATE] --> city_resources += production_rate (bounded by warehouse)
        |
[PostgreSQL WAL] --> change detected
        |
[Realtime] --> DB Changes event sent to all subscribed players
        |
[ResourceNotifier] --> receives stream update --> updates resource counts
        |
[UI] --> resource numbers update
```

### Battle Turn Flow

```
[pg_cron] -- every 5 minutes during active battle -->
        |
[pg_cron invokes] --> Edge Function /battle-turn
        |
[Edge Function] --> load battle state from DB
        |
[Edge Function] --> calculate combat (unit stats, terrain, research bonuses)
        |
[Edge Function] --> write turn result + survivors to DB
        |
[Edge Function] --> broadcast turn result via Realtime channel 'battle:{id}'
        |
[Both players' clients] --> receive Broadcast event --> update battle HUD
        |
[Edge Function] --> if battle_over: insert battle_report record
        |
[Realtime DB Changes] --> both players receive battle_report notification
```

### State Management Flow

```
[Supabase DB]
    | stream (Realtime subscription)
    v
[Riverpod AsyncNotifier]  <-->  [Edge Function calls (mutations)]
    | watch/read
    v
[Flutter widgets / Flame components]
    | rebuild on state change
    v
[UI renders current game state]
```

### Key Data Flows Summary

1. **Read path:** Client reads via PostgREST (REST) or Supabase Realtime stream — RLS enforces what each player can see
2. **Write path:** Client calls Edge Function with JWT — Edge Function validates, writes to DB — Realtime pushes change back to subscribed clients
3. **Tick path:** pg_cron runs SQL directly on DB — Realtime detects WAL changes — pushes to clients
4. **Battle path:** pg_cron triggers battle-turn Edge Function every 5 min — Edge Function computes result, writes it — Broadcast pushes turn update to both players immediately

---

## Component Boundaries

### What Talks to What

| From | To | Channel | Direction |
|------|----|---------|-----------|
| Flutter UI | Riverpod Providers | read/watch | UI reads state |
| Riverpod Providers | Service Layer | Dart calls | Providers call services |
| Service Layer | Supabase SDK | Dart SDK | Services use Supabase client |
| Supabase SDK | Edge Functions | HTTPS POST | Client triggers server action |
| Supabase SDK | PostgREST | HTTPS GET | Client reads data |
| Supabase SDK | Realtime WebSocket | WS subscribe | Client receives push events |
| Edge Functions | PostgreSQL | Direct SQL | Server writes game state |
| pg_cron | PostgreSQL | Direct SQL | Scheduler updates state |
| pg_cron | Edge Functions | HTTP invoke | Scheduler triggers complex logic |
| PostgreSQL WAL | Realtime | Internal | DB changes propagate to clients |
| Flame Components | Riverpod Providers | RiverpodComponentMixin | Game components read/react to state |

### Rules

- Client NEVER writes game state directly to the DB (no direct INSERT/UPDATE from client code)
- Client only: reads via SELECT (PostgREST + RLS) and triggers Edge Functions
- All calculations (battle damage, resource production, build costs) happen in Edge Functions or pg_cron SQL — never in Dart client code
- RLS policies ensure players only read their own cities, private messages, etc.

---

## Build Order (Phase Dependencies)

The component dependency graph determines build order:

```
Phase 1: Foundation
  Auth system → Player profile → DB schema (base tables)
       ↓
Phase 2: Core Game Loop
  Resource system (pg_cron ticks) → City view → Building system
  (Resources are needed before buildings make sense)
       ↓
Phase 3: World & Expansion
  World map (islands/cities) → Research system
  (Need a world before players interact with it)
       ↓
Phase 4: Military
  Military units → Battle system (turn engine)
  (Need units before battles)
       ↓
Phase 5: Social & Economy
  Trade / Marketplace → Alliance system → Messaging
  (Need players established before social features matter)
       ↓
Phase 6: Meta
  Ranking system → Diplomacy (war declarations, NAP)
```

### Dependency Rationale

- **Auth before everything:** Every DB table has `player_id` foreign keys — auth must exist first
- **Resources before buildings:** Building upgrade costs require the resource system to be functional and testable
- **pg_cron tick before city view:** Resource display in the city view needs the tick system to be meaningful
- **Buildings before research:** Research requires the Academy building to generate research points
- **Units before battles:** Battle calculations reference unit stats — unit tables and seeded data must exist
- **Realtime can be added incrementally:** Polling works initially; Realtime subscriptions can replace polling feature by feature

---

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 0-500 players | Supabase free/pro tier. Single DB, pg_cron every 5 min, no optimization needed. |
| 500-5,000 players | Monitor pg_cron job duration. If resource tick takes >30s, batch cities into chunks. Add DB indexes on `city_id`, `player_id`, `battle_id`. |
| 5,000-50,000 players | Supabase Pro or Enterprise. Consider partitioning battle_reports table by date. Realtime connection count may require Supabase plan upgrade. |
| 50,000+ players | This stack's ceiling. Would need custom game server (Elixir/Go) to replace Edge Functions for battle calculations. Supabase remains viable for persistence. |

### Scaling Priorities

1. **First bottleneck:** pg_cron resource tick touching all cities simultaneously. Fix: process cities in batches, or shard by island.
2. **Second bottleneck:** Realtime connection count. Fix: Supabase plan upgrade; group players into fewer channels per island/region.
3. **Third bottleneck:** Edge Function cold starts during battle spikes. Fix: pg_cron invokes battle functions — warm invocations are faster; acceptable for 5-min turns.

---

## Anti-Patterns

### Anti-Pattern 1: Client-Side Game Calculations

**What people do:** Calculate battle outcomes, resource production, or building costs in Dart and send the result to the server.

**Why it's wrong:** Any calculation on the client is cheatable. Players can modify Flutter web code or intercept network calls to send fraudulent results (e.g., "I won the battle with 0 losses").

**Do this instead:** Client sends intent only (`{ action: 'attack', target_city_id: '...' }`). Edge Function receives, validates, calculates, writes result. Client receives outcome via Realtime.

### Anti-Pattern 2: Polling Instead of Realtime Subscriptions

**What people do:** `setInterval(() => fetchResources(), 5000)` to keep UI fresh.

**Why it's wrong:** Creates N × interval HTTP requests per player. At 100 players polling every 5s, that is 20 requests/second just for resource reads. Wastes Supabase request quota and adds server load.

**Do this instead:** Subscribe to Supabase Realtime DB Changes on the `city_resources` table. The client receives a push only when the pg_cron tick runs, not continuously.

### Anti-Pattern 3: Direct DB Writes from Client

**What people do:** Use the Supabase JS/Dart client directly to INSERT into `buildings` or UPDATE `resources`.

**Why it's wrong:** Even with RLS, this bypasses game logic validation. A player could INSERT a level-20 building without paying costs, or set resources to max.

**Do this instead:** All writes go through Edge Functions that validate preconditions, check costs, and apply formulas before writing. PostgREST is read-only from the client.

### Anti-Pattern 4: One Flame Game for Everything

**What people do:** Create a single `FlameGame` instance with all components — world map, city buildings, battle HUD — all loaded simultaneously.

**Why it's wrong:** Flame components for the world map (hundreds of island tiles) and city view (building grid) should not be in memory at the same time. This causes unnecessary memory use and rendering overhead in a web context.

**Do this instead:** Create separate `FlameGame` subclasses per view (`WorldMapGame`, `CityGame`). Mount the correct `GameWidget` for the active screen. Use Flutter Navigator to switch between screens, letting Flame games unmount with the screen.

### Anti-Pattern 5: Storing Countdown Timers Client-Side

**What people do:** On receiving a "construction queued" response, store `remainingSeconds = 3600` in local state and decrement it with a timer.

**Why it's wrong:** Client timers drift, can be paused/manipulated, and are lost on refresh. The server and client disagree on completion time.

**Do this instead:** Store `completes_at: DateTime` (server UTC timestamp) in the database. Client calculates `remainingSeconds = completesAt.difference(DateTime.now().toUtc()).inSeconds` for display only. Server pg_cron checks `completes_at < NOW()` to finalize.

---

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Supabase Auth | Dart SDK `supabase.auth.signInWithPassword()` | JWT stored in SDK session; auto-refreshed |
| PostgREST | Dart SDK `.from('table').select()` — RLS enforced | Read-only from client; all writes via Edge Functions |
| Edge Functions | Dart SDK `supabase.functions.invoke('fn-name', body: {...})` | Authenticated with user JWT automatically |
| Realtime | Dart SDK `.channel().onPostgresChanges().subscribe()` | DB Changes + Broadcast channels |
| pg_cron | Defined in SQL migrations; no client integration | Server-only scheduler |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Flutter UI ↔ Flame | Flutter Overlays API | UI dialogs sit on top of Flame canvas via `overlays.add()` |
| Flame components ↔ Riverpod | `RiverpodComponentMixin` | Components call `ref.read()` inside `onMount()` |
| Feature providers ↔ Services | Direct Dart function calls | No global event bus needed at this scale |
| Edge Functions ↔ DB | Supabase Deno client with `service_role` key | Bypasses RLS — functions have full write access |
| pg_cron ↔ Edge Functions | `net.http_post()` via pg_net extension | Cron invokes functions over HTTP internally |

---

## Sources

- [Supabase Architecture Docs](https://supabase.com/docs/guides/getting-started/architecture) — HIGH confidence
- [Supabase Realtime Architecture](https://supabase.com/docs/guides/realtime/architecture) — HIGH confidence
- [Supabase Edge Functions Architecture](https://supabase.com/docs/guides/functions/architecture) — HIGH confidence
- [Flame Component System Docs](https://docs.flame-engine.org/latest/flame/components.html) — HIGH confidence
- [flame_riverpod Bridge Package](https://docs.flame-engine.org/latest/bridge_packages/flame_riverpod/riverpod.html) — HIGH confidence
- [Gabriel Gambetta: Client-Server Game Architecture](https://www.gabrielgambetta.com/client-server-game-architecture.html) — HIGH confidence
- [Heroic Labs: Authoritative Multiplayer Architecture](https://heroiclabs.com/docs/nakama/concepts/multiplayer/authoritative/) — MEDIUM confidence
- [Aleksandra Codes: Supabase Realtime Game](https://www.aleksandra.codes/supabase-game) — MEDIUM confidence
- [Red Gate: MMO Game Database Design](https://www.red-gate.com/blog/mmo-games-and-database-design) — MEDIUM confidence
- [Supabase Cron Docs](https://supabase.com/docs/guides/cron) — HIGH confidence

---

*Architecture research for: Ikariam-style browser multiplayer strategy game*
*Stack: Flutter + Flame + Supabase (PostgreSQL + Edge Functions + Realtime + pg_cron) + Riverpod*
*Researched: 2026-03-11*
