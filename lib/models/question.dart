class Question {
  final String id;
  final String text;
  final String authorName;
  final String authorAvatar;
  final bool isAnonymous;
  final DateTime createdAt;
  final String? imageUrl;

  Question({
    required this.id,
    required this.text,
    required this.authorName,
    required this.authorAvatar,
    required this.isAnonymous,
    required this.createdAt,
    this.imageUrl,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'],
      text: json['text'],
      authorName: json['from_user'] ?? 'Anonymous',
      authorAvatar: '',
      isAnonymous: json['is_anonymous'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      imageUrl: json['image_url'],
    );
  }
}
