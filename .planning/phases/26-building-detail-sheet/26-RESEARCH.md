# Phase 26: Building Detail Sheet - Research

**Researched:** 2026-03-20
**Domain:** Flutter bottom sheet UI, Riverpod state, building/military widget migration
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Sheet structure and size:**
- `showModalBottomSheet` with `isScrollControlled: true` — ~80-90% screen height
- Standard Material bottom sheet animation (slide up from bottom)
- Drag handle at top for visual affordance
- Background dimmed behind sheet
- Sheet content scrollable via `SingleChildScrollView`

**Header layout:**
- Drag handle at very top
- Left: building icon (colored, from `buildingTypeIcon`/`buildingTypeColor`) + building name + "Level X" subtitle
- Right: X close button
- Divider below header separating from content

**Section structure:**
- Section titles ("Stats", "Actions") as small text headings with thin divider lines
- Consistent across all building types: Header → Stats → Actions
- Follows existing upgrade dialog's visual style (Divider + labeled sections)

**Barracks/Shipyard integration:**
- All content moves INTO the bottom sheet — no more full-page navigation
- `barracks_screen.dart` and `shipyard_screen.dart` are completely removed along with their routes
- Sheet stays open during train operations — inline SnackBar feedback
- Dispatch button is NOT in the sheet — dispatch flow remains separate

**Dynamic content per building type:**
- Town Hall: population, growth rate/tick, idle citizens, tax income/hr, max population at current level
- Warehouse: storage capacity, per-resource fill bars (Wood/Marble/Crystal/Sulfur amount / max with progress bar)
- Tavern: wine spending slider (existing `_TavernWineSlider` logic), happiness contribution, wine consumption/tick, wine stock
- Barracks: active training queue with countdown + unit training grid (8 land unit types) + army roster summary + upgrade/downgrade
- Shipyard: active training queue with countdown + unit training grid (5 naval unit types) + navy roster summary + upgrade/downgrade
- Production buildings (Sawmill/Quarry/Glassblower/Sulfur Pit): production breakdown (base/building/island/research/total) + assigned workers — replaces `_ProductionBreakdownSheet`
- Town Wall: defense bonus percentage at current level
- Hideout: resource protection floor amount at current level
- Trading Port: trade capacity at current level
- Academy: "Research: Coming soon" placeholder
- Embassy: "Alliance: Coming soon" placeholder

**Upgrade/Downgrade actions:**
- Upgrade: existing cost breakdown (ResourceBadge), build time, "Start Upgrade" ElevatedButton
- Downgrade: new feature — reduces level by 1, refunds 50% of that level's upgrade cost, instant (no queue), cannot go below level 1
- Side-by-side buttons: Upgrade (primary ElevatedButton) + Downgrade (outlined OutlinedButton, smaller)
- Downgrade shows refund amounts and confirmation dialog ("Are you sure?")
- Queue busy: Upgrade disabled with warning, Downgrade stays active
- Building being upgraded: show upgrade-in-progress section with countdown

### Claude's Discretion
- Exact spacing and padding values within sections
- Loading skeleton while data loads
- Error state handling within the sheet
- Widget file organization (single file vs multiple files per building type)
- How to extract reusable widgets from barracks/shipyard screens before deletion

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| BLDG-01 | Tapping any building opens a large scrollable bottom sheet showing building information | `BuildingCell.onTap` in `city_grid_screen.dart` currently routes barracks/shipyard to push and others to `showDialog` — must unify to `showModalBottomSheet` for all 14 building types |
| BLDG-02 | Bottom sheet shows dynamic content per building type (upgrade/downgrade, tavern→happiness, barracks→unit training, shipyard→ship building, resource spots→production rates) | All data providers exist: `buildingsStreamProvider`, `trainingQueueProvider`, `armyRosterProvider`, `productionBreakdownProvider`, `cityEconomyStreamProvider`, `resourcesStreamProvider` |
| BLDG-03 | All building detail sheets use the same layout structure (header, stats, actions) | Scaffold widget wraps type-specific stats/actions content; `buildingTypeIcon`/`buildingTypeColor` maps are complete for all 14 types |
</phase_requirements>

---

## Summary

Phase 26 replaces three distinct interaction patterns (Dialog for most buildings, `context.push('/barracks')`, `context.push('/shipyard')`) with a single unified `showModalBottomSheet` for all 14 building types. The shell is always the same: drag handle → header (icon + name + level + close) → Stats section → Actions section. Only the content inside Stats and Actions varies per building type.

All required data providers already exist and are battle-tested. The main work is: (1) building the shared scaffold widget, (2) extracting reusable unit-training widgets from `barracks_screen.dart` / `shipyard_screen.dart` before deleting those files, (3) implementing per-building-type stat/action content, (4) adding the downgrade feature (new Edge Function needed on the backend), and (5) wiring `BuildingCell.onTap` to the new sheet for all buildings.

The production breakdown content (`_ProductionBreakdownSheet` in `city_screen.dart`) also moves into the new production building sheet — so that sheet needs to be removed from `city_screen.dart` as well.

**Primary recommendation:** Build the shared scaffold first (Plan 26-01), then add per-building-type dynamic content and the downgrade backend in one pass (Plan 26-02). This matches the two planned plans.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter | SDK | UI framework | Project base |
| flutter_riverpod | ^2.x | State management | Established pattern in all city/military providers |
| go_router | ^14.x | Routing | Existing router — only for route removal, not new routes |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| supabase_flutter | ^2.x | Backend calls | Edge Function invocation for downgrade action |

**No new packages required.** All capabilities are already in the project.

---

## Architecture Patterns

### Recommended File Structure

```
lib/features/city/screens/
├── building_detail_sheet.dart          # Public entry: showBuildingDetailSheet()
│                                       # + _BuildingDetailSheetContent (scaffold)
├── building_upgrade_sheet.dart         # KEEP for now, upgrade logic extracted later
└── city_screen.dart                    # Remove _ProductionBreakdownSheet

lib/features/city/widgets/
├── building_sheet_header.dart          # Drag handle + icon + name + level + close X
├── building_sheet_section.dart         # Section title + divider helper widget
└── building_sheet_upgrade_actions.dart # Shared upgrade/downgrade action buttons

lib/features/city/widgets/building_stats/
├── town_hall_stats.dart
├── warehouse_stats.dart
├── tavern_stats.dart                   # Extracts _TavernWineSlider from upgrade sheet
├── barracks_stats.dart                 # Training queue countdown
├── shipyard_stats.dart
├── production_building_stats.dart      # Reuses productionBreakdownProvider
├── town_wall_stats.dart
├── hideout_stats.dart
├── trading_port_stats.dart
├── placeholder_stats.dart              # Academy + Embassy "Coming soon"

lib/features/military/widgets/
├── unit_training_section.dart          # Extracted from barracks_screen + shipyard_screen
└── unit_roster_section.dart            # Extracted from barracks_screen + shipyard_screen
```

> Claude has discretion over exact file organization. The above shows one clean approach. Single-file-per-building is also acceptable if preferred for simplicity.

### Pattern 1: showModalBottomSheet with isScrollControlled

**What:** Covers 80-90% of screen height, scrollable content, Material drag handle.
**When to use:** All 14 building types uniformly.

```dart
// Source: existing city_screen.dart _ProductionBreakdownSheet usage
Future<void> showBuildingDetailSheet(
  BuildContext context, {
  required CityBuilding building,
  required String cityId,
  required List<CityResource> currentResources,
  required ConstructionQueueEntry? activeConstruction,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => _BuildingDetailSheetContent(
        building: building,
        cityId: cityId,
        currentResources: currentResources,
        activeConstruction: activeConstruction,
        scrollController: controller,
      ),
    ),
  );
}
```

**Alternative (simpler):** Use plain `showModalBottomSheet` with `isScrollControlled: true` and `constraints: BoxConstraints(maxHeight: screenHeight * 0.88)` — avoids `DraggableScrollableSheet` complexity. Since the barracks sheet is tall (8 unit types), `DraggableScrollableSheet` provides better UX but is optional.

### Pattern 2: ConsumerStatefulWidget for the sheet scaffold

**What:** The sheet needs stateful behavior (loading state for upgrade/downgrade button).
**When to use:** Whenever the sheet has async operations.

```dart
// Source: existing _BuildingUpgradeContent pattern
class _BuildingDetailSheetContent extends ConsumerStatefulWidget {
  // ...
}
```

### Pattern 3: Shared section heading widget

```dart
// Consistent section headings across all building types
class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.grey.shade600,
              letterSpacing: 1.1,
            ),
          ),
          const Divider(height: 8),
        ],
      ),
    );
  }
}
```

### Pattern 4: Per-type content dispatch via switch

```dart
// In _BuildingDetailSheetContent.build()
Widget _buildStats(BuildContext context, WidgetRef ref) {
  switch (widget.building.buildingType) {
    case BuildingType.townHall:     return TownHallStats(...);
    case BuildingType.warehouse:    return WarehouseStats(...);
    case BuildingType.tavern:       return TavernStats(...);
    case BuildingType.barracks:     return BarracksStats(...);
    case BuildingType.shipyard:     return ShipyardStats(...);
    case BuildingType.sawmill:
    case BuildingType.quarry:
    case BuildingType.glassblower:
    case BuildingType.sulfurPit:    return ProductionBuildingStats(...);
    case BuildingType.townWall:     return TownWallStats(...);
    case BuildingType.hideout:      return HideoutStats(...);
    case BuildingType.tradingPort:  return TradingPortStats(...);
    case BuildingType.academy:
    case BuildingType.embassy:      return PlaceholderStats(...);
  }
}
```

### Pattern 5: Downgrade confirmation dialog

```dart
// Standard AlertDialog confirm pattern — already used in dispatch flow
final confirmed = await showDialog<bool>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: const Text('Downgrade Building?'),
    content: Text(
      'This will reduce ${building.buildingType.displayName} to '
      'Level ${building.level - 1} and refund:\n'
      '${_formatRefund(refundCost)}',
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
      ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
    ],
  ),
);
```

### Anti-Patterns to Avoid

- **Don't navigate away from the sheet for train operations:** Keep sheet open, use SnackBar feedback per locked decision.
- **Don't duplicate upgrade logic:** Extract a shared `_UpgradeActionsWidget` rather than reimplementing in every building type.
- **Don't use `showDialog` for any building:** The locked decision is `showModalBottomSheet` for all 14 types.
- **Don't keep `/barracks` and `/shipyard` routes after migration:** They must be removed along with the screen files.
- **Don't use `Navigator.of(context).pop()` inside the sheet for SnackBar feedback:** The sheet should stay open; pop only for close button / dismiss gesture.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Training queue countdown | Custom timer widget | `CountdownTimerWidget` | Already built, handles edge cases, tabular font features |
| Wine spending slider | New slider widget | Extract `_TavernWineSlider` from `building_upgrade_sheet.dart` | Already debounced, handles 0-wine warning, server sync |
| Production breakdown display | Custom breakdown calc | `productionBreakdownProvider((cityId, resource))` | Already computes base/building/island/research breakdown correctly |
| Resource cost display | Custom resource row | `ResourceBadge` widget | Canonical colored badge — ICON-01/02/03 compliant |
| Building icon + color | Hardcoded values | `buildingTypeIcon[type]` / `buildingTypeColor[type]` | Canonical maps, Phase 25 output |
| Upgrade button logic | Duplicate state machine | Extract shared `_UpgradeActionsWidget` from existing `_BuildingUpgradeContent` | Complex disabled-state logic already tested |

**Key insight:** The barracks and shipyard screens already contain all the widgets needed for the military sheets — the work is extraction and embedding, not rebuilding from scratch.

---

## Common Pitfalls

### Pitfall 1: BuildContext validity after async gaps in sheet
**What goes wrong:** Calling `ScaffoldMessenger.of(context)` or `Navigator.of(context)` after `await` inside a sheet widget throws if the sheet was dismissed.
**Why it happens:** User swipes the sheet away during a slow server call.
**How to avoid:** Always check `if (mounted)` before using context after any `await`. Already established in `_BuildingUpgradeContent._startUpgrade()`.
**Warning signs:** `!mounted` assertion errors in debug logs.

### Pitfall 2: Keyboard overlap when editing unit quantity
**What goes wrong:** The quantity `TextField` in unit training rows (Barracks/Shipyard sheet) gets covered by the software keyboard because the sheet uses fixed sizing.
**Why it happens:** `showModalBottomSheet` with `isScrollControlled: true` but without `resizeToAvoidBottomInset`.
**How to avoid:** Pass `resizeToAvoidBottomInset: true` (default is `true` for modal bottom sheets with `isScrollControlled`). If using `DraggableScrollableSheet`, ensure the scroll controller is passed to `SingleChildScrollView` so the focused field scrolls into view.
**Warning signs:** TextField hidden behind keyboard on tap.

### Pitfall 3: Quantity TextEditingControllers not disposed
**What goes wrong:** Memory leak / "A TextEditingController was used after being disposed" error.
**Why it happens:** 8 land unit controllers (barracks) and 5 naval controllers (shipyard) are created for each sheet open. If the sheet widget is `StatefulWidget` they need disposal.
**How to avoid:** Use `ConsumerStatefulWidget` for military sheets with `dispose()` that cancels all controllers. Same pattern as current `BarracksScreen`.

### Pitfall 4: Production breakdown sheet not removed from city_screen.dart
**What goes wrong:** Two sheets coexist — tapping a resource in city_screen still opens `_ProductionBreakdownSheet`, but tapping the production building opens the new building detail sheet with the same content.
**Why it happens:** Forgetting to remove the `showModalBottomSheet` call in `city_screen.dart` (line ~350) that opens `_ProductionBreakdownSheet`.
**How to avoid:** Plan 26-02 must explicitly include removing `_ProductionBreakdownSheet` from `city_screen.dart`. The production building sheet IS the new breakdown sheet.

### Pitfall 5: Downgrade Edge Function missing — not a UI-only task
**What goes wrong:** Downgrade button UI exists but there is no `downgrade-building` Edge Function in Supabase.
**Why it happens:** Current backend only has `upgrade-building`. Downgrade requires a new Deno Edge Function that: validates level > 1, calculates 50% refund of `upgradeCost(type, level-1)`, decrements level in DB, credits resources.
**How to avoid:** Plan 26-02 must include the `downgrade-building` Edge Function. The UI and backend must ship together.
**Warning signs:** Only `upgrade-building` exists in `supabase/functions/` — confirmed by file listing.

### Pitfall 6: Barracks/Shipyard route removal breaks existing navigation
**What goes wrong:** Removing `/barracks` and `/shipyard` routes from `app_router.dart` without checking for all call sites causes a crash when anything tries to `context.push('/barracks')`.
**Why it happens:** `BuildingCell.onTap` in `city_grid_screen.dart` still has the old push logic until it is updated.
**How to avoid:** Update `BuildingCell.onTap` first (or simultaneously with route removal), ensuring the switch to `showBuildingDetailSheet` is done before the routes are removed.

---

## Code Examples

Verified patterns from existing codebase:

### Existing showModalBottomSheet call (model to follow)
```dart
// Source: city_screen.dart line ~349
showModalBottomSheet<void>(
  context: context,
  builder: (_) => _ProductionBreakdownSheet(
    cityId: cityId,
    resourceTypeName: type.value,
    resourceType: type,
  ),
)
// NOTE: This does NOT use isScrollControlled — new sheet must add it for tall content
```

### BuildingCell.onTap — current split routing (to be replaced)
```dart
// Source: city_grid_screen.dart BuildingCell.build()
onTap: readOnly ? null : () {
  if (building.buildingType == BuildingType.barracks) {
    context.push('/barracks?cityId=$cityId');
    return;
  }
  if (building.buildingType == BuildingType.shipyard) {
    context.push('/shipyard?cityId=$cityId');
    return;
  }
  showBuildingUpgradeSheet(context, building: building, cityId: cityId, ...);
},
// REPLACE with: showBuildingDetailSheet(context, building: building, cityId: cityId, ...)
```

### TavernWineSlider — extraction target
```dart
// Source: building_upgrade_sheet.dart — _TavernWineSlider
// This private widget must be made public (rename to TavernWineSlider)
// and moved to its own file or the new sheet file.
// Key: it watches cityEconomyStreamProvider + resourcesStreamProvider
// and calls cityRepositoryProvider.setWineRate() with 300ms debounce.
```

### Downgrade refund calculation (pure Dart, no new logic needed)
```dart
// Source: building_constants.dart upgradeCost() function
// Downgrade from level N refunds 50% of upgradeCost(type, N-1)
Map<ResourceType, int> downgradeRefund(BuildingType type, int currentLevel) {
  assert(currentLevel > 1, 'Cannot downgrade below level 1');
  final fullCost = upgradeCost(type, currentLevel - 1);
  return fullCost.map((r, v) => MapEntry(r, (v * 0.5).floor()));
}
// Use upgradeCost(type, currentLevel - 1) because that was the cost
// to upgrade FROM level (currentLevel-1) TO level currentLevel.
```

### Production breakdown display (reuse existing breakdown)
```dart
// Source: production_rate_provider.dart productionBreakdownProvider
// In production building stats widget:
final breakdown = ref.watch(
  productionBreakdownProvider((cityId, resourceTypeName)),
);
// breakdown.baseRate / .buildingBonus / .islandBonus / .researchBonus / .total
```

### Army roster filter (land vs naval)
```dart
// Source: barracks_screen.dart _isNaval()
bool _isNaval(String unitType) {
  try { return unitTypeFromDbName(unitType).isNaval; }
  catch (_) { return false; }
}
// barracks sheet: show units where !_isNaval(u.unitType)
// shipyard sheet: show units where _isNaval(u.unitType)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `showDialog` for all buildings | `showModalBottomSheet` for all buildings | Phase 26 | Consistent, larger, scrollable |
| `context.push('/barracks')` / `context.push('/shipyard')` | Inline in bottom sheet | Phase 26 | Eliminates 2 screens + 2 routes |
| `_ProductionBreakdownSheet` in city_screen | Production building detail sheet | Phase 26 | One less separate sheet trigger |
| Upgrade-only actions | Upgrade + Downgrade side by side | Phase 26 | New feature — needs backend Edge Function |

**Deprecated/outdated after Phase 26:**
- `lib/features/military/screens/barracks_screen.dart` — deleted
- `lib/features/military/screens/shipyard_screen.dart` — deleted
- `lib/features/military/widgets/building_upgrade_card.dart` — likely unused, delete
- `/barracks` and `/shipyard` routes in `app_router.dart` — removed
- `_ProductionBreakdownSheet` private class in `city_screen.dart` — removed
- `showBuildingUpgradeSheet` in `building_upgrade_sheet.dart` — replaced by `showBuildingDetailSheet`

---

## Open Questions

1. **Warehouse: what is the max storage capacity formula?**
   - What we know: Warehouse exists in DB, `CityBuilding.level` is available
   - What's unclear: No `warehouseCapacity(level)` function found in `building_constants.dart`. The Warehouse stats need to show "capacity at current level" but the formula is not in client-side code.
   - Recommendation: Search Supabase DB schema or server-side functions for the capacity formula before implementing warehouse stats. May need to add a Dart helper similar to `hideoutProtectionFloor()`.

2. **Town Hall: population, growth rate, max population, tax income data sources**
   - What we know: `cityEconomyStreamProvider` returns `population`, `happiness`, `wine_spending_rate`
   - What's unclear: `growth_rate`, `idle_citizens`, `tax_income`, `max_population` are not in the observed provider fields
   - Recommendation: Read `cities` table schema to confirm what columns exist. These may need either new provider fields or direct DB query.

3. **Trading Port: trade capacity formula**
   - What we know: TradingPort exists as a building type
   - What's unclear: No `tradingPortCapacity(level)` function found in client code
   - Recommendation: Check server-side trade logic or add a simple formula constant.

4. **Town Wall: defense bonus formula**
   - What we know: TownWall is a building type, building level available
   - What's unclear: No `townWallDefenseBonus(level)` Dart function exists
   - Recommendation: Add a simple formula constant in `building_constants.dart` (similar to `hideoutProtectionFloor`).

5. **downgrade-building Edge Function: does it need resource crediting logic?**
   - What we know: Upgrade deducts resources via Edge Function. Downgrade should refund 50%.
   - What's unclear: The refund method — direct DB UPDATE to city resources or a new function pattern
   - Recommendation: Follow same pattern as `upgrade-building`: Deno Edge Function that validates, decrements level, credits resources in a transaction.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None detected — no test/ directory or test config found |
| Config file | None |
| Quick run command | N/A |
| Full suite command | N/A |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BLDG-01 | All 14 buildings open bottom sheet on tap | manual smoke | N/A — no widget test infra | No framework |
| BLDG-02 | Dynamic content per building type correct | manual smoke | N/A | No framework |
| BLDG-03 | Consistent header/stats/actions structure | manual smoke | N/A | No framework |

### Sampling Rate
- **Per task commit:** Manual smoke test on device/emulator — tap each building, verify sheet opens
- **Per wave merge:** Full building type sweep (all 14 types), verify upgrade + downgrade actions
- **Phase gate:** All 14 buildings confirmed before `/gsd:verify-work`

### Wave 0 Gaps
None from test framework perspective — project has no automated test infrastructure. Manual verification is the established project pattern.

---

## Sources

### Primary (HIGH confidence)
- Direct code reading: `lib/features/city/screens/building_upgrade_sheet.dart` — upgrade dialog structure, TavernWineSlider, _UpgradeInProgressSection
- Direct code reading: `lib/features/map/screens/city_grid_screen.dart` — BuildingCell.onTap routing logic, existing split behavior
- Direct code reading: `lib/features/military/screens/barracks_screen.dart` — _UnitTrainingRow, _ArmyRosterSection, _TrainingBanner
- Direct code reading: `lib/features/military/screens/shipyard_screen.dart` — identical structure for naval units
- Direct code reading: `lib/features/city/providers/production_rate_provider.dart` — ProductionBreakdown model, productionBreakdownProvider
- Direct code reading: `lib/core/constants/building_constants.dart` — all upgrade formulas, hideoutProtectionFloor
- Direct code reading: `lib/core/constants/visual_constants.dart` — buildingTypeIcon, buildingTypeColor, complete for all 14 types
- Direct code reading: `lib/core/router/app_router.dart` — confirmed /barracks and /shipyard route existence
- Direct code reading: `supabase/functions/` directory listing — confirmed no `downgrade-building` function exists

### Secondary (MEDIUM confidence)
- Flutter documentation (training): `showModalBottomSheet` with `isScrollControlled: true` and `DraggableScrollableSheet` — standard Material pattern
- Flutter documentation (training): `showDragHandle: true` parameter on `showModalBottomSheet` — adds built-in drag handle

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages, all existing dependencies confirmed in pubspec
- Architecture: HIGH — all data providers confirmed to exist and work; patterns copied from existing code
- Pitfalls: HIGH — all identified by direct code inspection (not assumptions)
- Open questions: MEDIUM — gaps identified by absence of code, not guessed

**Research date:** 2026-03-20
**Valid until:** 2026-04-20 (stable Flutter/Riverpod patterns; project code is stable)
