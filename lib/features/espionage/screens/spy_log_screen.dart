// Spy log screen — lists all past spy reports for the current player,
// ordered by most recent first.
//
// Accessible from the Battles tab AppBar. Nested inside the battles
// StatefulShellBranch so the bottom navigation bar remains visible.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/spy_report.dart';
import '../providers/espionage_providers.dart';

/// Screen listing past spy reports ordered by most recent.
class SpyLogScreen extends ConsumerWidget {
  const SpyLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(spyReportsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Spy Reports')),
      body: reportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Failed to load spy reports: $e')),
        data: (reports) {
          if (reports.isEmpty) return const _EmptySpyLog();
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: reports.length,
            itemBuilder: (context, index) =>
                _SpyLogTile(report: reports[index]),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptySpyLog extends StatelessWidget {
  const _EmptySpyLog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.visibility_off,
              size: 64,
              color: theme.colorScheme.onSurface.withAlpha(80),
            ),
            const SizedBox(height: 16),
            Text(
              'No spy reports yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(140),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Tap 'Spy' on an enemy city to gather intelligence.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Spy log tile
// ---------------------------------------------------------------------------

class _SpyLogTile extends StatelessWidget {
  const _SpyLogTile({required this.report});

  final SpyReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(Icons.visibility, color: theme.colorScheme.primary),
        title: Text(
          report.targetCityName,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          _formatDate(report.createdAt),
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Colors.grey.shade500,
        ),
        onTap: () => context.push(
          '/city-view'
          '?cityId=${Uri.encodeComponent(report.targetCityId)}'
          '&cityName=${Uri.encodeComponent(report.targetCityName)}'
          '&ownerName=${Uri.encodeComponent(report.ownerName)}',
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final month = _monthName(local.month);
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month ${local.day}, ${local.year} · $hour:$minute';
  }

  String _monthName(int m) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[m - 1];
  }
}
