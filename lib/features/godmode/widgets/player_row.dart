import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/godmode_repository.dart';
import '../models/godmode_player.dart';
import '../providers/godmode_world_provider.dart';
import 'bot_badge.dart';

/// A single row in the GodMode player table.
///
/// Supports two modes:
/// - Normal mode ([isEditing] == false): shows player data with action buttons.
/// - Edit mode ([isEditing] == true): shows inline text fields for resources
///   and army units, with Save / Cancel buttons.
class PlayerRow extends ConsumerStatefulWidget {
  const PlayerRow({
    super.key,
    required this.player,
    required this.isEditing,
    required this.onStartEdit,
    required this.onEditDone,
  });

  final GodmodePlayer player;
  final bool isEditing;
  final VoidCallback onStartEdit;
  final VoidCallback onEditDone;

  @override
  ConsumerState<PlayerRow> createState() => _PlayerRowState();
}

class _PlayerRowState extends ConsumerState<PlayerRow> {
  // Resource text controllers — keyed by resource name.
  late final Map<String, TextEditingController> _resourceControllers;

  // Army text controllers — keyed by unit type.
  late final Map<String, TextEditingController> _armyControllers;

  static const _resourceKeys = [
    'wood',
    'marble',
    'crystal',
    'sulfur',
    'gold',
  ];

  static const _armyKeys = [
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

  @override
  void initState() {
    super.initState();
    _resourceControllers = {
      for (final key in _resourceKeys)
        key: TextEditingController(
          text: widget.player.resources[key]?.toString() ?? '0',
        ),
    };
    _armyControllers = {
      for (final key in _armyKeys)
        key: TextEditingController(text: '0'),
    };
  }

  @override
  void dispose() {
    for (final c in _resourceControllers.values) {
      c.dispose();
    }
    for (final c in _armyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _togglePause() async {
    final repo = ref.read(godmodeRepositoryProvider);
    final player = widget.player;
    final newPaused = !player.isPaused;
    try {
      await repo.setBotPaused(player.id, newPaused);
      await ref.read(godmodeWorldProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${player.displayName} ${newPaused ? "paused" : "resumed"}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _forceAction() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Force Action'),
        content: Text(
          'Force bot ${widget.player.displayName} to act now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final action =
          await ref.read(godmodeRepositoryProvider).forceAction(widget.player.id);
      await ref.read(godmodeWorldProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.player.displayName} chose: $action'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    final repo = ref.read(godmodeRepositoryProvider);
    final player = widget.player;
    try {
      final wood =
          double.tryParse(_resourceControllers['wood']!.text) ?? 0.0;
      final marble =
          double.tryParse(_resourceControllers['marble']!.text) ?? 0.0;
      final crystal =
          double.tryParse(_resourceControllers['crystal']!.text) ?? 0.0;
      final sulfur =
          double.tryParse(_resourceControllers['sulfur']!.text) ?? 0.0;
      final gold =
          double.tryParse(_resourceControllers['gold']!.text) ?? 0.0;

      await repo.setResources(
        player.id,
        wood: wood,
        marble: marble,
        crystal: crystal,
        sulfur: sulfur,
        gold: gold,
      );

      final units = {
        for (final key in _armyKeys)
          key: int.tryParse(_armyControllers[key]!.text) ?? 0,
      };
      await repo.setArmy(player.id, units);

      widget.onEditDone();
      await ref.read(godmodeWorldProvider.notifier).refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  Widget _buildNormalRow({bool grayed = false}) {
    final player = widget.player;
    final textStyle = TextStyle(
      color: grayed ? Colors.grey : null,
      fontSize: 13,
    );

    Widget nameCell = Text(player.displayName, style: textStyle);
    if (player.isBot) {
      nameCell = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          nameCell,
          const SizedBox(width: 4),
          const BotBadge(),
        ],
      );
    }

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          // Name
          Expanded(flex: 3, child: Padding(padding: const EdgeInsets.all(8), child: nameCell)),
          // Resources
          Expanded(flex: 2, child: Padding(padding: const EdgeInsets.all(8), child: Text('${player.totalResources}', style: textStyle))),
          // Land
          Expanded(child: Padding(padding: const EdgeInsets.all(8), child: Text('${player.landCount}', style: textStyle))),
          // Naval
          Expanded(child: Padding(padding: const EdgeInsets.all(8), child: Text('${player.navalCount}', style: textStyle))),
          // Buildings
          Expanded(child: Padding(padding: const EdgeInsets.all(8), child: Text('${player.buildingCount}', style: textStyle))),
          // Battles
          Expanded(child: Padding(padding: const EdgeInsets.all(8), child: Text('${player.activeBattleCount}', style: textStyle))),
          // Actions — width 160 to accommodate up to 3 bot buttons (pause,
          // force, edit) at default Material icon button minimum size 48px.
          SizedBox(
            width: 160,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (player.isBot) ...[
                  IconButton(
                    icon: Icon(
                      player.isPaused ? Icons.play_arrow : Icons.pause,
                      size: 18,
                    ),
                    tooltip: player.isPaused ? 'Resume bot' : 'Pause bot',
                    onPressed: _togglePause,
                  ),
                  IconButton(
                    icon: const Icon(Icons.flash_on, size: 18),
                    tooltip: 'Force action',
                    onPressed: _forceAction,
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  tooltip: 'Edit player',
                  onPressed: widget.onStartEdit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Normal row on top, grayed out
        _buildNormalRow(grayed: true),

        // Resource fields
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Resources',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final key in _resourceKeys)
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _resourceControllers[key],
                        decoration: InputDecoration(
                          labelText: key,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Army Units',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final key in _armyKeys)
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _armyControllers[key],
                        decoration: InputDecoration(
                          labelText: key,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: widget.onEditDone,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing) {
      return _buildEditMode();
    }
    return GestureDetector(
      onTap: widget.onStartEdit,
      child: _buildNormalRow(),
    );
  }
}
