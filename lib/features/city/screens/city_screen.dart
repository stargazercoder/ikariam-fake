import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/data/auth_repository.dart';
import '../../../features/city/providers/city_provider.dart';
import '../../../features/profile/providers/profile_provider.dart';
import '../../../shared/widgets/avatar_widget.dart';

/// Placeholder city screen — the destination after completing profile setup.
///
/// Shows the player's auto-assigned city name and island location from the
/// database.  Actual building/resource content is added in Phase 2.
///
/// Displays:
/// - AppBar with city name as title, player avatar + display name as action
/// - City name prominently in the body
/// - Island grid coordinates and luxury resource type
/// - Phase 2 placeholder message
/// - Sign-out button in the AppBar
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

/// Body content for the city screen.
class _CityBody extends StatelessWidget {
  const _CityBody({
    required this.city,
    required this.displayName,
  });

  final Map<String, dynamic>? city;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    if (city == null) {
      return const Center(child: Text('No city found. Please contact support.'));
    }

    final cityName = city!['name'] as String? ?? 'Unknown City';
    final island = city!['islands'] as Map<String, dynamic>?;
    final gridX = island?['grid_x'] as int? ?? 0;
    final gridY = island?['grid_y'] as int? ?? 0;
    final luxuryType = island?['luxury_type'] as String? ?? 'unknown';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 8),
              if (displayName.isNotEmpty)
                Text(
                  'Governor: $displayName',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 24),
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
              const SizedBox(height: 24),
              // Phase 2 placeholder.
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.construction,
                        size: 48,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your city awaits...',
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Buildings coming in Phase 2',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                      ),
                    ],
                  ),
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
