import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/godmode_events_provider.dart';
import '../providers/godmode_world_provider.dart';
import '../widgets/elapsed_timer_text.dart';
import '../widgets/event_feed.dart';
import '../widgets/player_table.dart';

/// Full GodMode admin dashboard screen.
///
/// Displays a [DefaultTabController] with two tabs:
///   1. **Players** — sortable, inline-editable player table with bot controls.
///   2. **Events** — filtered chronological event feed.
///
/// AppBar shows an [ElapsedTimerText] counter, a refresh spinner while polling
/// is in-flight, and a manual refresh button.
///
/// Protected by the router guard in [_redirect] (Rule 4b): non-admin users
/// are redirected to /map before this screen is ever built.
class GodModeDashboardScreen extends ConsumerWidget {
  const GodModeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worldState = ref.watch(godmodeWorldProvider);
    // Read notifier for isRefreshing / lastUpdated — these don't trigger
    // rebuilds themselves; they are accessed inside the build as snapshots.
    final notifier = ref.read(godmodeWorldProvider.notifier);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () => context.go('/map'),
          ),
          title: const Text('GodMode'),
          actions: [
            ElapsedTimerText(since: notifier.lastUpdated),
            const SizedBox(width: 8),
            // Refresh spinner — shown only while a background refresh is running.
            notifier.isRefreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const SizedBox.shrink(),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () {
                ref.read(godmodeWorldProvider.notifier).refresh();
                ref.read(godmodeEventsProvider.notifier).refresh();
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Players'),
              Tab(text: 'Events'),
            ],
          ),
        ),
        body: worldState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Failed to load world: $e')),
          data: (players) => TabBarView(
            children: [
              PlayerTable(players: players),
              const EventFeed(),
            ],
          ),
        ),
      ),
    );
  }
}
