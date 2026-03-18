import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ikariam/features/godmode/data/godmode_repository.dart';
import 'package:ikariam/features/godmode/models/godmode_event.dart';
import 'package:ikariam/features/godmode/models/godmode_player.dart';
import 'package:ikariam/features/godmode/providers/godmode_events_provider.dart';
import 'package:ikariam/features/godmode/providers/godmode_world_provider.dart';

// ---------------------------------------------------------------------------
// Mock data factories
// ---------------------------------------------------------------------------

/// A human player fixture for tests.
GodmodePlayer mockHumanPlayer() {
  return GodmodePlayer(
    id: 'player-001',
    displayName: 'TestHuman',
    isBot: false,
    isPaused: false,
    resources: {
      'wood': 1000,
      'marble': 500,
      'crystal': 200,
      'sulfur': 100,
      'gold': 800,
    },
    landCount: 50,
    navalCount: 10,
    buildingCount: 5,
    activeBattleCount: 0,
    activeBattles: [],
    buildings: {'town_hall': 3, 'barracks': 2},
  );
}

/// A bot player fixture for tests. Pass [isPaused] to control pause state.
GodmodePlayer mockBotPlayer({bool isPaused = false}) {
  return GodmodePlayer(
    id: 'bot-001',
    displayName: 'Bot01',
    isBot: true,
    isPaused: isPaused,
    resources: {
      'wood': 500,
      'marble': 200,
      'crystal': 100,
      'sulfur': 50,
      'gold': 300,
    },
    landCount: 30,
    navalCount: 5,
    buildingCount: 3,
    activeBattleCount: 1,
    activeBattles: [
      {
        'battle_id': 'b-001',
        'attacker_name': 'Bot01',
        'defender_name': 'TestHuman',
      },
    ],
    buildings: {'town_hall': 2, 'barracks': 1},
  );
}

/// A battle event fixture for tests.
GodmodeEvent mockBattleEvent() {
  return GodmodeEvent(
    eventType: 'battle',
    timestamp: DateTime(2026, 3, 18, 10, 30),
    detail: {
      'battle_id': 'b-001',
      'attacker': 'Bot01',
      'defender': 'TestHuman',
      'summary': 'Battle turn 2 - active',
    },
  );
}

/// A trade event fixture for tests.
GodmodeEvent mockTradeEvent() {
  return GodmodeEvent(
    eventType: 'trade',
    timestamp: DateTime(2026, 3, 18, 9, 0),
    detail: {'summary': 'Trade completed'},
  );
}

/// An espionage event fixture for tests.
GodmodeEvent mockEspionageEvent() {
  return GodmodeEvent(
    eventType: 'espionage',
    timestamp: DateTime(2026, 3, 18, 8, 0),
    detail: {'summary': 'Spy report received'},
  );
}

// ---------------------------------------------------------------------------
// Stub notifiers — world provider
// ---------------------------------------------------------------------------

/// Stub world notifier that immediately returns [players] — no Supabase call.
class FakeWorldNotifier extends GodmodeWorldNotifier {
  FakeWorldNotifier(this._players);

  final List<GodmodePlayer> _players;

  @override
  Future<List<GodmodePlayer>> build() async => _players;

  @override
  bool get isRefreshing => false;

  @override
  DateTime get lastUpdated => DateTime(2026, 3, 18);

  @override
  Future<void> refresh() async {}

  @override
  void sortBy(String column, bool ascending) {}
}

/// Error world notifier — throws immediately so async error state is tested.
class ErrorWorldNotifier extends GodmodeWorldNotifier {
  @override
  Future<List<GodmodePlayer>> build() async =>
      throw Exception('Network error');

  @override
  bool get isRefreshing => false;

  @override
  DateTime get lastUpdated => DateTime(2026, 3, 18);
}

// ---------------------------------------------------------------------------
// Stub notifiers — events provider
// ---------------------------------------------------------------------------

/// Stub events notifier that immediately returns [events] — no Supabase call.
class FakeEventsNotifier extends GodmodeEventsNotifier {
  FakeEventsNotifier(this._events);

  final List<GodmodeEvent> _events;

  @override
  Future<List<GodmodeEvent>> build() async => _events;

  @override
  Future<void> refresh() async {}
}

/// Error events notifier — throws immediately so async error state is tested.
class ErrorEventsNotifier extends GodmodeEventsNotifier {
  @override
  Future<List<GodmodeEvent>> build() async =>
      throw Exception('Network error');
}

/// Stub filter notifier — always returns null (no filter active).
class FakeEventFilterNotifier extends GodmodeEventFilterNotifier {
  @override
  String? build() => null;
}

// ---------------------------------------------------------------------------
// Fake repository — used when godmodeRepositoryProvider must be overridden
// to prevent Supabase.instance access during provider tree construction.
// ---------------------------------------------------------------------------

/// Fake [GodmodeRepository] that never calls Supabase. All methods throw
/// [UnimplementedError] to surface accidental calls in tests.
class FakeGodmodeRepository extends GodmodeRepository {
  FakeGodmodeRepository() : super(_fakeClient);

  static final SupabaseClient _fakeClient = _FakeSupabaseClient._();

  @override
  Future<List<GodmodePlayer>> getWorldState() async => [];

  @override
  Future<void> setBotPaused(String botId, bool paused) async {}

  @override
  Future<String> forceAction(String botId) async => 'none';

  @override
  Future<void> setResources(
    String playerId, {
    required double wood,
    required double marble,
    required double crystal,
    required double sulfur,
    required double gold,
  }) async {}

  @override
  Future<void> setArmy(String playerId, Map<String, int> units) async {}

  @override
  Future<List<GodmodeEvent>> getEvents({
    int limit = 50,
    String? eventType,
  }) async =>
      [];
}

/// Minimal fake SupabaseClient subclass used solely so [FakeGodmodeRepository]
/// can be instantiated without initialising Supabase. All calls will error —
/// real methods must never be invoked in tests.
class _FakeSupabaseClient extends SupabaseClient {
  _FakeSupabaseClient._()
      : super(
          'https://fake.supabase.co',
          'fake-anon-key',
        );
}
