import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/godmode_repository.dart';
import '../models/godmode_event.dart';

/// Notifier that holds the active event type filter.
/// null = All events, 'battle' | 'trade' | 'espionage' = filtered.
class GodmodeEventFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setFilter(String? eventType) => state = eventType;
}

/// Provider for [GodmodeEventFilterNotifier].
final godmodeEventFilterProvider =
    NotifierProvider<GodmodeEventFilterNotifier, String?>(
  GodmodeEventFilterNotifier.new,
);

/// AsyncNotifier that holds the GodMode events list.
///
/// Polls every 30 seconds. Re-builds automatically when
/// [godmodeEventFilterProvider] changes (via ref.watch in build).
///
/// [isRefreshing] tracks in-flight background refresh without replacing
/// the current AsyncData state.
class GodmodeEventsNotifier extends AsyncNotifier<List<GodmodeEvent>> {
  Timer? _pollTimer;
  bool _isRefreshing = false;
  DateTime _lastUpdated = DateTime.now();

  bool get isRefreshing => _isRefreshing;
  DateTime get lastUpdated => _lastUpdated;

  @override
  Future<List<GodmodeEvent>> build() async {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      refresh();
    });
    ref.onDispose(() => _pollTimer?.cancel());
    final filter = ref.watch(godmodeEventFilterProvider);
    return _fetch(filter);
  }

  Future<List<GodmodeEvent>> _fetch(String? eventType) async {
    final repo = ref.read(godmodeRepositoryProvider);
    final events = await repo.getEvents(eventType: eventType);
    _lastUpdated = DateTime.now();
    return events;
  }

  /// Refreshes events in the background (stale-while-refresh).
  /// Reads the current filter from [godmodeEventFilterProvider].
  Future<void> refresh() async {
    _isRefreshing = true;
    final filter = ref.read(godmodeEventFilterProvider);
    try {
      final events = await _fetch(filter);
      state = AsyncData(events);
    } catch (e, s) {
      state = AsyncError(e, s);
    }
    _isRefreshing = false;
  }
}

/// Provider for [GodmodeEventsNotifier].
final godmodeEventsProvider =
    AsyncNotifierProvider<GodmodeEventsNotifier, List<GodmodeEvent>>(
  GodmodeEventsNotifier.new,
);
