# Phase 25: Visual Constants - Research

**Researched:** 2026-03-19
**Domain:** Flutter UI — resource and building icon/color system
**Confidence:** HIGH

## Summary

The codebase has five separate places that re-implement identical `switch` statements mapping `ResourceType` → icon and `ResourceType` → color. These are private helper methods inside individual widget classes, meaning any icon or color change must be applied in five different files. Building types have a similar problem: two places use a bare binary (`isProductionBuilding ? Icons.factory : Icons.home`) instead of per-type icons, and the spy report dialog re-implements building icon logic independently.

The existing `unitTypeColors` and `unitTypeIcons` maps in `unit_constants.dart` show the correct pattern: a `Map<UnitType, Color>` and `Map<UnitType, IconData>` defined once in a constants file, then imported wherever needed. Phase 25 simply repeats that pattern for `ResourceType` and `BuildingType`.

The phase also requires changing the resource display widget from a raw `Icon` to a `CircleAvatar` containing a letter (W/M/C/S/G). That widget change must be applied in every file that renders resource chips — currently two files both define their own `_ResourceChip` private class.

**Primary recommendation:** Create `lib/core/constants/visual_constants.dart` with `resourceTypeColor`, `resourceTypeIcon`, `resourceTypeLetter`, `buildingTypeColor`, and `buildingTypeIcon` maps. Then replace every private `_icon()` / `_color()` switch method in every file with a lookup into those maps. Replace raw `Icon` resource widgets with a shared `ResourceBadge` widget.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| ICON-01 | 5 resource types displayed with colored circle + letter icons consistently | Define `resourceTypeColor`, `resourceTypeLetter` maps; create `ResourceBadge` widget using `CircleAvatar` |
| ICON-02 | 10 building types have consistent icon and color defined and used across all UI | Define `buildingTypeColor`, `buildingTypeIcon` maps; replace binary `isProductionBuilding` icon logic in `BuildingCell` and `_SpyReportDialogContent` |
| ICON-03 | Resource bar, production breakdown, trade dialog, and all resource-displaying screens use the new resource icons | Replace ad-hoc `_icon()` / `_color()` switch methods in 5 files with lookups into shared maps |
</phase_requirements>

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter/material.dart | SDK | `CircleAvatar`, `Icons`, `Colors` | Already used everywhere |

No new dependencies. Everything needed is already in the Flutter SDK.

**Installation:** None required.

---

## Architecture Patterns

### Pattern 1: Existing unitTypeColors / unitTypeIcons (pattern to follow exactly)

Source: `lib/core/constants/unit_constants.dart` lines 219–255.

```dart
/// Fixed color for each unit type, used in battle report charts and legends.
const Map<UnitType, Color> unitTypeColors = {
  UnitType.hoplite: Color(0xFF4CAF50),
  // ...
};

/// Icon for each unit type, used in military screen CircleAvatars.
const Map<UnitType, IconData> unitTypeIcons = {
  UnitType.hoplite: Icons.shield,
  // ...
};
```

Usage pattern in barracks_screen.dart (lines 261–269):
```dart
CircleAvatar(
  radius: 16,
  backgroundColor: unitTypeColors[unitType],
  child: Icon(
    unitTypeIcons[unitType] ?? Icons.help_outline,
    color: Colors.white,
    size: 16,
  ),
)
```

### Pattern 2: New constants to add to visual_constants.dart

The requirement specifies colored circle + letter icons (W, M, C, S, G). The letter approach is used instead of a `CircleAvatar` + `Icon`:

```dart
// In lib/core/constants/visual_constants.dart

import 'package:flutter/material.dart';
import 'resource_constants.dart';
import 'building_constants.dart';

/// Canonical color for each resource type.
const Map<ResourceType, Color> resourceTypeColor = {
  ResourceType.wood:    Color(0xFF388E3C), // Colors.green.shade700
  ResourceType.marble:  Color(0xFF757575), // Colors.grey.shade600
  ResourceType.crystal: Color(0xFF42A5F5), // Colors.blue.shade400
  ResourceType.sulfur:  Color(0xFFEF6C00), // Colors.orange.shade700
  ResourceType.gold:    Color(0xFFFFA000), // Colors.amber.shade700
  ResourceType.wine:    Color(0xFF7B1FA2), // Colors.purple.shade700 (wine_bar decision)
};

/// Single uppercase letter identifier for each resource type.
/// Used in CircleAvatar badges per ICON-01 requirement.
const Map<ResourceType, String> resourceTypeLetter = {
  ResourceType.wood:    'W',
  ResourceType.marble:  'M',
  ResourceType.crystal: 'C',
  ResourceType.sulfur:  'S',
  ResourceType.gold:    'G',
  ResourceType.wine:    'V', // Vinum — wine in Latin, avoids clash with Wood
};

/// Canonical display name for each resource type.
const Map<ResourceType, String> resourceTypeName = {
  ResourceType.wood:    'Wood',
  ResourceType.marble:  'Marble',
  ResourceType.crystal: 'Crystal',
  ResourceType.sulfur:  'Sulfur',
  ResourceType.gold:    'Gold',
  ResourceType.wine:    'Wine',
};

/// Canonical Material icon for each resource type (fallback when letter not used).
const Map<ResourceType, IconData> resourceTypeIcon = {
  ResourceType.wood:    Icons.forest,
  ResourceType.marble:  Icons.square,
  ResourceType.crystal: Icons.diamond,
  ResourceType.sulfur:  Icons.local_fire_department,
  ResourceType.gold:    Icons.monetization_on,
  ResourceType.wine:    Icons.wine_bar,
};

/// Canonical color for each building type.
const Map<BuildingType, Color> buildingTypeColor = {
  BuildingType.townHall:    Color(0xFF1565C0), // blue
  BuildingType.warehouse:   Color(0xFF6D4C41), // brown
  BuildingType.barracks:    Color(0xFFC62828), // red
  BuildingType.shipyard:    Color(0xFF00838F), // cyan-dark
  BuildingType.academy:     Color(0xFF4527A0), // deep purple
  BuildingType.embassy:     Color(0xFF2E7D32), // green-dark
  BuildingType.tradingPort: Color(0xFF00695C), // teal
  BuildingType.townWall:    Color(0xFF37474F), // blue-grey
  BuildingType.hideout:     Color(0xFF4E342E), // dark brown
  BuildingType.tavern:      Color(0xFF6A1B9A), // purple
  // Production buildings (tertiary theme color family)
  BuildingType.sawmill:     Color(0xFF558B2F), // light-green-dark
  BuildingType.quarry:      Color(0xFF546E7A), // blue-grey
  BuildingType.glassblower: Color(0xFF0277BD), // light-blue-dark
  BuildingType.sulfurPit:   Color(0xFFE65100), // deep-orange
};

/// Canonical Material icon for each building type.
const Map<BuildingType, IconData> buildingTypeIcon = {
  BuildingType.townHall:    Icons.account_balance,
  BuildingType.warehouse:   Icons.warehouse,
  BuildingType.barracks:    Icons.shield,
  BuildingType.shipyard:    Icons.directions_boat,
  BuildingType.academy:     Icons.school,
  BuildingType.embassy:     Icons.flag,
  BuildingType.tradingPort: Icons.local_shipping,
  BuildingType.townWall:    Icons.security,
  BuildingType.hideout:     Icons.visibility_off,
  BuildingType.tavern:      Icons.wine_bar,
  BuildingType.sawmill:     Icons.forest,
  BuildingType.quarry:      Icons.terrain,
  BuildingType.glassblower: Icons.diamond,
  BuildingType.sulfurPit:   Icons.local_fire_department,
};
```

### Pattern 3: Shared ResourceBadge widget

Create `lib/shared/widgets/resource_badge.dart`:

```dart
// Canonical colored-circle + letter badge for a resource type.
// Implements ICON-01: colored circle + letter (W, M, C, S, G).
class ResourceBadge extends StatelessWidget {
  const ResourceBadge({
    super.key,
    required this.type,
    this.radius = 10.0,
  });

  final ResourceType type;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = resourceTypeColor[type] ?? Colors.grey;
    final letter = resourceTypeLetter[type] ?? '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
```

### Recommended File Structure

```
lib/
├── core/constants/
│   ├── visual_constants.dart     # NEW — all resourceType* and buildingType* maps
│   ├── resource_constants.dart   # existing — no changes needed
│   ├── building_constants.dart   # existing — no changes needed
│   └── unit_constants.dart       # existing — pattern reference
└── shared/widgets/
    └── resource_badge.dart       # NEW — CircleAvatar letter badge widget
```

### Anti-Patterns to Avoid

- **Duplicated switch methods:** Never add another private `_icon(ResourceType)` or `_color(ResourceType)` method to a widget. Always import from `visual_constants.dart`.
- **Hardcoded Colors.X.shadeY in widgets:** Replace all `Colors.green.shade700` (etc.) used for resource color with the map lookup.
- **Binary building icon logic:** `isProductionBuilding ? Icons.factory : Icons.home` must be replaced with `buildingTypeIcon[building.buildingType] ?? Icons.home`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Resource letter badges | Custom painter or complex layout | `CircleAvatar` + `Text` | Built-in Flutter widget, handles sizing automatically |
| Resource color lookup | New switch statement in each widget | `resourceTypeColor[type]` map | Single source of truth, O(1) lookup |

---

## Files That Need Changes

This is the most important section for the planner. Every file below has ad-hoc resource or building icon/color code that must be replaced.

### Files with ad-hoc resource icon/color switches (MUST replace with visual_constants.dart lookups)

| File | What to Replace | Lines (approx) |
|------|----------------|---------------|
| `lib/features/city/screens/city_screen.dart` | `_ResourceChip._icon()`, `_ResourceChip._color()`, `_ProductionBreakdownSheet._resourceIcon()` | 505–536, 647–659 |
| `lib/features/map/screens/city_grid_screen.dart` | `_ResourceChip._icon()`, `_ResourceChip._color()` (local copy) | 463–512 |
| `lib/features/city/screens/building_upgrade_sheet.dart` | `_BuildingUpgradeContentState._resourceIcon()` | 358–373 |
| `lib/features/trade/screens/trade_dialog.dart` | top-level `_resourceIcon(String)` function | 307–313 |
| `lib/features/battles/screens/widgets/pillage_result_card.dart` | `_ResourceRow._iconForResource()`, `_ResourceRow._colorForResource()` | 163–191 |
| `lib/features/espionage/screens/spy_report_dialog.dart` | `_resourceIcon()`, `_resourceColor()` methods | 290–322 |

### Files with ad-hoc building icon logic (MUST replace with buildingTypeIcon map)

| File | What to Replace | Current Code |
|------|----------------|-------------|
| `lib/features/map/screens/city_grid_screen.dart` | `BuildingCell` icon logic | `isProduction ? Icons.factory : Icons.home` (line 307) |
| `lib/features/city/screens/building_upgrade_sheet.dart` | header icon in `_BuildingUpgradeContent` | `isProductionBuilding ? Icons.factory : Icons.home` (line 168) |
| `lib/features/espionage/screens/spy_report_dialog.dart` | `_buildingIcon()` method | `productionTypes.contains(buildingType) ? Icons.factory : Icons.home` (line 324–330) |

### Files where resource display uses old Icon (must switch to ResourceBadge)

The `_ResourceChip` in `city_screen.dart` and `city_grid_screen.dart` currently renders:
```dart
Icon(_icon(type), size: 16, color: _color(type))
```
This must become a `ResourceBadge(type: type, radius: 10)`.

The `_ResourceRow` in `pillage_result_card.dart` renders resource icons inline — same replacement.

The `_ResourceSliderRow` in `trade_dialog.dart` uses `Icon(_resourceIcon(type), size: 18)` — same replacement.

The `spy_report_dialog.dart` resource rows use raw `Icon` — same replacement.

---

## Common Pitfalls

### Pitfall 1: Duplicate _ResourceChip class in two files

**What goes wrong:** `city_screen.dart` and `city_grid_screen.dart` both define their own `_ResourceChip` private class. A comment in `city_grid_screen.dart` (line 372) notes this is a "local copy to avoid circular import."
**Why it happens:** `city_screen.dart` and `city_grid_screen.dart` are in different feature directories. Making one import the other would create circular deps.
**How to avoid:** The shared `ResourceBadge` widget lives in `lib/shared/widgets/` which neither feature file imports from each other. After Phase 25, both `_ResourceChip` classes can be replaced or simplified to use `ResourceBadge`.
**Warning signs:** If you see two files both defining `_ResourceChip`, both need updating.

### Pitfall 2: wine icon color inconsistency

**What goes wrong:** The wine icon already has a decision in PROJECT.md: `Icons.wine_bar + Colors.purple.shade600`. However, `city_screen.dart` uses `Colors.purple.shade600` while `building_upgrade_sheet.dart` uses `Colors.purple` (no shade). The canonical map must use one value.
**How to avoid:** Use `Color(0xFF7B1FA2)` (purple.shade700, one step darker than shade600 `0xFF8E24AA`) or match shade600 exactly. Confirm the choice and apply consistently.

### Pitfall 3: String-keyed vs enum-keyed resource lookup

**What goes wrong:** Several files (`pillage_result_card.dart`, `trade_dialog.dart`, `spy_report_dialog.dart`) receive resource data as `Map<String, int>` or `Map<String, dynamic>` keyed by DB name strings ('wood', 'marble', etc.), not `ResourceType` enums. The visual_constants maps are keyed by `ResourceType` enum.
**How to avoid:** Use `resourceTypeFromDbName(key)` from `building_constants.dart` to convert DB string to enum before looking up color/icon/letter. Always guard with a fallback:
```dart
ResourceType? type;
try { type = resourceTypeFromDbName(key); } catch (_) {}
final color = type != null ? resourceTypeColor[type] : Colors.grey;
```

### Pitfall 4: resource_constants.dart wine enum member

**What goes wrong:** `ResourceType.wine` is defined in `resource_constants.dart` but the 5-resource display bar in `city_screen.dart` only applies production rate logic to wood/marble/crystal/sulfur. Wine and gold appear in the bar without rate labels. Phase 25 only adds wine's circle+letter badge, not a rate label.
**How to avoid:** `resourceTypeLetter` should include wine ('V' or 'W' — but 'W' is taken by Wood). Use 'V' for wine to avoid the clash.

---

## Code Examples

### Replacing a resource icon switch method

Before (example from `city_screen.dart`):
```dart
IconData _icon(ResourceType type) {
  switch (type) {
    case ResourceType.wood:    return Icons.forest;
    case ResourceType.marble:  return Icons.square;
    case ResourceType.crystal: return Icons.diamond;
    case ResourceType.sulfur:  return Icons.local_fire_department;
    case ResourceType.gold:    return Icons.monetization_on;
    case ResourceType.wine:    return Icons.wine_bar;
  }
}
```

After (import visual_constants.dart, remove the method, use map lookup):
```dart
import '../../../core/constants/visual_constants.dart';
// In widget build():
ResourceBadge(type: type, radius: 10)
// or for non-badge icon contexts:
Icon(resourceTypeIcon[type] ?? Icons.help_outline, ...)
```

### Replacing building icon binary logic

Before (city_grid_screen.dart `BuildingCell.build()`):
```dart
Icon(
  isProduction ? Icons.factory : Icons.home,
  size: 14,
  color: Colors.white.withAlpha(220),
)
```

After:
```dart
import '../../../core/constants/visual_constants.dart';
// ...
Icon(
  buildingTypeIcon[building.buildingType] ?? Icons.home,
  size: 14,
  color: Colors.white.withAlpha(220),
)
```

### Building cell color should also use canonical map

Currently `BuildingCell.build()` in `city_grid_screen.dart`:
```dart
final color = isProduction
    ? theme.colorScheme.tertiary
    : theme.colorScheme.primary;
```

After Phase 25 this becomes:
```dart
final color = buildingTypeColor[building.buildingType]
    ?? theme.colorScheme.primary;
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| No unit icons/colors | `unitTypeColors` + `unitTypeIcons` maps in `unit_constants.dart` | Phase 17 (v1.2) | Pattern to follow for resources and buildings |
| Wine icon undefined | `Icons.wine_bar + Colors.purple.shade600` decision | Phase 10 (v1.1) | Already locked; copy to `resourceTypeColor[wine]` |

---

## Open Questions

1. **Wine letter: 'V' vs 'W'**
   - What we know: 'W' is used for Wood. Wine in Latin is "vinum" → 'V'. No other resource starts with V.
   - What's unclear: The user hasn't confirmed the letter.
   - Recommendation: Use 'V' for Wine to avoid clash with Wood's 'W'. This is a discretion call — the planner should pick 'V' unless overridden.

2. **Resource bar: should gold and wine also show circle+letter?**
   - What we know: ICON-01 says "W, M, C, S, G for all 5 resource types." Gold = G. Wine is the 6th resource and is not in the 5-resource spec.
   - What's unclear: Does wine get a circle+letter too, or does it keep the `Icons.wine_bar` icon?
   - Recommendation: Apply `ResourceBadge` to all `ResourceType` values including wine for full consistency. The letter 'V' disambiguates wine from wood.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (Flutter SDK built-in) |
| Config file | pubspec.yaml dev_dependencies |
| Quick run command | `flutter test test/widget_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ICON-01 | `ResourceBadge` renders colored circle + correct letter | unit | `flutter test test/widgets/resource_badge_test.dart` | ❌ Wave 0 |
| ICON-02 | `buildingTypeIcon` and `buildingTypeColor` cover all 14 BuildingType values | unit | `flutter test test/constants/visual_constants_test.dart` | ❌ Wave 0 |
| ICON-03 | `resourceTypeColor` and `resourceTypeLetter` cover all ResourceType values | unit | `flutter test test/constants/visual_constants_test.dart` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/constants/visual_constants_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/constants/visual_constants_test.dart` — covers ICON-01, ICON-02, ICON-03 (map completeness)
- [ ] `test/widgets/resource_badge_test.dart` — widget render test for `ResourceBadge`

---

## Sources

### Primary (HIGH confidence)
- Direct codebase reading — `lib/core/constants/unit_constants.dart` (unitTypeColors/unitTypeIcons pattern)
- Direct codebase reading — `lib/features/city/screens/city_screen.dart` (5 ad-hoc resource switch methods identified)
- Direct codebase reading — `lib/features/map/screens/city_grid_screen.dart` (duplicate ResourceChip, binary building icon)
- Direct codebase reading — `lib/features/city/screens/building_upgrade_sheet.dart` (ad-hoc icon/color switches)
- Direct codebase reading — `lib/features/trade/screens/trade_dialog.dart` (string-keyed resource icon function)
- Direct codebase reading — `lib/features/battles/screens/widgets/pillage_result_card.dart` (divergent icon/color for marble: `Icons.domain` + `Colors.blueGrey`)
- Direct codebase reading — `lib/features/espionage/screens/spy_report_dialog.dart` (building icon binary logic)
- `.planning/PROJECT.md` — wine icon decision (locked: `Icons.wine_bar + Colors.purple.shade600`)
- `.planning/REQUIREMENTS.md` — ICON-01, ICON-02, ICON-03 definitions

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new deps; Flutter SDK only
- Architecture: HIGH — directly modeled on existing `unitTypeColors` pattern in same codebase
- Pitfalls: HIGH — identified from direct file reads, not inference

**Research date:** 2026-03-19
**Valid until:** 2026-04-18 (stable domain — no external dependencies)
