// City Grid screen — spatial building grid wrapper for the city view.
//
// Wraps the existing city data with a Stack-based spatial layout.
// Reuses _ResourcePanel and _ConstructionBanner from city_screen.dart via
// the BuildingsGrid widget defined here.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/city/models/city_building.dart';
import '../../../features/city/models/city_resource.dart';
import '../../../features/city/models/construction_queue_entry.dart';
import '../../../features/city/providers/buildings_provider.dart';
import '../../../features/city/providers/city_provider.dart';
import '../../../features/city/providers/resources_provider.dart';
import '../../../features/city/providers/construction_provider.dart';
import '../../../features/city/screens/building_upgrade_sheet.dart';
import '../../../core/constants/building_constants.dart';
import '../../../core/constants/resource_constants.dart';
import '../constants/building_positions.dart';

/// City grid screen — displays buildings on a spatial 2D grid.
///
/// This is the City tab content replacing the flat list from CityScreen.
/// The resource panel and construction banner remain above the grid.
class CityGridScreen extends ConsumerWidget {
  const CityGridScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cityAsync = ref.watch(cityProvider);

    return cityAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Failed to load city: $error',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      data: (city) {
        if (city == null) {
          return const Center(
            child: Text('No city found. Please contact support.'),
          );
        }
        return _CityGridBody(city: city);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// City grid body
// ---------------------------------------------------------------------------

class _CityGridBody extends ConsumerWidget {
  const _CityGridBody({required this.city});

  final Map<String, dynamic> city;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cityId = city['id'] as String;

    final resourcesAsync = ref.watch(resourcesStreamProvider(cityId));
    final buildingsAsync = ref.watch(buildingsStreamProvider(cityId));
    final constructionAsync = ref.watch(constructionQueueProvider(cityId));

    final activeConstruction = constructionAsync.whenOrNull(data: (e) => e);
    final currentResources =
        resourcesAsync.whenOrNull(data: (r) => r) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Resource panel.
              _ResourcePanel(resourcesAsync: resourcesAsync),
              const SizedBox(height: 12),

              // Construction banner (if active).
              if (activeConstruction != null) ...[
                _ConstructionBanner(entry: activeConstruction),
                const SizedBox(height: 12),
              ],

              // Building grid section label.
              Text(
                'City Buildings',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 8),

              // Spatial building grid.
              buildingsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(
                  'Failed to load buildings: $e',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                data: (buildings) => BuildingsGrid(
                  buildings: buildings,
                  cityId: cityId,
                  currentResources: currentResources,
                  activeConstruction: activeConstruction,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Buildings grid (public, reusable)
// ---------------------------------------------------------------------------

/// Spatial 6×5 building grid using Stack + Positioned.
///
/// Each building occupies a fixed cell defined by [kBuildingPositions].
/// Buildings not in the map are skipped (defensive coding).
class BuildingsGrid extends StatelessWidget {
  const BuildingsGrid({
    super.key,
    required this.buildings,
    required this.cityId,
    required this.currentResources,
    required this.activeConstruction,
  });

  final List<CityBuilding> buildings;
  final String cityId;
  final List<CityResource> currentResources;
  final ConstructionQueueEntry? activeConstruction;

  /// Size of each grid cell in logical pixels.
  static const double cellSize = 60.0;

  /// Grid dimensions: 6 columns × 5 rows.
  static const int cols = 6;
  static const int rows = 5;

  @override
  Widget build(BuildContext context) {
    final gridWidth = cols * cellSize;
    final gridHeight = rows * cellSize;

    return Center(
      child: SizedBox(
        width: gridWidth,
        height: gridHeight,
        child: Stack(
          children: [
            // Background grid lines.
            Positioned.fill(
              child: CustomPaint(
                painter: _BuildingGridPainter(
                  cols: cols,
                  rows: rows,
                  cellSize: cellSize,
                ),
              ),
            ),
            // Building cells.
            for (final building in buildings)
              if (kBuildingPositions.containsKey(building.buildingType))
                Builder(
                  builder: (context) {
                    final pos =
                        kBuildingPositions[building.buildingType]!;
                    return Positioned(
                      left: pos.col * cellSize + 1,
                      top: pos.row * cellSize + 1,
                      width: cellSize - 2,
                      height: cellSize - 2,
                      child: BuildingCell(
                        building: building,
                        cityId: cityId,
                        currentResources: currentResources,
                        activeConstruction: activeConstruction,
                      ),
                    );
                  },
                ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Building grid background painter
// ---------------------------------------------------------------------------

class _BuildingGridPainter extends CustomPainter {
  const _BuildingGridPainter({
    required this.cols,
    required this.rows,
    required this.cellSize,
  });

  final int cols;
  final int rows;
  final double cellSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(20)
      ..strokeWidth = 0.5;

    for (int i = 0; i <= cols; i++) {
      final x = i * cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (int i = 0; i <= rows; i++) {
      final y = i * cellSize;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_BuildingGridPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Building cell (public, reusable)
// ---------------------------------------------------------------------------

/// A single tappable building cell in the city grid.
class BuildingCell extends StatelessWidget {
  const BuildingCell({
    super.key,
    required this.building,
    required this.cityId,
    required this.currentResources,
    required this.activeConstruction,
  });

  final CityBuilding building;
  final String cityId;
  final List<CityResource> currentResources;
  final ConstructionQueueEntry? activeConstruction;

  bool get _isBeingUpgraded =>
      activeConstruction != null &&
      activeConstruction!.buildingType == building.buildingType.dbName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isProduction = building.buildingType.isProductionBuilding;
    final color = isProduction
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;

    return GestureDetector(
      onTap: () {
        // Barracks and Shipyard navigate to their dedicated military screens.
        if (building.buildingType == BuildingType.barracks) {
          context.push('/barracks?cityId=$cityId');
          return;
        }
        if (building.buildingType == BuildingType.shipyard) {
          context.push('/shipyard?cityId=$cityId');
          return;
        }
        // All other buildings show the upgrade bottom sheet.
        showBuildingUpgradeSheet(
          context,
          building: building,
          cityId: cityId,
          currentResources: currentResources,
          activeConstruction: activeConstruction,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: color.withAlpha(_isBeingUpgraded ? 200 : 160),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _isBeingUpgraded
                ? Colors.orange.shade400
                : color.withAlpha(200),
            width: _isBeingUpgraded ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isBeingUpgraded)
              const Icon(Icons.construction, size: 14, color: Colors.orange)
            else
              Icon(
                isProduction ? Icons.factory : Icons.home,
                size: 14,
                color: Colors.white.withAlpha(220),
              ),
            const SizedBox(height: 2),
            Text(
              _shortName(building.buildingType),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 8,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Lv${building.level}',
              style: TextStyle(
                fontSize: 8,
                color: Colors.white.withAlpha(180),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Short display name for building cell (fits in small cell).
  String _shortName(BuildingType type) {
    switch (type) {
      case BuildingType.townHall:
        return 'Town\nHall';
      case BuildingType.warehouse:
        return 'Whouse';
      case BuildingType.barracks:
        return 'Barr.';
      case BuildingType.shipyard:
        return 'Shpyd';
      case BuildingType.academy:
        return 'Acad.';
      case BuildingType.embassy:
        return 'Emb.';
      case BuildingType.tradingPort:
        return 'Trade\nPort';
      case BuildingType.townWall:
        return 'Wall';
      case BuildingType.hideout:
        return 'Hide.';
      case BuildingType.tavern:
        return 'Tav.';
      case BuildingType.sawmill:
        return 'Saw\nmill';
      case BuildingType.quarry:
        return 'Qrry';
      case BuildingType.glassblower:
        return 'Glass';
      case BuildingType.sulfurPit:
        return 'Sulf.\nPit';
    }
  }
}

// ---------------------------------------------------------------------------
// Resource panel (local copy to avoid circular import from city_screen.dart)
// ---------------------------------------------------------------------------

/// Compact card showing all 5 resource types with live amounts.
class _ResourcePanel extends StatelessWidget {
  const _ResourcePanel({required this.resourcesAsync});

  final AsyncValue<List<CityResource>> resourcesAsync;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resources',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 10),
            resourcesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (e, _) => Text(
                'Failed to load resources: $e',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
              data: (resources) => Wrap(
                spacing: 12,
                runSpacing: 8,
                children: resources.map((r) {
                  return _ResourceChip(resource: r);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceChip extends StatelessWidget {
  const _ResourceChip({required this.resource});

  final CityResource resource;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _icon(resource.resourceType),
          size: 16,
          color: _color(resource.resourceType),
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _label(resource.resourceType),
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            Text(
              resource.amount.toInt().toString(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  IconData _icon(ResourceType type) {
    switch (type) {
      case ResourceType.wood:
        return Icons.forest;
      case ResourceType.marble:
        return Icons.square;
      case ResourceType.crystal:
        return Icons.diamond;
      case ResourceType.sulfur:
        return Icons.local_fire_department;
      case ResourceType.gold:
        return Icons.monetization_on;
      case ResourceType.wine:
        return Icons.wine_bar;
    }
  }

  Color _color(ResourceType type) {
    switch (type) {
      case ResourceType.wood:
        return Colors.green.shade700;
      case ResourceType.marble:
        return Colors.grey.shade600;
      case ResourceType.crystal:
        return Colors.blue.shade400;
      case ResourceType.sulfur:
        return Colors.orange.shade700;
      case ResourceType.gold:
        return Colors.amber.shade700;
      case ResourceType.wine:
        return Colors.purple.shade600;
    }
  }

  String _label(ResourceType type) {
    switch (type) {
      case ResourceType.wood:
        return 'Wood';
      case ResourceType.marble:
        return 'Marble';
      case ResourceType.crystal:
        return 'Crystal';
      case ResourceType.sulfur:
        return 'Sulfur';
      case ResourceType.gold:
        return 'Gold';
      case ResourceType.wine:
        return 'Wine';
    }
  }
}

// ---------------------------------------------------------------------------
// Construction banner (local copy to avoid circular import)
// ---------------------------------------------------------------------------

/// Banner shown when a building is upgrading.
class _ConstructionBanner extends StatelessWidget {
  const _ConstructionBanner({required this.entry});

  final ConstructionQueueEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buildingName = _buildingDisplayName(entry.buildingType);

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.construction,
              color: theme.colorScheme.onPrimaryContainer,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Upgrading $buildingName to Level ${entry.targetLevel}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildingDisplayName(String dbName) {
    try {
      return buildingTypeFromDbName(dbName).displayName;
    } catch (_) {
      return dbName;
    }
  }
}
