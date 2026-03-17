// Shipyard screen — naval unit training and navy roster display.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/building_constants.dart';
import '../../../core/constants/unit_constants.dart';
import '../../../features/city/providers/buildings_provider.dart';
import '../../../features/city/providers/construction_provider.dart';
import '../../../features/city/providers/resources_provider.dart';
import '../../../features/city/widgets/countdown_timer_widget.dart';
import '../data/military_repository.dart';
import '../models/city_unit.dart';
import '../providers/army_roster_provider.dart';
import '../providers/training_queue_provider.dart';
import '../widgets/building_upgrade_card.dart';

/// Screen for training naval units in the Shipyard.
///
/// Shows 5 naval unit types with unlock level gating, a quantity input, and
/// a Train button. Displays active training countdown and current navy roster.
class ShipyardScreen extends ConsumerStatefulWidget {
  const ShipyardScreen({super.key, required this.cityId});

  final String cityId;

  @override
  ConsumerState<ShipyardScreen> createState() => _ShipyardScreenState();
}

class _ShipyardScreenState extends ConsumerState<ShipyardScreen> {
  // Quantity controllers for each naval unit type (keyed by UnitType.dbName).
  final Map<String, TextEditingController> _quantityControllers = {};

  @override
  void initState() {
    super.initState();
    for (final unit in _navalUnits) {
      _quantityControllers[unit.dbName] = TextEditingController(text: '1');
    }
  }

  @override
  void dispose() {
    for (final ctrl in _quantityControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  /// Naval unit types in display order.
  static final List<UnitType> _navalUnits = UnitType.values
      .where((u) => u.isNaval)
      .toList();

  Future<void> _trainUnits(String unitType, int quantity) async {
    try {
      await ref.read(militaryRepositoryProvider).trainUnits(
            cityId: widget.cityId,
            unitType: unitType,
            quantity: quantity,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Training $quantity ${_displayName(unitType)} started!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } on TrainingException catch (e) {
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
            content: Text('Training failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  String _displayName(String dbName) {
    try {
      return unitTypeFromDbName(dbName).displayName;
    } catch (_) {
      return dbName;
    }
  }

  @override
  Widget build(BuildContext context) {
    final buildingsAsync = ref.watch(buildingsStreamProvider(widget.cityId));
    final trainingAsync = ref.watch(trainingQueueProvider(widget.cityId));
    final rosterAsync = ref.watch(armyRosterProvider(widget.cityId));
    final constructionAsync =
        ref.watch(constructionQueueProvider(widget.cityId));
    final resourcesAsync = ref.watch(resourcesStreamProvider(widget.cityId));

    // Derive shipyard building and level from buildings stream.
    final shipyardBuilding = buildingsAsync.whenOrNull(
      data: (buildings) {
        try {
          return buildings.firstWhere(
            (b) => b.buildingType == BuildingType.shipyard,
          );
        } catch (_) {
          return null;
        }
      },
    );
    final shipyardLevel = shipyardBuilding?.level ?? 0;

    final activeConstruction = constructionAsync.whenOrNull(data: (e) => e);
    final currentResources =
        resourcesAsync.whenOrNull(data: (r) => r) ?? [];

    // Derive active training entry (null if queue empty).
    final activeTraining = trainingAsync.whenOrNull(data: (e) => e);

    // Derive current naval units for roster section.
    final allUnits = rosterAsync.whenOrNull(data: (units) => units) ?? [];
    final navalUnits = allUnits.where((u) => _isNaval(u.unitType)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Shipyard (Level $shipyardLevel)'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Building upgrade card.
                if (shipyardBuilding != null) ...[
                  BuildingUpgradeCard(
                    building: shipyardBuilding,
                    cityId: widget.cityId,
                    currentResources: currentResources,
                    activeConstruction: activeConstruction,
                  ),
                  const SizedBox(height: 16),
                ],

                // Active training banner.
                if (activeTraining != null) ...[
                  _TrainingBanner(entry: activeTraining),
                  const SizedBox(height: 16),
                ],

                // Unit training list.
                Text(
                  'Train Naval Units',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 8),
                ..._navalUnits.map((unit) {
                  final requiredLevel = unitUnlockLevels[unit] ?? 99;
                  final isUnlocked = shipyardLevel >= requiredLevel;
                  final queueBusy = activeTraining != null;
                  final ctrl = _quantityControllers[unit.dbName]!;
                  return _UnitTrainingRow(
                    unit: unit,
                    requiredLevel: requiredLevel,
                    isUnlocked: isUnlocked,
                    queueBusy: queueBusy,
                    quantityController: ctrl,
                    onTrain: () {
                      final qty = int.tryParse(ctrl.text) ?? 1;
                      if (qty > 0) _trainUnits(unit.dbName, qty);
                    },
                  );
                }),
                const SizedBox(height: 24),

                // Navy roster section.
                Text(
                  'Current Navy',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 8),
                _NavyRosterSection(units: navalUnits),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isNaval(String unitType) {
    try {
      return unitTypeFromDbName(unitType).isNaval;
    } catch (_) {
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Training banner
// ---------------------------------------------------------------------------

class _TrainingBanner extends StatelessWidget {
  const _TrainingBanner({required this.entry});

  final dynamic entry; // TrainingQueueEntry

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String unitName;
    try {
      unitName = unitTypeFromDbName(entry.unitType as String).displayName;
    } catch (_) {
      unitName = entry.unitType as String;
    }

    UnitType? unitType;
    try {
      unitType = unitTypeFromDbName(entry.unitType as String);
    } catch (_) {}

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (unitType != null)
              CircleAvatar(
                radius: 16,
                backgroundColor: unitTypeColors[unitType],
                child: Icon(
                  unitTypeIcons[unitType] ?? Icons.help_outline,
                  color: Colors.white,
                  size: 16,
                ),
              )
            else
              Icon(
                Icons.sailing,
                size: 32,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            const SizedBox(height: 8),
            Text(
              'Training $unitName x${entry.quantity}',
              style: theme.textTheme.titleSmall?.copyWith(
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
                  'Ready in: ',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                CountdownTimerWidget(
                  finishAt: entry.finishAt as DateTime,
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
    );
  }
}

// ---------------------------------------------------------------------------
// Unit training row
// ---------------------------------------------------------------------------

class _UnitTrainingRow extends StatelessWidget {
  const _UnitTrainingRow({
    required this.unit,
    required this.requiredLevel,
    required this.isUnlocked,
    required this.queueBusy,
    required this.quantityController,
    required this.onTrain,
  });

  final UnitType unit;
  final int requiredLevel;
  final bool isUnlocked;
  final bool queueBusy;
  final TextEditingController quantityController;
  final VoidCallback onTrain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final costs = unitBaseCosts[unit] ?? {};
    final timePerUnit = unitBaseTimes[unit] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Unit name + lock icon
            Row(
              children: [
                Expanded(
                  child: Text(
                    unit.displayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isUnlocked
                          ? null
                          : theme.colorScheme.onSurface.withAlpha(100),
                    ),
                  ),
                ),
                if (!isUnlocked)
                  Icon(
                    Icons.lock,
                    size: 14,
                    color: theme.colorScheme.onSurface.withAlpha(100),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            if (!isUnlocked)
              Text(
                'Requires Shipyard Lv.$requiredLevel',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontSize: 11,
                ),
              )
            else ...[
              Text(
                '${_costString(costs)}  •  ${timePerUnit}m/unit',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      enabled: !queueBusy,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: ElevatedButton(
                      onPressed: queueBusy ? null : onTrain,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      child: const Text('Train'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _costString(Map<String, int> costs) {
    return costs.entries
        .map((e) => '${e.value} ${_capitalise(e.key)}')
        .join(', ');
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ---------------------------------------------------------------------------
// Navy roster section
// ---------------------------------------------------------------------------

class _NavyRosterSection extends StatelessWidget {
  const _NavyRosterSection({required this.units});

  final List<CityUnit> units;

  @override
  Widget build(BuildContext context) {
    if (units.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No naval units yet. Train some ships above!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Card(
      child: Column(
        children: units
            .map(
              (u) => ListTile(
                leading: Builder(builder: (_) {
                  UnitType? type;
                  try {
                    type = unitTypeFromDbName(u.unitType);
                  } catch (_) {}
                  if (type == null) return const Icon(Icons.help_outline);
                  return CircleAvatar(
                    radius: 16,
                    backgroundColor: unitTypeColors[type],
                    child: Icon(
                      unitTypeIcons[type] ?? Icons.help_outline,
                      color: Colors.white,
                      size: 16,
                    ),
                  );
                }),
                title: Text(_displayName(u.unitType)),
                trailing: Text(
                  '${u.quantity}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  String _displayName(String dbName) {
    try {
      return unitTypeFromDbName(dbName).displayName;
    } catch (_) {
      return dbName;
    }
  }
}
