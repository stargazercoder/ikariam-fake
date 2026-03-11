# Phase 5: Combat - Context

**Gathered:** 2026-03-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Turn-based 5-minute battle engine: when dispatched armies arrive at enemy cities, battles begin and resolve server-side in 5-minute turns. Naval units fight before land units each turn (gate-keeper model). Both players receive real-time battle reports via Supabase Realtime. No pillage, no occupation, no reinforcements during battle — those are v2 (CMBT-06/07/08).

</domain>

<decisions>
## Implementation Decisions

### Battle Resolution Mechanics
- All-in engagement: all surviving units fight every turn (no front-line/reserve system in v1, but design should allow adding front-line later)
- Simple ratio damage: total attack vs total defense determines casualty ratio per side
- Each unit type contributes its own attack/defense stats to the side total
- Naval gate-keeper: if defender wins naval phase, attacker's land units cannot land — battle ends, attacker retreats
- Naval phase resolves first each turn, then land phase (if attacker has surviving naval or defender has no naval)
- Town Wall defense bonus: defender's land units get +X% defense per Town Wall level (flat multiplier)

### Battle Lifecycle
- Battle starts immediately when process_arrivals() detects army arriving at enemy city
- First turn resolves at arrival_time + 5 minutes
- Battle ends only on wipeout: one side has zero units remaining
- No retreat mechanic in v1
- After attacker wins: surviving units automatically travel back to origin city (travel time applies)
- After defender wins: attacker's units are gone, defender keeps survivors
- One battle at a time per city: if a city is already in battle, new arriving armies are rejected/queued

### Battle Report UI
- Battles list screen (no push notifications or banners) — players check manually
- Turn-by-turn display: each turn shown as a card/row with Naval phase casualties then Land phase casualties
- 4th bottom navigation tab: "Battles" added to existing World Map / Island / City tabs
- Active battles show live countdown timer to next turn (reuse CountdownTimerWidget pattern)
- Battle history: completed battles remain viewable as past reports

### Battle Data Model
- Two new tables: `battles` (active battle state) and `battle_turns` (per-turn results)
- `battles` table: attacker/defender info, army JSONB snapshots (per unit type), status, next_turn_at, turn_number, city reference
- `battle_turns` table: turn number, naval/land phase results, casualties per side (JSONB with per-unit-type breakdown), survivors
- Army snapshots use full JSONB unit breakdown: `{hoplite: 20, archer: 15, ...}` — consistent with unit_movements.units pattern
- resolve_battles() pg function called by new 'battle-tick' pg_cron job (every minute, checks next_turn_at <= NOW())
- process_arrivals() modified: if destination city owner != army owner, create battle instead of upserting units
- Add movement_type column to unit_movements ('attack' only in v1, column exists for future 'reinforce')
- Both tables Realtime-enabled (REPLICA IDENTITY FULL + supabase_realtime publication)
- RLS: both attacker and defender can read their own battles/turns

### Claude's Discretion
- Exact damage formula coefficients and casualty calculation
- Town Wall defense bonus percentage per level
- battle_turns table exact schema design
- How to handle edge case: attacker has no naval but defender does (skip naval phase or auto-lose naval?)
- Battle list UI layout and styling
- How rejected/queued armies are handled when city is already in battle
- Return trip travel time calculation for victorious attacker

</decisions>

<specifics>
## Specific Ideas

- All-in engagement chosen for v1 simplicity, but the system should be structured so front-line/reserve can be added later without schema changes
- Naval gate-keeper is a key strategic decision: building a navy matters for island defense
- No occupation or pillage in v1 — winning a battle just proves military dominance and costs the loser their units
- pg_cron pattern is well-established (resource-tick, construction-tick, training-tick, arrivals-tick) — battle-tick follows the same pattern

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `deduct_units(p_city_id, p_unit_type, p_quantity)`: Existing pg function for removing units — reusable for applying battle casualties
- `CountdownTimerWidget`: Display-only countdown timer — reuse for "time until next turn" display
- `unit_constants.dart` / `dispatch-units/index.ts`: Unit stats (attack, defense, HP) already defined — combat formula uses these
- `MilitaryRepository`: Existing Realtime stream patterns for city_units and unit_movements — battle streams follow same pattern
- StreamProvider.autoDispose.family pattern: Established for all Realtime subscriptions

### Established Patterns
- pg_cron + pg function for all server-side ticks (process_resource_tick, complete_building_upgrades, complete_training, process_arrivals)
- JSONB snapshots for army composition (unit_movements.units)
- REPLICA IDENTITY FULL + supabase_realtime publication for all game tables
- Single eq filter on Realtime .stream(), client-side filtering for compound conditions
- Edge Functions for player-initiated actions, pg functions for server-side ticks
- Manual Riverpod providers (no code-gen)

### Integration Points
- `process_arrivals()` in movement_functions.sql: Must be modified to check destination city ownership and create battle instead of direct upsert
- `unit_movements` table: Needs new movement_type column (default 'attack')
- `dispatch-units/index.ts`: May need update to set movement_type
- `app_router.dart`: StatefulShellRoute needs 4th branch for Battles tab
- `navigation_shell.dart` (or equivalent): Bottom nav needs 4th tab
- Battles tab follows same StreamProvider pattern as military screens

</code_context>

<deferred>
## Deferred Ideas

- Reinforcements during active battles — CMBT-06 (v2)
- Pillage (steal resources on victory) — CMBT-07 (v2)
- Occupation (city takeover) — CMBT-08 (v2)
- Front-line/reserve engagement system — future enhancement to v1's all-in system
- Unit-type matchups (rock-paper-scissors) — future enhancement to damage calculation
- Push notifications for battle events — future UX improvement

</deferred>

---

*Phase: 05-combat*
*Context gathered: 2026-03-12*
