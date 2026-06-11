import 'package:flutter/material.dart';

class AnimatedStreakFlame extends StatelessWidget {
  final int streakCount;
  final double size;
  final bool forceStatic;

  const AnimatedStreakFlame({
    super.key,
    required this.streakCount,
    this.size = 20,
    this.forceStatic = false,
  });

  @override
  Widget build(BuildContext context) {
    // Reverting to the standard fire emoji as requested.
    return Text(
      "🔥",
      style: TextStyle(
        fontSize: size * 0.8,
      ),
    );
  }
}
