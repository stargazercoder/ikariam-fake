# Phase 26: Building Detail Sheet - Context

**Gathered:** 2026-03-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Tapping any building on the city grid opens a large, scrollable bottom sheet with building-specific information and actions. All 14 building types use the same layout structure (header, stats, actions) but with dynamic content per building type. Replaces the current split behavior (Dialog for most buildings, full-page navigation for Barracks/Shipyard).

</domain>

<decisions>
## Implementation Decisions

### Sheet structure and size
- Bottom sheet covers ~80-90% of screen height using `showModalBottomSheet` with `isScrollControlled: true`
- Standard Material bottom sheet animation (slide up from bottom)
- Drag handle at top for visual affordance
- Background dimmed behind sheet
- Sheet content is scrollable via `SingleChildScrollView`

### Header layout
- Drag handle at very top
- Left: building icon (colored, from `buildingTypeIcon`/`buildingTypeColor`) + building name + "Level X" subtitle
- Right: X close button
- Divider below header separating from content

### Section structure
- Section titles ("Stats", "Actions") as small text headings with thin divider lines
- Consistent across all building types: Header → Stats → Actions
- Follows existing upgrade dialog's visual style (Divider + labeled sections)

### Barracks/Shipyard integration
- All content (unit training, queue, roster) moves INTO the bottom sheet — no more full-page navigation
- `barracks_screen.dart` and `shipyard_screen.dart` files are completely removed along with their routes
- Sheet stays open during train operations — inline feedback via SnackBar, user can train multiple unit types sequentially
- Dispatch (send troops) button is NOT in the sheet — dispatch flow remains separate

### Dynamic content per building type

**Town Hall:**
- Stats: current population, growth rate/tick, idle citizens, tax income/hr, max population at current level

**Warehouse:**
- Stats: storage capacity at current level, per-resource fill bars (Wood/Marble/Crystal/Sulfur amount / max capacity with progress bar)

**Tavern:**
- Stats: wine spending slider (existing `_TavernWineSlider` logic), happiness contribution, wine consumption/tick, wine stock

**Barracks:**
- Stats: active training queue with countdown timer
- Actions: unit training grid (8 land unit types, quantity input, Train button per type), army roster summary
- Building upgrade/downgrade at bottom

**Shipyard:**
- Stats: active training queue with countdown timer
- Actions: unit training grid (5 naval unit types, quantity input, Train button per type), navy roster summary
- Building upgrade/downgrade at bottom

**Production buildings (Sawmill, Quarry, Glassblower, Sulfur Pit):**
- Stats: production breakdown (base rate, building bonus, island bonus, research bonus, total) + assigned workers count
- Replaces existing `_ProductionBreakdownSheet` — that content moves here

**Town Wall:**
- Stats: defense bonus percentage at current level

**Hideout:**
- Stats: resource protection floor amount at current level (from `hideoutProtectionFloor()`)

**Trading Port:**
- Stats: trade capacity at current level

**Academy:**
- Stats: "Research: Coming soon" placeholder (research system not yet implemented)

**Embassy:**
- Stats: "Alliance: Coming soon" placeholder (alliance system not yet implemented)

### Upgrade/Downgrade actions
- Upgrade: same as existing — shows cost breakdown per resource (with ResourceBadge), build time, "Start Upgrade" button
- Downgrade: new feature — reduces level by 1, refunds 50% of that level's upgrade cost, executes instantly (no queue), cannot go below level 1
- Buttons: side by side in Actions section — Upgrade (primary, large ElevatedButton) + Downgrade (outlined, smaller OutlinedButton)
- Downgrade shows refund amounts and confirmation dialog ("Are you sure?")
- When construction queue is busy: Upgrade button disabled with warning message, Downgrade button stays active (instant, no queue needed)
- When building is being upgraded: show upgrade-in-progress section with countdown (existing behavior)

### Claude's Discretion
- Exact spacing and padding values within sections
- Loading skeleton while data loads
- Error state handling within the sheet
- Widget file organization (single file vs multiple files per building type)
- How to extract reusable widgets from barracks/shipyard screens before deletion

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Building system
- `lib/core/constants/building_constants.dart` — BuildingType enum (14 types), base costs, upgrade formulas, `hideoutProtectionFloor()`
- `lib/core/constants/visual_constants.dart` — `buildingTypeIcon` and `buildingTypeColor` maps for all 14 building types

### Existing upgrade UI (to be replaced)
- `lib/features/city/screens/building_upgrade_sheet.dart` — Current Dialog-based upgrade UI with tavern wine slider, cost breakdown, upgrade-in-progress section
- `lib/features/map/screens/city_grid_screen.dart` — `BuildingCell.onTap` routing logic (Barracks/Shipyard → push, others → showDialog)

### Military screens (to be removed)
- `lib/features/military/screens/barracks_screen.dart` — Land unit training, queue, roster (content moves to sheet)
- `lib/features/military/screens/shipyard_screen.dart` — Naval unit training, queue, roster (content moves to sheet)
- `lib/features/military/widgets/building_upgrade_card.dart` — Upgrade card used within military screens

### Data providers
- `lib/features/city/providers/production_rate_provider.dart` — Production rate and breakdown providers
- `lib/features/city/providers/resources_provider.dart` — Resource streams for warehouse fill display
- `lib/features/military/providers/training_queue_provider.dart` — Training queue data for Barracks/Shipyard
- `lib/features/military/providers/army_roster_provider.dart` — Army/navy roster data

### Resource display
- `lib/shared/widgets/resource_badge.dart` — ResourceBadge widget for cost display
- `lib/core/constants/resource_constants.dart` — ResourceType enum and related constants

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `buildingTypeIcon` / `buildingTypeColor` maps: icon and color for all 14 building types — use in sheet header
- `ResourceBadge` widget: colored circle+letter resource icons — use in upgrade cost display
- `CountdownTimerWidget`: live countdown timer — use for upgrade-in-progress and training queue
- `_TavernWineSlider`: wine spending slider with debounced server calls — extract and reuse in tavern sheet
- `upgradeCost()` / `upgradeDurationMinutes()`: upgrade formula functions — use for cost/time display
- `hideoutProtectionFloor()`: protection calculation — use in hideout stats
- `_ProductionBreakdownSheet`: production breakdown UI — content moves to production building sheet

### Established Patterns
- `showModalBottomSheet` already used for production breakdown in city_screen.dart — same pattern for building sheet
- `ConsumerStatefulWidget` pattern for stateful sheets (wine slider, upgrade button loading state)
- SnackBar feedback for server action results (upgrade success/failure)
- `buildingsStreamProvider` / `resourcesStreamProvider` for reactive data

### Integration Points
- `BuildingCell.onTap` in `city_grid_screen.dart` — change from push/showDialog to showModalBottomSheet for all buildings
- Router: remove `/barracks` and `/shipyard` routes after migration
- `building_upgrade_card.dart` in military widgets — may become unused after migration

</code_context>

<specifics>
## Specific Ideas

- Warehouse sheet should have visual progress bars showing fill percentage per resource type
- Academy and Embassy show "Coming soon" placeholders since research and alliance systems aren't implemented yet
- Downgrade refunds exactly 50% of the upgrade cost for the level being downgraded (e.g., downgrading from Lv.5 refunds 50% of Lv.4→5 cost)
- Sheet should feel like a comprehensive building management panel — all info and actions in one place

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 26-building-detail-sheet*
*Context gathered: 2026-03-20*
