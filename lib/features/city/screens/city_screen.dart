import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/data/auth_repository.dart';
import '../../../features/city/providers/city_provider.dart';
import '../../../features/map/screens/city_grid_screen.dart';
import '../../../features/profile/providers/profile_provider.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/resource_badge.dart';
import '../../../core/constants/building_constants.dart';
import '../../../core/constants/resource_constants.dart';
import '../models/city_building.dart';
import '../models/city_resource.dart';
import '../models/construction_queue_entry.dart';
import '../providers/buildings_provider.dart';
import '../providers/city_economy_provider.dart';
import '../providers/construction_provider.dart';
import '../providers/production_rate_provider.dart';
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
              data: (p) => (p?['avatar_id'] as num?)?.toInt(),
            ) ??
            1);

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
        actionsIconTheme: const IconThemeData(
          color: Colors.white,
          shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
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
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
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
    final gridX = (island?['grid_x'] as num?)?.toInt() ?? 0;
    final gridY = (island?['grid_y'] as num?)?.toInt() ?? 0;
    final luxuryType = island?['luxury_type'] as String? ?? 'unknown';

    // Watch all economy streams.
    final resourcesAsync = ref.watch(resourcesStreamProvider(cityId));
    final buildingsAsync = ref.watch(buildingsStreamProvider(cityId));
    final constructionAsync = ref.watch(constructionQueueProvider(cityId));
    final economyAsync = ref.watch(cityEconomyStreamProvider(cityId));

    // Extract active construction entry (may be null if queue is empty).
    final activeConstruction = constructionAsync.whenOrNull(data: (e) => e);

    // Current resources for the upgrade sheet cost check.
    final currentResources =
        resourcesAsync.whenOrNull(data: (r) => r) ?? <CityResource>[];

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
        left: 16,
        right: 16,
        bottom: 16,
      ),
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
                      color: Colors.white,
                      shadows: const [
                        Shadow(blurRadius: 4, color: Colors.black54),
                      ],
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

              // Resource panel with economy indicators and hourly rate labels.
              _ResourcePanel(
                cityId: cityId,
                resourcesAsync: resourcesAsync,
                economyAsync: economyAsync,
                buildingsAsync: buildingsAsync,
              ),
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

/// Compact card showing all 6 resource types with live amounts, plus
/// happiness indicator and population summary rows.
///
/// Production resources (wood, marble, crystal, sulfur) also show a +X/hr
/// label below the amount and are tappable to show a breakdown sheet.
class _ResourcePanel extends ConsumerWidget {
  const _ResourcePanel({
    required this.cityId,
    required this.resourcesAsync,
    required this.economyAsync,
    required this.buildingsAsync,
  });

  final String cityId;
  final AsyncValue<List<CityResource>> resourcesAsync;
  final AsyncValue<Map<String, dynamic>?> economyAsync;
  final AsyncValue<List<dynamic>> buildingsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hourly production rates map keyed by resource name.
    final rates = ref.watch(productionRateProvider(cityId));

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
            // Row 1: Resource chips for all 6 types.
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

                  // Only production resources get hourly rate + tap.
                  final isProduction = type == ResourceType.wood ||
                      type == ResourceType.marble ||
                      type == ResourceType.crystal ||
                      type == ResourceType.sulfur;

                  final hourlyRate =
                      isProduction ? rates[type.value] : null;

                  return _ResourceChip(
                    type: type,
                    amount: amount,
                    hourlyRate: hourlyRate,
                    onTap: null,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 4),
            // Row 2: Happiness + Population summary driven by economy stream.
            economyAsync.when(
              loading: () => const SizedBox(height: 20),
              error: (e, _) => const SizedBox.shrink(),
              data: (economy) {
                if (economy == null) return const SizedBox.shrink();
                final happiness =
                    (economy['happiness'] as num?)?.toDouble() ?? 0.0;
                final population =
                    (economy['population'] as num?)?.toDouble() ?? 0.0;

                // Sum assigned workers across all buildings.
                final totalWorkers = buildingsAsync.whenOrNull(
                      data: (buildings) => buildings.fold<int>(
                        0,
                        (sum, b) => sum + (b as CityBuilding).assignedWorkers,
                      ),
                    ) ??
                    0;

                final hideoutLevel = buildingsAsync.whenOrNull(
                  data: (buildings) => buildings
                      .whereType<CityBuilding>()
                      .where((b) => b.buildingType == BuildingType.hideout)
                      .firstOrNull
                      ?.level,
                );
                final protectionFloor =
                    hideoutProtectionFloor(hideoutLevel);

                return Column(
                  children: [
                    Row(
                      children: [
                        _HappinessChip(happiness: happiness),
                        const Spacer(),
                        _PopulationSummary(
                          population: population,
                          happiness: happiness,
                          totalWorkers: totalWorkers,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.security,
                          size: 14,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(140),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Protected: $protectionFloor per resource'
                          '${hideoutLevel == null ? ' (no Hideout)' : ' (Lv$hideoutLevel)'}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withAlpha(140),
                                    fontSize: 11,
                                  ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact chip showing one resource type and its current amount.
///
/// Production resources optionally show a "+X/hr" label and can be tapped
/// to open a production breakdown sheet.
class _ResourceChip extends StatelessWidget {
  const _ResourceChip({
    required this.type,
    required this.amount,
    this.hourlyRate,
    this.onTap,
  });

  final ResourceType type;
  final double amount;

  /// When non-null and positive, shows a "+X/hr" label below the amount.
  final double? hourlyRate;

  /// When non-null, wraps the chip in a GestureDetector.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ResourceBadge(type: type, radius: 10),
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
            if (hourlyRate != null && hourlyRate! > 0)
              Text(
                '+${hourlyRate!.toStringAsFixed(0)}/hr',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.green.shade600,
                ),
              ),
          ],
        ),
      ],
    );

    if (onTap == null) return chip;
    return GestureDetector(onTap: onTap, child: chip);
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
      case ResourceType.wine:
        return 'Wine';
    }
  }
}

// ---------------------------------------------------------------------------
// Happiness and population widgets
// ---------------------------------------------------------------------------

/// Compact chip showing happiness score with emoji and colored text.
///
/// Positive happiness: green text with happy emoji.
/// Negative happiness: red text with sad emoji.
/// Zero: grey text with neutral emoji.
class _HappinessChip extends StatelessWidget {
  const _HappinessChip({required this.happiness});

  final double happiness;

  @override
  Widget build(BuildContext context) {
    final String emoji;
    final Color color;
    final String label;

    if (happiness > 0) {
      emoji = '😄';
      color = Colors.green.shade700;
      label = '+${happiness.toInt()}';
    } else if (happiness < 0) {
      emoji = '😟';
      color = Colors.red.shade700;
      label = happiness.toInt().toString();
    } else {
      emoji = '😐';
      color = Colors.grey.shade600;
      label = '0';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Compact summary showing population count, growth per tick, and tax per hour.
///
/// Growth formula: population * 0.01 * (happiness / 100) when happiness > 0.
/// Tax formula: idle_citizens * 3 gold/hour where idle = population - totalWorkers.
class _PopulationSummary extends StatelessWidget {
  const _PopulationSummary({
    required this.population,
    required this.happiness,
    required this.totalWorkers,
  });

  final double population;
  final double happiness;
  final int totalWorkers;

  @override
  Widget build(BuildContext context) {
    final int pop = population.floor();
    final double growthPerTick = happiness > 0
        ? population * 0.01 * (happiness / 100)
        : 0.0;
    final int idle = (pop - totalWorkers).clamp(0, pop);
    final int taxPerHour = idle * 3;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '\u{1F465} $pop (+${growthPerTick.toStringAsFixed(1)}/tick)',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(width: 8),
        Text(
          '\u{1FA99} Tax: +$taxPerHour/hr',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
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
