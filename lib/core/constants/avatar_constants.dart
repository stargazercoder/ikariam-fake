import 'package:flutter/material.dart';

/// An avatar entry combining an id, label, and icon placeholder.
/// In v1 icons are used; later phases can replace with image assets.
class AvatarEntry {
  const AvatarEntry({
    required this.id,
    required this.label,
    required this.icon,
  });

  final int id;
  final String label;
  final IconData icon;
}

/// 20 preset avatars with ancient Greek deity names.
class AvatarConstants {
  AvatarConstants._();

  static const List<AvatarEntry> avatars = [
    AvatarEntry(id: 1,  label: 'Zeus',        icon: Icons.bolt),
    AvatarEntry(id: 2,  label: 'Athena',      icon: Icons.shield),
    AvatarEntry(id: 3,  label: 'Poseidon',    icon: Icons.waves),
    AvatarEntry(id: 4,  label: 'Ares',        icon: Icons.sports_martial_arts),
    AvatarEntry(id: 5,  label: 'Apollo',      icon: Icons.wb_sunny),
    AvatarEntry(id: 6,  label: 'Artemis',     icon: Icons.nightlight_round),
    AvatarEntry(id: 7,  label: 'Hermes',      icon: Icons.send),
    AvatarEntry(id: 8,  label: 'Hephaestus', icon: Icons.local_fire_department),
    AvatarEntry(id: 9,  label: 'Aphrodite',   icon: Icons.favorite),
    AvatarEntry(id: 10, label: 'Demeter',     icon: Icons.eco),
    AvatarEntry(id: 11, label: 'Hera',        icon: Icons.star),
    AvatarEntry(id: 12, label: 'Dionysus',    icon: Icons.local_bar),
    AvatarEntry(id: 13, label: 'Hades',       icon: Icons.dark_mode),
    AvatarEntry(id: 14, label: 'Persephone',  icon: Icons.local_florist),
    AvatarEntry(id: 15, label: 'Helios',      icon: Icons.light_mode),
    AvatarEntry(id: 16, label: 'Selene',      icon: Icons.nightlight),
    AvatarEntry(id: 17, label: 'Nike',        icon: Icons.emoji_events),
    AvatarEntry(id: 18, label: 'Tyche',       icon: Icons.casino),
    AvatarEntry(id: 19, label: 'Eros',        icon: Icons.favorite_border),
    AvatarEntry(id: 20, label: 'Pan',         icon: Icons.forest),
  ];

  /// Returns the avatar entry for the given id, or the first entry as default.
  static AvatarEntry getById(int id) {
    return avatars.firstWhere(
      (a) => a.id == id,
      orElse: () => avatars.first,
    );
  }
}
