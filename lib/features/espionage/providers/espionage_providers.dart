// Riverpod providers for the espionage feature.
//
// Exposes the EspionageRepository, a list of spy reports for the current player,
// and a per-city "has spied" boolean flag used by the city view UI.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/espionage_repository.dart';
import '../models/spy_report.dart';

/// Provider for the [EspionageRepository] singleton.
final espionageRepositoryProvider = Provider<EspionageRepository>((ref) {
  return const EspionageRepository();
});

/// FutureProvider that fetches all spy reports for the current player,
/// ordered by created_at DESC.
///
/// autoDispose releases memory when no widget is watching.
final spyReportsProvider =
    FutureProvider.autoDispose<List<SpyReport>>((ref) async {
  final repo = ref.read(espionageRepositoryProvider);
  return repo.fetchSpyReports();
});

/// FutureProvider.family that returns true if the current player has at least
/// one spy report for the given [targetCityId].
///
/// Used by the city action dialog to show a "View last report" option
/// when the player has already spied on a city.
final hasSpiedProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, targetCityId) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return false;
  final row = await Supabase.instance.client
      .from('spy_reports')
      .select('id')
      .eq('player_id', userId)
      .eq('target_city_id', targetCityId)
      .limit(1)
      .maybeSingle();
  return row != null;
});
