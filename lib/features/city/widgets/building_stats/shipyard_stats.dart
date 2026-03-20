// Shipyard stats widget — naval unit training grid, active training queue
// countdown, and navy roster. Extracted from shipyard_screen.dart.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/unit_constants.dart';
import '../../../military/data/military_repository.dart';
import '../../../military/models/city_unit.dart';
import '../../../military/providers/army_roster_provider.dart';
import '../../../military/providers/training_queue_provider.dart';
import '../countdown_timer_widget.dart';

/// Shipyard building stats — shows the unit training grid for all 5 naval
/// unit types, displays the active training queue countdown, and lists the
/// current navy roster.
class ShipyardStats extends ConsumerStatefulWidget {
  const ShipyardStats({
    super.key,
    required this.cityId,
    required this.shipyardLevel,
  });

  final String cityId;
  final int shipyardLevel;

  @override
  ConsumerState<ShipyardStats> createState() => _ShipyardStatsState();
}

class _ShipyardStatsState extends ConsumerState<ShipyardStats> {
  /// Quantity controllers for each naval unit type (keyed by UnitType.dbName).
  final Map<String, TextEditingController> _quantityControllers = {};

  /// Naval unit types in display order.
  static final List<UnitType> _navalUnits =
      UnitType.values.where((u) => u.isNaval).toList();

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
            content: Text(
                'Training $quantity ${_displayName(unitType)} started!'),
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
    final theme = Theme.of(context);
    final trainingAsync = ref.watch(trainingQueueProvider(widget.cityId));
    final rosterAsync = ref.watch(armyRosterProvider(widget.cityId));

    final activeTraining = trainingAsync.whenOrNull(data: (e) => e);
    final allUnits = rosterAsync.whenOrNull(data: (units) => units) ?? [];
    final navalUnits = allUnits.where((u) => _isNaval(u.unitType)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Active training banner.
        if (activeTraining != null) ...[
          _TrainingBanner(entry: activeTraining),
          const SizedBox(height: 16),
        ],

        // Unit training grid.
        Text(
          'Train Naval Units',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        ..._navalUnits.map((unit) {
          final requiredLevel = unitUnlockLevels[unit] ?? 99;
          final isUnlocked = widget.shipyardLevel >= requiredLevel;
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
        const SizedBox(height: 16),

        // Navy roster section.
        Text(
          'Current Navy',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        _NavyRosterSection(units: navalUnits),
      ],
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
            // Unit name + lock icon.
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
                '${_costString(costs)}  \u2022  ${timePerUnit}m/unit',
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
