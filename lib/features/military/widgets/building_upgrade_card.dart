// Inline building upgrade card for military screens (Barracks/Shipyard).
// Reuses the same upgrade logic as the building_upgrade_sheet but renders
// as an embedded card instead of a modal bottom sheet.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/building_constants.dart';
import '../../../core/constants/resource_constants.dart';
import '../../../features/city/data/buildings_repository.dart';
import '../../../features/city/models/city_building.dart';
import '../../../features/city/models/city_resource.dart';
import '../../../features/city/models/construction_queue_entry.dart';
import '../../../features/city/widgets/countdown_timer_widget.dart';

/// Embedded card that shows building info and an upgrade button.
///
/// Used at the top of BarracksScreen and ShipyardScreen so users can
/// upgrade the building without leaving the military screen.
class BuildingUpgradeCard extends ConsumerStatefulWidget {
  const BuildingUpgradeCard({
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

  @override
  ConsumerState<BuildingUpgradeCard> createState() =>
      _BuildingUpgradeCardState();
}

class _BuildingUpgradeCardState extends ConsumerState<BuildingUpgradeCard> {
  bool _isLoading = false;

  bool get _isBeingUpgraded =>
      widget.activeConstruction != null &&
      widget.activeConstruction!.buildingType ==
          widget.building.buildingType.dbName;

  bool get _queueBusy => widget.activeConstruction != null;

  Map<ResourceType, double> get _currentAmounts => {
        for (final r in widget.currentResources) r.resourceType: r.amount,
      };

  bool get _hasEnoughResources {
    final cost = upgradeCost(
      widget.building.buildingType,
      widget.building.level,
    );
    for (final entry in cost.entries) {
      final available = _currentAmounts[entry.key] ?? 0.0;
      if (available < entry.value) return false;
    }
    return true;
  }

  Future<void> _startUpgrade() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(buildingsRepositoryProvider).upgradeBuilding(
            cityId: widget.cityId,
            buildingType: widget.building.buildingType.dbName,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Upgrade started! ${widget.building.buildingType.displayName} '
              'will reach Level ${widget.building.level + 1} soon.',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } on BuildingUpgradeException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upgrade failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final building = widget.building;
    final targetLevel = building.level + 1;
    final cost = upgradeCost(building.buildingType, building.level);
    final durationMinutes =
        upgradeDurationMinutes(building.buildingType, building.level);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: _isBeingUpgraded
            ? BorderSide(color: Colors.orange.shade400, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _isBeingUpgraded
            ? _buildUpgradeInProgress(theme)
            : _buildUpgradeAvailable(theme, targetLevel, cost, durationMinutes),
      ),
    );
  }

  Widget _buildUpgradeInProgress(ThemeData theme) {
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.construction, color: Colors.orange.shade700, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Upgrading to Level ${widget.activeConstruction!.targetLevel}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Ready in: ', style: TextStyle(color: Colors.orange.shade700)),
            CountdownTimerWidget(
              finishAt: widget.activeConstruction!.finishAt,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.bold,
                fontFeatures: [const FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUpgradeAvailable(
    ThemeData theme,
    int targetLevel,
    Map<ResourceType, int> cost,
    int durationMinutes,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row: "Upgrade to Level X" + duration
        Row(
          children: [
            Icon(Icons.arrow_circle_up, color: theme.colorScheme.primary, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Upgrade to Level $targetLevel',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            Icon(Icons.timer_outlined, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              '${durationMinutes}m',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Cost chips in a row
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: cost.entries.map((entry) {
            final available = _currentAmounts[entry.key] ?? 0.0;
            final sufficient = available >= entry.value;
            return Chip(
              avatar: Icon(
                _resourceIcon(entry.key),
                size: 16,
                color: sufficient ? Colors.green.shade700 : theme.colorScheme.error,
              ),
              label: Text(
                '${entry.value}',
                style: TextStyle(
                  fontSize: 12,
                  color: sufficient ? Colors.green.shade700 : theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            );
          }).toList(),
        ),
        const SizedBox(height: 10),

        // Queue busy warning
        if (_queueBusy && !_isBeingUpgraded)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Construction queue is busy.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),

        // Upgrade button
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            height: 36,
            child: ElevatedButton.icon(
              onPressed: (_isLoading || !_hasEnoughResources || _queueBusy)
                  ? null
                  : _startUpgrade,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.build, size: 18),
              label: Text(_isLoading ? 'Starting...' : 'Upgrade'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _resourceIcon(ResourceType type) {
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
    }
  }
}
