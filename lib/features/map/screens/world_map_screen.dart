// World Map screen — pannable/zoomable grid of all islands.
//
// Watches allIslandsProvider to display a 5×2 grid of islands.
// Tapping an island sets selectedIslandIdProvider and navigates to /island.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/island.dart';
import '../providers/islands_provider.dart';

/// World map screen showing all islands on a pannable/zoomable 2D grid.
class WorldMapScreen extends ConsumerWidget {
  const WorldMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final islandsAsync = ref.watch(allIslandsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('World Map'),
      ),
      body: islandsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to load islands: $error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (islands) => _IslandGrid(islands: islands),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Island grid
// ---------------------------------------------------------------------------

/// Pannable/zoomable grid of island cells.
class _IslandGrid extends ConsumerWidget {
  const _IslandGrid({required this.islands});

  final List<Island> islands;

  // Each grid cell is 120 logical pixels.
  static const double _cellSize = 120.0;

  // World map dimensions: 5 columns × 5 rows.
  static const int _cols = 5;
  static const int _rows = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gridWidth = _cols * _cellSize;
    final gridHeight = _rows * _cellSize;

    // Build a lookup map from (gridX, gridY) to Island for quick access.
    final islandByPos = {
      for (final island in islands) '${island.gridX},${island.gridY}': island,
    };

    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(80),
      minScale: 0.3,
      maxScale: 2.5,
      child: SizedBox(
        width: gridWidth,
        height: gridHeight,
        child: Stack(
          children: [
            // Background grid lines.
            Positioned.fill(
              child: CustomPaint(painter: _GridPainter(cols: _cols, rows: _rows, cellSize: _cellSize)),
            ),
            // Island cells placed by grid position.
            for (int row = 0; row < _rows; row++)
              for (int col = 0; col < _cols; col++)
                Positioned(
                  left: col * _cellSize + 4,
                  top: row * _cellSize + 4,
                  width: _cellSize - 8,
                  height: _cellSize - 8,
                  child: _IslandCell(
                    island: islandByPos['$col,$row'],
                    gridX: col,
                    gridY: row,
                    onTap: (island) {
                      if (island != null) {
                        ref
                            .read(selectedIslandIdProvider.notifier)
                            .select(island.id);
                      }
                      context.go('/island');
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grid background painter
// ---------------------------------------------------------------------------

class _GridPainter extends CustomPainter {
  const _GridPainter({
    required this.cols,
    required this.rows,
    required this.cellSize,
  });

  final int cols;
  final int rows;
  final double cellSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(30)
      ..strokeWidth = 1;

    for (int i = 0; i <= cols; i++) {
      final x = i * cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (int i = 0; i <= rows; i++) {
      final y = i * cellSize;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Single island cell
// ---------------------------------------------------------------------------

class _IslandCell extends StatelessWidget {
  const _IslandCell({
    required this.island,
    required this.gridX,
    required this.gridY,
    required this.onTap,
  });

  final Island? island;
  final int gridX;
  final int gridY;
  final void Function(Island?) onTap;

  @override
  Widget build(BuildContext context) {
    if (island == null) {
      // Empty ocean cell.
      return Container(
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade900.withAlpha(80),
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    final color = _islandColor(island!.luxuryType);
    final icon = _luxuryIcon(island!.luxuryType);

    return GestureDetector(
      onTap: () => onTap(island),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withAlpha(60), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: Colors.white.withAlpha(220)),
            const SizedBox(height: 4),
            Text(
              '(${island!.gridX},${island!.gridY})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns a color based on the island's luxury resource type.
  Color _islandColor(String luxuryType) {
    switch (luxuryType.toLowerCase()) {
      case 'marble':
        return const Color(0xFF4A6880); // grey-blue
      case 'crystal':
        return const Color(0xFF3A7FC1); // light-blue
      case 'sulfur':
        return const Color(0xFF8B6914); // amber-tint
      default:
        return const Color(0xFF2E5E4E); // default teal
    }
  }

  /// Returns an icon for the luxury resource type.
  IconData _luxuryIcon(String luxuryType) {
    switch (luxuryType.toLowerCase()) {
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
}
