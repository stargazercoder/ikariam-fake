// Building upgrade dialog — popup for building details and upgrade confirmation.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/building_constants.dart';
import '../../../core/constants/resource_constants.dart';
import '../data/buildings_repository.dart';
import '../data/city_repository.dart';
import '../models/city_building.dart';
import '../models/city_resource.dart';
import '../models/construction_queue_entry.dart';
import '../providers/city_economy_provider.dart';
import '../providers/resources_provider.dart';
import '../widgets/countdown_timer_widget.dart';

/// Shows the building upgrade dialog as a centered popup.
///
/// Returns a [Future<bool?>] that resolves to true if an upgrade was started,
/// false/null if the dialog was dismissed.
Future<bool?> showBuildingUpgradeSheet(
  BuildContext context, {
  required CityBuilding building,
  required String cityId,
  required List<CityResource> currentResources,
  required ConstructionQueueEntry? activeConstruction,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: _BuildingUpgradeContent(
          building: building,
          cityId: cityId,
          currentResources: currentResources,
          activeConstruction: activeConstruction,
        ),
      ),
    ),
  );
}

/// Internal StatefulWidget for the upgrade dialog content.
class _BuildingUpgradeContent extends ConsumerStatefulWidget {
  const _BuildingUpgradeContent({
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
  ConsumerState<_BuildingUpgradeContent> createState() =>
      _BuildingUpgradeContentState();
}

class _BuildingUpgradeContentState
    extends ConsumerState<_BuildingUpgradeContent> {
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

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                // Close button
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const Divider(height: 24),

            // Tavern wine slider — shown only for tavern buildings.
            if (building.buildingType == BuildingType.tavern) ...[
              _TavernWineSlider(
                cityId: widget.cityId,
                tavernLevel: building.level,
              ),
              const Divider(height: 24),
            ],

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
                child: const Text('Close'),
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
      case ResourceType.wine:
        return Icons.wine_bar;
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
      case ResourceType.wine:
        return 'Wine';
    }
  }
}

// ---------------------------------------------------------------------------
// Tavern wine slider
// ---------------------------------------------------------------------------

/// Wine spending slider shown inside the Tavern building upgrade sheet.
///
/// Allows the player to set the city's wine spending rate (0–100%).
/// - Reads initial value from [cityEconomyStreamProvider] (wine_spending_rate).
/// - Updates local state immediately on slider move for snappy feedback.
/// - Debounces Edge Function calls at 300ms to avoid spamming the server.
/// - Displays happiness contribution, wine consumed per tick, and wine stock.
class _TavernWineSlider extends ConsumerStatefulWidget {
  const _TavernWineSlider({
    required this.cityId,
    required this.tavernLevel,
  });

  final String cityId;
  final int tavernLevel;

  @override
  ConsumerState<_TavernWineSlider> createState() => _TavernWineSliderState();
}

class _TavernWineSliderState extends ConsumerState<_TavernWineSlider> {
  /// Local slider value in [0.0, 1.0] — maps to 0–100%.
  double _rate = 0.0;

  /// Whether we've received the initial value from the stream yet.
  bool _initialized = false;

  /// Debounce timer for Edge Function calls.
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSliderChanged(double value) {
    setState(() => _rate = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      try {
        await ref.read(cityRepositoryProvider).setWineRate(
              cityId: widget.cityId,
              wineSpendingRate: (_rate * 100).round(),
            );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update wine rate: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Sync initial rate from economy stream (only on first emission).
    final economyAsync = ref.watch(cityEconomyStreamProvider(widget.cityId));
    economyAsync.whenData((economy) {
      if (!_initialized && economy != null) {
        final serverRate =
            ((economy['wine_spending_rate'] as num?)?.toInt() ?? 0) / 100.0;
        if (mounted) {
          setState(() {
            _rate = serverRate;
            _initialized = true;
          });
        }
      }
    });

    // Read wine stock from resources stream.
    final resourcesAsync =
        ref.watch(resourcesStreamProvider(widget.cityId));
    final wineAmount = resourcesAsync.whenOrNull(
          data: (resources) => resources
              .where((r) => r.resourceType == ResourceType.wine)
              .firstOrNull
              ?.amount,
        ) ??
        0.0;

    // Derived display values.
    final int ratePercent = (_rate * 100).round();
    final double happinessContribution = _rate * widget.tavernLevel;
    final double winePerTick = _rate * widget.tavernLevel * 5.0;
    final bool tavernActive = widget.tavernLevel > 0;
    final bool hasWine = wineAmount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.wine_bar, size: 20, color: Colors.purple),
            const SizedBox(width: 8),
            Text(
              'Wine Spending',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (!tavernActive) ...[
          // Tavern not yet built — disable slider with message.
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Upgrade the Tavern to start consuming wine.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Slider(
            value: 0,
            onChanged: null,
            min: 0,
            max: 1,
            divisions: 100,
            label: '0%',
          ),
        ] else ...[
          // Wine stock warning.
          if (!hasWine)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber,
                      size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 6),
                  Text(
                    'No wine available',
                    style: TextStyle(
                        color: Colors.orange.shade700, fontSize: 12),
                  ),
                ],
              ),
            ),

          // Slider row.
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _rate,
                  min: 0,
                  max: 1,
                  divisions: 100,
                  label: '$ratePercent%',
                  onChanged: _onSliderChanged,
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '$ratePercent%',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          // Stats row.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text(
                  '😄 +${happinessContribution.toStringAsFixed(1)} happiness',
                  style: TextStyle(
                    fontSize: 12,
                    color: happinessContribution > 0
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                Text(
                  '🍷 ${winePerTick.toStringAsFixed(1)}/tick',
                  style: const TextStyle(fontSize: 12, color: Colors.purple),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Wine stock: ${wineAmount.toInt()}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ],
      ],
    );
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
