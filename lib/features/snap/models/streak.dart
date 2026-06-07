import 'package:supabase_flutter/supabase_flutter.dart';

class SnapStreak {
  final String id;
  final String user1Id;
  final String user2Id;
  final int streakCount;
  final int brokenStreakCount;
  final bool isRestoreable;
  final DateTime? restoreDeadline;
  final int restoreCount;

  SnapStreak({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.streakCount,
    required this.brokenStreakCount,
    required this.isRestoreable,
    this.restoreDeadline,
    required this.restoreCount,
  });

  factory SnapStreak.fromMap(Map<String, dynamic> map) {
    return SnapStreak(
      id: map['id'],
      user1Id: map['user1_id'],
      user2Id: map['user2_id'],
      streakCount: map['streak_count'] ?? 0,
      brokenStreakCount: map['broken_streak_count'] ?? 0,
      isRestoreable: map['is_restoreable'] ?? false,
      restoreDeadline: map['restore_deadline'] != null
          ? DateTime.parse(map['restore_deadline'])
          : null,
      restoreCount: map['restore_count'] ?? 0,
    );
  }

  bool get canBeRestored {
    if (!isRestoreable || restoreDeadline == null) return false;
    return DateTime.now().isBefore(restoreDeadline!);
  }

  Duration? get timeUntilDeadline {
    if (restoreDeadline == null) return null;
    final diff = restoreDeadline!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }
}
