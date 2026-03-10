# Phase 1: Foundation - Research

**Researched:** 2026-03-11
**Domain:** Flutter Web + Supabase Auth + PostgreSQL RLS + Riverpod + GoRouter
**Confidence:** HIGH

## Summary

Phase 1 establishes the entire project foundation: Flutter web project initialization, Supabase Auth with email/password, session persistence across browser refresh, player profile creation with preset avatars, and automated city placement on first login. The server-authority contract (no client writes to game-state tables) is enforced via RLS policies at migration time.

The stack is well-defined by locked decisions: supabase_flutter 2.12.0, Riverpod 3.x with code generation, GoRouter 17.x with redirect-based auth guards, and Flame added as a dormant dependency. The auto city placement is implemented as a PostgreSQL trigger on `auth.users` — not an Edge Function — because a DB trigger is atomic with user creation and cannot fail silently. The `handle_new_user` trigger pattern is Supabase's official recommended approach for this exact use case.

The biggest implementation risk is the auth-to-profile-to-city creation chain: if the Postgres trigger fails, signups are blocked. The trigger must be tested thoroughly in local Supabase before deployment. RLS must be enabled in the same migration that creates each table — this is a locked project decision and must never be deferred.

**Primary recommendation:** Use the `handle_new_user` Postgres trigger (SECURITY DEFINER) to atomically create profile + city on signup. GoRouter + Riverpod StreamProvider on `supabase.auth.onAuthStateChange` handles all routing guards. All game-state tables get `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` with no INSERT/UPDATE/DELETE policies, blocking client writes entirely.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **Player Profile & Avatar:** Preset avatar set (10-20 ancient Greek themed avatars) — no user upload, no Storage needed. Profile creation screen appears immediately after sign-up — cannot enter game without profile. Display name: 3-20 characters, alphanumeric + underscore, unique constraint in DB. Both display name and avatar can be changed later via settings.
- **Auto City Placement:** New player's city placed on the island with the most empty slots (least populated). Fixed starting resource pack: same amounts for every player (e.g., 500 Wood, 500 Gold, others 0). Only Town Hall (Level 1) pre-built — player builds everything else. Auto-assigned city name from ancient Greek city name pool (Sparta, Athens, etc.) — changeable later.
- **Database Schema Scope:** Phase 1 creates only the tables needed for this phase: profiles, islands, cities. Other tables (resources, buildings, units, etc.) added in their respective phases via new migrations. 100 islands created via seed migration at project setup. Each island has 16-17 city slots, 1 wood resource area, 1 luxury resource area. Luxury resource types (Marble, Crystal, Sulfur) distributed equally across islands (~33 each). RLS enabled in the same migration that creates each table — never added later.
- **Flutter Project Structure:** GoRouter for declarative routing with auth guards. Feature-first folder organization: lib/features/auth/, lib/features/city/, lib/features/map/. Riverpod for state management (per PROJECT.md constraints). Flame engine dependency added in Phase 1, GameWidget wrapper prepared, but map/game rendering deferred to Phase 3. Auth screens are standard Flutter widgets (not Flame).
- **UI Style:** Minimal and clean design — Material 3 based. Ancient Greek color palette (navy blue, gold, white). No illustrations, columns, or parchment textures in v1.
- **Backend/Architecture (from PROJECT.md):** All game mutations go through Edge Functions — no Flutter client writes directly to game-state tables. RLS must be enabled in the same migration that creates each table — never added later. All timestamps are server-side NOW() — client computes display-only countdowns from server UTC.

### Claude's Discretion

- Exact starting resource amounts per type
- Avatar asset selection/style
- Specific ancient Greek city names in the pool
- GoRouter route structure and guard implementation
- Supabase Edge Function naming conventions
- Loading/error state designs

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| AUTH-01 | User can sign up with email and password via Supabase Auth | supabase_flutter 2.12.0 `signUpWithPassword()`, PKCE flow for web, Site URL config for email confirmation redirect |
| AUTH-02 | User can log in and session persists across browser refresh | supabase_flutter uses SharedPreferences by default; `onAuthStateChange` stream provides persistent session detection on app start |
| AUTH-03 | User can create player profile with display name and avatar | `profiles` table with unique display_name constraint; preset avatar stored as avatar_id (1-20); profile screen gated by GoRouter redirect if profile incomplete |
| AUTH-04 | User gets a city automatically placed on an island on first login | `handle_new_user` Postgres trigger (SECURITY DEFINER) selects least-populated island and inserts into `cities`; city auto-named from Greek name pool |
| INFR-02 | All game state mutations run server-side (no client-side calculations) | RLS policies block all INSERT/UPDATE/DELETE from client; only SELECT policies granted; mutations go through SECURITY DEFINER functions or Edge Functions |
| INFR-03 | RLS enabled on every database table from creation | `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` in same migration block that creates the table; verified in migration checklist |
</phase_requirements>

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| supabase_flutter | ^2.12.0 | Supabase client: Auth, DB, Realtime, Storage | Official Supabase-maintained Flutter SDK; handles session persistence automatically |
| flutter_riverpod | ^3.3.1 | Reactive state management and dependency injection | Locked project decision; Riverpod 3.x unifies AutoDispose/Family APIs |
| riverpod_annotation | ^4.0.2 | `@riverpod` annotation for code generation | Required companion to riverpod_generator |
| go_router | ^17.1.0 | Declarative routing with redirect-based auth guards | Locked project decision; official Flutter team package |
| flame | ^1.36.0 | 2D game engine (dormant in Phase 1, activated Phase 3) | Locked project decision; added now so pubspec is stable |

### Supporting (Dev)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| riverpod_generator | ^4.0.3 | Code generation for `@riverpod` providers | Required for code-gen pattern; add to dev_dependencies |
| build_runner | ^2.x | Runs code generators | Required to run `dart run build_runner build` |
| riverpod_lint | ^2.x | Linting for Riverpod scoping errors | Recommended; catches common provider misuse |

### Supabase CLI (local dev)
| Tool | Purpose |
|------|---------|
| supabase CLI | `supabase init`, `supabase start`, `supabase migration new`, `supabase db reset` |
| supabase/migrations/*.sql | Migration files named `<timestamp>_<description>.sql` |
| supabase/seed.sql | Seed data (100 islands, luxury resource distribution) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Postgres trigger for city placement | Supabase Edge Function + DB webhook | Trigger is atomic; webhook can fail silently or have latency |
| Code-gen Riverpod (`@riverpod`) | Manual provider definitions | Code-gen reduces boilerplate, enforces typing; recommended by Riverpod 3.x docs |
| GoRouter redirect | Navigator 2.0 manual | GoRouter is the Flutter-team-endorsed abstraction |

**Installation:**
```bash
flutter pub add supabase_flutter flutter_riverpod riverpod_annotation go_router flame
flutter pub add --dev riverpod_generator build_runner riverpod_lint
```

---

## Architecture Patterns

### Recommended Project Structure
```
lib/
├── main.dart                   # Supabase.initialize() + ProviderScope + GoRouter app
├── core/
│   ├── router/
│   │   └── app_router.dart     # GoRouter config, routes, redirect logic
│   ├── supabase/
│   │   └── supabase_provider.dart  # supabaseClientProvider
│   └── theme/
│       └── app_theme.dart      # Material 3 + ancient Greek palette
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   └── auth_repository.dart
│   │   ├── providers/
│   │   │   ├── auth_state_provider.dart   # StreamProvider on onAuthStateChange
│   │   │   └── auth_state_provider.g.dart # generated
│   │   └── screens/
│   │       ├── login_screen.dart
│   │       └── signup_screen.dart
│   ├── profile/
│   │   ├── data/
│   │   │   └── profile_repository.dart
│   │   ├── providers/
│   │   │   └── profile_provider.dart
│   │   └── screens/
│   │       └── create_profile_screen.dart
│   └── city/
│       └── screens/
│           └── city_screen.dart  # placeholder, Phase 2 fills content
└── shared/
    └── widgets/
        └── loading_overlay.dart

supabase/
├── config.toml
├── migrations/
│   ├── 20260311000000_create_islands.sql
│   ├── 20260311000001_create_profiles.sql
│   ├── 20260311000002_create_cities.sql
│   └── 20260311000003_handle_new_user_trigger.sql
└── seed.sql     # 100 islands with slots + luxury distribution
```

### Pattern 1: Supabase Initialization + Riverpod Root
**What:** Initialize Supabase before runApp, wrap with ProviderScope
**When to use:** Always — required for both packages to work
**Example:**
```dart
// lib/main.dart
// Source: https://supabase.com/docs/reference/dart/initializing
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  runApp(const ProviderScope(child: IkariamApp()));
}
```

### Pattern 2: Auth State Provider (Riverpod 3.x code-gen)
**What:** Stream Supabase auth changes into a Riverpod provider; GoRouter watches it
**When to use:** Foundation of all auth-gated routing
**Example:**
```dart
// lib/features/auth/providers/auth_state_provider.dart
// Source: https://riverpod.dev/docs/whats_new
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_state_provider.g.dart';

@riverpod
Stream<AuthState> authStateChanges(Ref ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
}

@riverpod
User? currentUser(Ref ref) {
  final authState = ref.watch(authStateChangesProvider);
  return authState.when(
    data: (state) => state.session?.user,
    loading: () => Supabase.instance.client.auth.currentUser,
    error: (_, __) => null,
  );
}
```

### Pattern 3: GoRouter with Auth Redirect
**What:** Redirect unauthenticated users to /login; redirect authenticated users without profiles to /create-profile
**When to use:** Every protected route
**Example:**
```dart
// lib/core/router/app_router.dart
// Source: https://pub.dev/packages/go_router (v17.x)
@riverpod
GoRouter appRouter(Ref ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    refreshListenable: _AuthChangeNotifier(ref),
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isAuthRoute = state.matchedLocation == '/login' ||
                          state.matchedLocation == '/signup';

      // Not logged in -> go to login
      if (session == null && !isAuthRoute) return '/login';
      // Logged in but on auth screen -> go to game
      if (session != null && isAuthRoute) return '/city';
      return null; // no redirect
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(path: '/create-profile', builder: (_, __) => const CreateProfileScreen()),
      GoRoute(path: '/city', builder: (_, __) => const CityScreen()),
    ],
  );
}

// Bridges Riverpod state changes to GoRouter's ChangeNotifier system
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen(authStateChangesProvider, (_, __) => notifyListeners());
  }
}
```

### Pattern 4: handle_new_user Postgres Trigger
**What:** Atomically creates profile stub + places city when a user signs up
**When to use:** User creation in auth.users — the ONLY safe place to guarantee it runs
**Example:**
```sql
-- Source: https://supabase.com/docs/guides/auth/managing-user-data
-- Migration: 20260311000003_handle_new_user_trigger.sql

-- Function: creates profile stub (display_name NULL until user fills profile screen)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_island_id   uuid;
  v_slot_number integer;
  v_city_name   text;
  v_city_names  text[] := ARRAY[
    'Sparta','Athens','Corinth','Argos','Thebes','Delphi','Rhodes',
    'Olympia','Mycenae','Epidaurus','Megara','Tegea','Sicyon','Phlius',
    'Mantinea','Elis','Ithaca','Pylos','Tiryns','Nafplio'
  ];
BEGIN
  -- Find island with most empty slots (least populated)
  SELECT i.id, (i.max_city_slots - COUNT(c.id)) AS empty_slots
  INTO v_island_id
  FROM public.islands i
  LEFT JOIN public.cities c ON c.island_id = i.id
  GROUP BY i.id, i.max_city_slots
  HAVING COUNT(c.id) < i.max_city_slots
  ORDER BY empty_slots DESC
  LIMIT 1;

  -- Assign next available slot number on that island
  SELECT COALESCE(MAX(slot_number), 0) + 1
  INTO v_slot_number
  FROM public.cities
  WHERE island_id = v_island_id;

  -- Pick random city name from pool
  v_city_name := v_city_names[1 + floor(random() * array_length(v_city_names, 1))::int];

  -- Insert profile stub (no display_name yet — user fills this in the profile screen)
  INSERT INTO public.profiles (id, avatar_id)
  VALUES (NEW.id, 1);  -- default avatar_id=1 until user picks

  -- Place city on the island
  INSERT INTO public.cities (owner_id, island_id, slot_number, name)
  VALUES (NEW.id, v_island_id, v_slot_number, v_city_name);

  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
```

### Pattern 5: RLS — Block Client Writes, Allow Server Writes
**What:** Tables have RLS enabled but NO insert/update/delete policies for the `authenticated` role. Only SELECT is permitted. Server-side mutations use SECURITY DEFINER functions.
**When to use:** All game-state tables (`cities`, `islands`, and all future tables)
**Example:**
```sql
-- Source: https://supabase.com/docs/guides/database/postgres/row-level-security
-- In the SAME migration that creates the table:

ALTER TABLE public.cities ENABLE ROW LEVEL SECURITY;

-- Players can read any city (needed for map display later)
CREATE POLICY "cities_select_authenticated"
  ON public.cities FOR SELECT
  TO authenticated
  USING (true);

-- NO INSERT/UPDATE/DELETE policies = Flutter client cannot mutate cities
-- Server functions use SECURITY DEFINER (bypasses RLS) to write

-- Profiles: users can read all, update only their own
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select_all"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "profiles_update_own"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);
-- Note: INSERT on profiles comes from the trigger (SECURITY DEFINER) — no client INSERT policy needed
```

### Anti-Patterns to Avoid
- **Adding RLS after table creation:** The project mandates RLS in the same migration. A table that exists without RLS is accessible to the anon role by default.
- **Using `security definer` without `set search_path = ''`:** Allows SQL injection via schema search path manipulation.
- **Calling edge functions for synchronous profile creation:** Edge functions invoked via DB webhooks can fail silently or add latency. Use a Postgres trigger for atomic user setup.
- **Storing SUPABASE_URL and SUPABASE_ANON_KEY in source code:** Use `--dart-define` at build time or environment variables.
- **Triggering GoRouter rebuild by reconstructing the router object:** Use a stable `ChangeNotifier` that calls `notifyListeners()` on auth changes; do not recreate the GoRouter instance.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Auth session persistence | Custom token storage in localStorage | supabase_flutter built-in SharedPreferences storage | Handles token refresh, expiry, web/mobile differences |
| Auth state routing guards | Manual `Navigator.pushReplacement` in initState | GoRouter `redirect` + `refreshListenable` | Declarative, handles deep links, back button, web URL bar |
| Profile form validation | Custom regex in widget | Flutter's `Form` + `TextFormField` validators with `RegExp(r'^[a-zA-Z0-9_]{3,20}$')` | Built-in, battle-tested |
| Island slot selection algorithm | Application-level code in Flutter | Postgres function in `handle_new_user` trigger | Runs atomically with user creation; cannot be race-conditioned |
| Display name uniqueness check | Client-side query before insert | Postgres `UNIQUE` constraint on `profiles.display_name` | DB-level enforcement; client-side check has race condition |
| Auth email confirmation redirect | Custom URL handler | Supabase PKCE flow + Site URL config in dashboard | supabase_flutter SDK v2 auto-detects auth callback URLs |

**Key insight:** In a multiplayer game, any uniqueness or placement logic done client-side has race conditions. Push it all to the database where transactions and constraints can enforce it atomically.

---

## Common Pitfalls

### Pitfall 1: handle_new_user Trigger Failure Blocks Signups
**What goes wrong:** If the trigger throws an exception (e.g., no islands exist yet, query returns null), the `INSERT INTO auth.users` is rolled back and the user gets a generic signup error.
**Why it happens:** The trigger runs inside the same transaction as user creation.
**How to avoid:** Seed 100 islands BEFORE the trigger is created (or use a separate seed migration that runs first). Add a `WHEN (EXISTS (SELECT 1 FROM public.islands LIMIT 1))` guard or a `EXCEPTION WHEN OTHERS THEN RETURN NEW` block with logging.
**Warning signs:** Signup returns 500 or "Database error saving new user" message.

### Pitfall 2: RLS Blocks the Trigger Itself
**What goes wrong:** Trigger is SECURITY DEFINER but inserts into a table where even the postgres role is restricted.
**Why it happens:** `set search_path = ''` in SECURITY DEFINER functions means you must use fully qualified schema names (`public.profiles`, not just `profiles`).
**How to avoid:** Always use `public.table_name` in trigger functions. Test via `supabase db reset` locally.
**Warning signs:** Trigger appears to run but no row appears in profiles or cities.

### Pitfall 3: Auth Redirect URL Not Configured for Flutter Web
**What goes wrong:** Email confirmation link redirects to `localhost:3000` in production, or the confirmation token is lost.
**Why it happens:** Supabase's `Site URL` defaults to `localhost:3000`. Flutter web at the production URL is a different origin.
**How to avoid:** Set `Site URL` to the production domain in Supabase Auth settings. Add `http://localhost:PORT` to "Additional Redirect URLs" for local dev. The supabase_flutter SDK v2 auto-handles PKCE code exchange — no manual `authCallbackUrlHostname` needed.
**Warning signs:** Clicking the confirmation email link shows a 404 or blank page.

### Pitfall 4: GoRouter Rebuilds on Every Auth State Change
**What goes wrong:** The GoRouter provider is reconstructed every time auth state changes, causing navigation to reset or flash.
**Why it happens:** If `routerProvider` returns a new `GoRouter()` instance on each watch, every rebuild recreates the router.
**How to avoid:** Create the GoRouter once (use `ref.listenSelf` or a stable ChangeNotifier). Pass auth state via the `redirect` callback which is re-evaluated on `refreshListenable.notifyListeners()`, not by creating a new router.
**Warning signs:** Users see the login screen flash briefly after logging in, or the back button stops working.

### Pitfall 5: Profile Screen Not Gated Properly
**What goes wrong:** A user who has authenticated but not yet set their display_name can reach the city/game screens.
**Why it happens:** The auth redirect only checks session existence, not profile completeness.
**How to avoid:** Add a second redirect check in GoRouter: if `session != null` but profile has no `display_name`, redirect to `/create-profile`. The profile provider fetches the row by `auth.uid()` on startup.
**Warning signs:** Users reach the game with a null display_name, causing DB constraint errors later.

### Pitfall 6: Display Name Race Condition
**What goes wrong:** Two users submit the same display_name at the same instant; both pass the availability check, one gets a 23505 unique violation.
**Why it happens:** Any client-side "check if name is taken" query has a TOCTOU race.
**How to avoid:** Catch `PostgrestException` with code `23505` on the `UPDATE profiles SET display_name = ?` call. Show "That name is already taken" error to the user.
**Warning signs:** Intermittent unique constraint errors during profile creation.

---

## Code Examples

### Supabase Auth: Sign Up
```dart
// Source: https://supabase.com/docs/reference/dart/auth-signup
final AuthResponse res = await Supabase.instance.client.auth.signUpWithPassword(
  email: email,
  password: password,
);
// After signup: handle_new_user trigger fires server-side
// User is redirected to /create-profile to set display_name + avatar_id
```

### Supabase Auth: Sign In
```dart
// Source: https://supabase.com/docs/reference/dart/auth-signinwithpassword
final AuthResponse res = await Supabase.instance.client.auth.signInWithPassword(
  email: email,
  password: password,
);
```

### Profile Update (display_name + avatar_id)
```dart
// Source: supabase_flutter v2 API
await Supabase.instance.client
  .from('profiles')
  .update({'display_name': displayName, 'avatar_id': avatarId})
  .eq('id', Supabase.instance.client.auth.currentUser!.id);
// Catch PostgrestException code '23505' for unique violation on display_name
```

### Migration: islands table with RLS
```sql
-- Migration: 20260311000000_create_islands.sql
CREATE TABLE public.islands (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  grid_x          integer NOT NULL,
  grid_y          integer NOT NULL,
  max_city_slots  integer NOT NULL DEFAULT 16,
  wood_level      integer NOT NULL DEFAULT 1,  -- resource richness
  luxury_type     text NOT NULL CHECK (luxury_type IN ('marble', 'crystal', 'sulfur')),
  luxury_level    integer NOT NULL DEFAULT 1,
  created_at      timestamptz NOT NULL DEFAULT NOW()
);

ALTER TABLE public.islands ENABLE ROW LEVEL SECURITY;

CREATE POLICY "islands_select_authenticated"
  ON public.islands FOR SELECT
  TO authenticated
  USING (true);
-- No INSERT/UPDATE/DELETE from client
```

### Migration: profiles table with RLS
```sql
-- Migration: 20260311000001_create_profiles.sql
CREATE TABLE public.profiles (
  id              uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name    text UNIQUE CHECK (char_length(display_name) BETWEEN 3 AND 20
                    AND display_name ~ '^[a-zA-Z0-9_]+$'),
  avatar_id       integer NOT NULL DEFAULT 1
                    CHECK (avatar_id BETWEEN 1 AND 20),
  created_at      timestamptz NOT NULL DEFAULT NOW(),
  updated_at      timestamptz NOT NULL DEFAULT NOW()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select_all"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "profiles_update_own"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);
```

### Migration: cities table with RLS
```sql
-- Migration: 20260311000002_create_cities.sql
CREATE TABLE public.cities (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id        uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  island_id       uuid NOT NULL REFERENCES public.islands(id),
  slot_number     integer NOT NULL CHECK (slot_number BETWEEN 1 AND 17),
  name            text NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (island_id, slot_number)
);

ALTER TABLE public.cities ENABLE ROW LEVEL SECURITY;

CREATE POLICY "cities_select_authenticated"
  ON public.cities FOR SELECT
  TO authenticated
  USING (true);
-- No client INSERT/UPDATE/DELETE
```

### Seed: 100 islands
```sql
-- supabase/seed.sql (excerpt — generated with a series of INSERTs)
-- 100 islands in a 10x10 grid, luxury types evenly distributed (~33 each)
DO $$
DECLARE
  x int;
  y int;
  luxury_types text[] := ARRAY['marble','crystal','sulfur'];
  idx int := 0;
BEGIN
  FOR x IN 1..10 LOOP
    FOR y IN 1..10 LOOP
      INSERT INTO public.islands (grid_x, grid_y, luxury_type, max_city_slots)
      VALUES (x, y, luxury_types[1 + (idx % 3)], 16 + (CASE WHEN (idx % 5) = 0 THEN 1 ELSE 0 END));
      idx := idx + 1;
    END LOOP;
  END LOOP;
END;
$$;
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `StateNotifier` + manual providers | `@riverpod` code-gen with `AsyncNotifier` | Riverpod 2.0 / 3.0 | Less boilerplate, stronger typing, Ref unification |
| `AutoDisposeNotifier`, `FamilyNotifier` separate classes | Unified `Notifier` with keep-alive modifiers | Riverpod 3.0 | Simpler API |
| `authCallbackUrlHostname` in `Supabase.initialize()` | Removed — SDK auto-detects | supabase_flutter 2.x | Less config needed for web auth callbacks |
| Manual `OAuthProvider` enum clash with `provider` package | Renamed to `OAuthProvider` in supabase_flutter 2.x | supabase_flutter 2.0 | Can use Supabase and Provider package in same project without prefixes |
| `supabase.from('table').stream()` for realtime | `supabase.from('table').stream()` still valid; `.onAuthStateChange` is the standard auth stream | Ongoing | Use `.onAuthStateChange` not polling for session |

**Deprecated/outdated:**
- `authCallbackUrlHostname` parameter: removed in supabase_flutter 2.x — do not use
- `StateNotifierProvider`: still functional but Riverpod docs recommend migrating to `@riverpod` + `Notifier`/`AsyncNotifier`

---

## Open Questions

1. **Email confirmation behavior for new signups**
   - What we know: Supabase Auth sends a confirmation email by default. The `Site URL` must be set to the Flutter web app's URL for the link to work.
   - What's unclear: Should Phase 1 require email confirmation before granting access, or allow immediate login? The profile creation screen could serve as a soft gate while confirmation is pending.
   - Recommendation: Disable email confirmation requirement for Phase 1 development (in Supabase Auth settings: "Confirm email" toggle). Re-enable before production deployment with proper Site URL configured.

2. **Profile completeness check in GoRouter**
   - What we know: GoRouter redirect can check `session != null` for auth. Checking profile completeness requires an async DB fetch.
   - What's unclear: GoRouter's `redirect` callback is synchronous. Checking if `display_name` is set requires the profile to be loaded in a Riverpod provider first.
   - Recommendation: Create a `profileProvider` (AsyncNotifier) that fetches `profiles.display_name` on app start. GoRouter redirect checks `ref.read(profileProvider)` — if `AsyncLoading`, redirect to a `/loading` splash; if `display_name == null`, redirect to `/create-profile`.

3. **Starting resource amounts**
   - What we know: Fixed starting pack (Claude's discretion). Resources table is Phase 2.
   - What's unclear: Should Phase 1 store starting resources in the `cities` table as JSONB, or wait for Phase 2's resources table?
   - Recommendation: Do NOT store resource amounts in Phase 1's cities table. Resources are Phase 2's responsibility. The trigger only creates the city shell. Phase 2 migration adds the resources table and a separate trigger/function to populate starting resources.

---

## Validation Architecture

> nyquist_validation key not found in config — treating as enabled.

### Test Framework

This is a greenfield Flutter project. No test infrastructure exists yet.

| Property | Value |
|----------|-------|
| Framework | Flutter test (built-in) + integration_test package |
| Config file | None — created in Wave 0 |
| Quick run command | `flutter test test/unit/ --reporter compact` |
| Full suite command | `flutter test --reporter compact` |
| Integration tests | `flutter test integration_test/ -d chrome` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AUTH-01 | signUpWithPassword creates user in Supabase | Integration (needs Supabase local) | `flutter test integration_test/auth_test.dart -d chrome` | ❌ Wave 0 |
| AUTH-02 | Session persists after hot-restart simulation | Widget test (mock Supabase) | `flutter test test/unit/auth_persistence_test.dart` | ❌ Wave 0 |
| AUTH-03 | Profile form validates 3-20 chars, alphanumeric+_ | Widget test | `flutter test test/unit/profile_validation_test.dart` | ❌ Wave 0 |
| AUTH-03 | Unique constraint violation surfaces as "name taken" | Widget test (mock repository) | `flutter test test/unit/profile_name_taken_test.dart` | ❌ Wave 0 |
| AUTH-04 | City auto-placed on signup (trigger fires) | Integration (needs Supabase local) | `flutter test integration_test/city_placement_test.dart -d chrome` | ❌ Wave 0 |
| INFR-02 | Flutter client cannot INSERT into cities directly | Integration (needs Supabase local) | `flutter test integration_test/rls_test.dart -d chrome` | ❌ Wave 0 |
| INFR-03 | RLS enabled on islands/profiles/cities tables | DB migration test (psql) | `supabase db reset && psql ... -c "SELECT tablename FROM pg_tables ..."` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/unit/ --reporter compact`
- **Per wave merge:** `flutter test --reporter compact`
- **Phase gate:** Full suite + `supabase db reset` (clean migration run) green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/unit/profile_validation_test.dart` — covers AUTH-03 display_name validation
- [ ] `test/unit/auth_persistence_test.dart` — covers AUTH-02 with mocked Supabase session
- [ ] `integration_test/auth_test.dart` — covers AUTH-01 full signup flow
- [ ] `integration_test/city_placement_test.dart` — covers AUTH-04 trigger behavior
- [ ] `integration_test/rls_test.dart` — covers INFR-02 + INFR-03
- [ ] Framework install: `flutter pub add --dev integration_test` (if not already present via Flutter SDK)

---

## Sources

### Primary (HIGH confidence)
- [supabase_flutter pub.dev](https://pub.dev/packages/supabase_flutter) — version 2.12.0, initialization API
- [flutter_riverpod pub.dev](https://pub.dev/packages/flutter_riverpod) — version 3.3.1
- [riverpod_annotation pub.dev](https://pub.dev/packages/riverpod_annotation) — version 4.0.2
- [riverpod_generator pub.dev](https://pub.dev/packages/riverpod_generator) — version 4.0.3
- [go_router pub.dev](https://pub.dev/packages/go_router) — version 17.1.0
- [flame pub.dev](https://pub.dev/packages/flame) — version 1.36.0
- [Supabase: Managing User Data (handle_new_user trigger)](https://supabase.com/docs/guides/auth/managing-user-data) — official trigger pattern
- [Supabase: Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security) — RLS policy syntax
- [Riverpod 3.0 What's New](https://riverpod.dev/docs/whats_new) — Riverpod 3.x API changes

### Secondary (MEDIUM confidence)
- [Supabase Auth Hooks docs](https://supabase.com/docs/guides/auth/auth-hooks) — confirmed no "after user created" hook; Postgres trigger is the right approach
- [apparencekit.dev: Flutter + Riverpod + GoRouter redirect](https://apparencekit.dev/blog/flutter-riverpod-gorouter-redirect/) — GoRouter + Riverpod auth pattern (verified against go_router 17.x docs)
- [Supabase Local Development](https://supabase.com/docs/guides/local-development/overview) — migration file structure and CLI workflow
- [Supabase Redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls) — PKCE flow and Site URL configuration

### Tertiary (LOW confidence)
- Medium/community articles on Riverpod 2.x patterns — superseded by Riverpod 3.x; verify any code samples against official docs

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all versions verified directly from pub.dev on 2026-03-11
- Architecture: HIGH — Postgres trigger pattern from official Supabase docs; GoRouter/Riverpod patterns from official packages
- Pitfalls: HIGH — trigger-blocks-signup and RLS-blocks-trigger are documented Supabase gotchas with official troubleshooting pages
- Test infrastructure: MEDIUM — Flutter test framework is standard; specific test file contents need authoring in Wave 0

**Research date:** 2026-03-11
**Valid until:** 2026-04-11 (30 days — stable ecosystem; Riverpod 3.x and supabase_flutter 2.x are recent majors, unlikely to have breaking changes in 30 days)
