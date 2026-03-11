// Repository for military operations: streaming training queue, army roster,
// unit movements, and invoking train-units / dispatch-units Edge Functions.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../models/city_unit.dart';
import '../models/training_queue_entry.dart';
import '../models/unit_movement.dart';

/// Exception thrown when the train-units Edge Function returns an error.
class TrainingException implements Exception {
  const TrainingException(this.message);

  final String message;

  @override
  String toString() => 'TrainingException: $message';
}

/// Exception thrown when the dispatch-units Edge Function returns an error.
class DispatchException implements Exception {
  const DispatchException(this.message);

  final String message;

  @override
  String toString() => 'DispatchException: $message';
}

/// Repository for military data access and mutations.
///
/// Reads use Supabase Realtime streams; writes go through Edge Functions
/// (never direct client mutations to game-state tables).
class MilitaryRepository {
  const MilitaryRepository();

  /// Returns a live stream of the active [TrainingQueueEntry] for [cityId],
  /// or null if no training is in progress.
  ///
  /// The UNIQUE(city_id) constraint on training_queue guarantees at most one
  /// row per city. The stream emits null when pg_cron's complete_training()
  /// deletes the completed row.
  Stream<TrainingQueueEntry?> watchTrainingQueue(String cityId) {
    return supabaseClient
        .from('training_queue')
        .stream(primaryKey: ['id'])
        .eq('city_id', cityId)
        .map(
          (rows) => rows.isEmpty
              ? null
              : TrainingQueueEntry.fromJson(rows.first),
        );
  }

  /// Returns a live stream of all [CityUnit] rows for [cityId].
  ///
  /// Emits a new snapshot whenever any unit row changes (e.g., when
  /// complete_training() inserts or updates units after training finishes).
  Stream<List<CityUnit>> watchArmyRoster(String cityId) {
    return supabaseClient
        .from('city_units')
        .stream(primaryKey: ['id'])
        .eq('city_id', cityId)
        .order('unit_type')
        .map((rows) => rows.map((r) => CityUnit.fromJson(r)).toList());
  }

  /// Returns a live stream of outgoing [UnitMovement] rows owned by the
  /// current user, filtered client-side to those originating from [cityId].
  ///
  /// Supabase Realtime .stream() does not support filtering by two columns
  /// simultaneously. We stream all movements owned by the current user and
  /// filter client-side by originCityId.
  Stream<List<UnitMovement>> watchOutgoingMovements(String cityId) {
    final userId = supabaseClient.auth.currentUser?.id;
    if (userId == null) {
      return const Stream.empty();
    }
    return supabaseClient
        .from('unit_movements')
        .stream(primaryKey: ['id'])
        .eq('owner_id', userId)
        .map(
          (rows) => rows
              .map((r) => UnitMovement.fromJson(r))
              .where((m) => m.originCityId == cityId)
              .toList(),
        );
  }

  /// Invokes the train-units Edge Function to queue a unit training job.
  ///
  /// Throws [TrainingException] on non-200 responses with the server error
  /// message (e.g., queue already busy, insufficient resources, level too low).
  Future<void> trainUnits({
    required String cityId,
    required String unitType,
    required int quantity,
  }) async {
    final response = await supabaseClient.functions.invoke(
      'train-units',
      body: {
        'city_id': cityId,
        'unit_type': unitType,
        'quantity': quantity,
      },
    );

    if (response.status != 200) {
      final data = response.data;
      String errorMessage = 'Training failed';
      if (data is Map<String, dynamic>) {
        errorMessage = (data['error'] as String?) ?? errorMessage;
      }
      throw TrainingException(errorMessage);
    }
  }

  /// Invokes the dispatch-units Edge Function to send an army to another city.
  ///
  /// [units] is a map of unit_type (DB snake_case) to quantity to dispatch.
  ///
  /// Throws [DispatchException] on non-200 responses with the server error
  /// message (e.g., insufficient units, invalid city IDs).
  Future<void> dispatchUnits({
    required String originCityId,
    required String destinationCityId,
    required Map<String, int> units,
  }) async {
    final response = await supabaseClient.functions.invoke(
      'dispatch-units',
      body: {
        'origin_city_id': originCityId,
        'destination_city_id': destinationCityId,
        'units': units,
      },
    );

    if (response.status != 200) {
      final data = response.data;
      String errorMessage = 'Dispatch failed';
      if (data is Map<String, dynamic>) {
        errorMessage = (data['error'] as String?) ?? errorMessage;
      }
      throw DispatchException(errorMessage);
    }
  }
}

/// Riverpod provider for [MilitaryRepository].
final militaryRepositoryProvider = Provider<MilitaryRepository>(
  (ref) => const MilitaryRepository(),
);
