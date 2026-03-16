// Repository for trade operations: invoking the send-trade Edge Function.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';

/// Exception thrown when the send-trade Edge Function returns an error.
class TradeException implements Exception {
  const TradeException(this.message);

  final String message;

  @override
  String toString() => 'TradeException: $message';
}

/// Repository for trade operations.
///
/// Writes go through the send-trade Edge Function
/// (never direct client mutations to game-state tables).
class TradeRepository {
  const TradeRepository();

  /// Invokes the send-trade Edge Function to send cargo to another city.
  ///
  /// [cargo] is a map of resource_type (DB snake_case) to quantity to send.
  ///
  /// Returns response data containing arrive_at and travel_minutes on success.
  /// Throws [TradeException] on non-200 responses with the server error message.
  Future<Map<String, dynamic>> sendTrade({
    required String originCityId,
    required String destinationCityId,
    required Map<String, int> cargo,
  }) async {
    final response = await supabaseClient.functions.invoke(
      'send-trade',
      body: {
        'origin_city_id': originCityId,
        'destination_city_id': destinationCityId,
        'cargo': cargo,
      },
    );

    if (response.status != 200) {
      final data = response.data;
      String errorMessage = 'Trade failed';
      if (data is Map<String, dynamic>) {
        errorMessage = (data['error'] as String?) ?? errorMessage;
      }
      throw TradeException(errorMessage);
    }

    // Return response data containing arrive_at and travel_minutes.
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return {};
  }
}

/// Riverpod provider for [TradeRepository].
final tradeRepositoryProvider = Provider<TradeRepository>(
  (ref) => const TradeRepository(),
);
