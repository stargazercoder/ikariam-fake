// Riverpod StreamProvider for real-time city resource amounts.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/resources_repository.dart';
import '../models/city_resource.dart';

/// StreamProvider.family that emits live [CityResource] snapshots for [cityId].
///
/// The stream is obtained from [ResourcesRepository.watchCityResources] and
/// stored in a local variable before returning — this prevents the Supabase
/// Realtime subscription from being cancelled on rebuild (Riverpod disposes
/// streams only when the provider itself is disposed, not on each rebuild).
///
/// autoDispose ensures the Realtime subscription is released when no widget
/// is watching this provider (e.g., when the city screen is not visible).
final resourcesStreamProvider = StreamProvider.autoDispose
    .family<List<CityResource>, String>((ref, cityId) {
  final stream =
      ref.read(resourcesRepositoryProvider).watchCityResources(cityId);
  return stream;
});
