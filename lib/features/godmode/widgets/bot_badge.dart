import 'package:flutter/material.dart';

/// A small pill-shaped badge that labels a player as a bot.
///
/// Renders an orange "BOT" label with white bold text. Intended to be
/// placed inline next to the player's display name in the player table.
class BotBadge extends StatelessWidget {
  const BotBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'BOT',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
