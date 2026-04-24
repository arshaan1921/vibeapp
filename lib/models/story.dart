enum StoryMediaType { image, video }

class StoryModel {
  final String id;
  final String userId;
  final String mediaUrl;
  final StoryMediaType mediaType;
  final String? caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isLiked;
  final int viewsCount;

  StoryModel({
    required this.id,
    required this.userId,
    required this.mediaUrl,
    required this.mediaType,
    this.caption,
    required this.createdAt,
    required this.expiresAt,
    this.isLiked = false,
    this.viewsCount = 0,
  });

  factory StoryModel.fromMap(Map<String, dynamic> map, {bool isLiked = false}) {
    return StoryModel(
      id: map['id'].toString(),
      userId: map['user_id'],
      mediaUrl: map['media_url'],
      mediaType: map['media_type'] == 'video' ? StoryMediaType.video : StoryMediaType.image,
      caption: map['caption'],
      createdAt: DateTime.parse(map['created_at']),
      expiresAt: DateTime.parse(map['expires_at']),
      isLiked: isLiked,
      viewsCount: map['views_count'] ?? 0,
    );
  }
}

class UserStories {
  final String userId;
  final String username;
  final String? avatarUrl;
  final List<StoryModel> stories;
  bool allSeen;

  UserStories({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.stories,
    this.allSeen = false,
  });
}
