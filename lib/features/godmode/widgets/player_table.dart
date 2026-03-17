import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/godmode_repository.dart';
import '../models/godmode_player.dart';
import '../providers/godmode_world_provider.dart';
import 'player_row.dart';

/// Sortable, scrollable player table with bulk pause/resume controls.
///
/// Accepts a [players] list from the parent widget (typically obtained via
/// [godmodeWorldProvider]). Sorting is delegated to [GodmodeWorldNotifier.sortBy]
/// so the sort order is preserved across refreshes.
class PlayerTable extends ConsumerStatefulWidget {
  const PlayerTable({super.key, required this.players});

  final List<GodmodePlayer> players;

  @override
  ConsumerState<PlayerTable> createState() => _PlayerTableState();
}

class _PlayerTableState extends ConsumerState<PlayerTable> {
  String? _editingPlayerId;
  String _sortColumn = 'displayName';
  bool _sortAscending = true;

  void _sort(String column) {
    final ascending =
        _sortColumn == column ? !_sortAscending : true;
    setState(() {
      _sortColumn = column;
      _sortAscending = ascending;
    });
    ref.read(godmodeWorldProvider.notifier).sortBy(column, ascending);
  }

  Widget _headerCell(String label, String column) {
    final isActive = _sortColumn == column;
    return GestureDetector(
      onTap: () => _sort(column),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            if (isActive)
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pauseAllBots() async {
    final repo = ref.read(godmodeRepositoryProvider);
    final bots = widget.players
        .where((p) => p.isBot && !p.isPaused)
        .toList();
    if (bots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active bots to pause')),
      );
      return;
    }
    try {
      await Future.wait(bots.map((b) => repo.setBotPaused(b.id, true)));
      await ref.read(godmodeWorldProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paused ${bots.length} bots')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error pausing bots: $e')),
        );
      }
    }
  }

  Future<void> _resumeAllBots() async {
    final repo = ref.read(godmodeRepositoryProvider);
    final bots = widget.players
        .where((p) => p.isBot && p.isPaused)
        .toList();
    if (bots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No paused bots to resume')),
      );
      return;
    }
    try {
      await Future.wait(bots.map((b) => repo.setBotPaused(b.id, false)));
      await ref.read(godmodeWorldProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Resumed ${bots.length} bots')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resuming bots: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Bulk controls row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.pause, size: 16),
                label: const Text('Pause All Bots'),
                onPressed: _pauseAllBots,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text('Resume All Bots'),
                onPressed: _resumeAllBots,
              ),
            ],
          ),
        ),

        // Header row
        Container(
          color: Colors.grey.shade300,
          child: Row(
            children: [
              Expanded(flex: 3, child: _headerCell('Name', 'displayName')),
              Expanded(
                flex: 2,
                child: _headerCell('Resources', 'totalResources'),
              ),
              Expanded(child: _headerCell('Land', 'landCount')),
              Expanded(child: _headerCell('Naval', 'navalCount')),
              Expanded(child: _headerCell('Buildings', 'buildingCount')),
              Expanded(child: _headerCell('Battles', 'activeBattleCount')),
              const SizedBox(width: 120, child: Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'Actions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              )),
            ],
          ),
        ),

        // Player rows
        Expanded(
          child: ListView.builder(
            itemCount: widget.players.length,
            itemBuilder: (context, index) {
              final player = widget.players[index];
              return PlayerRow(
                player: player,
                isEditing: _editingPlayerId == player.id,
                onStartEdit: () =>
                    setState(() => _editingPlayerId = player.id),
                onEditDone: () =>
                    setState(() => _editingPlayerId = null),
              );
            },
          ),
        ),
      ],
    );
  }
}
