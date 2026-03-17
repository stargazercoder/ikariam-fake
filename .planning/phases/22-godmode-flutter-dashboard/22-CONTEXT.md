# Phase 22: GodMode Flutter Dashboard - Context

**Gathered:** 2026-03-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Full-page admin dashboard consuming the Phase 21 GodMode RPCs. Admin user can observe every player's state and control bot behaviors without leaving the app. Three tabs: Players (table with inline controls), Events (timeline feed), and Bots tab is merged into Players via inline controls. Includes a new `admin_set_army` RPC for army count editing (not covered in Phase 21).

</domain>

<decisions>
## Implementation Decisions

### Dashboard Layout
- Tabbed layout with TabBar at the top: **Players** | **Events**
- `/godmode` route is full-page (outside StatefulShellRoute, no bottom nav) — carried from Phase 21
- Each tab has its own content area, no cross-tab navigation needed

### Player Table (Players Tab)
- Compact rows with columns: Name, total resources (single number), land army count, naval army count, building count, bot/human indicator, active battles count, actions column
- Column headers are sortable (tap to sort by that column)
- Bot players show a small "BOT" badge next to their name — visible only to admin
- Bot rows have inline controls in the actions column: pause/play toggle icon + force action button
- Human player rows have only the edit (resource/army) action
- "Pause All Bots" / "Resume All Bots" bulk control button above the table

### Event Feed (Events Tab)
- Chronological timeline list, newest first
- Each event shows: event type icon + timestamp + one-line summary with player names
- Filter chips at the top: All | Battle | Trade | Espionage (maps to `godmode_get_events` `p_event_type` parameter)
- Event type icons: sword for battle, package for trade, spy for espionage

### Data Refresh & Polling
- Auto-poll every 30 seconds for both world state and events
- Stale data stays visible during refresh — no loading overlay on subsequent polls
- AppBar shows "Last updated: Xs ago" indicator that counts up between refreshes
- Small spinner icon in AppBar during active refresh
- Manual refresh button also available in AppBar
- Initial load shows standard loading spinner (first load only)

### Bot Control Interactions
- Pause/resume: instant toggle (no confirmation dialog), result shown via SnackBar
- Force action: confirmation dialog before executing ("Force bot [name] to act now?"), result SnackBar shows which action the bot took (upgrade/train/attack/none)
- Bulk pause/resume: instant (no confirmation), SnackBar confirms count

### Resource & Army Editing
- Inline table editing: tap a resource/army cell to enter edit mode for that row
- Edit mode activates for the entire row — all editable fields become text inputs with current values pre-filled
- Row-level Save button appears when in edit mode; Cancel button to discard changes
- Resources: 5 fields (Wood, Marble, Crystal, Sulfur, Gold) — calls existing `admin_set_resources` RPC
- Army: 13 unit type fields (8 land + 5 naval) — requires new `admin_set_army` SECURITY DEFINER RPC
- Save calls the appropriate RPC(s) and exits edit mode on success; shows error SnackBar on failure
- Only one row can be in edit mode at a time

### Claude's Discretion
- Exact tab order and naming
- Color scheme and typography for the dashboard
- Loading skeleton design for initial load
- Exact layout of inline edit mode (how fields are arranged in the row)
- Whether to use Flutter DataTable or custom Row/Column for the player table
- Error state design (RPC failure, network issues)
- AppBar design and back navigation to game

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### GodMode Backend (Phase 21 RPCs)
- `supabase/migrations/20260317000005_godmode_rpcs.sql` — All 5 RPC signatures: `godmode_get_world_state()`, `godmode_set_bot_paused()`, `godmode_force_action()`, `admin_set_resources()`, `godmode_get_events()`
- `.planning/phases/21-godmode-backend/21-CONTEXT.md` — RPC response shapes, admin guard pattern, route guard decisions

### Admin Schema
- `supabase/migrations/20260317000001_bot_schema.sql` — `is_admin`, `is_bot` columns, `bot_schedules` table, RLS policies

### Flutter Routing & Auth
- `lib/core/router/app_router.dart` — GoRouter with `/godmode` route guard already implemented
- `lib/features/profile/providers/profile_provider.dart` — `isAdmin` getter on `ProfileNotifier`

### Existing Screen Patterns
- `lib/features/godmode/screens/godmode_placeholder_screen.dart` — Placeholder to replace with actual dashboard
- `lib/core/dev/dev_rpc_service.dart` — Established RPC call pattern (`_client.rpc('name', params: {...})`)

### Game Tables (for army editing RPC)
- `supabase/migrations/20260311000006_create_military_units.sql` — `military_units` table with unit types per city

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `GodModePlaceholderScreen` — Replace with actual `GodModeDashboardScreen`
- `DevRpcService` — Pattern for calling Supabase RPCs from Dart (`_client.rpc()`)
- `ProfileNotifier.isAdmin` — Already available for route guard and UI gating
- `CountdownTimerWidget` — Could adapt for "last updated X seconds ago" display
- `LoadingOverlay` widget — For initial load state

### Established Patterns
- `ConsumerWidget` with `ref.watch()` for Riverpod integration
- `AsyncValue.when()` for loading/error/data states
- Repository pattern: `lib/features/[feature]/data/[feature]_repository.dart`
- Provider pattern: `StreamProvider` for real-time, `AsyncNotifierProvider` for complex state
- SnackBar for action feedback throughout the app
- Profile is raw `Map<String, dynamic>` — no typed Dart class

### Integration Points
- `app_router.dart` — Replace `GodModePlaceholderScreen` with `GodModeDashboardScreen`
- `godmode_get_world_state()` — Returns JSONB with all player data for the table
- `godmode_get_events()` — Returns JSONB array for the event feed
- `bot_schedules.is_paused` — Updated by `godmode_set_bot_paused()`
- `military_units` table — Needs new `admin_set_army` RPC for army editing

</code_context>

<specifics>
## Specific Ideas

- Inline table editing for resources and army — tap cell to enter row edit mode, Save/Cancel buttons per row
- Bot badge next to player name (not row background color)
- Force action shows result in SnackBar: "Bot-03 chose: attack" / "Bot-03 chose: none"
- New `admin_set_army` SECURITY DEFINER RPC needed (not in Phase 21 scope) — follows same pattern as `admin_set_resources`

</specifics>

<deferred>
## Deferred Ideas

- GodMode world map overlay — v1.3+ future requirement (GOD-F01)
- Time-travel replay — v1.3+ future requirement (GOD-F02)
- Economy analytics dashboard — v1.3+ future requirement (GOD-F03)
- Bot speed adjustment (manipulating `next_action_at`) — could add later if needed

</deferred>

---

*Phase: 22-godmode-flutter-dashboard*
*Context gathered: 2026-03-17*
