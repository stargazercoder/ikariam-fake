// Modal bottom sheet for building upgrade details and confirmation.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/building_constants.dart';
import '../../../core/constants/resource_constants.dart';
import '../data/buildings_repository.dart';
import '../models/city_building.dart';
import '../models/city_resource.dart';
import '../models/construction_queue_entry.dart';
import '../widgets/countdown_timer_widget.dart';

/// Shows the building upgrade modal bottom sheet.
///
/// Returns a [Future<bool?>] that resolves to true if an upgrade was started,
/// false/null if the sheet was dismissed.
Future<bool?> showBuildingUpgradeSheet(
  BuildContext context, {
  required CityBuilding building,
  required String cityId,
  required List<CityResource> currentResources,
  required ConstructionQueueEntry? activeConstruction,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _BuildingUpgradeSheet(
      building: building,
      cityId: cityId,
      currentResources: currentResources,
      activeConstruction: activeConstruction,
    ),
  );
}

/// Internal StatefulWidget for the upgrade bottom sheet content.
class _BuildingUpgradeSheet extends ConsumerStatefulWidget {
  const _BuildingUpgradeSheet({
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
  ConsumerState<_BuildingUpgradeSheet> createState() =>
      _BuildingUpgradeSheetState();
}

class _BuildingUpgradeSheetState extends ConsumerState<_BuildingUpgradeSheet> {
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

  /// Returns true if this building is the one currently being upgraded.
  bool get _isBeingUpgraded =>
      widget.activeConstruction != null &&
      widget.activeConstruction!.buildingType ==
          widget.building.buildingType.dbName;

  /// Returns true if there is any active construction (blocks new upgrades).
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
        Navigator.of(context).pop(true);
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
    final building = widget.building;
    final targetLevel = building.level + 1;
    final cost = upgradeCost(building.buildingType, building.level);
    final durationMinutes =
        upgradeDurationMinutes(building.buildingType, building.level);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Building name + current level
            Row(
              children: [
                Icon(
                  building.buildingType.isProductionBuilding
                      ? Icons.factory
                      : Icons.home,
                  size: 32,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        building.buildingType.displayName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Current Level: ${building.level}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),

            // If this building is actively being upgraded — show countdown
            if (_isBeingUpgraded) ...[
              _UpgradeInProgressSection(
                activeConstruction: widget.activeConstruction!,
                theme: theme,
              ),
            ] else ...[
              // Upgrade target
              Text(
                'Upgrade to Level $targetLevel',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),

              // Cost breakdown
              Text(
                'Resource Cost:',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              ...cost.entries.map((entry) {
                final available = _currentAmounts[entry.key] ?? 0.0;
                final sufficient = available >= entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(
                        _resourceIcon(entry.key),
                        size: 18,
                        color: sufficient
                            ? Colors.green.shade700
                            : theme.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _resourceName(entry.key),
                        style: TextStyle(
                          color: sufficient
                              ? null
                              : theme.colorScheme.error,
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

              // Duration
              Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
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

              // Queue busy warning
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

              // Confirm button
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
              const SizedBox(height: 10),

              // Cancel button
              OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
            ],
          ],
        ),
      ),
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
    }
  }
}

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
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
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
