import 'package:flutter/material.dart';

/// Reusable widget that wraps [child] with a semi-transparent loading overlay.
///
/// When [isLoading] is true a full-screen [Stack] with a darkened scrim and
/// a centred [CircularProgressIndicator] is shown on top of [child].
/// User interaction with [child] is blocked while loading, preventing
/// accidental double-taps on submit buttons.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.4),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}
