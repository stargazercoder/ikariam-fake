// Canonical resource and building icon/color constants.
//
// Single source of truth for all resource and building visual representations.
// Follow the same pattern as unitTypeColors / unitTypeIcons in unit_constants.dart.
//
// Usage:
//   resourceTypeColor[ResourceType.wood]  → Color(0xFF388E3C)
//   resourceTypeLetter[ResourceType.wood] → 'W'
//   buildingTypeIcon[BuildingType.barracks] ?? Icons.home

import 'package:flutter/material.dart';

import 'building_constants.dart';
import 'resource_constants.dart';

/// Canonical color for each resource type.
/// Used in ResourceBadge CircleAvatar backgrounds and inline icon colors.
/// Wine color locked to purple.shade600 per PROJECT.md key decision.
const Map<ResourceType, Color> resourceTypeColor = {
  ResourceType.wood:    Color(0xFF388E3C), // Colors.green.shade700
  ResourceType.marble:  Color(0xFF757575), // Colors.grey.shade600
  ResourceType.crystal: Color(0xFF42A5F5), // Colors.blue.shade400
  ResourceType.sulfur:  Color(0xFFEF6C00), // Colors.orange.shade700
  ResourceType.gold:    Color(0xFFFFA000), // Colors.amber.shade700
  ResourceType.wine:    Color(0xFF8E24AA), // Colors.purple.shade600 (locked decision)
};

/// Single uppercase letter identifier for each resource type.
/// Used in CircleAvatar badges (ICON-01 requirement).
/// Wine uses 'V' (Vinum, Latin for wine) to avoid clash with Wood's 'W'.
const Map<ResourceType, String> resourceTypeLetter = {
  ResourceType.wood:    'W',
  ResourceType.marble:  'M',
  ResourceType.crystal: 'C',
  ResourceType.sulfur:  'S',
  ResourceType.gold:    'G',
  ResourceType.wine:    'V',
};

/// Canonical Material icon for each resource type.
/// Use when a letter badge (ResourceBadge) is not appropriate (e.g. icon-only row).
/// Always access via `resourceTypeIcon[type] ?? Icons.help_outline` for null safety.
const Map<ResourceType, IconData> resourceTypeIcon = {
  ResourceType.wood:    Icons.forest,
  ResourceType.marble:  Icons.square,
  ResourceType.crystal: Icons.diamond,
  ResourceType.sulfur:  Icons.local_fire_department,
  ResourceType.gold:    Icons.monetization_on,
  ResourceType.wine:    Icons.wine_bar,
};

/// Canonical color for each building type.
/// Replaces the binary isProductionBuilding color logic in BuildingCell.
/// Always access via `buildingTypeColor[type] ?? theme.colorScheme.primary`.
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
  BuildingType.sawmill:     Color(0xFF558B2F), // light-green-dark
  BuildingType.quarry:      Color(0xFF546E7A), // blue-grey-medium
  BuildingType.glassblower: Color(0xFF0277BD), // light-blue-dark
  BuildingType.sulfurPit:   Color(0xFFE65100), // deep-orange
};

/// Canonical Material icon for each building type.
/// Replaces binary `isProductionBuilding ? Icons.factory : Icons.home` logic.
/// Always access via `buildingTypeIcon[type] ?? Icons.home` for null safety.
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
