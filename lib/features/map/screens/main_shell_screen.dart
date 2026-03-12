import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dev/dev_toolbar.dart';

/// Shell scaffold that wraps all four main game views with a bottom navigation bar.
///
/// This widget is the builder for [StatefulShellRoute.indexedStack] and provides
/// the persistent navigation between:
///   - Index 0: World Map (pan/zoom grid of islands)
///   - Index 1: Island (city slots on a selected island)
///   - Index 2: City (existing city management screen)
///   - Index 3: Battles (active and completed battles list)
class MainShellScreen extends StatelessWidget {
  const MainShellScreen({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: kDebugMode
          ? DevToolbarWrapper(child: navigationShell)
          : navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'World',
          ),
          NavigationDestination(
            icon: Icon(Icons.terrain_outlined),
            selectedIcon: Icon(Icons.terrain),
            label: 'Island',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_city_outlined),
            selectedIcon: Icon(Icons.location_city),
            label: 'City',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield),
            label: 'Battles',
          ),
        ],
      ),
    );
  }
}
