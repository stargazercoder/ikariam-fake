import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/data/auth_repository.dart';
import '../../../features/city/providers/city_provider.dart';
import '../../../features/map/screens/city_grid_screen.dart';
import '../../../features/profile/providers/profile_provider.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../core/constants/building_constants.dart';
import '../../../core/constants/resource_constants.dart';
import '../models/city_resource.dart';
import '../models/construction_queue_entry.dart';
import '../providers/buildings_provider.dart';
import '../providers/construction_provider.dart';
import '../providers/resources_provider.dart';
import '../widgets/countdown_timer_widget.dart';

/// City screen showing real-time resources, building list, and construction
/// progress.
///
/// Replaces the Phase 2 placeholder with full economy content:
/// - AppBar: city name title, player avatar + display name, sign-out button
/// - Island info card (unchanged from Phase 1)
/// - Resource panel: 5 resource types with live amounts (Supabase Realtime)
/// - Construction queue banner (if a building is upgrading)
/// - Building list: 14 buildings grouped into City Buildings + Production
///   Buildings, tappable to open upgrade bottom sheet
class CityScreen extends ConsumerWidget {
  const CityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cityAsync = ref.watch(cityProvider);
    final profileAsync = ref.watch(profileProvider);

    // Derive display name and avatar id from the profile.
    final displayName = profileAsync.whenOrNull(
          data: (p) => p?['display_name'] as String?,
        ) ??
        '';
    final avatarId = (profileAsync.whenOrNull(
              data: (p) => p?['avatar_id'] as int?,
            ) ??
            1);

    return Scaffold(
      appBar: AppBar(
        title: cityAsync.when(
          data: (city) => Text(city?['name'] as String? ?? 'My City'),
          loading: () => const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          error: (err, stack) => const Text('My City'),
        ),
        actions: [
          // Player avatar + display name.
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AvatarWidget(avatarId: avatarId, size: 32),
                const SizedBox(width: 6),
                if (displayName.isNotEmpty)
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          // Sign-out button.
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: cityAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Failed to load city: $error',
            style: const TextStyle(color: Colors.red),
          ),
        ),
        data: (city) => _CityBody(city: city, displayName: displayName),
      ),
    );
  }
}

/// Full economy body — shown once the city data has loaded.
class _CityBody extends ConsumerWidget {
  const _CityBody({
    required this.city,
    required this.displayName,
  });

  final Map<String, dynamic>? city;
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (city == null) {
      return const Center(
        child: Text('No city found. Please contact support.'),
      );
    }

    final cityId = city!['id'] as String;
    final cityName = city!['name'] as String? ?? 'Unknown City';
    final island = city!['islands'] as Map<String, dynamic>?;
    final gridX = island?['grid_x'] as int? ?? 0;
    final gridY = island?['grid_y'] as int? ?? 0;
    final luxuryType = island?['luxury_type'] as String? ?? 'unknown';

    // Watch all three economy streams.
    final resourcesAsync = ref.watch(resourcesStreamProvider(cityId));
    final buildingsAsync = ref.watch(buildingsStreamProvider(cityId));
    final constructionAsync = ref.watch(constructionQueueProvider(cityId));

    // Extract active construction entry (may be null if queue is empty).
    final activeConstruction = constructionAsync.whenOrNull(data: (e) => e);

    // Current resources for the upgrade sheet cost check.
    final currentResources =
        resourcesAsync.whenOrNull(data: (r) => r) ?? <CityResource>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // City name header.
              Text(
                cityName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              if (displayName.isNotEmpty)
                Text(
                  'Governor: $displayName',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 16),

              // Island info card.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Island Information',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.location_on,
                        label: 'Location',
                        value: 'Island at ($gridX, $gridY)',
                      ),
                      const SizedBox(height: 4),
                      _InfoRow(
                        icon: _luxuryIcon(luxuryType),
                        label: 'Luxury Resource',
                        value: _capitalise(luxuryType),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Resource panel.
              _ResourcePanel(resourcesAsync: resourcesAsync),
              const SizedBox(height: 16),

              // Construction queue banner (if active).
              if (activeConstruction != null)
                _ConstructionBanner(entry: activeConstruction),

              if (activeConstruction != null) const SizedBox(height: 16),

              // Building grid (spatial layout replacing flat list).
              buildingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(
                  'Failed to load buildings: $e',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                data: (buildings) => BuildingsGrid(
                  buildings: buildings,
                  cityId: cityId,
                  currentResources: currentResources,
                  activeConstruction: activeConstruction,
                ),
              ),
            ],
          ),
        ),
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
        return Icons.help_outline;
    }
  }

  String _capitalise(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

// ---------------------------------------------------------------------------
// Resource panel
// ---------------------------------------------------------------------------

/// Compact card showing all 5 resource types with live amounts.
class _ResourcePanel extends StatelessWidget {
  const _ResourcePanel({required this.resourcesAsync});

  final AsyncValue<List<CityResource>> resourcesAsync;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resources',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 10),
            resourcesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (e, _) => Text(
                'Failed to load resources: $e',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
              data: (resources) => Wrap(
                spacing: 12,
                runSpacing: 8,
                children: ResourceType.values.map((type) {
                  final match = resources
                      .where((r) => r.resourceType == type)
                      .firstOrNull;
                  final amount = match?.amount ?? 0.0;
                  return _ResourceChip(
                    type: type,
                    amount: amount,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact chip showing one resource type and its current amount.
class _ResourceChip extends StatelessWidget {
  const _ResourceChip({required this.type, required this.amount});

  final ResourceType type;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _icon(type),
          size: 16,
          color: _color(context, type),
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _label(type),
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            Text(
              amount.toInt().toString(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  IconData _icon(ResourceType type) {
    switch (type) {
      case ResourceType.wood:
        return Icons.forest;
      case ResourceType.marble:
        return Icons.square;
      case ResourceType.crystal:
        return Icons.diamond;
      case ResourceType.sulfur:
        return Icons.local_fire_department;
      case ResourceType.gold:
        return Icons.monetization_on;
    }
  }

  Color _color(BuildContext context, ResourceType type) {
    switch (type) {
      case ResourceType.wood:
        return Colors.green.shade700;
      case ResourceType.marble:
        return Colors.grey.shade600;
      case ResourceType.crystal:
        return Colors.blue.shade400;
      case ResourceType.sulfur:
        return Colors.orange.shade700;
      case ResourceType.gold:
        return Colors.amber.shade700;
    }
  }

  String _label(ResourceType type) {
    switch (type) {
      case ResourceType.wood:
        return 'Wood';
      case ResourceType.marble:
        return 'Marble';
      case ResourceType.crystal:
        return 'Crystal';
      case ResourceType.sulfur:
        return 'Sulfur';
      case ResourceType.gold:
        return 'Gold';
    }
  }
}

// ---------------------------------------------------------------------------
// Construction queue banner
// ---------------------------------------------------------------------------

/// Banner shown at the top of the buildings section when an upgrade is active.
class _ConstructionBanner extends StatelessWidget {
  const _ConstructionBanner({required this.entry});

  final ConstructionQueueEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Try to get a display name from BuildingType enum; fall back to raw string.
    final buildingName = _buildingDisplayName(entry.buildingType);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.construction,
              color: theme.colorScheme.onPrimaryContainer,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upgrading $buildingName to Level ${entry.targetLevel}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Finishing in: ',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontSize: 13,
                        ),
                      ),
                      CountdownTimerWidget(
                        finishAt: entry.finishAt,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [
                            const FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
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

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// A labelled icon + value row used in the island info card.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}
