// Island screen — shows city slots and resource areas for a selected island.
//
// Uses selectedIslandIdProvider for cross-tab island selection.
// Falls back to the player's own island when no island is selected.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../city/providers/city_provider.dart';
import '../../espionage/providers/espionage_providers.dart';
import '../../espionage/screens/spy_report_dialog.dart';
import '../../trade/screens/trade_dialog.dart';
import '../../../core/constants/island_constants.dart';
import '../../../core/constants/ownership_colors.dart';
import '../models/island.dart';
import '../models/island_city_slot.dart';
import '../providers/island_detail_provider.dart';
import '../providers/islands_provider.dart';

/// Island screen showing city slots and resource areas for a specific island.
class IslandScreen extends ConsumerWidget {
  const IslandScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedIslandIdProvider);
    final playerIslandId = ref.watch(playerIslandIdProvider);

    final String? effectiveIslandId = selectedId ?? playerIslandId;

    if (effectiveIslandId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _IslandDetailView(islandId: effectiveIslandId);
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

  String? _playerCityId(WidgetRef ref) {
    final city = ref.read(cityProvider).whenOrNull(data: (c) => c);
    return city?['id'] as String?;
  }

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
                  const SizedBox(height: 8),
                  // Island resource level indicator.
                  Row(
                    children: [
                      Icon(
                        Icons.upgrade,
                        size: 18,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Resource Level: ${island.resourceLevel} / $maxIslandResourceLevel',
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
                // Wood cell — tappable to donate and upgrade island resource.
                final playerCityId = _playerCityId(ref);
                return _ResourceCell(
                  icon: Icons.forest,
                  label: 'Wood',
                  color: Colors.green.shade700,
                  onTap: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => _DonateWoodDialog(
                        islandId: island.id,
                        currentLevel: island.resourceLevel,
                        cityId: playerCityId ?? '',
                        onDonated: () {
                            ref.invalidate(islandDetailProvider(island.id));
                            ref.invalidate(cityProvider);
                          },
                      ),
                    );
                  },
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
                  if (slot == null || !slot.isOccupied) return;
                  _showCityActionDialog(
                      context, ref, slot, currentUserId, island);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  /// Shows a unified city action dialog for any occupied slot.
  ///
  /// Own city: "Go to City" (primary) + "Trade" (secondary).
  /// Enemy city: "Trade" (primary) + "Attack" (secondary/error style).
  void _showCityActionDialog(
    BuildContext context,
    WidgetRef ref,
    CitySlot slot,
    String? currentUserId,
    Island island,
  ) {
    final isOwn = slot.ownerId == currentUserId;
    final playerCityId = _playerCityId(ref) ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.location_city, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                slot.cityName ?? 'City',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: isOwn
            ? null
            : Text(
                'Owner: ${_shortId(slot.ownerId ?? '')}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
        actions: [
          if (isOwn) ...[
            // Own city: Trade (secondary) + Go to City (primary).
            OutlinedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                showTradeDialog(
                  context,
                  originCityId: playerCityId,
                  destinationCityId: slot.cityId!,
                  destinationCityName: slot.cityName ?? 'City',
                  originIslandX: island.gridX,
                  originIslandY: island.gridY,
                  destIslandX: island.gridX,
                  destIslandY: island.gridY,
                );
              },
              child: const Text('Trade'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go('/city');
              },
              child: const Text('Go to City'),
            ),
          ],
          if (!isOwn) ...[
            // Enemy city: Attack (error style) + Trade (primary) + Spy + View City.
            OutlinedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.push(
                  '/dispatch?cityId=$playerCityId&targetCityId=${slot.cityId}',
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(
                    color: Theme.of(context).colorScheme.error),
              ),
              child: const Text('Attack'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                showTradeDialog(
                  context,
                  originCityId: playerCityId,
                  destinationCityId: slot.cityId!,
                  destinationCityName: slot.cityName ?? 'City',
                  originIslandX: island.gridX,
                  originIslandY: island.gridY,
                  destIslandX: island.gridX,
                  destIslandY: island.gridY,
                );
              },
              child: const Text('Trade'),
            ),
            // Spy button — always enabled for enemy cities.
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                showSpyReportDialog(
                  context,
                  targetCityId: slot.cityId!,
                  targetCityName: slot.cityName ?? 'City',
                );
              },
              child: const Text('Spy (100 gold)'),
            ),
            // View City button — enabled only if player has spied on this city.
            Consumer(builder: (_, ref, _) {
              final hasSpied =
                  ref.watch(hasSpiedProvider(slot.cityId!)).whenOrNull(
                        data: (v) => v,
                      ) ??
                      false;
              return OutlinedButton(
                onPressed: hasSpied
                    ? () {
                        Navigator.of(ctx).pop();
                        context.push(
                          '/city-view'
                          '?cityId=${Uri.encodeComponent(slot.cityId!)}'
                          '&cityName=${Uri.encodeComponent(slot.cityName ?? 'City')}'
                          '&ownerName=${Uri.encodeComponent(_shortId(slot.ownerId ?? ''))}',
                        );
                      }
                    : null,
                child:
                    Text(hasSpied ? 'View City' : 'View City (spy first)'),
              );
            }),
          ],
        ],
      ),
    );
  }

  String _shortId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}...';
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
    if (slot == null || !slot!.isOccupied) {
      // Empty slot.
      return GestureDetector(
        onTap: null,
        child: Container(
          decoration: BoxDecoration(
            color: OwnershipColors.empty.withAlpha(40),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: OwnershipColors.empty, width: 2),
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

    // Occupied slot — color from OwnershipColors.
    final Color color;
    if (_isPlayerOwned) {
      color = OwnershipColors.own;
    } else {
      color = OwnershipColors.enemy;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withAlpha(200),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 2),
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
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;

  /// Optional tap callback. When set, wraps the cell in a GestureDetector.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cell = Container(
      decoration: BoxDecoration(
        color: color.withAlpha(180),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: onTap != null ? Colors.white : color,
          width: onTap != null ? 2 : 2,
        ),
      ),
      child: Stack(
        children: [
          Center(
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
          ),
          // Tap indicator for tappable cells.
          if (onTap != null)
            Positioned(
              right: 2,
              top: 2,
              child: Icon(
                Icons.touch_app,
                size: 10,
                color: Colors.white.withAlpha(200),
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return cell;
    return GestureDetector(onTap: onTap, child: cell);
  }
}

// ---------------------------------------------------------------------------
// Donate wood dialog
// ---------------------------------------------------------------------------

/// Dialog for donating wood to upgrade the island's shared resource building.
class _DonateWoodDialog extends StatefulWidget {
  const _DonateWoodDialog({
    required this.islandId,
    required this.currentLevel,
    required this.cityId,
    required this.onDonated,
  });

  final String islandId;
  final int currentLevel;
  final String cityId;

  /// Called after a successful donation so the parent can refresh island data.
  final VoidCallback onDonated;

  @override
  State<_DonateWoodDialog> createState() => _DonateWoodDialogState();
}

class _DonateWoodDialogState extends State<_DonateWoodDialog> {
  bool _donating = false;

  @override
  Widget build(BuildContext context) {
    // Maximum level reached — show info message only.
    if (widget.currentLevel >= maxIslandResourceLevel) {
      return AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.upgrade, size: 22),
            SizedBox(width: 8),
            Text('Island Resource Building'),
          ],
        ),
        content: const Text(
          'Island resource building is at maximum level!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    }

    final woodCost = islandDonationCost(widget.currentLevel);
    final currentMult = islandMultiplier(widget.currentLevel);
    final nextMult = islandMultiplier(widget.currentLevel + 1);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.upgrade, size: 22),
          SizedBox(width: 8),
          Text('Upgrade Island Resource'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Donate wood to upgrade the island\'s shared resource building '
            'from level ${widget.currentLevel} to ${widget.currentLevel + 1}.',
          ),
          const SizedBox(height: 12),
          // Cost row.
          Row(
            children: [
              const Icon(Icons.forest, size: 18, color: Colors.green),
              const SizedBox(width: 6),
              Text(
                '$woodCost Wood',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Benefit row.
          Text(
            'Production bonus: ${currentMult.toStringAsFixed(1)}x'
            ' \u2192 ${nextMult.toStringAsFixed(1)}x'
            ' for all cities on this island',
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _donating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _donating ? null : _donate,
          child: _donating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Donate'),
        ),
      ],
    );
  }

  Future<void> _donate() async {
    setState(() => _donating = true);
    try {
      await Supabase.instance.client.functions.invoke(
        'donate-island-wood',
        body: {'city_id': widget.cityId},
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onDonated();
    } catch (e) {
      if (!mounted) return;
      setState(() => _donating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Donation failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}
