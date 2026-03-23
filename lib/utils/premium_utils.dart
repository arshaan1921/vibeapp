import 'package:flutter/material.dart';

class PremiumUtils {
  static int getQuestionLimit(String? plan) {
    switch (plan) {
      case 'green':
        return 50;
      case 'blue':
      case 'gold':
        return 999999; // Practically unlimited
      default:
        return 10; // free plan
    }
  }

  static Color? getBadgeColor(String? plan) {
    switch (plan) {
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      case 'gold':
        return const Color(0xFFFFD700); // Gold
      default:
        return null;
    }
  }

  static Color getRingColor(String? plan) {
    switch (plan) {
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      case 'gold':
        return const Color(0xFFFFD700); // Gold
      default:
        return Colors.transparent;
    }
  }

  static Widget buildBadge(String? plan) {
    final color = getBadgeColor(plan);
    if (color == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Icon(Icons.star, color: color, size: 14),
    );
  }

  static Decoration buildProfileRing(String? plan, {double width = 2.0}) {
    final color = getRingColor(plan);
    if (color == Colors.transparent) return const BoxDecoration();
    return BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color, width: width),
    );
  }
}
