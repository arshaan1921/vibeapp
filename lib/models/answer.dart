class AnswerModel {
  final String id;
  final String userId;
  final String text;
  final String? avatarUrl;
  final String username;
  final String? premiumPlan;
  final bool isVerified;
  final bool isFounder;
  final int? streakCount;
  final DateTime createdAt;
  final String questionText;
  final String? questionImageUrl;
  final bool isAnonymous;
  final String? askerUsername;
  final String? askerId;
  final bool isPinned;
  int likeCount;
  bool isLiked;

  AnswerModel({
    required this.id,
    required this.userId,
    required this.text,
    this.avatarUrl,
    required this.username,
    this.premiumPlan,
    this.isVerified = false,
    this.isFounder = false,
    this.streakCount,
    required this.createdAt,
    required this.questionText,
    this.questionImageUrl,
    required this.isAnonymous,
    this.askerUsername,
    this.askerId,
    this.isPinned = false,
    this.likeCount = 0,
    this.isLiked = false,
  });

  factory AnswerModel.fromMap(Map<String, dynamic> map, {bool? isLiked, int? likeCount}) {
    var profileData = map['profiles'];
    Map<String, dynamic>? profile;
    if (profileData is List && profileData.isNotEmpty) {
      profile = profileData.first;
    } else if (profileData is Map<String, dynamic>) {
      profile = profileData;
    }

    var questionData = map['questions'];
    Map<String, dynamic>? question;
    if (questionData is List && questionData.isNotEmpty) {
      question = questionData.first;
    } else if (questionData is Map<String, dynamic>) {
      question = questionData;
    }

    // Handle nested asker profile
    final askerData = question?['asker'] ?? question?['profiles'];
    Map<String, dynamic>? asker;
    if (askerData is List && askerData.isNotEmpty) {
      asker = (askerData as List).first;
    } else if (askerData is Map<String, dynamic>) {
      asker = askerData;
    }

    return AnswerModel(
      id: map['id'].toString(),
      userId: map['user_id']?.toString() ?? '',
      text: map['answer_text'] ?? '',
      avatarUrl: profile?['avatar_url'],
      username: profile?['username'] ?? 'User',
      premiumPlan: profile?['premium_plan'],
      isVerified: profile?['is_verified'] ?? false,
      isFounder: profile?['is_founder'] ?? false,
      streakCount: profile?['streak_count'],
      createdAt: DateTime.parse(map['created_at']),
      questionText: question?['text'] ?? '',
      questionImageUrl: question?['image_url'],
      isAnonymous: question?['is_anonymous'] ?? false,
      askerUsername: asker?['username'],
      askerId: asker?['id'],
      isPinned: map['is_pinned'] ?? false,
      likeCount: likeCount ?? (map['likes_count'] is int ? map['likes_count'] : 0),
      isLiked: isLiked ?? false,
    );
  }

  AnswerModel copyWith({bool? isLiked, int? likeCount, bool? isPinned, int? streakCount}) {
    return AnswerModel(
      id: id,
      userId: userId,
      text: text,
      avatarUrl: avatarUrl,
      username: username,
      premiumPlan: premiumPlan,
      isVerified: isVerified,
      isFounder: isFounder,
      streakCount: streakCount ?? this.streakCount,
      createdAt: createdAt,
      questionText: questionText,
      questionImageUrl: questionImageUrl,
      isAnonymous: isAnonymous,
      askerUsername: askerUsername,
      askerId: askerId,
      isPinned: isPinned ?? this.isPinned,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}