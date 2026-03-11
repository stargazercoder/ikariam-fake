// Riverpod StreamProvider for real-time training queue state.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/military_repository.dart';
import '../models/training_queue_entry.dart';

/// StreamProvider.family that emits the active [TrainingQueueEntry] for
/// [cityId], or null if no training is in progress.
///
/// The UNIQUE(city_id) constraint on training_queue guarantees at most one
/// row per city. The stream emits null automatically when pg_cron's
/// complete_training() deletes the finished row.
///
/// autoDispose releases the Realtime subscription when no widget watches it.
final trainingQueueProvider =
    StreamProvider.autoDispose.family<TrainingQueueEntry?, String>(
  (ref, cityId) =>
      ref.read(militaryRepositoryProvider).watchTrainingQueue(cityId),
);
