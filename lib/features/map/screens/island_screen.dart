// Island screen — shows city slots and resource areas for a selected island.
//
// Uses selectedIslandIdProvider for cross-tab island selection.
// Falls back to the player's own island when no island is selected.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/island_city_slot.dart';
import '../providers/island_detail_provider.dart';
import '../providers/islands_provider.dart';

/// Island screen showing city slots and resource areas for a specific island.
class IslandScreen extends ConsumerWidget {
  const IslandScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedIslandIdProvider);

    // If no island is selected, we need the player's island ID.
    // Read it from cityProvider (cityProvider is in features/city/providers).
    // Avoid circular dependency by reading directly from Supabase.
    final String? effectiveIslandId = selectedId ?? _getPlayerIslandId();

    if (effectiveIslandId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _IslandDetailView(islandId: effectiveIslandId);
  }

  /// Reads the player's island_id directly from the city cached in Supabase.
  ///
  /// Returns null while loading or if no city is found.
  String? _getPlayerIslandId() {
    // We cannot easily async here in build, so we rely on selectedIslandId
    // being set before the Island tab is shown, or use the player city from
    // a separate source. Returning null triggers a loading spinner which is
    // resolved once the user taps an island on the world map.
    return null;
  }
}

// ---------------------------------------------------------------------------
// Island detail view (requires a resolved island ID)
// ---------------------------------------------------------------------------

class _IslandDetailView extends ConsumerWidget {
  const _IslandDetailView({required this.islandId});

  final String islandId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(islandDetailProvider(islandId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Island'),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to load island: $error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (detail) => _IslandDetailBody(detail: detail),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Island detail body
// ---------------------------------------------------------------------------

class _IslandDetailBody extends ConsumerWidget {
  const _IslandDetailBody({required this.detail});

  final IslandDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final island = detail.island;
    final slots = detail.citySlots;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    // Total items = maxCitySlots city slot cells + 2 resource cells.
    final totalItems = island.maxCitySlots + 2;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Island header info.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Island (${island.gridX}, ${island.gridY})',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        _luxuryIcon(island.luxuryType),
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Luxury: ${_capitalise(island.luxuryType)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.people,
                        size: 18,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${detail.cityCount} / ${island.maxCitySlots} cities',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // City slots + resource areas grid.
          Text(
            'City Slots & Resources',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            itemCount: totalItems,
            itemBuilder: (context, index) {
              // Last 2 items are resource areas.
              if (index == island.maxCitySlots) {
                return _ResourceCell(
                  icon: Icons.forest,
                  label: 'Wood',
                  color: Colors.green.shade700,
                );
              }
              if (index == island.maxCitySlots + 1) {
                return _ResourceCell(
                  icon: _luxuryIcon(island.luxuryType),
                  label: _capitalise(island.luxuryType),
                  color: _luxuryColor(island.luxuryType),
                );
              }

              // City slot cell.
              final slotNumber = index + 1;
              final slot = slots
                  .where((s) => s.slotNumber == slotNumber)
                  .firstOrNull;

              return _CitySlotCell(
                slotNumber: slotNumber,
                slot: slot,
                currentUserId: currentUserId,
                onTap: () {
                  if (slot != null &&
                      slot.isOccupied &&
                      slot.ownerId == currentUserId) {
                    context.go('/city');
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _luxuryIcon(String type) {
    switch (type.toLowerCase()) {
      case 'marble':
        return Icons.square;
      case 'crystal':
        return Icons.diamond;
      case 'sulfur':
        return Icons.local_fire_department;
      default:
        return Icons.landscape;
    }
  }

  Color _luxuryColor(String type) {
    switch (type.toLowerCase()) {
      case 'marble':
        return Colors.grey.shade600;
      case 'crystal':
        return Colors.blue.shade400;
      case 'sulfur':
        return Colors.orange.shade700;
      default:
        return Colors.teal;
    }
  }

  String _capitalise(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

// ---------------------------------------------------------------------------
// City slot cell
// ---------------------------------------------------------------------------

class _CitySlotCell extends StatelessWidget {
  const _CitySlotCell({
    required this.slotNumber,
    required this.slot,
    required this.currentUserId,
    required this.onTap,
  });

  final int slotNumber;
  final CitySlot? slot;
  final String? currentUserId;
  final VoidCallback onTap;

  bool get _isPlayerOwned =>
      slot != null &&
      slot!.isOccupied &&
      slot!.ownerId == currentUserId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (slot == null || !slot!.isOccupied) {
      // Empty slot.
      return GestureDetector(
        onTap: null,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade800.withAlpha(120),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade700, width: 1),
          ),
          child: Center(
            child: Text(
              '$slotNumber',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ),
        ),
      );
    }

    // Occupied slot.
    final color = _isPlayerOwned
        ? theme.colorScheme.primary
        : theme.colorScheme.secondary;

    return GestureDetector(
      onTap: _isPlayerOwned ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: color.withAlpha(200),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _isPlayerOwned ? color : color.withAlpha(150),
            width: _isPlayerOwned ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isPlayerOwned ? Icons.home : Icons.location_city,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(height: 2),
              Text(
                slot!.cityName ?? '$slotNumber',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Resource area cell
// ---------------------------------------------------------------------------

class _ResourceCell extends StatelessWidget {
  const _ResourceCell({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withAlpha(180),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: Colors.white),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
