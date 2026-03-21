// Read-only view of an enemy city — shows buildings and construction status.
//
// Navigated to via /city-view route after a spy report is received.
// Uses BuildingsGrid(readOnly: true) so tapping cells does nothing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/city/models/construction_queue_entry.dart';
import '../../../features/city/providers/buildings_provider.dart';
import '../../../features/city/providers/construction_provider.dart';
import '../../../features/city/widgets/countdown_timer_widget.dart';
import '../../../core/constants/building_constants.dart';
import 'city_grid_screen.dart';

/// Read-only view of an enemy city.
///
/// Displays a transparent AppBar, a read-only notice banner,
/// an optional construction banner, and the city's building grid with all taps disabled.
class EnemyCityViewScreen extends ConsumerWidget {
  const EnemyCityViewScreen({
    super.key,
    required this.cityId,
    required this.cityName,
    required this.ownerName,
  });

  final String cityId;
  final String cityName;
  final String ownerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildingsAsync = ref.watch(buildingsStreamProvider(cityId));
    final constructionAsync = ref.watch(constructionQueueProvider(cityId));
    final activeConstruction = constructionAsync.whenOrNull(data: (e) => e);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        iconTheme: const IconThemeData(
          color: Colors.white,
          shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
        ),
      ),
      body: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + kToolbarHeight,
        ),
        child: Column(
          children: [
            // Read-only notice banner (also shows city/owner context).
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red.shade50,
              child: Row(
                children: [
                  Icon(Icons.visibility_outlined,
                      size: 16, color: Colors.red.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Viewing enemy city \u2014 read only',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.red.shade800,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          // Construction banner (if active).
          if (activeConstruction != null)
            _EnemyConstructionBanner(entry: activeConstruction),
          // Building grid in read-only mode.
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      buildingsAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('Failed to load buildings: $e'),
                        data: (buildings) => BuildingsGrid(
                          buildings: buildings,
                          cityId: cityId,
                          currentResources: const [],
                          activeConstruction: activeConstruction,
                          readOnly: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Enemy construction banner
// ---------------------------------------------------------------------------

/// Banner shown when an enemy city has a building under construction.
class _EnemyConstructionBanner extends StatelessWidget {
  const _EnemyConstructionBanner({required this.entry});

  final ConstructionQueueEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buildingName = _buildingDisplayName(entry.buildingType);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.construction,
              color: theme.colorScheme.onErrorContainer,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Building $buildingName to Level ${entry.targetLevel}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            CountdownTimerWidget(
              finishAt: entry.finishAt,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildingDisplayName(String dbName) {
    try {
      return buildingTypeFromDbName(dbName).displayName;
    } catch (_) {
      return dbName;
    }
  }
}
