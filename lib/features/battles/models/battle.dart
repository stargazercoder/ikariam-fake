// Typed model for battles table rows from Supabase.
// Read-only: no toJson, insert, update, or delete methods.
// All battle mutations are server-side only (SECURITY DEFINER functions).

/// Immutable model representing an active or completed battle between two players.
///
/// The [attackerUnits] and [defenderUnits] fields contain live unit counts as
/// JSONB snapshots (key = DB snake_case unit type, value = quantity remaining).
/// These are mutated server-side each turn by resolve_battles().
class Battle {
  const Battle({
    required this.id,
    required this.defenderCityId,
    required this.attackerCityId,
    required this.attackerId,
    required this.defenderId,
    required this.attackerUnits,
    required this.defenderUnits,
    required this.status,
    required this.turnNumber,
    required this.nextTurnAt,
    required this.createdAt,
    this.pillageResult,
  });

  final String id;
  final String defenderCityId;
  final String attackerCityId;
  final String attackerId;
  final String defenderId;

  /// Live unit counts for the attacker: key = DB snake_case unit type, value = quantity remaining.
  /// Example: {'hoplite': 15, 'archer': 10, 'cargo_ship': 3}
  final Map<String, int> attackerUnits;

  /// Live unit counts for the defender: key = DB snake_case unit type, value = quantity remaining.
  final Map<String, int> defenderUnits;

  /// Battle status: 'active', 'attacker_won', or 'defender_won'.
  final String status;

  /// Current turn number (0 = not yet started, increments after each resolve).
  final int turnNumber;

  /// UTC time when the next turn will be resolved by resolve_battles().
  final DateTime nextTurnAt;

  final DateTime createdAt;

  /// Pillaged resource amounts (null if no pillage occurred or battle not yet won).
  /// Keys are resource types ('wood', 'marble', 'crystal', 'sulfur'), values are amounts.
  final Map<String, int>? pillageResult;

  /// Returns true when the battle is still in progress.
  bool get isActive => status == 'active';

  /// Parses a Supabase JSON row into a [Battle] instance.
  /// The 'attacker_units' and 'defender_units' JSONB fields are parsed from
  /// Map<String, dynamic> to Map<String, int>.
  factory Battle.fromJson(Map<String, dynamic> json) {
    return Battle(
      id: json['id'] as String,
      defenderCityId: json['defender_city_id'] as String,
      attackerCityId: json['attacker_city_id'] as String,
      attackerId: json['attacker_id'] as String,
      defenderId: json['defender_id'] as String,
      attackerUnits: (json['attacker_units'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toInt())),
      defenderUnits: (json['defender_units'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toInt())),
      status: json['status'] as String,
      turnNumber: (json['turn_number'] as num).toInt(),
      nextTurnAt: DateTime.parse(json['next_turn_at'] as String).toUtc(),
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
      pillageResult: json['pillage_result'] == null
          ? null
          : (json['pillage_result'] as Map<String, dynamic>)
              .map((k, v) => MapEntry(k, (v as num).toInt())),
    );
  }

  @override
  String toString() =>
      'Battle(id: $id, status: $status, turnNumber: $turnNumber, '
      'attackerId: $attackerId, defenderId: $defenderId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Battle && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
