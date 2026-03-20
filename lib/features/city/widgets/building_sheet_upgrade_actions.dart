// Upgrade actions widget for the building detail sheet.
// Extracted from _BuildingUpgradeContent in building_upgrade_sheet.dart.
// Shows cost breakdown, build time, queue state, and Start Upgrade button.
// Does NOT pop the sheet on upgrade — stays open and shows a SnackBar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/building_constants.dart';
import '../../../core/constants/resource_constants.dart';
import '../../../shared/widgets/resource_badge.dart';
import '../data/buildings_repository.dart';
import '../models/city_building.dart';
import '../models/city_resource.dart';
import '../models/construction_queue_entry.dart';
import 'countdown_timer_widget.dart';

/// Shared upgrade action panel used by every building type in the detail sheet.
///
/// - If the building is currently being upgraded: shows upgrade-in-progress
///   section with a live [CountdownTimerWidget].
/// - Otherwise: shows resource cost breakdown with [ResourceBadge] per resource,
///   build time, optional queue-busy warning, and a Start Upgrade button.
///
/// On successful upgrade: shows a SnackBar and stays open (does NOT pop).
class BuildingSheetUpgradeActions extends ConsumerStatefulWidget {
  const BuildingSheetUpgradeActions({
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
  ConsumerState<BuildingSheetUpgradeActions> createState() =>
      _BuildingSheetUpgradeActionsState();
}

class _BuildingSheetUpgradeActionsState
    extends ConsumerState<BuildingSheetUpgradeActions> {
  bool _isLoading = false;

  /// Map from ResourceType to current amount for quick lookup.
  late Map<ResourceType, double> _currentAmounts;

  @override
  void initState() {
    super.initState();
    _currentAmounts = {
      for (final r in widget.currentResources) r.resourceType: r.amount,
    };
  }

  @override
  void didUpdateWidget(BuildingSheetUpgradeActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentResources != widget.currentResources) {
      _currentAmounts = {
        for (final r in widget.currentResources) r.resourceType: r.amount,
      };
    }
  }

  /// Returns true if this specific building is the one currently upgrading.
  bool get _isBeingUpgraded =>
      widget.activeConstruction != null &&
      widget.activeConstruction!.buildingType ==
          widget.building.buildingType.dbName;

  /// Returns true if there is any active construction in the queue.
  bool get _queueBusy => widget.activeConstruction != null;

  /// Returns true if the player has enough resources for this upgrade.
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
            content: Text('Upgrade failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isBeingUpgraded) {
      return _UpgradeInProgressSection(
        activeConstruction: widget.activeConstruction!,
        theme: theme,
      );
    }

    final targetLevel = widget.building.level + 1;
    final cost = upgradeCost(widget.building.buildingType, widget.building.level);
    final durationMinutes = upgradeDurationMinutes(
      widget.building.buildingType,
      widget.building.level,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Upgrade target title.
        Text(
          'Upgrade to Level $targetLevel',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),

        // Resource cost label.
        Text('Resource Cost:', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),

        // Cost rows.
        ...cost.entries.map((entry) {
          final available = _currentAmounts[entry.key] ?? 0.0;
          final sufficient = available >= entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                ResourceBadge(type: entry.key, radius: 10),
                const SizedBox(width: 8),
                Text(
                  _resourceName(entry.key),
                  style: TextStyle(
                    color: sufficient ? null : theme.colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '${available.toInt()} / ${entry.value}',
                  style: TextStyle(
                    color: sufficient
                        ? Colors.green.shade700
                        : theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),

        // Build time row.
        Row(
          children: [
            Icon(Icons.timer_outlined, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              'Build time: ${durationMinutes}m',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Queue busy warning (when another building is upgrading).
        if (_queueBusy && !_isBeingUpgraded)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Construction queue is busy. '
                    'Wait for the current upgrade to finish.',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 20),

        // Start Upgrade button.
        ElevatedButton.icon(
          onPressed: (_isLoading || !_hasEnoughResources || _queueBusy)
              ? null
              : _startUpgrade,
          icon: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.build),
          label: Text(_isLoading ? 'Starting...' : 'Start Upgrade'),
        ),
      ],
    );
  }

  String _resourceName(ResourceType type) {
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
// Upgrade in progress section
// ---------------------------------------------------------------------------

/// Section shown when this specific building is currently upgrading.
class _UpgradeInProgressSection extends StatelessWidget {
  const _UpgradeInProgressSection({
    required this.activeConstruction,
    required this.theme,
  });

  final ConstructionQueueEntry activeConstruction;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.construction,
            size: 36,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(height: 8),
          Text(
            'Upgrading to Level ${activeConstruction.targetLevel}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Time remaining: ',
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              CountdownTimerWidget(
                finishAt: activeConstruction.finishAt,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
