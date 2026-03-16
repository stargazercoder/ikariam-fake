import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/city/providers/city_provider.dart';
import 'dev_rpc_service.dart';

/// Wraps [child] with a floating developer toolbar FAB in debug mode.
///
/// In release builds, [kDebugMode] is `false` and this widget returns [child]
/// directly — tree-shaken by the compiler so zero overhead in production.
///
/// In debug mode (including flutter test), a [Stack] overlays the FAB above
/// the bottom-right corner of the child widget.
///
/// DEV ONLY — imported only via [MainShellScreen]'s kDebugMode conditional.
class DevToolbarWrapper extends StatelessWidget {
  const DevToolbarWrapper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return child;

    return Stack(
      children: [
        child,
        const Positioned(
          bottom: 80,
          right: 16,
          child: _DevToolbarFab(),
        ),
      ],
    );
  }
}

/// FAB that expands into a column of developer action buttons.
class _DevToolbarFab extends ConsumerStatefulWidget {
  const _DevToolbarFab();

  @override
  ConsumerState<_DevToolbarFab> createState() => _DevToolbarFabState();
}

class _DevToolbarFabState extends ConsumerState<_DevToolbarFab> {
  bool _isExpanded = false;
  late final DevRpcService _devRpc;

  @override
  void initState() {
    super.initState();
    _devRpc = DevRpcService();
  }

  // Building types matching city_buildings CHECK constraint
  static const _buildingTypes = [
    'town_hall',
    'warehouse',
    'barracks',
    'shipyard',
    'academy',
    'embassy',
    'trading_port',
    'town_wall',
    'hideout',
    'tavern',
    'sawmill',
    'quarry',
    'glassblower',
    'sulfur_pit',
  ];

  // Unit types matching unit_type CHECK constraint
  static const _unitTypes = [
    'hoplite',
    'phalanx',
    'archer',
    'cavalry',
    'catapult',
    'mortar',
    'medic',
    'cook',
    'cargo_ship',
    'ram_ship',
    'catapult_ship',
    'mortar_ship',
    'diving_boat',
  ];

  String? _currentCityId() {
    final city = ref.read(cityProvider).whenOrNull(data: (c) => c);
    return city?['id'] as String?;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  Future<void> _injectResources() async {
    final cityId = _currentCityId();
    if (cityId == null) {
      _showSnack('No city loaded — cannot inject resources');
      return;
    }
    try {
      await _devRpc.injectResources(cityId);
      _showSnack('Injected 5000 of each resource');
    } catch (_) {
      _showSnack('Failed to inject resources');
    }
  }

  Future<void> _levelUpBuilding() async {
    final cityId = _currentCityId();
    if (cityId == null) {
      _showSnack('No city loaded — cannot level up building');
      return;
    }

    String? selectedType = _buildingTypes.first;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Level Up Building'),
        content: StatefulBuilder(
          builder: (ctx2, setStateDialog) => DropdownButton<String>(
            value: selectedType,
            isExpanded: true,
            items: _buildingTypes
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) {
              setStateDialog(() => selectedType = v);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Level Up'),
          ),
        ],
      ),
    );

    if (confirmed != true || selectedType == null) return;
    try {
      await _devRpc.levelUpBuilding(cityId, selectedType!);
      _showSnack('Leveled up $selectedType');
    } catch (_) {
      _showSnack('Failed to level up $selectedType');
    }
  }

  Future<void> _spawnUnits() async {
    final cityId = _currentCityId();
    if (cityId == null) {
      _showSnack('No city loaded — cannot spawn units');
      return;
    }

    String? selectedType = _unitTypes.first;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Spawn Units'),
        content: StatefulBuilder(
          builder: (ctx2, setStateDialog) => DropdownButton<String>(
            value: selectedType,
            isExpanded: true,
            items: _unitTypes
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) {
              setStateDialog(() => selectedType = v);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Spawn 50'),
          ),
        ],
      ),
    );

    if (confirmed != true || selectedType == null) return;
    try {
      await _devRpc.spawnUnits(cityId, selectedType!);
      _showSnack('Spawned 50 $selectedType units');
    } catch (_) {
      _showSnack('Failed to spawn $selectedType');
    }
  }

  Future<void> _bulkSpawnUnits() async {
    final cityId = _currentCityId();
    if (cityId == null) {
      _showSnack('No city loaded — cannot bulk spawn units');
      return;
    }

    // Pre-create controllers to avoid TextEditingController rebuild pitfall inside itemBuilder
    final controllers = {
      for (final type in _unitTypes) type: TextEditingController(text: '50'),
    };
    var checkedTypes = <String>{};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bulk Spawn Units'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: StatefulBuilder(
            builder: (ctx2, setStateDialog) => ListView.builder(
              itemCount: _unitTypes.length,
              itemBuilder: (_, index) {
                final type = _unitTypes[index];
                return Row(
                  children: [
                    Checkbox(
                      value: checkedTypes.contains(type),
                      onChanged: (checked) {
                        setStateDialog(() {
                          if (checked == true) {
                            checkedTypes.add(type);
                            controllers[type]!.text = '50';
                          } else {
                            checkedTypes.remove(type);
                          }
                        });
                      },
                    ),
                    Expanded(child: Text(type)),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: controllers[type],
                        keyboardType: TextInputType.number,
                        enabled: checkedTypes.contains(type),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Spawn'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      for (final c in controllers.values) {
        c.dispose();
      }
      return;
    }

    final toSpawn = {
      for (final type in checkedTypes)
        type: int.tryParse(controllers[type]!.text) ?? 50,
    };

    for (final c in controllers.values) {
      c.dispose();
    }

    if (toSpawn.isEmpty) return;

    try {
      await _devRpc.bulkSpawnUnits(cityId, toSpawn);
      _showSnack(
        'Spawned: ${toSpawn.entries.map((e) => "${e.value} ${e.key}").join(", ")}',
      );
    } catch (_) {
      _showSnack('Failed to bulk spawn units');
    }
  }

  Future<void> _instantComplete() async {
    final cityId = _currentCityId();
    if (cityId == null) {
      _showSnack('No city loaded — cannot instant complete');
      return;
    }
    try {
      await _devRpc.instantComplete(cityId);
      _showSnack('Completed all training & construction');
    } catch (_) {
      _showSnack('Failed to instant complete');
    }
  }

  Future<void> _triggerBattle() async {
    final cityId = _currentCityId();
    if (cityId == null) {
      _showSnack('No city loaded — cannot trigger battle');
      return;
    }

    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trigger Battle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attacker city: $cityId', style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Defender city UUID',
                hintText: 'Enter target city ID',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Attack'),
          ),
        ],
      ),
    );

    final defenderCityId = controller.text.trim();
    controller.dispose();
    if (confirmed != true || defenderCityId.isEmpty) return;
    try {
      final battleId = await _devRpc.triggerBattle(cityId, defenderCityId);
      _showSnack('Battle started: $battleId');
    } catch (_) {
      _showSnack('Failed to trigger battle');
    }
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isExpanded) ...[
          _ActionButton(
            icon: Icons.inventory_2,
            label: 'Inject Resources',
            onPressed: _injectResources,
          ),
          const SizedBox(height: 8),
          _ActionButton(
            icon: Icons.upgrade,
            label: 'Level Up Building',
            onPressed: _levelUpBuilding,
          ),
          const SizedBox(height: 8),
          _ActionButton(
            icon: Icons.groups,
            label: 'Spawn Units',
            onPressed: _spawnUnits,
          ),
          const SizedBox(height: 8),
          _ActionButton(
            icon: Icons.gps_fixed,
            label: 'Trigger Battle',
            onPressed: _triggerBattle,
          ),
          const SizedBox(height: 8),
          _ActionButton(
            icon: Icons.dynamic_feed,
            label: 'Bulk Spawn',
            onPressed: _bulkSpawnUnits,
          ),
          const SizedBox(height: 8),
          _ActionButton(
            icon: Icons.fast_forward,
            label: 'Instant Complete',
            onPressed: _instantComplete,
          ),
          const SizedBox(height: 8),
        ],
        FloatingActionButton(
          heroTag: 'dev_toolbar_fab',
          mini: true,
          backgroundColor: Colors.deepPurple,
          onPressed: () => setState(() => _isExpanded = !_isExpanded),
          tooltip: 'Dev Toolbar',
          child: const Icon(Icons.developer_mode, color: Colors.white),
        ),
      ],
    ),
    );
  }
}

/// Small labeled action button used in the expanded toolbar panel.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onPressed,
    );
  }
}
