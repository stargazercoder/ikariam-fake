import 'package:flutter/material.dart';

import '../../core/constants/avatar_constants.dart';
import '../../core/theme/app_theme.dart';

/// Reusable widget that renders a single avatar as a coloured circle.
///
/// The circle colour is derived from [avatarId] so each avatar has a
/// consistent, deterministic colour across the app.
///
/// When [isSelected] is true a navy-blue ring (matching the app primary
/// colour) is drawn around the circle.
class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    super.key,
    required this.avatarId,
    this.size = 48,
    this.isSelected = false,
  });

  /// The avatar id (1–20) that maps to an [AvatarEntry] in [AvatarConstants].
  final int avatarId;

  /// Diameter of the circle in logical pixels. Defaults to 48.
  final double size;

  /// When true a selection ring is drawn around the circle.
  final bool isSelected;

  /// Palette of background colours — one per avatar slot.
  static const List<Color> _avatarColors = [
    Color(0xFF1565C0), // Zeus        — deep blue
    Color(0xFF558B2F), // Athena      — olive green
    Color(0xFF0277BD), // Poseidon    — ocean blue
    Color(0xFFB71C1C), // Ares        — war red
    Color(0xFFF57F17), // Apollo      — sun amber
    Color(0xFF4A148C), // Artemis     — moonlit purple
    Color(0xFF00695C), // Hermes      — teal
    Color(0xFFBF360C), // Hephaestus — forge orange
    Color(0xFFAD1457), // Aphrodite   — rose
    Color(0xFF2E7D32), // Demeter     — earth green
    Color(0xFF6A1B9A), // Hera        — regal purple
    Color(0xFF4E342E), // Dionysus    — wine brown
    Color(0xFF212121), // Hades       — charcoal
    Color(0xFF00838F), // Persephone  — spring cyan
    Color(0xFFE65100), // Helios      — blazing orange
    Color(0xFF37474F), // Selene      — slate grey
    Color(0xFFC6A700), // Nike        — victory gold
    Color(0xFF00796B), // Tyche       — fortune teal
    Color(0xFFE91E63), // Eros        — love pink
    Color(0xFF388E3C), // Pan         — forest green
  ];

  Color get _color {
    final index = (avatarId - 1).clamp(0, _avatarColors.length - 1);
    return _avatarColors[index];
  }

  @override
  Widget build(BuildContext context) {
    final entry = AvatarConstants.getById(avatarId);
    final initial = entry.label.isNotEmpty ? entry.label[0] : '?';

    return Container(
      width: size + (isSelected ? 6 : 0),
      height: size + (isSelected ? 6 : 0),
      decoration: isSelected
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primaryColor,
                width: 3,
              ),
            )
          : null,
      child: Padding(
        padding: EdgeInsets.all(isSelected ? 2 : 0),
        child: CircleAvatar(
          radius: size / 2,
          backgroundColor: _color,
          child: Icon(
            entry.icon,
            color: Colors.white,
            size: size * 0.5,
            semanticLabel: initial,
          ),
        ),
      ),
    );
  }
}
