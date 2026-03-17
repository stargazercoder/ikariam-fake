import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/godmode_events_provider.dart';
import 'event_tile.dart';

/// Chronological event feed with filter chips.
///
/// Watches [godmodeEventsProvider] for the event list and
/// [godmodeEventFilterProvider] for the active type filter.
/// Filter options: All, Battle, Trade, Espionage.
///
/// When the filter changes via [GodmodeEventFilterNotifier.setFilter],
/// [godmodeEventsProvider] automatically rebuilds because it
/// ref.watches [godmodeEventFilterProvider] in its own build().
class EventFeed extends ConsumerWidget {
  const EventFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(godmodeEventsProvider);
    final currentFilter = ref.watch(godmodeEventFilterProvider);

    return Column(
      children: [
        // Filter chips row
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('All'),
                selected: currentFilter == null,
                onSelected: (_) =>
                    ref.read(godmodeEventFilterProvider.notifier).setFilter(null),
              ),
              FilterChip(
                label: const Text('Battle'),
                selected: currentFilter == 'battle',
                onSelected: (_) => ref
                    .read(godmodeEventFilterProvider.notifier)
                    .setFilter('battle'),
              ),
              FilterChip(
                label: const Text('Trade'),
                selected: currentFilter == 'trade',
                onSelected: (_) => ref
                    .read(godmodeEventFilterProvider.notifier)
                    .setFilter('trade'),
              ),
              FilterChip(
                label: const Text('Espionage'),
                selected: currentFilter == 'espionage',
                onSelected: (_) => ref
                    .read(godmodeEventFilterProvider.notifier)
                    .setFilter('espionage'),
              ),
            ],
          ),
        ),

        // Events list
        Expanded(
          child: eventsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Failed to load events: $e')),
            data: (events) {
              if (events.isEmpty) {
                return const Center(child: Text('No events'));
              }
              return ListView.builder(
                itemCount: events.length,
                itemBuilder: (_, i) => EventTile(event: events[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}
