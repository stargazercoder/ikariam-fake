// Spy report dialog — auto-triggers the spy-city Edge Function on open and
// displays resources, buildings, and army count for the target city.
//
// Entry point: showSpyReportDialog(context, targetCityId:, targetCityName:)
// NOTE: No playerCityId parameter — the Edge Function resolves the player's
// city server-side from auth.uid().

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/building_constants.dart';
import '../../../core/constants/visual_constants.dart';
import '../../../shared/widgets/resource_badge.dart';
import '../data/espionage_repository.dart';
import '../models/spy_report.dart';
import '../providers/espionage_providers.dart';

/// Shows the spy report dialog for [targetCityId].
///
/// The dialog auto-triggers the spy action on open (no confirmation step).
/// On success, displays resources, buildings, and army count with a
/// "View City" button to navigate to the read-only city view.
Future<void> showSpyReportDialog(
  BuildContext context, {
  required String targetCityId,
  required String targetCityName,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _SpyReportDialogContent(
      targetCityId: targetCityId,
      targetCityName: targetCityName,
    ),
  );
}

// ---------------------------------------------------------------------------
// Dialog content widget
// ---------------------------------------------------------------------------

class _SpyReportDialogContent extends ConsumerStatefulWidget {
  const _SpyReportDialogContent({
    required this.targetCityId,
    required this.targetCityName,
  });

  final String targetCityId;
  final String targetCityName;

  @override
  ConsumerState<_SpyReportDialogContent> createState() =>
      _SpyReportDialogContentState();
}

class _SpyReportDialogContentState
    extends ConsumerState<_SpyReportDialogContent> {
  bool _isLoading = true;
  SpyReport? _report;

  @override
  void initState() {
    super.initState();
    _executeSpy();
  }

  Future<void> _executeSpy() async {
    final repo = ref.read(espionageRepositoryProvider);
    try {
      final report = await repo.spyOnCity(targetCityId: widget.targetCityId);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _report = report;
      });
      // Invalidate caches so View City button updates and spy log refreshes.
      ref.invalidate(hasSpiedProvider(widget.targetCityId));
      ref.invalidate(spyReportsProvider);
    } on EspionageException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      final msg = e.message.contains('gold')
          ? 'Not enough gold. You need 100 gold to spy.'
          : 'Spy action failed. Check your connection and try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Spy action failed. Check your connection and try again.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    if (_isLoading) {
      return AlertDialog(
        content: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 120),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final report = _report;
    if (report == null) return const SizedBox.shrink();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title row.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
              child: Row(
                children: [
                  Icon(Icons.visibility, size: 32, color: primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report.targetCityName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close spy report',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Scrollable content.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Owner subtitle.
                    Text(
                      'Owner: ${report.ownerName}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const Divider(height: 24),
                    // Resources section.
                    Text(
                      'Resources',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._resourceRows(report.resources),
                    const Divider(height: 16),
                    // Buildings section.
                    Text(
                      'Buildings',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._buildingRows(report.buildings),
                    const Divider(height: 16),
                    // Army section.
                    Text(
                      'Army',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total units: ${report.armyCount}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            // Action buttons.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push(
                          '/city-view'
                          '?cityId=${Uri.encodeComponent(report.targetCityId)}'
                          '&cityName=${Uri.encodeComponent(report.targetCityName)}'
                          '&ownerName=${Uri.encodeComponent(report.ownerName)}',
                        );
                      },
                      child: const Text('View City'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close Report'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Resource rows (wood, marble, crystal, sulfur, gold)
  // ---------------------------------------------------------------------------

  List<Widget> _resourceRows(Map<String, int> resources) {
    const order = ['wood', 'marble', 'crystal', 'sulfur', 'gold'];
    final rows = <Widget>[];
    for (final key in order) {
      final amount = resources[key];
      if (amount == null) continue;
      rows.add(_ResourceBadgeRow(
        resourceKey: key,
        label: _capitalise(key),
        trailing: _formatNumber(amount),
      ));
    }
    // Any extra keys not in the fixed order.
    for (final entry in resources.entries) {
      if (!order.contains(entry.key)) {
        rows.add(_InfoRow(
          icon: Icons.monetization_on,
          iconColor: Colors.grey,
          label: _capitalise(entry.key),
          trailing: _formatNumber(entry.value),
        ));
      }
    }
    return rows;
  }

  // ---------------------------------------------------------------------------
  // Building rows
  // ---------------------------------------------------------------------------

  List<Widget> _buildingRows(Map<String, int> buildings) {
    return buildings.entries.map((e) {
      IconData icon;
      try {
        final buildingType = buildingTypeFromDbName(e.key);
        icon = buildingTypeIcon[buildingType] ?? Icons.home;
      } catch (_) {
        icon = Icons.home;
      }
      return _InfoRow(
        icon: icon,
        iconColor: Theme.of(context).colorScheme.secondary,
        label: _buildingDisplayName(e.key),
        trailing: 'Lv ${e.value}',
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _buildingDisplayName(String dbName) {
    // Convert snake_case to Title Case for display.
    return dbName
        .split('_')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  String _capitalise(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  String _formatNumber(int n) {
    // Format with comma separators for thousands.
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    final offset = s.length % 3;
    if (offset > 0) {
      buf.write(s.substring(0, offset));
    }
    for (int i = offset; i < s.length; i += 3) {
      if (buf.isNotEmpty) buf.write(',');
      buf.write(s.substring(i, i + 3));
    }
    return buf.toString();
  }
}

// ---------------------------------------------------------------------------
// Reusable info row widget
// ---------------------------------------------------------------------------

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            trailing,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Resource badge row widget (uses ResourceBadge instead of IconData)
// ---------------------------------------------------------------------------

class _ResourceBadgeRow extends StatelessWidget {
  const _ResourceBadgeRow({
    required this.resourceKey,
    required this.label,
    required this.trailing,
  });

  final String resourceKey;
  final String label;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    Widget badge;
    try {
      final type = resourceTypeFromDbName(resourceKey);
      badge = ResourceBadge(type: type, radius: 10);
    } catch (_) {
      badge = const Icon(Icons.circle, size: 16, color: Colors.grey);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          badge,
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            trailing,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
