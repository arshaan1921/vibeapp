class AppUser {
  final String id;
  final String username;
  final String? bio;
  final String? avatarUrl;
  final int? questionsCount;
  final int? answersCount;
  final int? likesCount;
  final String? name;
  final bool isOnline;
  final DateTime? lastSeen;

  AppUser({
    required this.id,
    required this.username,
    this.bio,
    this.avatarUrl,
    this.questionsCount,
    this.answersCount,
    this.likesCount,
    this.name,
    this.isOnline = false,
    this.lastSeen,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'],
      username: json['username'] ?? '',
      avatarUrl: json['avatar_url'],
      bio: json['bio'],
      name: json['name'],
      questionsCount: json['questions_count'],
      answersCount: json['answers_count'],
      likesCount: json['likes_count'],
      isOnline: json['is_online'] ?? false,
      lastSeen: json['last_seen'] != null ? DateTime.parse(json['last_seen']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'bio': bio,
      'avatar_url': avatarUrl,
      'name': name,
      'is_online': isOnline,
      'last_seen': lastSeen?.toIso8601String(),
    };
  }
}
