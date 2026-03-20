// Unified building detail bottom sheet — entry point for all 14 building types.
//
// Call showBuildingDetailSheet() from BuildingCell.onTap to open the sheet.
// The sheet scaffold renders:
//   1. BuildingSheetHeader — icon, name, level, close button
//   2. BuildingSheetSection('STATS') — type-dispatched stats widget
//   3. BuildingSheetSection('ACTIONS') — shared upgrade actions widget

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/building_constants.dart';
import '../models/city_building.dart';
import '../models/city_resource.dart';
import '../models/construction_queue_entry.dart';
import '../widgets/building_sheet_header.dart';
import '../widgets/building_sheet_section.dart';
import '../widgets/building_sheet_upgrade_actions.dart';
import '../widgets/building_stats/hideout_stats.dart';
import '../widgets/building_stats/placeholder_stats.dart';
import '../widgets/building_stats/town_hall_stats.dart';
import '../widgets/building_stats/town_wall_stats.dart';
import '../widgets/building_stats/trading_port_stats.dart';

/// Opens the unified building detail bottom sheet for any of the 14 building types.
///
/// The sheet is a large scrollable [DraggableScrollableSheet] with:
/// - A drag handle at the top
/// - [BuildingSheetHeader] with building icon, name, level and close button
/// - A STATS section dispatched by [BuildingType]
/// - An ACTIONS section with upgrade cost breakdown and Start Upgrade button
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
      builder: (context, scrollController) => _BuildingDetailSheetContent(
        building: building,
        cityId: cityId,
        currentResources: currentResources,
        activeConstruction: activeConstruction,
        scrollController: scrollController,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Sheet content
// ---------------------------------------------------------------------------

/// Internal content widget for the building detail sheet.
///
/// Uses [ConsumerStatefulWidget] to support future military tab controllers
/// (Plan 02 will add TabController for Barracks / Shipyard).
class _BuildingDetailSheetContent extends ConsumerStatefulWidget {
  const _BuildingDetailSheetContent({
    required this.building,
    required this.cityId,
    required this.currentResources,
    required this.activeConstruction,
    required this.scrollController,
  });

  final CityBuilding building;
  final String cityId;
  final List<CityResource> currentResources;
  final ConstructionQueueEntry? activeConstruction;
  final ScrollController scrollController;

  @override
  ConsumerState<_BuildingDetailSheetContent> createState() =>
      _BuildingDetailSheetContentState();
}

class _BuildingDetailSheetContentState
    extends ConsumerState<_BuildingDetailSheetContent> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        BuildingSheetHeader(
          building: widget.building,
          onClose: () => Navigator.of(context).pop(),
        ),
        BuildingSheetSection(
          title: 'STATS',
          child: _buildStats(context, ref),
        ),
        BuildingSheetSection(
          title: 'ACTIONS',
          child: BuildingSheetUpgradeActions(
            building: widget.building,
            cityId: widget.cityId,
            currentResources: widget.currentResources,
            activeConstruction: widget.activeConstruction,
          ),
        ),
      ],
    );
  }

  /// Returns the stats widget appropriate for this building type.
  ///
  /// Simple buildings (Town Hall, Town Wall, Hideout, Trading Port, Academy,
  /// Embassy) return their specific stats widget.
  /// Complex types (Warehouse, Tavern, Barracks, Shipyard, production buildings)
  /// return placeholder text — Plan 02 will replace these with full content.
  Widget _buildStats(BuildContext context, WidgetRef ref) {
    switch (widget.building.buildingType) {
      case BuildingType.townHall:
        return TownHallStats(
          cityId: widget.cityId,
          level: widget.building.level,
        );
      case BuildingType.townWall:
        return TownWallStats(level: widget.building.level);
      case BuildingType.hideout:
        return HideoutStats(level: widget.building.level);
      case BuildingType.tradingPort:
        return TradingPortStats(level: widget.building.level);
      case BuildingType.academy:
        return const PlaceholderStats(featureName: 'Research');
      case BuildingType.embassy:
        return const PlaceholderStats(featureName: 'Alliance');
      // Complex types — Plan 02 will replace these with full implementations:
      case BuildingType.warehouse:
        return const Text('Storage details loading...');
      case BuildingType.tavern:
        return const Text('Wine controls loading...');
      case BuildingType.barracks:
        return const Text('Unit training loading...');
      case BuildingType.shipyard:
        return const Text('Ship building loading...');
      case BuildingType.sawmill:
      case BuildingType.quarry:
      case BuildingType.glassblower:
      case BuildingType.sulfurPit:
        return const Text('Production details loading...');
    }
  }
}
