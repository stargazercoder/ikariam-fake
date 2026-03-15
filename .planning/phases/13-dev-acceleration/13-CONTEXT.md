# Phase 13: Dev Acceleration - Context

**Gathered:** 2026-03-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Developers can accelerate game testing by spawning multiple unit types at once and running timers at 5x speed. All changes are dev-mode-only and invisible/inert in production builds.

</domain>

<decisions>
## Implementation Decisions

### Bulk spawn dialog (DEVT-01)
- Checklist layout: all 13 unit types listed with a checkbox and a quantity input field per row
- Default quantity when checkbox toggled on: 50
- Single RPC call with JSONB map (e.g., `{"hoplite": 100, "archer": 50, "cargo_ship": 20}`) — server loops and inserts atomically
- New `dev_bulk_spawn_units(p_city_id, p_units_map)` RPC function
- Keep the existing single-type "Spawn Units" button alongside the new bulk spawn button

### Timer speed mechanism (DEVT-02, DEVT-03)
- Server-side `app.environment` check — same pattern as existing env_guard_timers migration
- Divide training time by 5 when `app.environment IS DISTINCT FROM 'production'`
- Divide travel time by 5 when `app.environment IS DISTINCT FROM 'production'`
- Training + travel only — building construction times NOT modified (per requirements)
- Keep existing speed-ups (10s battle turns, 1min resource ticks) untouched — add 1/5 training/travel on top

### Dev toolbar scope
- Add new "Bulk Spawn" button to toolbar (alongside existing single-spawn)
- Add "Instant Complete" button — instantly completes all in-progress training queues AND construction in the current city
- New `dev_instant_complete(p_city_id)` RPC function for instant completion
- Timer speed-ups are server-side only — no new toolbar UI needed for DEVT-02/03

### Claude's Discretion
- Bulk spawn dialog scrollability and layout details
- Instant-complete RPC implementation approach (UPDATE timestamps vs DELETE+INSERT)
- Error handling and snackbar messaging for new buttons
- Whether to add a "Select All / Deselect All" toggle to bulk spawn

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Dev toolbar
- `lib/core/dev/dev_toolbar.dart` — Current toolbar UI with FAB pattern, action buttons, single-type spawn dialog
- `lib/core/dev/dev_rpc_service.dart` — Supabase RPC wrapper for dev functions (inject resources, level up, spawn, trigger battle)

### Timer infrastructure
- `supabase/migrations/20260312000007_speed_up_all_timers.sql` — Existing dev speed-ups (10s battles, 1min resource ticks, fast travel)
- `supabase/migrations/20260312000010_env_guard_timers.sql` — Production guard pattern using `app.environment` setting

### Requirements
- `.planning/REQUIREMENTS.md` — DEVT-01, DEVT-02, DEVT-03 definitions

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `DevToolbarWrapper` + `_DevToolbarFab`: FAB-based expandable toolbar with `_ActionButton` pattern — new buttons follow same structure
- `DevRpcService`: Supabase RPC client pattern — new RPC methods follow `spawnUnits()` pattern
- `_unitTypes` list: all 13 unit types already defined as constants in toolbar
- `kDebugMode` guard: ensures dev code is tree-shaken in production builds

### Established Patterns
- Dev RPC functions are `SECURITY DEFINER` in migration `20260312000008_dev_rpc_helpers.sql`
- `app.environment` check pattern for production vs dev behavior divergence
- `StatefulBuilder` inside `showDialog` for dialog state management (used in current spawn/building dialogs)
- Snackbar feedback for all dev actions

### Integration Points
- New RPC functions added via new SQL migration
- New buttons added to `_DevToolbarFabState.build()` method
- Training time formula lives in the training queue Edge Function / SQL function
- Travel time formula lives in `dispatch-troops` Edge Function

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 13-dev-acceleration*
*Context gathered: 2026-03-16*
