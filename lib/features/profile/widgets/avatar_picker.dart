import 'package:flutter/material.dart';

import '../../../core/constants/avatar_constants.dart';
import '../../../shared/widgets/avatar_widget.dart';

/// Displays a grid of all 20 selectable avatars.
///
/// Each avatar is rendered as an [AvatarWidget] with its label below.
/// Tapping an avatar triggers [onAvatarSelected] with the chosen avatar id.
/// The currently selected avatar (identified by [selectedAvatarId]) is
/// highlighted with a ring via [AvatarWidget.isSelected].
///
/// Column count adapts to screen width:
///   - narrow screens (< 600 px): 5 columns
///   - wider screens            : 4 columns
class AvatarPicker extends StatelessWidget {
  const AvatarPicker({
    super.key,
    required this.selectedAvatarId,
    required this.onAvatarSelected,
  });

  /// The currently selected avatar id (1–20).
  final int selectedAvatarId;

  /// Called with the new avatar id when the user taps an avatar.
  final ValueChanged<int> onAvatarSelected;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600 ? 5 : 4;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: AvatarConstants.avatars.length,
      itemBuilder: (context, index) {
        final entry = AvatarConstants.avatars[index];
        final isSelected = entry.id == selectedAvatarId;

        return GestureDetector(
          onTap: () => onAvatarSelected(entry.id),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AvatarWidget(
                avatarId: entry.id,
                size: 44,
                isSelected: isSelected,
              ),
              const SizedBox(height: 4),
              Text(
                entry.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}
