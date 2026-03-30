import 'user.dart';

class MemeGame {
  final String id;
  final String creatorId;
  final String imageUrl;
  final String? caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isActive;
  final AppUser? creator;

  MemeGame({
    required this.id,
    required this.creatorId,
    required this.imageUrl,
    this.caption,
    required this.createdAt,
    required this.expiresAt,
    required this.isActive,
    this.creator,
  });

  factory MemeGame.fromJson(Map<String, dynamic> json) {
    return MemeGame(
      id: json['id'],
      creatorId: json['creator_id'],
      imageUrl: json['image_url'],
      caption: json['caption'],
      createdAt: DateTime.parse(json['created_at']),
      expiresAt: DateTime.parse(json['expires_at']),
      isActive: json['is_active'] ?? true,
      creator: json['profiles'] != null ? AppUser.fromJson(json['profiles']) : null,
    );
  }
}

class MemeComment {
  final String id;
  final String memeId;
  final String userId;
  final String comment;
  int upvotes;
  final DateTime createdAt;
  final AppUser? user;
  bool isUpvotedByMe;

  MemeComment({
    required this.id,
    required this.memeId,
    required this.userId,
    required this.comment,
    required this.upvotes,
    required this.createdAt,
    this.user,
    this.isUpvotedByMe = false,
  });

  factory MemeComment.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final votes = json['comment_votes'] as List?;
    final isUpvoted = currentUserId != null && 
        votes != null && 
        votes.any((v) => v['user_id'] == currentUserId);

    return MemeComment(
      id: json['id'],
      memeId: json['meme_id'],
      userId: json['user_id'],
      comment: json['comment'],
      upvotes: json['upvotes'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      user: json['profiles'] != null ? AppUser.fromJson(json['profiles']) : null,
      isUpvotedByMe: isUpvoted,
    );
  }
}
