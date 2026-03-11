// Standalone countdown timer widget that ticks every second.
// Display-only — the server (pg_cron) handles actual construction completion.

import 'dart:async';

import 'package:flutter/material.dart';

/// Displays a live countdown timer that ticks once per second.
///
/// The server (pg_cron complete_building_upgrades) handles actual completion.
/// This widget only provides a display-only countdown derived from [finishAt].
/// When the countdown reaches zero the widget shows "00:00:00" and stops.
class CountdownTimerWidget extends StatefulWidget {
  const CountdownTimerWidget({
    super.key,
    required this.finishAt,
    this.style,
    this.onComplete,
  });

  /// UTC time when the construction finishes.
  final DateTime finishAt;

  /// Text style for the countdown string.
  final TextStyle? style;

  /// Optional callback fired once when the countdown reaches zero.
  final VoidCallback? onComplete;

  @override
  State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<CountdownTimerWidget> {
  late Timer _timer;
  Duration _remaining = Duration.zero;
  bool _completeFired = false;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateRemaining();
      }
    });
  }

  @override
  void didUpdateWidget(CountdownTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.finishAt != widget.finishAt) {
      _completeFired = false;
      _updateRemaining();
    }
  }

  void _updateRemaining() {
    final remaining =
        widget.finishAt.toUtc().difference(DateTime.now().toUtc());
    setState(() {
      _remaining = remaining.isNegative ? Duration.zero : remaining;
    });
    if (_remaining == Duration.zero && !_completeFired) {
      _completeFired = true;
      widget.onComplete?.call();
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _format(_remaining),
      style: widget.style ??
          Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFeatures: [const FontFeature.tabularFigures()],
                fontWeight: FontWeight.w600,
              ),
    );
  }
}
