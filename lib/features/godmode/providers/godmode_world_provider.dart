import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/godmode_repository.dart';
import '../models/godmode_player.dart';

/// AsyncNotifier that holds the full GodMode world state (all players).
///
/// Polls every 30 seconds. Uses stale-while-refresh: the existing data
/// remains visible while [refresh()] fetches new data in the background.
///
/// Supports column sorting via [sortBy()] — sort is applied locally so
/// the UI can resort without a network round-trip.
///
/// [isRefreshing] tracks in-flight background refresh without replacing
/// the current AsyncData state.
class GodmodeWorldNotifier extends AsyncNotifier<List<GodmodePlayer>> {
  Timer? _pollTimer;
  bool _isRefreshing = false;
  DateTime _lastUpdated = DateTime.now();
  String _sortColumn = 'displayName';
  bool _sortAscending = true;

  bool get isRefreshing => _isRefreshing;
  DateTime get lastUpdated => _lastUpdated;

  @override
  Future<List<GodmodePlayer>> build() async {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      refresh();
    });
    ref.onDispose(() => _pollTimer?.cancel());
    return _fetch();
  }

  Future<List<GodmodePlayer>> _fetch() async {
    final repo = ref.read(godmodeRepositoryProvider);
    final players = await repo.getWorldState();
    _lastUpdated = DateTime.now();
    return _applySorting(players);
  }

  /// Refreshes world state in the background (stale-while-refresh).
  /// Existing [AsyncData] remains visible while the request is in-flight.
  Future<void> refresh() async {
    _isRefreshing = true;
    try {
      final players = await _fetch();
      state = AsyncData(players);
    } catch (e, s) {
      state = AsyncError(e, s);
    }
    _isRefreshing = false;
  }

  /// Sorts the current data by [column] in [ascending] order.
  /// Does not trigger a network request — applies sorting to local state.
  void sortBy(String column, bool ascending) {
    _sortColumn = column;
    _sortAscending = ascending;
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(_applySorting([...current]));
  }

  List<GodmodePlayer> _applySorting(List<GodmodePlayer> players) {
    switch (_sortColumn) {
      case 'displayName':
        players.sort((a, b) => a.displayName.compareTo(b.displayName));
      case 'totalResources':
        players.sort((a, b) => a.totalResources.compareTo(b.totalResources));
      case 'landCount':
        players.sort((a, b) => a.landCount.compareTo(b.landCount));
      case 'navalCount':
        players.sort((a, b) => a.navalCount.compareTo(b.navalCount));
      case 'buildingCount':
        players.sort((a, b) => a.buildingCount.compareTo(b.buildingCount));
      case 'activeBattleCount':
        players.sort(
          (a, b) => a.activeBattleCount.compareTo(b.activeBattleCount),
        );
    }
    if (!_sortAscending) {
      return players.reversed.toList();
    }
    return players;
  }
}

/// Provider for [GodmodeWorldNotifier].
final godmodeWorldProvider =
    AsyncNotifierProvider<GodmodeWorldNotifier, List<GodmodePlayer>>(
  GodmodeWorldNotifier.new,
);
