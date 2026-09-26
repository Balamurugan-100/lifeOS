import 'dart:async';

import 'package:flutter/material.dart';

/// Trims a tracked duration for display: `45m`, `1h 20m`, `2h 05m`.
///
/// Short enough for a chip or a list row; the minute is always padded so
/// columns of durations line up.
String formatTracked(Duration d) {
  final total = d.isNegative ? Duration.zero : d;
  if (total.inHours == 0) return '${total.inMinutes}m';
  final rest = total.inMinutes.remainder(60).toString().padLeft(2, '0');
  return '${total.inHours}h $rest}m';
}

/// `mm:ss`, widening to `h:mm:ss` only past an hour.
String formatClock(Duration d) {
  final total = d.isNegative ? Duration.zero : d;
  final h = total.inHours;
  final m = total.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = total.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// Rebuilds [builder] once a second while mounted.
///
/// Deliberately opt-in: only mount it around something that is genuinely
/// running. A live `Stopwatch` beats scheduling a rebuild from the session's
/// `startedAt` because it stays correct across app backgrounding and clock
/// adjustments, and it costs nothing when the timer is stopped because the
/// widget simply is not in the tree.
class TickingTimer extends StatefulWidget {
  const TickingTimer({super.key, required this.builder});

  final Widget Function(Duration elapsed) builder;

  @override
  State<TickingTimer> createState() => _TickingTimerState();
}

class _TickingTimerState extends State<TickingTimer> {
  final Stopwatch _stopwatch = Stopwatch()..start();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    _stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_stopwatch.elapsed);
}
