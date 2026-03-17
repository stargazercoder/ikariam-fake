# Phase 18: Bot Schema Foundation - Research

**Researched:** 2026-03-17
**Domain:** PostgreSQL schema migration + Dart Map model extension
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- `is_bot BOOLEAN NOT NULL DEFAULT false` added to `profiles` table — marks bot accounts
- `is_admin BOOLEAN NOT NULL DEFAULT false` added to `profiles` table — gates GodMode access
- Both columns default to false so existing rows are unaffected (no data migration needed)
- New `bot_schedules` table with FK to profiles(id) WHERE is_bot = true
- Columns: `aggression INTEGER NOT NULL DEFAULT 1 CHECK (aggression BETWEEN 0 AND 3)`, `is_paused BOOLEAN NOT NULL DEFAULT false`, `next_action_at TIMESTAMPTZ`
- RLS enabled on `bot_schedules`; no client-facing SELECT policy (only SECURITY DEFINER functions and admin RPCs read this)
- Bots remain visible in profiles SELECT (existing `profiles_select_all` policy unchanged)
- `bot_schedules` has NO authenticated user policy — only server-side SECURITY DEFINER functions access it
- `is_admin` is readable by all but only the DB can set it (no UPDATE policy for is_admin column)
- Add `bool isBot` and `bool isAdmin` fields to Profile model with `false` defaults
- Use `(json['is_bot'] as bool?) ?? false` pattern for backwards compatibility
- ProfileNotifier and profileProvider remain unchanged — just reads additional fields

### Claude's Discretion
- Exact migration filename timestamp
- Whether to add a database index on `is_bot` (low cardinality — probably not needed for 20 bots)
- Column ordering in the migration

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| BOT-01 | 20 bot accounts exist on the world map with varied military, building, and resource levels | Schema foundation: `is_bot` column and `bot_schedules` table are the prerequisite for bot account creation in Phase 20 |
| BOT-06 | Bot behaviors are guarded by is_bot flag and invisible to non-admin players | `bot_schedules` RLS with no client-facing policies; `is_admin` column gates GodMode; `is_bot` flag enables server-side filtering in Phase 19 bot functions |
</phase_requirements>

---

## Summary

Phase 18 is a pure schema migration phase. It adds two boolean columns to the existing `profiles` table, creates a new `bot_schedules` table, and extends the Profile Dart model (currently a raw `Map<String, dynamic>`) to surface `isBot` and `isAdmin` boolean fields. No business logic, no bot behaviors, no seed data — only schema.

The existing codebase uses `ProfileRepository.fetchProfile()` with a bare `.select()` that returns all columns. The new columns are automatically included in every subsequent profile fetch with zero changes to the query layer. The `ProfileNotifier.build()` method reads the returned map directly, so the only Dart change is adding two accessor fields that read from the map.

The `bot_schedules` table is a control table for Phase 19 (bot behavior). It must exist now to unblock that phase. Its RLS setup is the critical security piece: enabling RLS with no client policies means no authenticated Flutter client can query it at all — reads are restricted to `SECURITY DEFINER` functions (pg_cron, GodMode RPCs).

**Primary recommendation:** Two migration files (one for `profiles` columns + `bot_schedules` table, one is not needed — combine both into a single `bot_schema` migration) plus a single Dart file edit to `profile_provider.dart` adding two bool getters. No new providers, no new screens, no behavioral code.

---

## Standard Stack

### Core (already in project — no new dependencies)
| Component | Version | Purpose | Notes |
|-----------|---------|---------|-------|
| Supabase PostgreSQL migrations | Existing | Schema definition via `.sql` migration files | Pattern established across 36 existing migrations |
| Flutter / Dart | Existing | Client model extension | Profile is a raw `Map<String, dynamic>` — no typed class to update |
| Riverpod AsyncNotifier | Existing | Profile state management | ProfileNotifier unchanged; only the data it returns gains new fields |

### No New Libraries Required
This phase adds no new packages to `pubspec.yaml`. All work is SQL migrations + Dart map field accessors.

**Installation:** None required.

---

## Architecture Patterns

### Recommended Migration Structure
```
supabase/migrations/
├── [existing 36 migrations — unchanged]
└── 20260317000001_bot_schema.sql   # profiles columns + bot_schedules table
```

A single migration file is correct here. The `profiles` ALTER and `bot_schedules` CREATE are logically one atomic schema change — they both must succeed together or not at all.

### Pattern 1: ALTER TABLE ADD COLUMN with DEFAULT (existing pattern)
**What:** Add nullable-safe boolean columns with NOT NULL DEFAULT false
**When to use:** Adding flags to existing tables where existing rows must be unaffected
**Example:**
```sql
-- Source: ARCHITECTURE.md verified pattern + Supabase official ALTER TABLE docs
ALTER TABLE public.profiles
  ADD COLUMN is_bot   boolean NOT NULL DEFAULT false,
  ADD COLUMN is_admin boolean NOT NULL DEFAULT false;
```
Both columns are added in a single `ALTER TABLE` statement. PostgreSQL fills existing rows with `DEFAULT false` atomically — no row update needed and no table lock beyond the schema change itself.

### Pattern 2: New RLS Table with No Client Policy
**What:** Enable RLS on a table but define no `TO authenticated` policies — clients cannot read or write
**When to use:** Server-only tables accessed exclusively by SECURITY DEFINER functions
**Example:**
```sql
-- Source: ARCHITECTURE.md — bot_schedules design
CREATE TABLE public.bot_schedules (
  bot_id         uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  is_paused      boolean NOT NULL DEFAULT false,
  aggression     integer NOT NULL DEFAULT 1 CHECK (aggression BETWEEN 0 AND 3),
  next_action_at timestamptz NOT NULL DEFAULT NOW()
);

ALTER TABLE public.bot_schedules ENABLE ROW LEVEL SECURITY;
-- Intentionally no policies: only SECURITY DEFINER functions can access this table.
-- Authenticated clients receive zero rows (RLS denies by default when no policy matches).
```
This is the correct Supabase pattern: RLS enabled + no policies = deny all from client. SECURITY DEFINER functions run as the function owner (bypassing RLS), so pg_cron functions and admin RPCs still work.

### Pattern 3: Dart Map Extension Fields
**What:** Add boolean accessors to the existing Map-based profile without introducing a typed class
**When to use:** Profile model is `Map<String, dynamic>?` — the CONTEXT.md explicitly states "keep as Map for this phase"
**Example:**
```dart
// Source: CONTEXT.md canonical pattern — backwards compatible null-safe read
// In profile_provider.dart — add convenience getters to ProfileNotifier

bool get isBot {
  return state.whenOrNull(
    data: (profile) => (profile?['is_bot'] as bool?) ?? false,
  ) ?? false;
}

bool get isAdmin {
  return state.whenOrNull(
    data: (profile) => (profile?['is_admin'] as bool?) ?? false,
  ) ?? false;
}
```
The `(json['is_bot'] as bool?) ?? false` pattern is critical for backwards compatibility: if a cached profile map was loaded before the migration ran, `json['is_bot']` returns null (key absent), and the null-coalescing returns `false` safely.

### Pattern 4: Migration Naming Convention
**What:** `YYYYMMDDNNNNNN_description.sql` — date-prefixed with sequential counter
**When to use:** Every new migration in this project
**Example:**
```
20260317000001_bot_schema.sql
```
Last existing migration is `20260316000003_spy_reports.sql`. Next date prefix is `20260317` (today). Counter starts at `000001`.

### Anti-Patterns to Avoid
- **Separate migration files for profiles ALTER and bot_schedules CREATE:** These are one logical unit; splitting adds complexity with no benefit for a schema-only phase.
- **Adding a typed Dart Profile class:** Explicitly out of scope per CONTEXT.md. The Map pattern is established across all existing models.
- **Client-facing RLS policy on bot_schedules:** Even a SELECT-only policy would expose bot scheduling data to any logged-in player. No policies is the correct choice.
- **UPDATE policy for is_admin column:** The profiles_update_own policy covers the whole row. To prevent clients from setting is_admin, the migration should NOT add a column-level UPDATE grant. The existing `profiles_update_own` policy allows updating display_name and avatar_id. Since `updateProfile()` in ProfileRepository only sends `{'display_name': ..., 'avatar_id': ...}`, is_admin is never sent in the UPDATE payload — no additional policy restriction needed at the column level.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Checking if calling user is admin | Custom auth check in Flutter | PostgreSQL `is_admin` column read via existing profileProvider | Admin check belongs in DB; profile row already loaded on startup |
| Hiding bot_schedules from clients | Separate schema / view | RLS with no client policy | Built-in Postgres RLS is the established pattern in this project |
| Backfilling existing rows | UPDATE migration | DEFAULT false on ADD COLUMN | PostgreSQL fills existing rows automatically — no explicit UPDATE needed |

**Key insight:** Supabase's RLS "deny by default" behavior is the entire security mechanism for `bot_schedules`. When RLS is enabled and no matching policy exists, the query returns zero rows (not an error). This is correct and intentional.

---

## Common Pitfalls

### Pitfall 1: profiles_update_own Policy Inadvertently Exposes is_admin to Client Updates
**What goes wrong:** A player could call `supabase.from('profiles').update({'is_admin': true}).eq('id', userId)` and it would succeed if the existing `profiles_update_own` policy (USING + WITH CHECK = `auth.uid() = id`) allows any column update.
**Why it happens:** The existing policy has no column-level restrictions. PostgreSQL RLS policies are row-level, not column-level by default.
**How to avoid:** Two approaches — (A) The simplest: document that `ProfileRepository.updateProfile()` only sends `display_name` and `avatar_id` — is_admin is never sent. Since there is no Flutter code path that sends is_admin in an update, it is unreachable from the client. (B) Stronger: use a column-level privilege (`REVOKE UPDATE (is_admin, is_bot) ON public.profiles FROM authenticated`) to make it enforced at the DB layer. Approach B is more defensible for a production system.
**Warning signs:** Any `supabase.from('profiles').update({...})` call in Flutter that includes `is_admin` or `is_bot` keys.

### Pitfall 2: bot_schedules FK to profiles(id) Without is_bot Check
**What goes wrong:** The FK `REFERENCES public.profiles(id)` allows any profile (including real players) to have a `bot_schedules` row inserted by a SECURITY DEFINER function.
**Why it happens:** Standard FK constraint doesn't filter by column value.
**How to avoid:** The CONTEXT.md notes the FK is "WHERE is_bot = true" — this is a partial FK constraint. Standard PostgreSQL FKs don't support WHERE clauses. The correct approach is to add a CHECK constraint on the bot_schedules insert path (in the SECURITY DEFINER function that inserts rows) or rely on application logic. For Phase 18 (schema only), a comment in the migration is sufficient. The actual enforcement happens in Phase 20 seed and Phase 19 bot logic. Alternatively, add a trigger `BEFORE INSERT ON bot_schedules` that checks `is_bot = true`.
**Warning signs:** A real player's profile_id appearing in `bot_schedules`.

### Pitfall 3: next_action_at Nullable vs NOT NULL
**What goes wrong:** CONTEXT.md specifies `next_action_at TIMESTAMPTZ` (no NOT NULL) but the ARCHITECTURE.md shows `next_action_at timestamptz NOT NULL DEFAULT NOW()`. The difference matters: if NULL, `run_bot_decisions()` must handle null values in its WHERE clause (`next_action_at <= NOW()` returns false for NULL in SQL).
**Why it happens:** Two documents written independently with slightly different specs.
**How to avoid:** Use `NOT NULL DEFAULT NOW()` as defined in ARCHITECTURE.md. This is the safer choice — a bot with `next_action_at = NOW()` at creation is immediately eligible for its first tick, which is correct. NULL would mean the bot is perpetually ineligible.
**Warning signs:** `bot_schedules` rows with NULL `next_action_at` after Phase 20 seed runs.

### Pitfall 4: Migration Runs in Wrong Order Relative to Existing Migrations
**What goes wrong:** If the new migration filename sorts before an existing migration that the new one depends on (e.g., profiles table), the migration could fail.
**Why it happens:** Supabase applies migrations in filename sort order.
**How to avoid:** Use date prefix `20260317` — all existing migrations are `20260316` or earlier. The new migration will always run last. Confirmed: last existing migration is `20260316000003_spy_reports.sql`.

---

## Code Examples

Verified patterns from existing codebase and ARCHITECTURE.md:

### Complete Migration File
```sql
-- Migration: bot schema foundation
-- Adds is_bot and is_admin columns to profiles table.
-- Creates bot_schedules table for Phase 19 bot behavior control.
-- No existing RLS policies are modified.
-- SECURITY NOTE: bot_schedules has RLS enabled with no client policies —
--   authenticated clients receive zero rows. Only SECURITY DEFINER functions
--   (pg_cron, GodMode RPCs) can read/write this table.

-- Step 1: Add bot flag columns to profiles
-- Both default false; existing rows are unaffected (no data migration needed).
ALTER TABLE public.profiles
  ADD COLUMN is_bot   boolean NOT NULL DEFAULT false,
  ADD COLUMN is_admin boolean NOT NULL DEFAULT false;

-- Step 2: Create bot_schedules table
-- bot_id is both PK and FK — one schedule row per bot account.
-- ON DELETE CASCADE ensures cleanup when a bot profile is deleted.
CREATE TABLE public.bot_schedules (
  bot_id         uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  is_paused      boolean     NOT NULL DEFAULT false,
  aggression     integer     NOT NULL DEFAULT 1 CHECK (aggression BETWEEN 0 AND 3),
  next_action_at timestamptz NOT NULL DEFAULT NOW()
);

-- Enable RLS with no policies: authenticated clients cannot read this table.
-- SECURITY DEFINER functions (run_bot_decisions, godmode RPCs) bypass RLS.
ALTER TABLE public.bot_schedules ENABLE ROW LEVEL SECURITY;
```

### Profile Provider Dart Extension
```dart
// Source: CONTEXT.md pattern — add to ProfileNotifier in profile_provider.dart

/// Returns true when the current user's account is flagged as a bot.
/// Always false for real players; only true for server-managed bot accounts.
bool get isBot {
  return state.whenOrNull(
    data: (profile) => (profile?['is_bot'] as bool?) ?? false,
  ) ?? false;
}

/// Returns true when the current user has admin (GodMode) access.
/// Used by GoRouter redirect guard and future GodMode screen.
bool get isAdmin {
  return state.whenOrNull(
    data: (profile) => (profile?['is_admin'] as bool?) ?? false,
  ) ?? false;
}
```

### Dart Unit Test Pattern
```dart
// Source: existing test/unit/ pattern in this project
// File: test/unit/profile_bot_fields_test.dart

test('isBot defaults to false when key absent', () {
  // Simulate a cached profile map without is_bot key (pre-migration data)
  final map = <String, dynamic>{'display_name': 'Alice', 'avatar_id': 1};
  final isBot = (map['is_bot'] as bool?) ?? false;
  expect(isBot, false);
});

test('isBot returns true when is_bot is true', () {
  final map = <String, dynamic>{'display_name': 'BotAres', 'is_bot': true};
  final isBot = (map['is_bot'] as bool?) ?? false;
  expect(isBot, true);
});

test('isAdmin defaults to false when key absent', () {
  final map = <String, dynamic>{'display_name': 'Alice'};
  final isAdmin = (map['is_admin'] as bool?) ?? false;
  expect(isAdmin, false);
});
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Typed Dart model class | Raw `Map<String, dynamic>` | Project inception | No change needed; add accessors to notifier |
| Multiple ALTER TABLE statements | Single multi-column ALTER | Standard PostgreSQL | Atomic: both columns added or neither |

**No deprecated approaches in scope for this phase.**

---

## Open Questions

1. **Column-level UPDATE restriction for is_bot and is_admin**
   - What we know: The existing `profiles_update_own` policy allows any column update for the authenticated user's own row. `ProfileRepository.updateProfile()` only sends `display_name` and `avatar_id` so is_admin is never sent in practice.
   - What's unclear: Whether to add explicit column-level REVOKE to make the protection DB-enforced rather than application-enforced.
   - Recommendation: Add `REVOKE UPDATE (is_bot, is_admin) ON public.profiles FROM authenticated;` to the migration for defense-in-depth. This costs one line and provides hard DB-layer protection without affecting any existing functionality.

2. **Where to place isBot/isAdmin getters: ProfileNotifier or a separate extension**
   - What we know: ProfileNotifier currently has `hasCompletedProfile` as a similar getter. The pattern of adding getters to the notifier is established.
   - What's unclear: Whether the planner should create a separate `lib/features/profile/models/profile_extensions.dart` or keep all getters in the notifier.
   - Recommendation: Add to ProfileNotifier directly (consistent with `hasCompletedProfile` pattern). A separate file adds indirection with no benefit at this scale.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (existing, no config file needed) |
| Config file | none — uses pubspec.yaml flutter test configuration |
| Quick run command | `flutter test test/unit/profile_bot_fields_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BOT-06 | `isBot` accessor returns false when key absent from map | unit | `flutter test test/unit/profile_bot_fields_test.dart -x` | Wave 0 |
| BOT-06 | `isBot` accessor returns true when `is_bot: true` in map | unit | `flutter test test/unit/profile_bot_fields_test.dart -x` | Wave 0 |
| BOT-06 | `isAdmin` accessor returns false when key absent | unit | `flutter test test/unit/profile_bot_fields_test.dart -x` | Wave 0 |
| BOT-06 | `isAdmin` accessor returns true when `is_admin: true` | unit | `flutter test test/unit/profile_bot_fields_test.dart -x` | Wave 0 |
| BOT-01 | SQL migration applies without error (smoke) | manual | `supabase db reset --local` | N/A — manual |
| BOT-06 | bot_schedules inaccessible to authenticated client (RLS) | manual | Supabase Studio or psql query | N/A — manual |

### Sampling Rate
- **Per task commit:** `flutter test test/unit/profile_bot_fields_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/unit/profile_bot_fields_test.dart` — covers BOT-06 (isBot/isAdmin accessor round-trip)

---

## Sources

### Primary (HIGH confidence)
- Direct codebase read: `supabase/migrations/20260311000001_create_profiles.sql` — current profiles table definition and RLS policies
- Direct codebase read: `lib/features/profile/providers/profile_provider.dart` — ProfileNotifier pattern for adding getters
- Direct codebase read: `lib/features/profile/data/profile_repository.dart` — `.select()` returns all columns including new ones
- `.planning/research/ARCHITECTURE.md` — bot_schedules exact SQL, ALTER TABLE pattern, complete column spec
- `.planning/research/PITFALLS.md` — RLS deny-by-default behavior, column-level update risks

### Secondary (MEDIUM confidence)
- Supabase RLS official docs (referenced in ARCHITECTURE.md) — RLS enabled + no policies = deny all from authenticated role
- PostgreSQL ALTER TABLE docs — multi-column ADD COLUMN with DEFAULT fills existing rows atomically

### Tertiary (LOW confidence)
None — all findings supported by direct codebase examination or official-doc-backed architecture research.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — entire stack is existing project stack, no new libraries
- Architecture: HIGH — SQL patterns lifted directly from ARCHITECTURE.md, which was verified against official Supabase docs
- Pitfalls: HIGH — column-level UPDATE risk identified from direct policy read; migration ordering verified from migration file listing

**Research date:** 2026-03-17
**Valid until:** 2026-04-17 (stable SQL/Dart domain; no fast-moving dependencies)
