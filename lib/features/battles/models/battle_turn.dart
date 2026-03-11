// Typed model for battle_turns table rows from Supabase.
// Read-only: no toJson, insert, update, or delete methods.
// All battle turn mutations are server-side only (SECURITY DEFINER functions).

/// Immutable model representing the per-turn results of one battle resolution.
///
/// Naval and land phase casualty fields are nullable because:
/// - Naval casualties are null when naval phase is skipped (navalOutcome == 'skipped').
/// - Land casualties are null when the naval gate-keeper blocks the land phase
///   (landOutcome == 'blocked').
///
/// [attackerSurvivors] and [defenderSurvivors] are non-nullable: they always
/// record the unit counts at the end of the turn, even if zero.
class BattleTurn {
  const BattleTurn({
    required this.id,
    required this.battleId,
    required this.turnNumber,
    this.navalAttackerCasualties,
    this.navalDefenderCasualties,
    this.navalOutcome,
    this.landAttackerCasualties,
    this.landDefenderCasualties,
    this.landOutcome,
    required this.attackerSurvivors,
    required this.defenderSurvivors,
    required this.resolvedAt,
  });

  final String id;
  final String battleId;
  final int turnNumber;

  /// Attacker naval unit casualties this turn. Null when naval phase was skipped.
  final Map<String, int>? navalAttackerCasualties;

  /// Defender naval unit casualties this turn. Null when naval phase was skipped.
  final Map<String, int>? navalDefenderCasualties;

  /// Naval phase result: 'attacker_won', 'defender_won', 'ongoing', 'skipped', or null.
  final String? navalOutcome;

  /// Attacker land unit casualties this turn. Null when land phase was blocked.
  final Map<String, int>? landAttackerCasualties;

  /// Defender land unit casualties this turn. Null when land phase was blocked.
  final Map<String, int>? landDefenderCasualties;

  /// Land phase result: 'attacker_won', 'defender_won', 'ongoing', 'blocked', or null.
  final String? landOutcome;

  /// Attacker unit survivors at end of this turn. Non-nullable (always present).
  /// Key = DB snake_case unit type, value = quantity remaining.
  final Map<String, int> attackerSurvivors;

  /// Defender unit survivors at end of this turn. Non-nullable (always present).
  final Map<String, int> defenderSurvivors;

  /// UTC time when this turn was resolved by resolve_battles().
  final DateTime resolvedAt;

  /// Parses a nullable JSONB casualties field into Map<String, int>?.
  /// Returns null when the DB value is null (phase was skipped or blocked).
  static Map<String, int>? _parseUnits(dynamic value) {
    if (value == null) return null;
    return (value as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int));
  }

  /// Parses a Supabase JSON row into a [BattleTurn] instance.
  factory BattleTurn.fromJson(Map<String, dynamic> json) {
    return BattleTurn(
      id: json['id'] as String,
      battleId: json['battle_id'] as String,
      turnNumber: json['turn_number'] as int,
      navalAttackerCasualties: _parseUnits(json['naval_attacker_casualties']),
      navalDefenderCasualties: _parseUnits(json['naval_defender_casualties']),
      navalOutcome: json['naval_outcome'] as String?,
      landAttackerCasualties: _parseUnits(json['land_attacker_casualties']),
      landDefenderCasualties: _parseUnits(json['land_defender_casualties']),
      landOutcome: json['land_outcome'] as String?,
      attackerSurvivors: (json['attacker_survivors'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as int)),
      defenderSurvivors: (json['defender_survivors'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as int)),
      resolvedAt: DateTime.parse(json['resolved_at'] as String).toUtc(),
    );
  }

  @override
  String toString() =>
      'BattleTurn(id: $id, battleId: $battleId, turnNumber: $turnNumber, '
      'navalOutcome: $navalOutcome, landOutcome: $landOutcome)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BattleTurn &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
