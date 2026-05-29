class AiCompanion {
  final String id;
  final String userId;
  final String name;
  final String purpose;
  final List<String> personalities;
  final String communicationStyle;
  final String relationshipTone;
  final String? avatarUrl;
  final DateTime createdAt;
  final int dailyMessageCount;
  final bool isPremium;
  final int messageLimit;
  final DateTime lastResetDate;

  AiCompanion({
    required this.id,
    required this.userId,
    required this.name,
    required this.purpose,
    required this.personalities,
    required this.communicationStyle,
    required this.relationshipTone,
    this.avatarUrl,
    required this.createdAt,
    required this.dailyMessageCount,
    required this.isPremium,
    required this.messageLimit,
    required this.lastResetDate,
  });

  factory AiCompanion.fromMap(Map<String, dynamic> map) {
    return AiCompanion(
      id: map['id'],
      userId: map['user_id'],
      name: map['name'],
      purpose: map['purpose'],
      personalities: List<String>.from(map['personalities'] ?? []),
      communicationStyle: map['communication_style'] ?? '',
      relationshipTone: map['relationship_tone'] ?? '',
      avatarUrl: map['avatar_url'],
      createdAt: DateTime.parse(map['created_at']),
      dailyMessageCount: map['daily_message_count'] ?? 0,
      isPremium: map['is_premium'] ?? false,
      messageLimit: map['message_limit'] ?? 30,
      lastResetDate: map['last_reset_date'] != null 
          ? DateTime.parse(map['last_reset_date']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'name': name,
      'purpose': purpose,
      'personalities': personalities,
      'communication_style': communicationStyle,
      'relationship_tone': relationshipTone,
      'avatar_url': avatarUrl,
      'daily_message_count': dailyMessageCount,
      'is_premium': isPremium,
      'message_limit': messageLimit,
      'last_reset_date': lastResetDate.toIso8601String().split('T')[0],
    };
  }
}
