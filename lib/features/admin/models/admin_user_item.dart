class AdminUserItem {
  final String id;
  final String username;
  final String? name;
  final String? avatarUrl;
  final DateTime? createdAt;
  final bool isBanned;
  final DateTime? bannedUntil;
  final String? banReason;
  final bool isShadowBanned;
  final int strikeCount;
  final int reportCount;

  const AdminUserItem({
    required this.id,
    required this.username,
    this.name,
    this.avatarUrl,
    this.createdAt,
    this.isBanned = false,
    this.bannedUntil,
    this.banReason,
    this.isShadowBanned = false,
    this.strikeCount = 0,
    this.reportCount = 0,
  });

  bool get isSuperAdmin =>
      id == '084ed6d9-7354-4301-9c73-d7f4a6a22a19' ||
      username.toLowerCase() == 'high5';

  /// Evaluates if account is currently suspended/banned considering temporary ban expiration
  bool get isCurrentlyBanned {
    if (!isBanned) return false;
    if (bannedUntil != null && DateTime.now().toUtc().isAfter(bannedUntil!)) {
      return false; // Ban expired
    }
    return true;
  }

  // Alias getters for backwards compatibility
  bool get isSuspended => isCurrentlyBanned;
  DateTime? get suspendedUntil => bannedUntil;
  String? get suspensionReason => banReason;

  factory AdminUserItem.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return null;
      }
    }

    final bool rawBanned =
        map['is_banned'] == true || map['is_suspended'] == true;
    final DateTime? until =
        parseDate(map['banned_until'] ?? map['suspended_until']);

    return AdminUserItem(
      id: map['id']?.toString() ?? '',
      username: map['username']?.toString() ?? 'user',
      name: map['name']?.toString(),
      avatarUrl: map['avatar_url']?.toString(),
      createdAt: parseDate(map['created_at']),
      isBanned: rawBanned,
      bannedUntil: until,
      banReason:
          map['ban_reason']?.toString() ?? map['suspension_reason']?.toString(),
      isShadowBanned: map['is_shadow_banned'] == true,
      strikeCount: (map['strike_count'] as num?)?.toInt() ?? 0,
      reportCount: (map['report_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class UserDetailStats {
  final int answersCount;
  final int questionsCount;
  final int snapsCount;
  final int reportsCount;

  const UserDetailStats({
    this.answersCount = 0,
    this.questionsCount = 0,
    this.snapsCount = 0,
    this.reportsCount = 0,
  });
}
