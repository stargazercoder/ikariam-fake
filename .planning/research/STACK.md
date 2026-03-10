# Stack Research

**Domain:** Browser-based multiplayer strategy game (Ikariam clone)
**Researched:** 2026-03-11
**Confidence:** HIGH (core stack verified via pub.dev official pages and Supabase docs)

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Flutter | 3.29.x (Dart 3.7) | UI framework + web build target | Single codebase, compiles to WASM/CanvasKit for browser, enables future mobile expansion. Flutter 3.29 ships Dart 3.7 with improved JS interop needed for WASM web builds. |
| Flame | 1.36.0 | 2D game engine — game loop, components, camera, input | Flutter Favorite package. Provides `FlameGame`, `Component` tree, camera/world system, `flame_tiled` for grid maps, `GameWidget` for Flutter overlay integration. Only mature 2D game engine in the Flutter ecosystem. |
| supabase_flutter | 2.12.0 | Backend client — Auth, DB, Realtime, Edge Functions | Official Supabase Dart SDK. Handles email/password auth, Postgres queries, Realtime WebSocket subscriptions, and Edge Function invocation in one package. Auth sessions persist via SharedPreferences on web. |
| flutter_riverpod | 3.3.1 | Reactive state management | Context-free providers work cleanly outside widget tree — critical because Flame components are NOT Flutter widgets. `flame_riverpod` bridge package makes Riverpod accessible inside Flame components. Riverpod 3.x adds automatic retry and offline caching (useful for game state resilience). |
| flame_riverpod | 5.5.3 | Bridges Riverpod into Flame component tree | Without this, Flame components cannot read/watch Riverpod providers. Provides `RiverpodAwareGameWidget`, `RiverpodGameMixin`, and `RiverpodComponentMixin`. Lifecycle-aware: subscriptions auto-dispose when components are removed. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flame_tiled | 3.1.0 | Tiled map editor integration | For the 2D grid world map and island views. Tiled (.tmx) files define tile layers, collision layers, and object placement. Use for the world map grid and city building grids. |
| go_router | 17.1.0 | Declarative URL-based navigation | Managing routes between Login, World Map, Island View, City View, Research screen. Required for deep linking (Supabase Auth email confirmation callback on web). |
| freezed | 3.2.5 | Immutable data classes with copyWith, equality, unions | All game model classes (City, Resource, BuildingQueue, Unit) should be immutable Freezed classes. Eliminates boilerplate for value equality and JSON serialization. |
| freezed_annotation | 3.x | Annotations for freezed code generation | Companion to freezed — required for @freezed and @JsonSerializable annotations on model classes. |
| json_serializable | 6.13.0 | JSON serialization code generation | Converts Supabase Postgres rows (JSON) to/from Dart model objects. Works seamlessly with freezed for fromJson/toJson. |
| riverpod_annotation | 4.0.2 | Code-gen annotations for Riverpod providers | Enables `@riverpod` annotation syntax instead of manual provider boilerplate. Required for `riverpod_generator`. |
| riverpod_generator | 4.0.3 | Code generation for Riverpod providers | Generates type-safe provider code from annotated classes/functions. Reduces provider declaration errors. |
| build_runner | 2.12.2 | Code generation runner | Runs freezed, json_serializable, and riverpod_generator. Dev-only. Run once on model changes: `dart run build_runner build`. |
| shared_preferences | 2.5.4 | Key-value local storage (web: localStorage) | Supabase session persistence on web uses SharedPreferences. Also for client-side preferences (sound toggle, map zoom level). |
| flame_audio | 2.12.0 | Audio playback via audioplayers | Background music, UI click sounds, battle sound effects. Use only after core game loop is stable (defer to late milestone). |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Supabase CLI | Local Supabase stack (Postgres, Auth, Realtime, Edge Functions) | Run `supabase start` to spin up full backend locally via Docker. Migrations tracked in `supabase/migrations/`. Required for offline development and CI. |
| Supabase Dashboard | Schema editor, SQL runner, pg_cron job management, RLS policy editor | Use for initial schema design; migrate changes to SQL migration files for reproducibility. |
| Tiled Map Editor | Visual 2D tile map editor | Create .tmx files for the world map grid and island layouts. Export to `assets/tiles/`. Used by `flame_tiled`. |
| Flutter DevTools | Performance profiler, widget inspector, network tab | Monitor frame rate (target 60fps), detect jank in Flame game loop, inspect Riverpod provider state. |
| Docker Desktop | Required for Supabase CLI local stack | Must be running when using `supabase start`. |
| Deno | Runtime for Supabase Edge Functions | Functions are TypeScript/Deno. Use `supabase functions serve` for local Edge Function development with hot reload. |

---

## Installation

```bash
# Flutter project setup (web target)
flutter create ikariam --platforms web
cd ikariam

# Core game packages
flutter pub add flame
flutter pub add flame_riverpod
flutter pub add flame_tiled
flutter pub add supabase_flutter
flutter pub add flutter_riverpod
flutter pub add go_router

# Model and serialization
flutter pub add freezed_annotation
flutter pub add json_annotation
flutter pub add riverpod_annotation

# Runtime utilities
flutter pub add shared_preferences

# Dev dependencies (code generation)
flutter pub add --dev build_runner
flutter pub add --dev freezed
flutter pub add --dev json_serializable
flutter pub add --dev riverpod_generator
flutter pub add --dev flutter_lints

# Run code generation after creating models
dart run build_runner build --delete-conflicting-outputs
```

```bash
# Supabase CLI setup (separate from Flutter project)
# Install Supabase CLI via npm or Scoop on Windows
npm install -g supabase

# Initialize and start local Supabase stack
supabase init
supabase start
# Outputs: local API URL, anon key, service role key for .env
```

---

## Web Build Commands

```bash
# Development (CanvasKit renderer, default)
flutter run -d chrome

# Production build — default (CanvasKit, broadest compatibility)
flutter build web --release

# Production build — WASM (Skwasm renderer, better performance, requires WasmGC-capable browser)
flutter build web --release --wasm
# Note: requires all dependencies to support new dart:js_interop (not legacy dart:js)
# supabase_flutter 2.x uses dart:js_interop — WASM-compatible
# Verify all packages before committing to --wasm in production
```

**Renderer recommendation for v1:** Use default CanvasKit (`flutter build web --release`). WASM gives 2-3x rendering performance gain but requires server headers (`COOP`/`COEP`) for SharedArrayBuffer support, and all transitive dependencies must be WASM-compatible. Validate WASM compatibility before switching.

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Flame 1.36.0 | Unity WebGL | Never for this project. Unity has no Flutter integration. Flutter + Flame keeps single Dart codebase with future mobile support. |
| Flame | Godot (web export) | If team has existing Godot expertise and mobile is not a goal. For this project, Flutter/Flame is correct. |
| flutter_riverpod | flutter_bloc | Bloc is viable but more verbose for reactive game state. Riverpod's context-free providers are a better fit for Flame's non-widget component tree. |
| flutter_riverpod | Provider | Provider is the predecessor. Riverpod 3.x strictly supersedes it — no reason to use Provider in 2025. |
| go_router | Navigator 2.0 (manual) | Only if routing needs are trivially simple. go_router is the Flutter team's recommended routing package and handles Supabase auth deep-link callbacks cleanly. |
| freezed | manual model classes | Manual classes are acceptable for very small projects. For a game with 20+ model types, freezed's code generation pays off immediately — copyWith and equality are critical for Riverpod state updates. |
| supabase_flutter | Firebase (Firestore + Auth) | If Postgres is not required. For this project, Supabase is correct: pg_cron for resource ticks, SQL queries for complex game logic, RLS for security, and Edge Functions for server-side validation. |
| Tiled + flame_tiled | Custom grid renderer | Only if game requires procedural map generation. For structured island/city grids with predefined layouts, Tiled provides visual editing tooling that custom renderers lack. |
| Skwasm/WASM (deferred) | CanvasKit (default) | WASM is the future target for better frame performance. Defer until all dependencies confirm WASM support. CanvasKit is production-ready today. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `dart:html` / `dart:js` (legacy) | Deprecated in Flutter 3.29+, breaks WASM compilation | `package:web` and `dart:js_interop` — already used internally by supabase_flutter 2.x |
| `flame_bloc` | BLoC integration for Flame — use Riverpod ecosystem instead for consistency | `flame_riverpod` |
| `Provider` package | Predecessor to Riverpod, deprecated pattern in 2025 | `flutter_riverpod` 3.x |
| `HTTP` package for Supabase calls | Bypasses RLS, Auth headers, and retry logic | `supabase_flutter` client — always route through the SDK |
| Supabase `service_role` key in client | Bypasses RLS entirely — catastrophic security hole in a game where players must not see each other's private data | Only use `anon` key client-side; service_role is server-only (Edge Functions) |
| Client-side resource calculations | Players can manipulate JS/WASM memory to cheat | All production ticks, battle resolution, and construction completion run server-side via pg_cron and Edge Functions |
| `SharedPreferences` for game state | Only for small key-value preferences. Game state (cities, armies, research) is in Supabase Postgres | Use Riverpod providers backed by Supabase queries for game state |
| Direct Postgres socket connections from client | Not supported by Supabase; all access is via REST/Realtime WebSocket | Use `supabase_flutter` SDK exclusively |
| `flame_forge2d` (Box2D physics) | Physics engine adds complexity with no benefit for a turn-based strategy game with no collision physics | Not needed — grid movement and turn-based combat require no physics simulation |

---

## Stack Patterns by Variant

**For Realtime game events (battle reports, chat, online presence):**
- Use Supabase Realtime **Broadcast** channel for ephemeral low-latency events (chat messages, battle notifications)
- Use Supabase Realtime **Postgres Changes** for authoritative state changes (construction completion, resource tick results)
- Use Supabase Realtime **Presence** for tracking which players are currently online
- Subscribe in Riverpod `StreamProvider` and expose to Flame components via `flame_riverpod`

**For server-side game ticks (resource production every 5 minutes):**
- Use `pg_cron` to schedule a SQL function or Edge Function invocation
- SQL function approach: `SELECT cron.schedule('resource-tick', '*/5 * * * *', $$SELECT tick_resources()$$);`
- Edge Function approach: `SELECT cron.schedule('resource-tick', '*/5 * * * *', $$SELECT net.http_post(...)$$);`
- SQL function is preferred for resource ticks (pure arithmetic, no external calls needed)
- Edge Functions preferred for battle resolution (complex logic, needs transaction safety)

**For Flutter UI panels over Flame game canvas:**
- Use `GameWidget` with `overlayBuilderMap` for menus, modals, and HUD panels
- Flame renders the game world; Flutter widgets render the UI layer on top
- This hybrid approach enables using standard Flutter widgets (ListView, Form, etc.) for game menus while Flame handles the map/city canvas

**For web-specific Flutter WASM deployment:**
- Set COOP/COEP headers on hosting server for SharedArrayBuffer support (required for Skwasm multi-threading)
- Netlify: add `_headers` file; Firebase Hosting: add headers to `firebase.json`
- Without these headers, Flutter WASM falls back to single-threaded mode (still functional, just slower)

---

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| flame 1.36.0 | Flutter 3.x, Dart 3.x | All 1.x Flame packages (flame_tiled, flame_riverpod, flame_audio) must be on compatible 1.x/matching versions. Check flame_* packages share same 1.x root. |
| flame_riverpod 5.5.3 | flutter_riverpod 3.x | flame_riverpod 5.x requires Riverpod 3.x. Do NOT mix flame_riverpod 4.x with Riverpod 3.x. |
| supabase_flutter 2.12.0 | Flutter 3.x, Dart 3.x | supabase_flutter 2.x uses `dart:js_interop` (WASM-compatible). v1.x was not WASM-compatible. Use 2.x only. |
| freezed 3.2.5 | Dart 3.7+ | Freezed 3.x requires Dart 3.x. Compatible with Flutter 3.29 (Dart 3.7). |
| riverpod_generator 4.0.3 | riverpod_annotation 4.0.2, flutter_riverpod 3.3.1 | Generator, annotation, and runtime versions must be kept in sync. All are published by the same author (dash-overflow.net) — update together. |
| go_router 17.1.0 | Flutter 3.x | go_router is published by the Flutter team. Version 17.x is the current stable for Flutter 3.29. |
| flutter_riverpod 3.3.1 | riverpod 3.2.1 | flutter_riverpod pins exact riverpod core version. Do not add riverpod separately; flutter_riverpod brings the correct version. |

---

## Supabase Services Used

| Service | Purpose in Game | Configuration |
|---------|----------------|---------------|
| PostgreSQL | All persistent game state (players, cities, resources, buildings, armies, alliances, messages) | Tables with RLS enabled. Use `uuid` primary keys. All timestamps use `NOW()` server-side — never trust client timestamps. |
| Supabase Auth | Email/password authentication, session management | `supabase.auth.signInWithPassword()`. Sessions stored in SharedPreferences on web. Email confirmation enabled for registration security. |
| Realtime | Battle notifications, chat, construction completion events, online presence | Subscribe via `supabase.channel()`. Use Broadcast for chat/notifications, Postgres Changes for state updates. |
| Edge Functions (Deno/TypeScript) | Server-side game logic: build queue completion, battle resolution, trade route arrival | Invoked by pg_cron or client trigger. Service-role key used server-side only. Input validated before DB writes. |
| pg_cron | Scheduled resource production ticks (every 5 min), daily score recalculation | Enabled as a Postgres extension. Jobs created via SQL: `SELECT cron.schedule(...)`. Max 8 concurrent jobs recommended. |
| Row Level Security (RLS) | Players can only read/write their own cities, armies, messages | Enable RLS on all tables. Index `user_id` columns for performance (can be 100x faster on large tables). Use `auth.uid()` in policies. |
| Storage | Player avatar images (optional, v1 low priority) | If implemented: use `avatars` bucket with user-scoped RLS policies. |

---

## Sources

- pub.dev/packages/flame — Version 1.36.0 confirmed (published 4 days ago as of research date) — HIGH confidence
- pub.dev/packages/supabase_flutter — Version 2.12.0 confirmed — HIGH confidence
- pub.dev/packages/flutter_riverpod — Version 3.3.1 confirmed (published 32 hours ago) — HIGH confidence
- pub.dev/packages/flame_riverpod — Version 5.5.3 confirmed — HIGH confidence
- pub.dev/packages/flame_tiled — Version 3.1.0 confirmed — HIGH confidence
- pub.dev/packages/riverpod_annotation — Version 4.0.2 confirmed — HIGH confidence
- pub.dev/packages/riverpod_generator — Version 4.0.3 confirmed — HIGH confidence
- pub.dev/packages/freezed — Version 3.2.5 confirmed — HIGH confidence
- pub.dev/packages/json_serializable — Version 6.13.0 confirmed — HIGH confidence
- pub.dev/packages/build_runner — Version 2.12.2 confirmed — HIGH confidence
- pub.dev/packages/shared_preferences — Version 2.5.4 confirmed — HIGH confidence
- pub.dev/packages/go_router — Version 17.1.0 confirmed — HIGH confidence
- pub.dev/packages/flame_audio — Version 2.12.0 confirmed — HIGH confidence
- docs.flutter.dev/platform-integration/web/renderers — CanvasKit vs Skwasm/WASM renderer comparison — HIGH confidence
- supabase.com/docs/guides/realtime — Broadcast, Presence, Postgres Changes channel types — HIGH confidence
- supabase.com/docs/guides/database/extensions/pg_cron — pg_cron scheduling patterns — HIGH confidence
- supabase.com/blog/flutter-real-time-multiplayer-game — Official Supabase tutorial: Flutter + Flame + Supabase Realtime — HIGH confidence
- docs.flutter.dev/release/release-notes/release-notes-3.29.0 — Flutter 3.29 ships Dart 3.7 — HIGH confidence
- supabase.com/docs/guides/troubleshooting/rls-performance-and-best-practices-Z5Jjwv — RLS performance: index user_id columns — HIGH confidence

---

*Stack research for: Ikariam-style browser multiplayer strategy game (Flutter + Flame + Supabase + Riverpod)*
*Researched: 2026-03-11*
