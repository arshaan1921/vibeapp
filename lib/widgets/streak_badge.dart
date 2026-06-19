import 'dart:async';
import 'package:flutter/material.dart';
import '../features/snap/models/streak.dart';

class StreakBadge extends StatefulWidget {
  final SnapStreak? streakData;
  final double fontSize;
  final Color? color;
  final Color? activeColor;
  final Color? brokenColor;
  final FontWeight? fontWeight;

  const StreakBadge({
    super.key,
    this.streakData,
    this.fontSize = 12,
    this.color,
    this.activeColor,
    this.brokenColor,
    this.fontWeight,
  });

  @override
  State<StreakBadge> createState() => _StreakBadgeState();
}

class _StreakBadgeState extends State<StreakBadge> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    // Check every minute to see if hourglass should appear/disappear
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.streakData == null) return const SizedBox.shrink();

    final streak = widget.streakData!.streakCount;
    final brokenStreak = widget.streakData!.brokenStreakCount;
    final canBeRestored = widget.streakData!.canBeRestored;
    final showHourglass = widget.streakData!.shouldShowHourglass;

    if (streak > 0) {
      return Text(
        "$streak🔥${showHourglass ? '⌛' : ''}",
        style: TextStyle(
          fontSize: widget.fontSize,
          fontWeight: widget.fontWeight ?? FontWeight.bold,
          color: widget.color ?? widget.activeColor ?? Colors.orange,
        ),
      );
    } else if (brokenStreak > 0 && canBeRestored) {
      return Text(
        "${brokenStreak}💔",
        style: TextStyle(
          fontSize: widget.fontSize,
          fontWeight: widget.fontWeight ?? FontWeight.bold,
          color: widget.color ?? widget.brokenColor ?? Colors.redAccent,
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
