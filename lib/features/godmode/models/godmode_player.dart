/// GodmodePlayer — parsed representation of one player entry from
/// the godmode_get_world_state() RPC response.
///
/// Response shape (from godmode_get_world_state JSONB):
/// ```json
/// {
///   "id": "...", "display_name": "...", "is_bot": true, "is_paused": false,
///   "resources": {"wood": 1000, "marble": 500, "crystal": 200, "sulfur": 100, "gold": 800},
///   "army": {"land_count": 120, "naval_count": 30},
///   "buildings": {"town_hall": 3, "barracks": 2},
///   "active_battles": [{"battle_id": "...", "attacker_name": "...", "defender_name": "...", "current_turn": 2}]
/// }
/// ```
class GodmodePlayer {
  GodmodePlayer({
    required this.id,
    required this.displayName,
    required this.isBot,
    required this.isPaused,
    required this.resources,
    required this.landCount,
    required this.navalCount,
    required this.buildingCount,
    required this.activeBattleCount,
    required this.activeBattles,
    required this.buildings,
  });

  final String id;
  final String displayName;
  final bool isBot;

  /// Whether the bot's decision cycle is paused. Always false for human players
  /// (bot_schedules has no row for humans, so is_paused will be null in JSON).
  final bool isPaused;

  /// Resource map with keys: wood, marble, crystal, sulfur, gold.
  final Map<String, dynamic> resources;

  final int landCount;
  final int navalCount;

  /// Number of buildings this player has constructed (map length).
  final int buildingCount;

  /// Number of currently active battles this player is involved in.
  final int activeBattleCount;

  /// Raw battle data list for potential detail display.
  final List<Map<String, dynamic>> activeBattles;

  /// Raw building data map for potential detail display.
  final Map<String, dynamic> buildings;

  /// Sum of all resource values as an integer, useful for sorting.
  int get totalResources {
    if (resources.isEmpty) return 0;
    return resources.values
        .map((v) => (v as num).toInt())
        .fold(0, (sum, v) => sum + v);
  }

  factory GodmodePlayer.fromJson(Map<String, dynamic> json) {
    final army = json['army'] as Map<String, dynamic>? ?? {};
    final buildingsMap = json['buildings'] as Map<String, dynamic>? ?? {};
    final battlesRaw = json['active_battles'] as List<dynamic>? ?? [];

    return GodmodePlayer(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? '—',
      isBot: (json['is_bot'] as bool?) ?? false,
      isPaused: (json['is_paused'] as bool?) ?? false,
      resources: json['resources'] as Map<String, dynamic>? ?? {},
      landCount: (army['land_count'] as num?)?.toInt() ?? 0,
      navalCount: (army['naval_count'] as num?)?.toInt() ?? 0,
      buildingCount: buildingsMap.length,
      activeBattleCount: battlesRaw.length,
      activeBattles: battlesRaw
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      buildings: buildingsMap,
    );
  }

  @override
  String toString() =>
      'GodmodePlayer(id: $id, displayName: $displayName, isBot: $isBot)';
}
