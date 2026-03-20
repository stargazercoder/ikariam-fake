// Tavern stats widget — wine spending slider with happiness and consumption stats.
// Extracted from _TavernWineSlider in building_upgrade_sheet.dart.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/resource_constants.dart';
import '../../data/city_repository.dart';
import '../../providers/city_economy_provider.dart';
import '../../providers/resources_provider.dart';

/// Tavern building stats — wine spending slider with live happiness and
/// consumption feedback.
///
/// - Reads the initial wine_spending_rate from [cityEconomyStreamProvider].
/// - Updates local state immediately on slider move for snappy feedback.
/// - Debounces Edge Function calls at 300ms to avoid spamming the server.
/// - Displays happiness contribution, wine consumed per tick, and wine stock.
class TavernStats extends ConsumerStatefulWidget {
  const TavernStats({
    super.key,
    required this.cityId,
    required this.tavernLevel,
  });

  final String cityId;
  final int tavernLevel;

  @override
  ConsumerState<TavernStats> createState() => _TavernStatsState();
}

class _TavernStatsState extends ConsumerState<TavernStats> {
  /// Local slider value in [0.0, 1.0] — maps to 0–100%.
  double _rate = 0.0;

  /// Whether we've received the initial value from the stream yet.
  bool _initialized = false;

  /// Debounce timer for Edge Function calls.
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSliderChanged(double value) {
    setState(() => _rate = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      try {
        await ref.read(cityRepositoryProvider).setWineRate(
              cityId: widget.cityId,
              wineSpendingRate: (_rate * 100).round(),
            );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update wine rate: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Sync initial rate from economy stream (only on first emission).
    final economyAsync = ref.watch(cityEconomyStreamProvider(widget.cityId));
    economyAsync.whenData((economy) {
      if (!_initialized && economy != null) {
        final serverRate =
            ((economy['wine_spending_rate'] as num?)?.toInt() ?? 0) / 100.0;
        if (mounted) {
          setState(() {
            _rate = serverRate;
            _initialized = true;
          });
        }
      }
    });

    // Read wine stock from resources stream.
    final resourcesAsync = ref.watch(resourcesStreamProvider(widget.cityId));
    final wineAmount = resourcesAsync.whenOrNull(
          data: (resources) => resources
              .where((r) => r.resourceType == ResourceType.wine)
              .firstOrNull
              ?.amount,
        ) ??
        0.0;

    // Derived display values.
    final int ratePercent = (_rate * 100).round();
    final double happinessContribution = _rate * widget.tavernLevel;
    final double winePerTick = _rate * widget.tavernLevel * 5.0;
    final bool tavernActive = widget.tavernLevel > 0;
    final bool hasWine = wineAmount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.wine_bar, size: 20, color: Colors.purple),
            const SizedBox(width: 8),
            Text(
              'Wine Spending',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (!tavernActive) ...[
          // Tavern not yet built — disable slider with message.
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Upgrade the Tavern to start consuming wine.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Slider(
            value: 0,
            onChanged: null,
            min: 0,
            max: 1,
            divisions: 100,
            label: '0%',
          ),
        ] else ...[
          // Wine stock warning.
          if (!hasWine)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber,
                      size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 6),
                  Text(
                    'No wine available',
                    style: TextStyle(
                        color: Colors.orange.shade700, fontSize: 12),
                  ),
                ],
              ),
            ),

          // Slider row.
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _rate,
                  min: 0,
                  max: 1,
                  divisions: 100,
                  label: '$ratePercent%',
                  onChanged: _onSliderChanged,
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '$ratePercent%',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          // Stats row.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text(
                  '\u{1F604} +${happinessContribution.toStringAsFixed(1)} happiness',
                  style: TextStyle(
                    fontSize: 12,
                    color: happinessContribution > 0
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                Text(
                  '\u{1F377} ${winePerTick.toStringAsFixed(1)}/tick',
                  style: const TextStyle(fontSize: 12, color: Colors.purple),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Wine stock: ${wineAmount.toInt()}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ],
      ],
    );
  }
}
