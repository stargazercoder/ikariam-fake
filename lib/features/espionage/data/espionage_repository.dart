// Repository for espionage operations: invoking the spy-city Edge Function
// and fetching spy reports from the spy_reports table.
//
// Decision INFR-02: All game mutations go through Edge Functions — no Flutter
// client writes directly to game-state tables.

import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/spy_report.dart';

/// Exception thrown when the spy-city Edge Function or a spy_reports query
/// returns an error.
class EspionageException implements Exception {
  const EspionageException(this.message);

  final String message;

  @override
  String toString() => 'EspionageException: $message';
}

/// Repository for espionage operations.
///
/// Mutations invoke the spy-city Edge Function (never direct table writes).
/// Reads query the spy_reports table directly via the anon client (RLS-filtered).
class EspionageRepository {
  const EspionageRepository();

  /// Invokes the spy-city Edge Function to perform a spy action.
  ///
  /// Deducts 100 gold from the player's city and returns a [SpyReport]
  /// containing the target city's resources, buildings, and army count.
  ///
  /// Throws [EspionageException] with a user-facing message on failure.
  Future<SpyReport> spyOnCity({required String targetCityId}) async {
    final response = await Supabase.instance.client.functions.invoke('spy-city',
      body: {'target_city_id': targetCityId},
    );

    if (response.status != 200) {
      final data = response.data;
      String errorMessage = 'Spy action failed';
      if (data is Map<String, dynamic>) {
        errorMessage = (data['error'] as String?) ?? errorMessage;
      } else if (data is String) {
        try {
          final decoded = jsonDecode(data) as Map<String, dynamic>;
          errorMessage = (decoded['error'] as String?) ?? errorMessage;
        } catch (_) {
          errorMessage = data;
        }
      }
      if (errorMessage.contains('gold')) {
        throw const EspionageException('Not enough gold. You need 100 gold to spy.');
      }
      throw EspionageException(errorMessage);
    }

    final Map<String, dynamic> responseData = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : jsonDecode(response.data as String) as Map<String, dynamic>;

    final report = responseData['report'] as Map<String, dynamic>;
    return SpyReport.fromJson(report);
  }

  /// Fetches all spy reports for the current player, ordered by created_at DESC.
  ///
  /// RLS on spy_reports ensures only the authenticated player's rows are returned.
  Future<List<SpyReport>> fetchSpyReports() async {
    final rows = await Supabase.instance.client
        .from('spy_reports')
        .select()
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(SpyReport.fromJson)
        .toList();
  }
}
