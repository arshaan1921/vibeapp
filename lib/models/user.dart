class AppUser {
  final String id;
  final String username;
  final String? bio;
  final String? avatarUrl;
  final int? questionsCount;
  final int? answersCount;
  final int? likesCount;
  final String? name;

  AppUser({
    required this.id,
    required this.username,
    this.bio,
    this.avatarUrl,
    this.questionsCount,
    this.answersCount,
    this.likesCount,
    this.name,
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
    );
  }
}
