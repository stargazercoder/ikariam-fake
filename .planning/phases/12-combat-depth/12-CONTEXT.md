# Phase 12: Combat Depth - Context

**Gathered:** 2026-03-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Winning a battle yields tangible resource rewards for the attacker (pillage), and players can review unit losses turn-by-turn in color-coded battle reports. Pillage is gated by cargo ship capacity. Hideout building protects a floor of resources from pillage.

</domain>

<decisions>
## Implementation Decisions

### Pillage Mechanics
- Pillage percentage scales with surviving attacker units (not a fixed %) — more survivors = higher % of unprotected resources
- Pillageable resources: wood, marble, crystal, sulfur (gold is exempt — tax income stays safe)
- Resources can be pillaged down to the Hideout protection floor (not capped at zero separately)
- Pillage details shown in battle report for BOTH attacker and defender — per-resource breakdown

### Cargo Transport
- Pillaged resources ride on the existing return movement (movement_type='return') — added as a JSONB cargo field on unit_movements
- Only cargo ships carry loot — 500 resources per surviving cargo ship
- 0 surviving cargo ships = 0 pillage, regardless of battle outcome
- Partial capacity: if loot exceeds cargo capacity, only carry what fits (excess stays with defender)
- Resources delivered to attacker's city when return movement arrives (process_arrivals handles it)

### Battle Report Visualization
- Stacked bar chart for turn-by-turn unit loss display
- Each unit type has a fixed color across all reports (hoplite=color1, archer=color2, etc.) — consistent identity
- Naval and land phases shown as separate chart sections (naval on top, land below) — clear phase separation
- Use fl_chart package for charting — supports stacked bars with animation

### Hideout Protection
- Protection formula: 100 * 1.5^level per resource type (exponential, matches Warehouse capacity curve)
- Protection applied per resource independently (Hideout lv5 = 759 protected for EACH of wood, marble, crystal, sulfur)
- Base protection: 50 per resource even without Hideout built (protects new players)
- Warehouse does NOT provide pillage protection — only storage capacity. Hideout is the sole protection mechanism.

### Claude's Discretion
- Exact pillage % formula based on survivor count (design the scaling curve)
- Specific color assignments for each unit type (13 unit types need distinct colors)
- fl_chart configuration and animation details
- How to distribute pillage across resource types when cargo capacity is limited (proportional vs priority)
- Stacked bar chart layout details (bar width, spacing, legend placement)
- resolve_battles() integration approach for pillage calculation

</decisions>

<specifics>
## Specific Ideas

- Pillage should feel rewarding — seeing the per-resource breakdown after a victory motivates combat
- Cargo ship requirement adds strategic depth: players must bring cargo ships in their fleet to profit from victories
- The 50/resource base protection ensures brand new players aren't completely wiped out by veterans

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `resolve_battles()` in `20260312000004_battle_functions.sql`: Main battle resolution — pillage logic hooks in at attacker_won branch
- `battle_turns` table: Already stores per-turn casualty JSONB — no schema change needed for visualization
- `BattleTurn` model in `battle_turn.dart`: Has `attackerSurvivors`/`defenderSurvivors` JSONB — chart data source
- `unit_movements` table: Has `movement_type` column — return movements already created on attacker win
- `process_arrivals()` in `20260312000005_modify_process_arrivals.sql`: Handles arrival — extend for cargo delivery
- `battle_detail_screen.dart`: Existing battle detail UI — extend with chart widget
- `building_constants.dart`: Hideout already defined with costs — add protection formula constant

### Established Patterns
- All game mutations via Edge Functions / pg_cron SQL functions (server authority)
- JSONB for immutable snapshots (unit_movements.units pattern) — reuse for cargo
- Supabase Realtime for reactive UI (battle streams already wired)
- Riverpod StreamProviders for data flow (watchBattleTurns already exists)

### Integration Points
- `resolve_battles()`: Add pillage calculation at attacker_won branch, compute loot, attach to return movement
- `unit_movements` table: Add `cargo` JSONB column (nullable) for pillaged resources
- `process_arrivals()`: When movement has cargo, add resources to destination city
- `battle_detail_screen.dart`: Add fl_chart stacked bar widget below existing turn cards
- `battles` table or `battle_turns`: Store pillage result for report display
- `city_buildings` → Hideout level lookup during pillage calculation

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 12-combat-depth*
*Context gathered: 2026-03-15*
