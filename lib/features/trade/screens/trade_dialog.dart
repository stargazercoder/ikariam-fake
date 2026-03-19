// Trade dialog — lets the player select resource amounts and send a cargo shipment.
//
// Entry point: showTradeDialog()
// Internal widget: _TradeDialogContent (ConsumerStatefulWidget)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/building_constants.dart';
import '../../../core/constants/unit_constants.dart';
import '../../../shared/widgets/resource_badge.dart';
import '../../city/providers/resources_provider.dart';
import '../data/trade_repository.dart';
import '../providers/trade_providers.dart';

/// Resource types available for trade (excludes gold and wine).
const List<String> _tradeableTypes = ['wood', 'marble', 'crystal', 'sulfur'];

/// Opens the trade dialog as a modal bottom sheet.
///
/// Returns true if trade was successfully sent, false/null if cancelled.
Future<bool?> showTradeDialog(
  BuildContext context, {
  required String originCityId,
  required String destinationCityId,
  required String destinationCityName,
  required int originIslandX,
  required int originIslandY,
  required int destIslandX,
  required int destIslandY,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _TradeDialogContent(
      originCityId: originCityId,
      destinationCityId: destinationCityId,
      destinationCityName: destinationCityName,
      originIslandX: originIslandX,
      originIslandY: originIslandY,
      destIslandX: destIslandX,
      destIslandY: destIslandY,
    ),
  );
}

/// Internal trade dialog widget.
class _TradeDialogContent extends ConsumerStatefulWidget {
  const _TradeDialogContent({
    required this.originCityId,
    required this.destinationCityId,
    required this.destinationCityName,
    required this.originIslandX,
    required this.originIslandY,
    required this.destIslandX,
    required this.destIslandY,
  });

  final String originCityId;
  final String destinationCityId;
  final String destinationCityName;
  final int originIslandX;
  final int originIslandY;
  final int destIslandX;
  final int destIslandY;

  @override
  ConsumerState<_TradeDialogContent> createState() =>
      _TradeDialogContentState();
}

class _TradeDialogContentState extends ConsumerState<_TradeDialogContent> {
  final Map<String, double> _sliderValues = {
    for (final type in _tradeableTypes) type: 0.0,
  };
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final senderResourcesAsync =
        ref.watch(resourcesStreamProvider(widget.originCityId));
    final recipientInfoAsync =
        ref.watch(recipientCityInfoProvider(widget.destinationCityId));

    // Compute travel time client-side.
    final travelMinutes = calcTravelMinutes(
      widget.originIslandX,
      widget.originIslandY,
      widget.destIslandX,
      widget.destIslandY,
    );
    final travelHours = travelMinutes ~/ 60;
    final travelMins = travelMinutes % 60;
    final travelLabel = travelHours > 0
        ? '${travelHours}h ${travelMins}m'
        : '${travelMins}m';

    // Build map of sender available amounts (keyed by resource type DB name).
    final senderAmounts = <String, double>{
      for (final type in _tradeableTypes) type: 0.0,
    };
    senderResourcesAsync.whenData((resources) {
      for (final r in resources) {
        if (_tradeableTypes.contains(r.resourceType.value)) {
          senderAmounts[r.resourceType.value] = r.amount;
        }
      }
    });

    final bool hasAnyAmount =
        _sliderValues.values.any((v) => v > 0);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row: icon + city name + close button.
              Row(
                children: [
                  Icon(
                    Icons.local_shipping,
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.destinationCityName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close dialog',
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),

              const Divider(height: 24),

              // Travel time row.
              Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Arrives in: $travelLabel',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),

              const Divider(height: 24),

              // Resource sliders.
              ...recipientInfoAsync.when(
                loading: () => [
                  const Center(child: CircularProgressIndicator()),
                ],
                error: (e, _) => [
                  Text(
                    'Failed to load recipient info.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                data: (recipientInfo) {
                  return _tradeableTypes.map((type) {
                    final senderAvailable = senderAmounts[type] ?? 0.0;
                    final currentValue = _sliderValues[type]!;
                    final recipientSpace =
                        recipientInfo.remainingSpace(type);
                    final isOverflow = currentValue > recipientSpace;

                    // Clamp max to min of sender available and recipient space.
                    final maxValue = senderAvailable;

                    return _ResourceSliderRow(
                      type: type,
                      sliderValue: currentValue,
                      senderAvailable: senderAvailable,
                      maxValue: maxValue,
                      recipientSpace: recipientSpace,
                      isOverflow: isOverflow,
                      isLoading: _isLoading,
                      onChanged: senderAvailable > 0
                          ? (val) => setState(() {
                                _sliderValues[type] = val;
                              })
                          : null,
                    );
                  }).toList();
                },
              ),

              const SizedBox(height: 8),

              // Send Trade button.
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: (hasAnyAmount && !_isLoading)
                      ? _onSendTrade
                      : null,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.local_shipping),
                  label: Text(_isLoading ? 'Sending...' : 'Send Trade'),
                ),
              ),
              const SizedBox(height: 8),

              // Discard button.
              OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Discard Trade'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSendTrade() async {
    setState(() => _isLoading = true);

    // Build cargo map, filtering out zero values.
    final cargoMap = <String, int>{
      for (final entry in _sliderValues.entries)
        if (entry.value > 0) entry.key: entry.value.toInt(),
    };

    try {
      final result = await ref.read(tradeRepositoryProvider).sendTrade(
            originCityId: widget.originCityId,
            destinationCityId: widget.destinationCityId,
            cargo: cargoMap,
          );

      if (!mounted) return;

      // Parse travel_minutes from response for success message.
      final responseTravelMinutes =
          (result['travel_minutes'] as num?)?.toInt() ?? 0;
      final hours = responseTravelMinutes ~/ 60;
      final mins = responseTravelMinutes % 60;
      final arrivalLabel = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Trade sent! Cargo arrives in $arrivalLabel.'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } on TradeException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Trade failed. Check your connection and try again.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}

/// A single resource slider row widget.
class _ResourceSliderRow extends StatelessWidget {
  const _ResourceSliderRow({
    required this.type,
    required this.sliderValue,
    required this.senderAvailable,
    required this.maxValue,
    required this.recipientSpace,
    required this.isOverflow,
    required this.isLoading,
    required this.onChanged,
  });

  final String type;
  final double sliderValue;
  final double senderAvailable;
  final double maxValue;
  final double recipientSpace;
  final bool isOverflow;
  final bool isLoading;
  final ValueChanged<double>? onChanged;

  /// Returns a ResourceBadge for the given resource DB name string.
  Widget _tradeResourceBadge(String resourceDbName) {
    try {
      final resourceType = resourceTypeFromDbName(resourceDbName);
      return ResourceBadge(type: resourceType, radius: 10);
    } catch (_) {
      return const Icon(Icons.inventory_2, size: 18);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = type[0].toUpperCase() + type.substring(1);
    final sliderInt = sliderValue.toInt();
    final senderAvailableInt = senderAvailable.toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label row: icon + name + Spacer + value / available.
        Row(
          children: [
            _tradeResourceBadge(type),
            const SizedBox(width: 6),
            Text(displayName, style: theme.textTheme.labelLarge),
            const Spacer(),
            Text(
              '$sliderInt / $senderAvailableInt',
              style: theme.textTheme.bodySmall?.copyWith(
                color: sliderInt > 0
                    ? Colors.green.shade700
                    : (senderAvailable == 0
                        ? theme.colorScheme.error
                        : null),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        // Slider.
        Slider(
          value: sliderValue.clamp(0, maxValue > 0 ? maxValue : 0),
          min: 0,
          max: maxValue > 0 ? maxValue : 1,
          divisions:
              maxValue > 0 ? maxValue.toInt().clamp(1, 500) : 1,
          label: sliderInt.toString(),
          onChanged: (isLoading || onChanged == null) ? null : onChanged,
        ),
        // Recipient space row.
        Row(
          children: [
            Text(
              'Recipient space: ${recipientSpace.toInt()}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            if (isOverflow) ...[
              const SizedBox(width: 8),
              Text(
                'Warehouse full',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.orange.shade700),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
