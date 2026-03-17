// Dispatch screen — select units and dispatch to a target city.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/unit_constants.dart';
import '../../../features/city/widgets/countdown_timer_widget.dart';
import '../data/military_repository.dart';
import '../models/city_unit.dart';
import '../models/unit_movement.dart';
import '../providers/army_roster_provider.dart';
import '../providers/unit_movements_provider.dart';

/// Screen for dispatching units from [originCityId] to another city.
///
/// Shows available units with quantity inputs, a target city ID text field,
/// and a Dispatch button. Also displays active outgoing movements with
/// arrival countdowns.
class DispatchScreen extends ConsumerStatefulWidget {
  const DispatchScreen({
    super.key,
    required this.originCityId,
    this.initialTargetCityId,
  });

  final String originCityId;
  final String? initialTargetCityId;

  @override
  ConsumerState<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends ConsumerState<DispatchScreen> {
  late final TextEditingController _targetCityController;
  // Map of unit_type (DB snake_case) -> quantity to dispatch.
  final Map<String, TextEditingController> _dispatchControllers = {};
  bool _isDispatching = false;

  @override
  void initState() {
    super.initState();
    _targetCityController = TextEditingController(
      text: widget.initialTargetCityId ?? '',
    );
  }

  @override
  void dispose() {
    _targetCityController.dispose();
    for (final ctrl in _dispatchControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  /// Returns true if at least one unit has a positive dispatch quantity.
  bool get _hasUnitsSelected {
    return _dispatchControllers.values.any(
      (ctrl) => (int.tryParse(ctrl.text) ?? 0) > 0,
    );
  }

  /// Returns true if target city ID is non-empty.
  bool get _hasTarget => _targetCityController.text.trim().isNotEmpty;

  bool get _canDispatch =>
      _hasUnitsSelected && _hasTarget && !_isDispatching;

  /// Builds the units map from the current controller values.
  Map<String, int> get _selectedUnits {
    final result = <String, int>{};
    for (final entry in _dispatchControllers.entries) {
      final qty = int.tryParse(entry.value.text) ?? 0;
      if (qty > 0) result[entry.key] = qty;
    }
    return result;
  }

  Future<void> _dispatch() async {
    final targetCityId = _targetCityController.text.trim();
    if (targetCityId.isEmpty) return;

    final units = _selectedUnits;
    if (units.isEmpty) return;

    setState(() => _isDispatching = true);
    try {
      await ref.read(militaryRepositoryProvider).dispatchUnits(
            originCityId: widget.originCityId,
            destinationCityId: targetCityId,
            units: units,
          );
      if (mounted) {
        // Reset form on success.
        _targetCityController.clear();
        for (final ctrl in _dispatchControllers.values) {
          ctrl.text = '0';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Army dispatched! Check movements below.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on DispatchException catch (e) {
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
            content: Text('Dispatch failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDispatching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rosterAsync = ref.watch(armyRosterProvider(widget.originCityId));
    final movementsAsync =
        ref.watch(unitMovementsProvider(widget.originCityId));

    final roster = rosterAsync.whenOrNull(data: (units) => units) ?? [];
    final movements =
        movementsAsync.whenOrNull(data: (m) => m) ?? [];

    // Sync controllers to current roster (add new entries, keep existing).
    _syncControllers(roster);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispatch Units'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Target city input.
                Text(
                  'Destination City',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _targetCityController,
                  decoration: const InputDecoration(
                    labelText: 'Target City ID',
                    hintText: 'Paste or type the destination city UUID',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_city),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),

                // Unit selection.
                Text(
                  'Select Units to Dispatch',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 8),
                if (roster.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No units available. Train some units first.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...roster
                      .where((u) => u.quantity > 0)
                      .map(
                        (u) => _UnitDispatchRow(
                          unit: u,
                          controller: _dispatchControllers[u.unitType] ??
                              TextEditingController(text: '0'),
                          onChanged: () => setState(() {}),
                        ),
                      ),

                const SizedBox(height: 20),

                // Dispatch button.
                ElevatedButton.icon(
                  onPressed: _canDispatch ? _dispatch : null,
                  icon: _isDispatching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(_isDispatching ? 'Dispatching...' : 'Dispatch'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 24),

                // Active movements section.
                Text(
                  'Active Movements',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 8),
                if (movements.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No active movements.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...movements.map((m) => _MovementCard(movement: m)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Ensures a dispatch controller exists for each unit in the roster.
  void _syncControllers(List<CityUnit> roster) {
    for (final unit in roster) {
      if (!_dispatchControllers.containsKey(unit.unitType)) {
        _dispatchControllers[unit.unitType] =
            TextEditingController(text: '0');
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Unit dispatch row
// ---------------------------------------------------------------------------

class _UnitDispatchRow extends StatelessWidget {
  const _UnitDispatchRow({
    required this.unit,
    required this.controller,
    required this.onChanged,
  });

  final CityUnit unit;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final displayName = _displayName(unit.unitType);

    UnitType? parsedType;
    try {
      parsedType = unitTypeFromDbName(unit.unitType);
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (parsedType != null)
              CircleAvatar(
                radius: 16,
                backgroundColor: unitTypeColors[parsedType] ?? Colors.grey,
                child: Icon(
                  unitTypeIcons[parsedType] ?? Icons.help_outline,
                  color: Colors.white,
                  size: 16,
                ),
              )
            else
              const Icon(Icons.help_outline, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    'Available: ${unit.quantity}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 70,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  hintText: '0',
                  helperText: 'max ${unit.quantity}',
                  helperStyle: const TextStyle(fontSize: 10),
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
          ],
        ),
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

// ---------------------------------------------------------------------------
// Movement card
// ---------------------------------------------------------------------------

class _MovementCard extends StatelessWidget {
  const _MovementCard({required this.movement});

  final UnitMovement movement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unitSummary = movement.units.entries
        .map((e) => '${_displayName(e.key)} x${e.value}')
        .join(', ');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.military_tech, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'To: ${_shortId(movement.destinationCityId)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              unitSummary.isEmpty ? 'No units' : unitSummary,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.timer, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  movement.hasArrived ? 'Arrived' : 'Arriving in: ',
                  style: theme.textTheme.bodySmall,
                ),
                if (!movement.hasArrived)
                  CountdownTimerWidget(
                    finishAt: movement.arriveAt,
                    style: theme.textTheme.bodySmall?.copyWith(
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

  String _displayName(String dbName) {
    try {
      return unitTypeFromDbName(dbName).displayName;
    } catch (_) {
      return dbName;
    }
  }

  /// Shortens a UUID for display (first 8 chars + ...).
  String _shortId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}...';
  }
}
