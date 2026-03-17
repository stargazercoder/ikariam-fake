import 'dart:async';

import 'package:flutter/material.dart';

/// Displays a live "Xs ago" counter that ticks every second.
///
/// Pass [since] as the reference timestamp. The widget calculates the
/// initial elapsed seconds from [DateTime.now()] and increments by 1
/// every second via a [Timer.periodic] ticker.
class ElapsedTimerText extends StatefulWidget {
  const ElapsedTimerText({super.key, required this.since});

  final DateTime since;

  @override
  State<ElapsedTimerText> createState() => _ElapsedTimerTextState();
}

class _ElapsedTimerTextState extends State<ElapsedTimerText> {
  Timer? _timer;
  int _elapsed = 0;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.since).inSeconds;
    _startTimer();
  }

  @override
  void didUpdateWidget(ElapsedTimerText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.since != oldWidget.since) {
      _timer?.cancel();
      _elapsed = DateTime.now().difference(widget.since).inSeconds;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed++;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${_elapsed}s ago',
      style: const TextStyle(fontSize: 12, color: Colors.white70),
    );
  }
}
