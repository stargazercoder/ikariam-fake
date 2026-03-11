// Repository for streaming real-time city resource data from Supabase.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../models/city_resource.dart';

/// Repository for city resource data access.
///
/// All reads use Supabase Realtime streams via .stream() so that the Flutter
/// UI updates automatically when the server-side pg_cron tick modifies rows.
class ResourcesRepository {
  const ResourcesRepository();

  /// Returns a live stream of all resource rows for [cityId].
  ///
  /// Uses .stream(primaryKey: ['id']) to register a Supabase Realtime
  /// subscription — the stream emits a new snapshot whenever any row in
  /// city_resources changes.  Rows are ordered by resource_type for
  /// deterministic UI ordering.
  Stream<List<CityResource>> watchCityResources(String cityId) {
    return supabaseClient
        .from('city_resources')
        .stream(primaryKey: ['id'])
        .eq('city_id', cityId)
        .order('resource_type')
        .map((rows) => rows.map((r) => CityResource.fromJson(r)).toList());
  }
}

/// Riverpod provider for [ResourcesRepository].
final resourcesRepositoryProvider = Provider<ResourcesRepository>(
  (ref) => const ResourcesRepository(),
);
