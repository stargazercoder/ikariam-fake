// Movements screen — displays all player in-transit armies with live ETA countdowns.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/unit_constants.dart';
import '../../city/widgets/countdown_timer_widget.dart';
import '../../military/models/unit_movement.dart';
import '../providers/movements_provider.dart';

/// Global movements screen showing all in-transit armies and cargo ships
/// owned by the current player.
///
/// Uses [allMovementsStreamProvider] for real-time updates via Supabase
/// Realtime. Cards disappear automatically when movements arrive (Realtime
/// DELETE removes the row).
class MovementsScreen extends ConsumerWidget {
  const MovementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(allMovementsStreamProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movements'),
      ),
      body: movementsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Failed to load movements. Check your connection and try again.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        data: (movements) {
          if (movements.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.swap_horiz, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No armies in transit',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Dispatch units from your city to see movements here.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: movements.length,
            itemBuilder: (context, index) =>
                _MovementCard(movement: movements[index]),
          );
        },
      ),
    );
  }
}

/// Returns the appropriate icon for a movement type.
IconData _movementIcon(String type) => switch (type) {
      'return' => Icons.call_received,
      'trade' => Icons.local_shipping,
      _ => Icons.call_made,
    };

/// Returns the appropriate color for a movement type.
Color _movementColor(String type, ThemeData theme) => switch (type) {
      'return' => Colors.grey.shade600,
      'trade' => Colors.green,
      _ => theme.colorScheme.primary,
    };

/// Card widget displaying a single in-transit movement row.
///
/// Shows movement direction icon, destination city name (resolved from UUID),
/// unit composition, optional cargo, and a live ETA countdown timer.
class _MovementCard extends ConsumerWidget {
  const _MovementCard({required this.movement});

  final UnitMovement movement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Movement type icon + destination city name
            Row(
              children: [
                Icon(
                  _movementIcon(movement.movementType),
                  size: 18,
                  color: _movementColor(movement.movementType, theme),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final cityNameAsync = ref.watch(
                        cityNameProvider(movement.destinationCityId),
                      );
                      return Text(
                        cityNameAsync.when(
                          data: (name) => name ?? movement.destinationCityId,
                          loading: () => '...',
                          error: (e, s) => movement.destinationCityId,
                        ),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            // Row 2: Unit summary
            const SizedBox(height: 4),
            Text(
              movement.movementType == 'trade'
                  ? 'Cargo shipment'
                  : movement.units.entries
                        .map((e) =>
                            '${unitTypeFromDbName(e.key).displayName} x${e.value}')
                        .join(', '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            // Row 3: Cargo (only rendered when cargo exists and is non-empty)
            if (movement.cargo != null && movement.cargo!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: movement.cargo!.entries.map((e) {
                  return Text(
                    '${e.key}: ${e.value}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  );
                }).toList(),
              ),
            ],
            // Row 4: ETA countdown
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.timer, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Arriving in: ',
                  style: theme.textTheme.bodySmall,
                ),
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
}
