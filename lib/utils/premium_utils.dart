import 'package:flutter/material.dart';

class PremiumUtils {
  // =========================
  // CHECK PREMIUM STATUS
  // =========================

  static bool isPremium(String? plan) {
    return plan != null && plan != 'free';
  }

  // =========================
  // QUESTION LIMITS
  // =========================

  static int getQuestionLimit(String? plan) {
    switch (plan) {
      case 'green':
        return 50;

      case 'blue':
      case 'gold':
      case 'yellow':
        return 999999; // Unlimited questions

      default:
        return 10; // Free plan
    }
  }

  // =========================
  // AI COMPANION LIMITS
  // =========================

  static int getAiMessageLimit(String? plan) {
    switch (plan) {
      case 'green':
        return 100;

      case 'blue':
        return 300;

      case 'gold':
      case 'yellow':
        return 1000;

      default:
        return 20; // Free plan
    }
  }

  // =========================
  // CHECK QUESTION LIMIT
  // =========================

  static bool canAskQuestion({
    required String? plan,
    required int questionsToday,
    required int boosterRemaining,
  }) {
    final limit = getQuestionLimit(plan);

    // Unlimited plans
    if (limit >= 999999) return true;

    // Daily limit not reached
    if (questionsToday < limit) return true;

    // Booster exists
    if (boosterRemaining > 0) return true;

    return false;
  }

  // =========================
  // CHECK AI LIMIT
  // =========================

  static bool canSendAiMessage({
    required String? plan,
    required int aiMessagesToday,
    required int boosterRemaining,
  }) {
    final limit = getAiMessageLimit(plan);

    // Unlimited-ish premium plans
    if (limit >= 999999) return true;

    // Within daily AI limit
    if (aiMessagesToday < limit) return true;

    // AI booster available
    if (boosterRemaining > 0) return true;

    return false;
  }

  // =========================
  // BADGE COLORS
  // =========================

  static Color? getBadgeColor(String? plan) {
    switch (plan) {
      case 'green':
        return Colors.green;

      case 'blue':
        return Colors.blue;

      case 'gold':
      case 'yellow':
        return const Color(0xFFFFD700);

      default:
        return null;
    }
  }

  // =========================
  // RING COLORS
  // =========================

  static Color getRingColor(String? plan) {
    switch (plan) {
      case 'green':
        return Colors.green;

      case 'blue':
        return Colors.blue;

      case 'gold':
      case 'yellow':
        return const Color(0xFFFFD700);

      default:
        return Colors.transparent;
    }
  }

  // =========================
  // PREMIUM BADGE
  // =========================

  static Widget buildBadge(String? plan) {
    final color = getBadgeColor(plan);

    if (color == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Icon(
        Icons.star,
        color: color,
        size: 14,
      ),
    );
  }

  // =========================
  // PROFILE RING
  // =========================

  static Decoration buildProfileRing(
      String? plan, {
        double width = 2.0,
      }) {
    final color = getRingColor(plan);

    if (color == Colors.transparent) {
      return const BoxDecoration();
    }

    return BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: color,
        width: width,
      ),
    );
  }
}